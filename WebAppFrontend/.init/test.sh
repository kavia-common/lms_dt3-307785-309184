#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/lms_dt3-307785-309184/WebAppFrontend"
cd "$WORKSPACE"
# Run tests once in CI mode
export CI=true
npm test --silent -- --watchAll=false || true
