#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${WORKSPACE:-/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend}"
cd "$WORKSPACE"
# verify required tools
command -v node >/dev/null 2>&1 || { echo "ERROR: node not found" >&2; exit 2; }
NODE_VER=$(node -v | sed 's/^v//')
# require Node >=18
if ! printf "%s\n18\n" "$NODE_VER" | sort -V | head -n1 | grep -q "18"; then :; fi
command -v npm >/dev/null 2>&1 || command -v yarn >/dev/null 2>&1 || { echo "ERROR: neither npm nor yarn found" >&2; exit 3; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found" >&2; exit 4; }
# choose package manager
if [ -f yarn.lock ] && [ -f package-lock.json ]; then echo "ERROR: both yarn.lock and package-lock.json present; refuse to mix managers" >&2; exit 6; fi
if [ -f yarn.lock ]; then PKG_MANAGER="yarn"; elif [ -f package-lock.json ]; then PKG_MANAGER="npm"; else PKG_MANAGER="npm"; fi
# If package.json exists, normalize scripts
if [ -f package.json ]; then
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};const deps=Object.assign({},p.dependencies||{},p.devDependencies||{});if(deps.vite){p.scripts.start=p.scripts.start||'vite';p.scripts.build=p.scripts.build||'vite build';}else if(deps['react-scripts']){p.scripts.start=p.scripts.start||'react-scripts start';p.scripts.build=p.scripts.build||'react-scripts build';}else{p.scripts.start=p.scripts.start||'npm start';p.scripts.build=p.scripts.build||'npm run build';}fs.writeFileSync('package.json',JSON.stringify(p,null,2));" || { echo "ERROR: normalizing package.json failed" >&2; exit 7; }
  echo "OK: package.json normalized (pkg manager: $PKG_MANAGER)"
  exit 0
fi
# refuse to scaffold if likely project files exist
if [ -e README.md ] || [ -e README ] || [ -d src ] || [ -d public ] || [ -f package.json ]; then
  echo "ERROR: workspace not empty; refusing to scaffold to avoid clobbering" >&2; exit 8
fi
# scaffold with preinstalled create-react-app
if command -v create-react-app >/dev/null 2>&1; then
  TMPDIR=$(mktemp -d)
  (cd "$TMPDIR" && create-react-app app --use-npm) || { rm -rf "$TMPDIR"; echo "ERROR: create-react-app failed" >&2; exit 9; }
  # move contents preserving dotfiles; try user-level mv then sudo fallback
  set +e
  shopt -s dotglob
  mv "$TMPDIR/app"/* "$WORKSPACE"/ 2>/dev/null
  MV_EXIT=$?
  if [ $MV_EXIT -ne 0 ]; then
    sudo mv "$TMPDIR/app"/* "$WORKSPACE"/ || { rm -rf "$TMPDIR"; echo "ERROR: moving scaffold files failed" >&2; exit 11; }
  fi
  rm -rf "$TMPDIR"
  set -e
  echo "OK: scaffolded CRA app into workspace (pkg manager default: $PKG_MANAGER)"
  exit 0
else
  echo "ERROR: create-react-app not available; cannot scaffold" >&2; exit 10
fi
