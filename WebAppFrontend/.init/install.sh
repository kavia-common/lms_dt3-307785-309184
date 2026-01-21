#!/usr/bin/env bash
set -euo pipefail
# dependencies install step (idempotent, non-interactive)
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
[ -f package.json ] || { echo 'package.json missing; run scaffold first' >&2; exit 2; }
cp package.json package.json.bak || true
# Prefer yarn when yarn.lock present
if [ -f yarn.lock ]; then
  command -v yarn >/dev/null 2>&1 || { echo 'yarn not found' >&2; exit 3; }
  yarn install --non-interactive --silent || { echo 'yarn install failed' >&2; exit 4; }
else
  command -v npm >/dev/null 2>&1 || { echo 'npm not found' >&2; exit 5; }
  if [ -f package-lock.json ]; then
    npm ci --no-audit --progress=false --no-fund --silent || npm install --no-audit --progress=false --no-fund --silent || { echo 'npm install failed' >&2; exit 6; }
  else
    npm install --no-audit --progress=false --no-fund --silent || { echo 'npm install failed' >&2; exit 7; }
  fi
fi
# Ensure jq exists for JSON checks; jq is typically present in image, but verify
if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y -qq jq || true
fi
has_pkg_dep(){ jq -e ".dependencies[\"$1\"]? // .devDependencies[\"$1\"]?" package.json >/dev/null 2>&1; }
# Ensure react-scripts present locally as devDependency
if ! has_pkg_dep react-scripts; then
  npm i --no-audit --no-fund --save-dev react-scripts --silent || { echo 'failed to install react-scripts' >&2; exit 8; }
fi
# Ensure testing libs
if ! has_pkg_dep "@testing-library/react"; then
  npm i --no-audit --no-fund --save-dev @testing-library/react @testing-library/jest-dom --silent || { echo 'failed to install testing libs' >&2; exit 9; }
fi
# Ensure serve for validation
if ! has_pkg_dep serve; then
  npm i --no-audit --no-fund --save-dev serve --silent || true
fi
# Verify react-scripts binary presence
if [ ! -x ./node_modules/.bin/react-scripts ]; then
  echo 'react-scripts binary missing after install' >&2; exit 10
fi
# Record versions for debugging
node --version || true
npm --version || true
command -v yarn >/dev/null 2>&1 && yarn --version || true
( [ -f node_modules/.bin/create-react-app ] && node_modules/.bin/create-react-app --version ) || true
# Ensure workspace owned by non-root user (idempotent)
RUN_USER=$(awk -F: '($3>=1000)&&($1!="nobody"){print $1; exit}' /etc/passwd || echo devuser)
echo "RUN_USER=$RUN_USER"
sudo chown -R "$RUN_USER":"$RUN_USER" "$WORKSPACE" || true
