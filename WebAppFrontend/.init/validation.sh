#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WS"
mkdir -p "$WS/.init" || true
# Quick environment checks
command -v node >/dev/null 2>&1 || { echo "node not found on PATH" >&2; exit 10; }
command -v npm >/dev/null 2>&1 || { echo "npm not found on PATH" >&2; exit 11; }
# Ensure node_modules present
[ -d node_modules ] || { echo "node_modules missing, run .init/install first" >&2; exit 3; }
# Run build and capture log
CI=true npm run build >"$WS/.init/build.log" 2>&1 || { echo "build failed - see $WS/.init/build.log" >&2; echo "artifacts=$WS/.init/build.log"; exit 4; }
# Start server
bash .init/start.sh
# Poll for expected content up to 90s
MAX=90
INTERVAL=2
ELAPSED=0
FOUND=0
OUT_HTML="$WS/.init/validation_response.html"
SNIP="$WS/.init/validation_snippet.html"
while [ $ELAPSED -lt $MAX ]; do
  HTTP=$(curl -sS -w "%{http_code}" -o "$OUT_HTML" --max-time 3 http://127.0.0.1:3000/ 2>/dev/null || true)
  head -c 2048 "$OUT_HTML" >"$SNIP" || true
  if [ -n "$HTTP" ] && echo "$HTTP" | grep -qE '^[23][0-9][0-9]$'; then
    if grep -q '<div id="root"' "$OUT_HTML" || grep -q 'Hello from WebAppFrontend' "$OUT_HTML"; then
      FOUND=1
      break
    fi
  fi
  sleep $INTERVAL
  ELAPSED=$((ELAPSED+INTERVAL))
done
if [ $FOUND -ne 1 ]; then
  echo "dev server did not serve expected content; see $WS/.init/serve.log and $OUT_HTML" >&2
  echo "artifacts=build_log=$WS/.init/build.log serve_log=$WS/.init/serve.log response=$OUT_HTML snippet=$SNIP"
  # Stop server before exiting
  bash .init/stop.sh || true
  exit 5
fi
# On success, stop server and print artifact paths
echo "validation ok"
echo "artifacts=build_log=$WS/.init/build.log serve_log=$WS/.init/serve.log response=$OUT_HTML snippet=$SNIP"
# stop server
bash .init/stop.sh || true
exit 0
