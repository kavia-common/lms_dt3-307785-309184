#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WS"
mkdir -p "$WS/.init" || true
SERVE_LOG="$WS/.init/serve.log"
PID_FILE="$WS/.init/serve.pid"
# Prevent duplicate runs: if pid file exists and process alive, exit
if [ -f "$PID_FILE" ]; then
  OLDPID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [ -n "$OLDPID" ] && kill -0 "$OLDPID" 2>/dev/null; then
    echo "server already running pid=$OLDPID" && exit 0
  fi
fi
# Start dev server headless and capture the top-level background pid (setsid ensures child is session leader)
# Use sh -c with exec to replace shell so that setsid has the node child as direct child of the setsid process
setsid sh -c 'exec env HOST=127.0.0.1 PORT=3000 CI=true BROWSER=none npx react-scripts start' >"$SERVE_LOG" 2>&1 &
LAUNCH_PID=$!
# Allow a short time for the real child to spawn
sleep 1
# Find the real descendant process (prefer node or react-scripts)
PID_CHILD="$LAUNCH_PID"
# Search descendants up to depth 3
for p in $(pgrep -P "$LAUNCH_PID" || true); do
  if ps -p "$p" -o comm= | grep -E "node|react-scripts" >/dev/null 2>&1; then PID_CHILD=$p; break; fi
done
# Fallback: if no immediate child found, search grandchildren
if [ "$PID_CHILD" = "$LAUNCH_PID" ]; then
  for c in $(pgrep -P $(pgrep -P "$LAUNCH_PID" || true) || true); do
    if ps -p "$c" -o comm= | grep -E "node|react-scripts" >/dev/null 2>&1; then PID_CHILD=$c; break; fi
  done
fi
# Persist pid (store the actual child if found, else the launcher)
echo "$PID_CHILD" >"$PID_FILE"
echo "$PID_CHILD" >"$WS/.init/serve_child.pid" || true
echo "started pid=$PID_CHILD serve_log=$SERVE_LOG pid_file=$PID_FILE"
