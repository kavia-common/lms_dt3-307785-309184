#!/usr/bin/env bash
set -euo pipefail
# Idempotent CRA scaffold for workspace
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE"
# If package.json exists validate minimum CRA bits
if [ -f package.json ]; then
  node -e "const fs=require('fs');const p='package.json';try{const j=JSON.parse(fs.readFileSync(p));const hasScripts=!!(j.scripts&&(j.scripts.start||j.scripts['react-scripts start'])&&j.scripts.build);const deps=j.dependencies||{};if(!hasScripts||(!deps.react&&!deps['react-dom'])){console.error('INCOMPLETE');process.exit(2);}console.log('OK');}catch(e){console.error('BAD_JSON',e.message);process.exit(3);}"
  rc=$? || true
  if [ "$rc" -eq 2 ]; then
    echo "ERROR: package.json present but missing CRA scripts or react deps; please inspect package.json" >&2
    exit 6
  elif [ "$rc" -eq 3 ]; then
    echo "ERROR: package.json contains invalid JSON" >&2
    exit 7
  fi
  echo "info: package.json appears valid; skipping scaffold"
  exit 0
fi
# Detect TS intent
USE_TS=0
[ -f tsconfig.json ] && USE_TS=1
# Prefer preinstalled create-react-app
SCAFF_OK=2
if command -v create-react-app >/dev/null 2>&1; then
  if [ "$USE_TS" -eq 1 ]; then
    create-react-app . --template typescript --use-npm --silent || SCAFF_OK=$?
  else
    create-react-app . --use-npm --silent || SCAFF_OK=$?
  fi
  SCAFF_OK=${SCAFF_OK:-0}
else
  if command -v npx >/dev/null 2>&1; then
    if [ "$USE_TS" -eq 1 ]; then
      timeout 300 npx --yes create-react-app@5 . --template typescript --use-npm || SCAFF_OK=$?
    else
      timeout 300 npx --yes create-react-app@5 . --use-npm || SCAFF_OK=$?
    fi
    SCAFF_OK=${SCAFF_OK:-0}
  else
    SCAFF_OK=2
  fi
fi
if [ "$SCAFF_OK" -ne 0 ]; then
  echo "warn: CRA scaffold failed or unavailable; creating minimal deterministic scaffold"
  cat > package.json <<'PKG'
{
  "name":"webappfrontend",
  "version":"0.1.0",
  "private":true,
  "scripts":{
    "start":"react-scripts start",
    "build":"react-scripts build",
    "test":"react-scripts test --env=jsdom --watchAll=false"
  },
  "dependencies":{
    "react":"18.2.0",
    "react-dom":"18.2.0"
  }
}
PKG
  mkdir -p src public
  if [ "$USE_TS" -eq 1 ]; then
    cat > src/App.tsx <<'TSAPP'
import React from 'react';
export default function App(){ return (<div>App</div>)}
TSAPP
    cat > tsconfig.json <<'TSC'
{
  "compilerOptions": {"jsx":"react-jsx","target":"ES2020"}
}
TSC
  else
    cat > src/App.js <<'JSAPP'
import React from 'react';
export default function App(){ return (<div>App</div>)}
JSAPP
  fi
fi
# Ensure public/index.html exists (safe grouping to avoid shell precedence pitfalls)
if [ -f public/index.html ]; then
  :
else
  mkdir -p public && cat > public/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>WebAppFrontend</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
HTML
fi
mkdir -p public/assets
[ -f .env ] || cat > .env <<'ENV'
REACT_APP_ENV=development
ENV
# Atomic update to ensure scripts present
PKG=package.json
if [ -f "$PKG" ]; then
  cp "$PKG" "$PKG.bak" 2>/dev/null || true
  TMP=$(mktemp)
  node -e "const fs=require('fs');const p='package.json';const t=process.env.TMP;const j=JSON.parse(fs.readFileSync(p));j.scripts=j.scripts||{};j.scripts.start=j.scripts.start||'react-scripts start';j.scripts.build=j.scripts.build||'react-scripts build';j.scripts.test=j.scripts.test||'react-scripts test --watchAll=false';fs.writeFileSync(t,JSON.stringify(j,null,2));" TMP="$TMP"
  mv "$TMP" "$PKG"
fi
exit 0
