#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
mkdir -p "$WS" && cd "$WS"
[ -f package.json ] && exit 0
cat > package.json <<'JSON'
{
  "name": "webapp-frontend",
  "version": "0.1.0",
  "private": true,
  "engines": { "node": ">=18" },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "jest --colors --runInBand"
  },
  "dependencies": {
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "react-scripts": "5.0.1"
  },
  "devDependencies": {}
}
JSON
mkdir -p public src
[ -f public/index.html ] || cat > public/index.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>WebAppFrontend</title></head>
  <body><div id="root"></div></body>
</html>
HTML
[ -f src/index.js ] || cat > src/index.js <<'JS'
import React from 'react'
import { createRoot } from 'react-dom/client'
const App = ()=> React.createElement('div',null,'Hello from WebAppFrontend')
createRoot(document.getElementById('root')).render(React.createElement(App))
JS
[ -f .gitignore ] || cat > .gitignore <<'TXT'
node_modules/
build/
.DS_Store
npm-debug.log
TXT
# Create tsconfig placeholder only if TS files exist (preserve if user provided)
shopt -s nullglob
TSFILES=(src/*.ts src/*.tsx)
shopt -u nullglob
if [ ${#TSFILES[@]} -gt 0 ] && [ ! -f tsconfig.json ]; then
  cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src"]
}
JSON
fi
