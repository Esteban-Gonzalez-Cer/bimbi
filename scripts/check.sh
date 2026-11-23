#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v fvm >/dev/null 2>&1; then F=(fvm flutter); D=(fvm dart); else F=(flutter); D=(dart); fi
"${D[@]}" format --output=none --set-exit-if-changed lib test integration_test
"${F[@]}" analyze --fatal-infos
test_args=(--coverage)
if [ "${BIMBI_SKIP_MAC_GOLDENS:-false}" = true ]; then
  test_args+=(--exclude-tags "golden || review")
fi
"${F[@]}" test "${test_args[@]}"
# Daylight-saving nights for the sleep diary, in a zone that still changes clocks.
TZ=America/New_York "${F[@]}" test --tags tz test/tz
npm --prefix payment_demo/server test
(cd firebase/emulator-tests && npm run emulators)
(cd android && ./gradlew :app:testDebugUnitTest)
"${F[@]}" build apk --debug
