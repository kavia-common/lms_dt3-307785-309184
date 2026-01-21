#!/usr/bin/env bash
set -euo pipefail
<<<<<<< HEAD
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
=======
# start CRA dev server headless and persist logs/pids for deterministic discovery
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
RUN_DIR="$WORKSPACE/.run"; mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/dev-server.log"
PIDFILE="$RUN_DIR/dev-server.pid"
PGFILE="$RUN_DIR/dev-server.pgid"
export NODE_ENV=development
export BROWSER=none
PORT="3000"
# choose command: prefer yarn when yarn.lock present
if [ -f "yarn.lock" ]; then CMD=(yarn start); else CMD=(npm start); fi
# ensure no existing listener on port -> fail early with clear message
if command -v ss >/dev/null 2>&1; then
  if ss -ltn "sport = :$PORT" >/dev/null 2>&1; then
    echo "ERROR: port $PORT already in use. Aborting start. Check existing process." >&2
    exit 8
  fi
elif command -v netstat >/dev/null 2>&1; then
  if netstat -ltn 2>/dev/null | /bin/grep -q ":$PORT\b"; then
    echo "ERROR: port $PORT already in use. Aborting start. Check existing process." >&2
    exit 8
  fi
fi
# launch in background using nohup + setsid to create independent process group
# redirect stdout/stderr to log; use exec in bash -c to replace shell and have stable PID
nohup bash -c "exec setsid ${CMD[*]}" >"$LOG" 2>&1 &
PID=$!
# persist PID and PGID for deterministic discovery
printf "%s\n" "$PID" >"$PIDFILE"
PGID=$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ' || true)
# if pgid not obtained immediately, try wait loop briefly
if [ -z "$PGID" ]; then
  for _i in 1 2 3; do
    sleep 0.2
    PGID=$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ' || true)
    [ -n "$PGID" ] && break
  done
fi
printf "%s\n" "$PGID" >"$PGFILE"
# wait for port readiness (20s total)
ready=0
for i in {1..20}; do
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "sport = :$PORT" >/dev/null 2>&1 && { ready=1; break; }
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | /bin/grep -q ":$PORT\b" && { ready=1; break; }
  fi
  sleep 1
done
# if port not listening, fail and include log path
if [ "$ready" -ne 1 ]; then
  echo "ERROR: dev server did not open port $PORT within timeout. See log: $LOG" >&2
  echo "PID saved in: $PIDFILE" >&2
  exit 7
fi
# if curl available, check for HTTP 2xx/3xx; otherwise just report success
if command -v curl >/dev/null 2>&1; then
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || true)
  if [[ ! "$HTTP" =~ ^(2|3) ]]; then
    echo "ERROR: dev server responded with HTTP $HTTP on port $PORT (expected 2xx/3xx). Check log: $LOG" >&2
    exit 7
  fi
fi
# success: print locations for deterministic discovery
echo "$LOG" "$PIDFILE" "$PGFILE"
exit 0
>>>>>>> cga-cg8841b3f7
