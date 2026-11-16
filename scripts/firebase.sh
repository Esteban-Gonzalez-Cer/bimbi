#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec node firebase/emulator-tests/node_modules/firebase-tools/lib/bin/firebase.js "$@"
