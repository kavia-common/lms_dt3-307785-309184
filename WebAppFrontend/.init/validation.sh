#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
# idempotent headless env
PROFILE=/etc/profile.d/react_headless.sh
sudo bash -lc "cat > $PROFILE <<'EOF'\nexport NODE_ENV=development\nexport CI=true\nEOF" || true
export NODE_ENV=development
export CI=true
command -v curl >/dev/null 2>&1 || { echo 'curl required' >&2; exit 2; }
# choose RUN_USER
RUN_USER=$(awk -F: '($3>=1000)&&($1!="nobody"){print $1; exit}' /etc/passwd || echo devuser)
# cleanup stale files
rm -f /tmp/webapp_serve.pid /tmp/webapp_dev.pid /tmp/webapp_serve.out /tmp/webapp_dev.out || true
# Build production artifacts explicitly with production env
NODE_ENV=production CI=true npm run build --silent
# Ensure build exists and owned by non-root
sudo chown -R "$RUN_USER":"$RUN_USER" "$WORKSPACE/build" || true
# Serve build: prefer local binary
PORT=5000
if [ -x ./node_modules/.bin/serve ]; then
  sudo -u "$RUN_USER" bash -lc "setsid ./node_modules/.bin/serve -s build -l $PORT > /tmp/webapp_serve.out 2>&1 & echo \$! > /tmp/webapp_serve.pid"
else
  if command -v npx >/dev/null 2>&1; then
    sudo -u "$RUN_USER" bash -lc "setsid bash -lc 'npx --yes serve -s build -l $PORT' > /tmp/webapp_serve.out 2>&1 & echo \$! > /tmp/webapp_serve.pid"
  else
    echo 'serve not available locally and npx missing' >&2; exit 3
  fi
fi
SERVE_PID=$(cat /tmp/webapp_serve.pid 2>/dev/null || echo '')
# Wait for availability
TRIES=12; i=0; until curl -sSf --max-time 3 "http://localhost:$PORT/" >/dev/null 2>&1 || [ $i -ge $TRIES ]; do sleep 1; i=$((i+1)); done
if ! curl -sSf --max-time 3 "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo 'Production build not reachable' >&2; tail -n 200 /tmp/webapp_serve.out || true; [ -n "$SERVE_PID" ] && kill "$SERVE_PID" >/dev/null 2>&1 || true; exit 4
fi
# Stop serve gracefully (use PGID if available)
if [ -n "$SERVE_PID" ]; then
  PGID=$(ps -o pgid= -p "$SERVE_PID" | tr -d ' ' || true)
  [ -n "$PGID" ] && sudo kill -TERM -"$PGID" >/dev/null 2>&1 || sudo kill -TERM "$SERVE_PID" >/dev/null 2>&1 || true
  sleep 1
  [ -n "$PGID" ] && sudo kill -0 -"$PGID" >/dev/null 2>&1 && sudo kill -KILL -"$PGID" >/dev/null 2>&1 || true
fi
# Start CRA dev server as non-root user, force PORT to avoid prompts
PORT=3000
sudo chown -R "$RUN_USER":"$RUN_USER" "$WORKSPACE" || true
WRAPPER="$WORKSPACE/.start_dev.sh"
cat > "$WRAPPER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "${1}"
export PORT=${2}
export CI=true
setsid npm run start > /tmp/webapp_dev.out 2>&1 &
echo $! >/tmp/webapp_dev.pid
SH
sudo chown "$RUN_USER":"$RUN_USER" "$WRAPPER"
sudo chmod +x "$WRAPPER"
# Start wrapper as RUN_USER
sudo -u "$RUN_USER" bash -lc "$WRAPPER '$WORKSPACE' $PORT" || { echo 'failed to start dev server' >&2; exit 5; }
DEV_PID=$(cat /tmp/webapp_dev.pid 2>/dev/null || echo '')
# Wait for dev server
TRIES=30; i=0; until curl -sSf --max-time 3 "http://localhost:$PORT/" >/dev/null 2>&1 || [ $i -ge $TRIES ]; do sleep 1; i=$((i+1)); done
if ! curl -sSf --max-time 3 "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo 'Dev server did not respond on port 3000' >&2; tail -n 300 /tmp/webapp_dev.out || true; [ -n "$DEV_PID" ] && sudo kill -TERM "$DEV_PID" >/dev/null 2>&1 || true; exit 6
fi
# Evidence
echo "build_exists=$( [ -d build ] && echo yes || echo no )"
curl -sSf --max-time 3 "http://localhost:$PORT/" | head -c 200 || true
# Stop dev server gracefully using PGID when possible
if [ -n "$DEV_PID" ]; then
  PGID=$(ps -o pgid= -p "$DEV_PID" | tr -d ' ' || true)
  [ -n "$PGID" ] && sudo kill -TERM -"$PGID" >/dev/null 2>&1 || sudo kill -TERM "$DEV_PID" >/dev/null 2>&1 || true
  sleep 2
  [ -n "$PGID" ] && sudo kill -0 -"$PGID" >/dev/null 2>&1 && sudo kill -KILL -"$PGID" >/dev/null 2>&1 || true
fi
# Cleanup temporary files
rm -f /tmp/webapp_serve.pid /tmp/webapp_dev.pid /tmp/webapp_serve.out /tmp/webapp_dev.out || true
