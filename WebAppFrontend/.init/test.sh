#!/usr/bin/env bash
set -euo pipefail
# Non-interactive smoke test step (testing)
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
RUN_DIR="$WORKSPACE/.run"; mkdir -p "$RUN_DIR"
export CI=1
# Detect App file extension (prefer TypeScript if present)
EXT="js"
if [ -f src/App.tsx ] || [ -f src/App.ts ]; then
  EXT="tsx"
fi
# Ensure tests directory and test file exist idempotently
TEST_DIR="src/__tests__"
TEST_FILE="$TEST_DIR/App.smoke.test.$EXT"
if [ ! -f "$TEST_FILE" ]; then
  mkdir -p "$TEST_DIR"
  if [ "$EXT" = "tsx" ]; then
    cat > "$TEST_FILE" <<'TS'
import React from 'react';
import { render } from '@testing-library/react';
import App from '../App';

test('App renders without throwing', () => {
  expect(() => render(<App />)).not.toThrow();
});
TS
  else
    cat > "$TEST_FILE" <<'JS'
import React from 'react';
import { render } from '@testing-library/react';
import App from '../App';

test('App renders without throwing', () => {
  expect(() => render(<App />)).not.toThrow();
});
JS
  fi
fi
# Run tests once non-interactively using detected package manager
RESULT_FILE="$RUN_DIR/test-result.txt"
> "$RESULT_FILE"
if [ -f yarn.lock ]; then
  if command -v yarn >/dev/null 2>&1; then
    set +e
    yarn test --silent --ci
    CODE=$?
    set -e
  else
    echo "yarn.lock present but 'yarn' not on PATH" > "$RESULT_FILE"
    exit 2
  fi
else
  if command -v npm >/dev/null 2>&1; then
    set +e
    npm run test -- --ci --silent
    CODE=$?
    set -e
  else
    echo "npm not available on PATH" > "$RESULT_FILE"
    exit 2
  fi
fi
if [ "$CODE" -eq 0 ]; then
  echo "OK: tests passed (exit $CODE)" > "$RESULT_FILE"
else
  echo "FAIL: tests failed (exit $CODE)" > "$RESULT_FILE"
fi
# Also write the raw exit code for tooling
echo "$CODE" >> "$RESULT_FILE"
exit "$CODE"
