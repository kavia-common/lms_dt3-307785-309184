#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
RUN_DIR="$WORKSPACE/.run"; mkdir -p "$RUN_DIR"
# Run deterministic production build: prefer yarn when yarn.lock exists
if [ -f yarn.lock ]; then
  echo "Using yarn build" >/dev/null
  yarn build --silent || { echo 'ERROR: build failed' >&2; exit 8; }
else
  echo "Using npm run build" >/dev/null
  npm run build --silent || { echo 'ERROR: build failed' >&2; exit 8; }
fi
# Verify artifact existence
if [ ! -f build/index.html ]; then
  echo 'ERROR: build did not produce build/index.html' >&2
  exit 9
fi
# Record artifact metadata: size and top files
( du -sh build 2>/dev/null || true; ls -1 build | head -n 20 ) > "$RUN_DIR/build-info.txt" || true
exit 0
