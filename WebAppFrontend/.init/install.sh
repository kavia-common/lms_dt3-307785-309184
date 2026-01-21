#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
# abort if both lockfiles present
[ -f yarn.lock -a -f package-lock.json ] && { echo "ERROR: both yarn.lock and package-lock.json present; aborting" >&2; exit 11; }
# choose package manager
if [ -f yarn.lock ]; then PKG_MANAGER="yarn"; elif [ -f package-lock.json ]; then PKG_MANAGER="npm"; else PKG_MANAGER="npm"; fi
# determine lockfile to checksum
LOCKFILE=""
if [ -f package-lock.json ]; then LOCKFILE="package-lock.json"; elif [ -f yarn.lock ]; then LOCKFILE="yarn.lock"; fi
# decide if reinstall required
REINSTALL=0
[ ! -d node_modules ] && REINSTALL=1
if [ -n "$LOCKFILE" ] && [ -f "$LOCKFILE" ]; then
  sha_file=".install.lockfile.sha"
  newsha=$(sha256sum "$LOCKFILE" | awk '{print $1}')
  if [ ! -f "$sha_file" ] || [ "$(cat "$sha_file")" != "$newsha" ]; then REINSTALL=1; fi
fi
[ "$REINSTALL" -eq 0 ] && exit 0
# run install with one retry
attempts=0
rc=1
until [ $attempts -ge 2 ]; do
  attempts=$((attempts+1))
  if [ "$PKG_MANAGER" = "yarn" ]; then
    yarn --frozen-lockfile --prefer-offline --silent || rc=$?
    rc=${rc:-0}
  else
    if [ -f package-lock.json ]; then
      npm ci --prefer-offline --no-audit --no-fund --loglevel=error || rc=$?
      rc=${rc:-0}
    else
      npm i --prefer-offline --no-audit --no-fund --silent || rc=$?
      rc=${rc:-0}
    fi
  fi
  [ ${rc:-0} -eq 0 ] && break || sleep 2
done
if [ ${rc:-0} -ne 0 ]; then echo "ERROR: dependency install failed (rc=${rc:-1})" >&2; exit 12; fi
# update checksum file
if [ -n "$LOCKFILE" ] && [ -f "$LOCKFILE" ]; then sha256sum "$LOCKFILE" | awk '{print $1}' > .install.lockfile.sha; fi
# ensure jest-environment-jsdom present
if ! node -e "try{require('jest-environment-jsdom');process.exit(0);}catch(e){process.exit(2)}" >/dev/null 2>&1; then
  if [ "$PKG_MANAGER" = "yarn" ]; then yarn add -D jest-environment-jsdom --silent; else npm i -D jest-environment-jsdom --silent; fi
fi
# If TypeScript sources detected but typescript devDep missing, add and verify
if ls src/*.ts src/*.tsx >/dev/null 2>&1; then
  if ! node -e "try{require('typescript');process.exit(0);}catch(e){process.exit(2)}" >/dev/null 2>&1; then
    if [ "$PKG_MANAGER" = "yarn" ]; then yarn add -D typescript @types/react @types/react-dom --silent; else npm i -D typescript @types/react @types/react-dom --silent; fi
  fi
fi
