#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
RUN_DIR="$WORKSPACE/.run"
mkdir -p "$RUN_DIR" && cd "$WORKSPACE"

# Validate presence of package.json
if [ ! -f package.json ]; then
  echo "ERROR: package.json missing; run scaffold first" >&2
  exit 6
fi

# Print Node/npm/yarn versions and advice
NODE_BIN=$(command -v node || true)
NPM_BIN=$(command -v npm || true)
YARN_BIN=$(command -v yarn || true)

echo "node: ${NODE_BIN:-not-found} $( [ -n "$NODE_BIN" ] && node --version || true )"
echo "npm: ${NPM_BIN:-not-found} $( [ -n "$NPM_BIN" ] && npm --version || true )"
echo "yarn: ${YARN_BIN:-not-found} $( [ -n "$YARN_BIN" ] && yarn --version || true )"

if [ -z "$NODE_BIN" ]; then
  echo "ERROR: node is not available in PATH. Install Node.js v18+ or ensure node is on PATH." >&2
  exit 2
fi
# ensure node >=18
NODE_V=$(node -p "process.versions.node")
NODE_MAJOR=${NODE_V%%.*}
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "ERROR: Node version $NODE_V detected; require >=18. Install or update Node." >&2
  exit 3
fi

# Determine package manager (prefer yarn when yarn.lock present)
PM="npm"
if [ -f yarn.lock ] && [ -n "$YARN_BIN" ]; then
  PM="yarn"
fi

# Known-good conservative pins for runtime and dev deps
# Only add packages that are NOT already declared in package.json
MISSING_RUNTIME=$(node -e '
const fs=require("fs");const j=JSON.parse(fs.readFileSync("package.json"));const deps=Object.assign({},j.dependencies||{},j.devDependencies||{});
const need={react:"18.2.0", "react-dom":"18.2.0", "react-scripts":"5.0.1", dotenv:"16.0.0"};
const out=Object.keys(need).filter(n=>!deps[n]).map(n=>n+"@"+need[n]);console.log(out.join(" "));
')

if [ -n "$MISSING_RUNTIME" ]; then
  echo "Installing missing runtime packages: $MISSING_RUNTIME"
  if [ "$PM" = "yarn" ]; then
    yarn add --silent $MISSING_RUNTIME
  else
    npm i --no-audit --no-fund --silent $MISSING_RUNTIME --save
  fi
fi

# Dev candidates (conservative ranges/pins)
DEV_CANDIDATES=("serve@^14.0.0" "cross-env@^7.0.0" "@testing-library/react@^14.0.0" "@testing-library/jest-dom@^6.0.0" "eslint@^8.0.0" "prettier@^2.0.0")
if [ -f tsconfig.json ]; then
  DEV_CANDIDATES+=("@types/react@^18.0.0" "@types/react-dom@^18.0.0" "typescript@^5.0.0")
fi

# Build list of dev packages not declared in package.json
TO_INSTALL_DEV=""
for p in "${DEV_CANDIDATES[@]}"; do
  NAME=$(echo "$p" | sed 's/@.*//')
  node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync('package.json'));const deps=Object.assign({},j.dependencies||{},j.devDependencies||{});if(!deps['$NAME']) process.exit(0); process.exit(1);" || TO_INSTALL_DEV="$TO_INSTALL_DEV $p"
done

if [ -n "$TO_INSTALL_DEV" ]; then
  echo "Installing devDependencies:$TO_INSTALL_DEV"
  if [ "$PM" = "yarn" ]; then
    yarn add --dev --silent $TO_INSTALL_DEV
  else
    npm i --no-audit --no-fund --silent --save-dev $TO_INSTALL_DEV
  fi
fi

# Avoid reinstalling globally-available CLIs: check common globals and skip if present
# (The script already only installs project-local deps)

# Clean npm/yarn temporary caches if needed (lightweight)
# Do not aggressively clear global caches; do a safe no-op if not present
if command -v npm >/dev/null 2>&1; then
  npm cache verify >/dev/null 2>&1 || true
fi
if command -v yarn >/dev/null 2>&1; then
  yarn cache list >/dev/null 2>&1 || true
fi

# Record installed/changed packages
RUNTIME_MISSING_LINE="runtime_missing:$MISSING_RUNTIME"
DEV_INSTALLED_LINE="dev_installed:${TO_INSTALL_DEV:-}" 
{
  echo "$RUNTIME_MISSING_LINE"
  echo "$DEV_INSTALLED_LINE"
  echo "pm:$PM"
  echo "node_version:$NODE_V"
} > "$RUN_DIR/deps-installed.txt"

# Final sanity: show top-level installed packages for visibility (no error if fails)
if command -v npm >/dev/null 2>&1; then npm ls --depth=0 >/dev/null 2>&1 || true; fi

exit 0
