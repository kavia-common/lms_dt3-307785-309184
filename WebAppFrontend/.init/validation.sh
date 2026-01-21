#!/usr/bin/env bash
set -euo pipefail
# validation: serve build/ with serve, poll for 2xx/3xx, capture 200 bytes, stop via PGID
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
RUN_DIR="$WORKSPACE/.run"; mkdir -p "$RUN_DIR"
# choose serve binary: prefer project-local then global
if [ -x "$WORKSPACE/node_modules/.bin/serve" ]; then
  SERVE_BIN="$WORKSPACE/node_modules/.bin/serve"
elif command -v serve >/dev/null 2>&1; then
  SERVE_BIN="serve"
else
  echo "ERROR: serve binary not available; install devDependency 'serve'" >&2
  exit 6
fi
PORT=3001
LOG="$RUN_DIR/serve.log"
PIDFILE="$RUN_DIR/serve.pid"
PGFILE="$RUN_DIR/serve.pgid"
# start serve in its own process group so we can kill by PGID
nohup bash -c "exec setsid \"$SERVE_BIN\" -s build -l $PORT" >"$LOG" 2>&1 &
PID=$!
printf "%s" "$PID" >"$PIDFILE"
# obtain PGID; may be empty if process already exited
PGID=$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ' || true)
printf "%s" "$PGID" >"$PGFILE"
# poll for readiness (max ~20s)
READY=0
for i in $(seq 1 20); do
  if command -v curl >/dev/null 2>&1; then
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || true)
    case "$CODE" in
      2*|3*) READY=1; break;;
    esac
  else
    if command -v ss >/dev/null 2>&1; then
      ss -ltn "sport = :$PORT" >/dev/null 2>&1 && { READY=1; break; }
    elif command -v netstat >/dev/null 2>&1; then
      netstat -ltn 2>/dev/null | /bin/grep -q ":$PORT" && { READY=1; break; }
    fi
  fi
  sleep 1
done
if [ "$READY" -ne 1 ]; then
  echo "ERROR: serve did not become ready within timeout; see $LOG" >&2
  # attempt cleanup
  if [ -n "$PGID" ] && [ "$PGID" != "" ]; then kill -TERM -"$PGID" >/dev/null 2>&1 || true; fi
  exit 7
fi
# final HTTP check and capture evidence
if command -v curl >/dev/null 2>&1; then
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || true)
  case "$CODE" in
    2*|3*) curl -s "http://127.0.0.1:$PORT/" | head -c 200 > "$RUN_DIR/validation-snippet.txt" || true ;;
    *) echo "ERROR: served site returned $CODE; see $LOG" >&2; if [ -n "$PGID" ]; then kill -TERM -"$PGID" >/dev/null 2>&1 || true; fi; exit 7 ;;
  esac
else
  echo "WARN: curl not available; cannot perform HTTP validation; check $LOG" >&2
fi
# cleanup server by PGID
if [ -n "$PGID" ] && [ "$PGID" != "" ]; then
  kill -TERM -"$PGID" >/dev/null 2>&1 || true
fi
# wait for pid to exit
wait "$PID" 2>/dev/null || true
# output paths for CI visibility
echo "$LOG" "$PIDFILE" "$PGFILE" "$RUN_DIR/validation-snippet.txt"
exit 0
