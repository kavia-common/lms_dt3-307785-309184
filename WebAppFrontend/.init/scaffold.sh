#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
# ensure workspace exists
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
# persist headless env
cat >/etc/profile.d/react_headless.sh <<'EOF'
export NODE_ENV=development
export CI=true
EOF
# export into current shell
export NODE_ENV=development
export CI=true
# validate node and npm (require Node >=16)
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "node or npm not found" >&2; exit 11
fi
NODE_MAJOR=$(node -v | sed -E 's/^v([0-9]+).*$/\1/') || NODE_MAJOR=0
if [ "${NODE_MAJOR:-0}" -lt 16 ]; then
  echo "Node major version must be >=16; found $(node -v)" >&2; exit 12
fi
# select non-root user with UID>=1000 and valid shell
NONROOT_USER=$(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false"){print $1; exit}' /etc/passwd || true)
if [ -z "$NONROOT_USER" ]; then
  NONROOT_USER=devuser
  id -u "$NONROOT_USER" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$NONROOT_USER"
fi
# ensure ownership so non-root can write
sudo chown -R "$NONROOT_USER":"$NONROOT_USER" "$WORKSPACE" || true
# If package.json exists, only ensure scripts
if [ -f package.json ]; then
  cp package.json package.json.bak || true
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};p.scripts.start=p.scripts.start||'react-scripts start';p.scripts.build=p.scripts.build||'react-scripts build';p.scripts.test=p.scripts.test||'react-scripts test --watchAll=false --ci';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" || { echo 'failed to update package.json' >&2; exit 2; }
  echo "scripts ensured in existing package.json"
  exit 0
fi
# ensure directory effectively empty (allow only .git)
if [ -n "$(ls -A . 2>/dev/null)" ]; then
  if [ -d .git ] && [ "$(ls -A | grep -v '^.git$' || true)" = "" ]; then
    :
  else
    echo 'Workspace not empty; skipping CRA init' >&2
    exit 3
  fi
fi
# TypeScript detection: tsconfig.json or package.json declares typescript
USE_TS=0
[ -f tsconfig.json ] && USE_TS=1
if [ -f package.json ]; then
  node -e "try{const p=require('./package.json');if((p.dependencies&&p.dependencies.typescript)||(p.devDependencies&&p.devDependencies.typescript))process.exit(0);process.exit(1)}catch(e){process.exit(1)}" && USE_TS=1 || true
fi
TEMPLATE_FLAG=""
[ "$USE_TS" -eq 1 ] && TEMPLATE_FLAG="--template typescript"
# Prefer installed create-react-app; check version compatibility
if command -v create-react-app >/dev/null 2>&1; then
  CRA_VER=$(create-react-app --version 2>/dev/null || echo '')
  # best-effort accept existing CRA; attempt invocation as non-root via bash -lc
  sudo -u "$NONROOT_USER" bash -lc "create-react-app . ${TEMPLATE_FLAG} --use-npm" || { echo 'create-react-app failed' >&2; exit 4; }
else
  # fallback to npx: check network quickly
  if command -v npx >/dev/null 2>&1; then
    if curl -sSf --connect-timeout 5 https://registry.npmjs.org/ >/dev/null 2>&1; then
      sudo -u "$NONROOT_USER" bash -lc "npx --yes create-react-app . ${TEMPLATE_FLAG} --use-npm" || { echo 'npx create-react-app failed' >&2; exit 5; }
    else
      echo 'Network unavailable for npx create-react-app' >&2; exit 6
    fi
  else
    echo 'create-react-app and npx unavailable' >&2; exit 7
  fi
fi
# final ownership fix
sudo chown -R "$NONROOT_USER":"$NONROOT_USER" "$WORKSPACE" || true
echo "CRA initialization complete"
