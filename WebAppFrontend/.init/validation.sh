#!/usr/bin/env bash
set -euo pipefail

# Validation: build, start, probe and graceful stop
WORKSPACE="${WORKSPACE:-/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend}"
cd "$WORKSPACE"
# determine package manager
if [ -f yarn.lock ] && [ -f package-lock.json ]; then echo "ERROR: both yarn.lock and package-lock.json present; aborting" >&2; exit 11; fi
if [ -f yarn.lock ]; then PKG_MANAGER="yarn"; else PKG_MANAGER="npm"; fi
# Build if build script exists
if grep -q '"build"' package.json 2>/dev/null; then
  if [ "$PKG_MANAGER" = "yarn" ]; then yarn build --silent; else npm run build --silent; fi
fi
PORT=${PORT:-3000}
HOST=${HOST:-0.0.0.0}
LOG="/tmp/webapp_frontend_stdout.log"
rm -f "$LOG"
export HOST PORT NODE_ENV=development
# Start server in new session so we can find descendants
if [ "$PKG_MANAGER" = "yarn" ]; then
  setsid sh -c "cd '$WORKSPACE' && exec env NODE_ENV=development HOST=$HOST PORT=$PORT yarn start" >"$LOG" 2>&1 &
else
  setsid sh -c "cd '$WORKSPACE' && exec env NODE_ENV=development HOST=$HOST PORT=$PORT npm start" >"$LOG" 2>&1 &
fi
WRAPPER_PID=$!
sleep 1
# find descendant PIDs by walking /proc for children of WRAPPER_PID
_descendants() {
  local pid=$1
  for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$' || true); do
    if [ -f "/proc/$p/stat" ]; then
      parent=$(awk '{print $4}' /proc/$p/stat 2>/dev/null || true)
      if [ "$parent" = "$pid" ]; then
        echo "$p"
        _descendants "$p"
      fi
    fi
  done
}
SERVER_PIDS=$(_descendants "$WRAPPER_PID" || true)
# prefer node processes among descendants
MAIN_PID=""
for p in $SERVER_PIDS; do
  cmd=$(tr -d '\0' < /proc/$p/cmdline 2>/dev/null || true)
  case "$cmd" in
    *node*|*react-scripts*|*vite*) MAIN_PID=$p; break;;
  esac
done
if [ -z "$MAIN_PID" ]; then MAIN_PID=$(echo "$SERVER_PIDS" | awk '{print $1}' || true); fi
if [ -z "$MAIN_PID" ]; then MAIN_PID=$WRAPPER_PID; fi
PGID=$(ps -o pgid= -p "$MAIN_PID" | tr -d ' ' || true)
[ -n "$PGID" ] || PGID=$(ps -o pgid= -p "$WRAPPER_PID" | tr -d ' ' || true)
# poll for readiness
max_wait=60
interval=2
elapsed=0
ok=1
while [ $elapsed -lt $max_wait ]; do
  if curl -s --max-time 3 "http://localhost:${PORT}/" >/dev/null 2>&1; then ok=0; break; fi
  sleep $interval; elapsed=$((elapsed+interval))
done
if [ $ok -ne 0 ]; then
  echo "ERROR: dev server did not respond on port ${PORT} after ${max_wait}s" >&2
  echo "---server-log-tail---"; tail -n 200 "$LOG" || true
  # cleanup
  if [ -n "$PGID" ]; then kill -TERM -"$PGID" >/dev/null 2>&1 || true; fi
  kill "$WRAPPER_PID" >/dev/null 2>&1 || true
  wait "$WRAPPER_PID" 2>/dev/null || true
  exit 15
fi
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/")
BODY=$(curl -s --max-time 3 "http://localhost:${PORT}/" | head -c 512)
echo "HTTP_STATUS=$STATUS"
echo "BODY_SNIPPET="
echo "$BODY"
# graceful stop: kill process group if available, otherwise kill discovered PIDs
if [ -n "$PGID" ]; then kill -TERM -"$PGID" >/dev/null 2>&1 || true; else
  for p in $SERVER_PIDS; do kill -TERM "$p" >/dev/null 2>&1 || true; done
fi
sleep 3
# escalate if necessary
if [ -n "$PGID" ] && ps -o pid= -g "$PGID" >/dev/null 2>&1; then kill -KILL -"$PGID" >/dev/null 2>&1 || true; fi
if kill -0 "$WRAPPER_PID" >/dev/null 2>&1; then kill -KILL "$WRAPPER_PID" >/dev/null 2>&1 || true; fi
wait "$WRAPPER_PID" 2>/dev/null || true
echo "---server-log-tail---"; tail -n 50 "$LOG" || true
