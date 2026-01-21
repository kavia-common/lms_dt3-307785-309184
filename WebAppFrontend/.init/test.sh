#!/usr/bin/env bash
set -euo pipefail
# minimal Jest sanity test runner
WS="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WS"
# Ensure node_modules present
if [ ! -d "node_modules" ]; then
  echo "node_modules missing, run install first" >&2
  exit 3
fi
# Create minimal sanity test only if absent
mkdir -p src
if [ ! -f src/App.test.js ]; then
  cat > src/App.test.js <<'JS'
test('sanity',()=>{expect(1+1).toBe(2)})
JS
fi
JEST_BIN="./node_modules/.bin/jest"
if [ ! -x "$JEST_BIN" ]; then
  echo "local jest not found at $JEST_BIN; ensure install completed (see $WS/npm_install.log)" >&2
  exit 4
fi
# Run jest directly to avoid npm overhead; capture stdout/stderr separately
"$JEST_BIN" --colors --runInBand >"$WS/test_output.out" 2>"$WS/test_output.log" || {
  echo "tests failed; see $WS/test_output.log and $WS/test_output.out" >&2
  exit 5
}
# If we reach here tests passed; write short success marker
printf "OK\n" >"$WS/test_success.marker"
