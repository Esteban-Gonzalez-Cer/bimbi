#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v fvm >/dev/null 2>&1; then F=(fvm flutter); D=(fvm dart); else F=(flutter); D=(dart); fi
"${D[@]}" format --output=none --set-exit-if-changed lib test integration_test
"${F[@]}" analyze --fatal-infos
"${F[@]}" test --coverage
npm --prefix payment_demo/server test
(cd firebase/emulator-tests && npm run emulators)
"${F[@]}" build apk --debug
