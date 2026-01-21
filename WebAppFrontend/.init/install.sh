#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WS"
[ -f package.json ] || { echo "package.json missing" >&2; exit 3; }
# compute sha256 hash of package files (sha256sum preferred)
if command -v sha256sum >/dev/null 2>&1; then
  H1=$(sha256sum package.json | cut -d' ' -f1)
  [ -f package-lock.json ] && H2=$(sha256sum package-lock.json | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
  H1=$(shasum -a 256 package.json | cut -d' ' -f1)
  [ -f package-lock.json ] && H2=$(shasum -a 256 package-lock.json | cut -d' ' -f1)
else
  echo "no sha256sum or shasum available" >&2
  exit 4
fi
HASH_SOURCE="$H1"
[ -n "${H2:-}" ] && HASH_SOURCE="$HASH_SOURCE-$H2"
INST_HASH_FILE="node_modules/.installed_hash"
# quick skip when hashes match
if [ -d node_modules ] && [ -f "$INST_HASH_FILE" ] && [ "$(cat "$INST_HASH_FILE")" = "$HASH_SOURCE" ]; then
  exit 0
fi
# detect declared deps using node to avoid brittle parsing
HAS_REACT=$(node -e "try{const p=require('./package.json');const d=Object.assign({},p.dependencies||{},p.devDependencies||{});console.log(Boolean(d.react));}catch(e){console.log('false');}")
HAS_REACT_SCRIPTS=$(node -e "try{const p=require('./package.json');const d=Object.assign({},p.dependencies||{},p.devDependencies||{});console.log(Boolean(d['react-scripts']));}catch(e){console.log('false');}")
HAS_JEST=$(node -e "try{const p=require('./package.json');const d=Object.assign({},p.dependencies||{},p.devDependencies||{});console.log(Boolean(d.jest));}catch(e){console.log('false');}")
HAS_REACT="$(echo "$HAS_REACT" | tr -d '\n\r ' )"
HAS_REACT_SCRIPTS="$(echo "$HAS_REACT_SCRIPTS" | tr -d '\n\r ' )"
HAS_JEST="$(echo "$HAS_JEST" | tr -d '\n\r ' )"
# detect TypeScript usage
shopt -s nullglob
TSFILES=(src/*.ts src/*.tsx)
shopt -u nullglob
HAS_TS=0
[ ${#TSFILES[@]} -gt 0 ] || [ -f tsconfig.json ] && HAS_TS=1 || HAS_TS=$HAS_TS
# prepare log paths
mkdir -p "$WS"
NPM_OUT="$WS/npm_install.out"
NPM_LOG="$WS/npm_install.log"
# prefer npm ci when lockfile exists; fall back to npm install on failure
set +e
RC=0
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund >"$NPM_OUT" 2>"$NPM_LOG"
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "npm ci failed; falling back to npm install (see $NPM_LOG)" >&2
    npm install --no-audit --no-fund >"$NPM_OUT" 2>>"$NPM_LOG"
    RC=$?
  fi
else
  # ensure core CRA deps declared; install pinned minimal set deterministically if missing
  if [ "${HAS_REACT,,}" = "false" ] || [ "${HAS_REACT_SCRIPTS,,}" = "false" ]; then
    npm i --no-audit --no-fund react@18.2.0 react-dom@18.2.0 react-scripts@5.0.1 >"$NPM_OUT" 2>"$NPM_LOG"
    RC=$?
    if [ $RC -ne 0 ]; then echo "npm install core deps failed" >&2; exit 5; fi
  fi
  npm i --no-audit --no-fund >"$NPM_OUT" 2>>"$NPM_LOG"
  RC=$?
fi
set -e
if [ $RC -ne 0 ]; then
  echo "npm install failed; see $NPM_LOG and $NPM_OUT" >&2
  exit 6
fi
# Ensure jest exists locally when not declared
if [ "${HAS_JEST,,}" = "false" ]; then
  npm i --no-audit --no-fund --save-dev jest >"$NPM_OUT" 2>>"$NPM_LOG"
  if [ $? -ne 0 ]; then echo "failed to install jest; see $NPM_LOG" >&2; exit 7; fi
fi
# Install TypeScript tooling deterministically if TS detected
if [ "$HAS_TS" -eq 1 ]; then
  npm i --no-audit --no-fund --save-dev typescript ts-node @types/react @types/react-dom >"$NPM_OUT" 2>>"$NPM_LOG"
  if [ $? -ne 0 ]; then echo "failed to install TypeScript deps; see $NPM_LOG" >&2; exit 8; fi
fi
# atomic write of installed hash
mkdir -p node_modules
TMP_HASH=$(mktemp) || { echo "mktemp failed" >&2; exit 9; }
printf "%s" "$HASH_SOURCE" > "$TMP_HASH"
mv -f "$TMP_HASH" "$INST_HASH_FILE"
