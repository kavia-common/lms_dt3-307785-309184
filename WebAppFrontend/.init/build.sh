#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
<<<<<<< HEAD
# persist headless env for future shells
PROFILE=/etc/profile.d/react_headless.sh
sudo bash -lc "cat > $PROFILE <<'EOF'\nexport NODE_ENV=development\nexport CI=true\nEOF" || true
# export into current shell
export NODE_ENV=development
export CI=true
command -v curl >/dev/null 2>&1 || { echo 'curl required' >&2; exit 2; }
# Clean stale artifacts
rm -f /tmp/webapp_serve.pid /tmp/webapp_dev.pid /tmp/webapp_serve.out /tmp/webapp_dev.out || true
# Run production build
NODE_ENV=production CI=true npm run build --silent
=======
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
>>>>>>> cga-cg8841b3f7
