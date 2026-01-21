#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
# pick non-root user
RUN_USER=$(awk -F: '($3>=1000)&&($1!="nobody"){print $1; exit}' /etc/passwd || echo devuser)
# ensure workspace ownership so non-root can operate
sudo chown -R "$RUN_USER":"$RUN_USER" "$WORKSPACE" || true
PORT=${1:-3000}
# create wrapper to start dev server as RUN_USER
WRAPPER="$WORKSPACE/.start_dev.sh"
cat > "$WRAPPER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "${1}"
export PORT=${2}
export CI=true
# start in new session and write pid
setsid npm run start > /tmp/webapp_dev.out 2>&1 &
echo $! >/tmp/webapp_dev.pid
SH
sudo chown "$RUN_USER":"$RUN_USER" "$WRAPPER"
sudo chmod +x "$WRAPPER"
# start as RUN_USER
sudo -u "$RUN_USER" bash -lc "$WRAPPER '$WORKSPACE' $PORT" || { echo 'failed to start dev server' >&2; exit 5; }
# Wait for availability
TRIES=30; i=0; until curl -sSf --max-time 3 "http://localhost:$PORT/" >/dev/null 2>&1 || [ $i -ge $TRIES ]; do sleep 1; i=$((i+1)); done
if ! curl -sSf --max-time 3 "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo 'Dev server did not respond' >&2; tail -n 300 /tmp/webapp_dev.out || true; exit 6
fi
# output a small evidence snippet
echo "build_exists=$( [ -d build ] && echo yes || echo no )"
curl -sSf --max-time 3 "http://localhost:$PORT/" | head -c 200 || true
