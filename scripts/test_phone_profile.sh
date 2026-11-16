#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK directory}"
case "${1:-}" in
  360) profile=Bimbi_Phone_360; port=5554; size=1080x2160 ;;
  412) profile=Bimbi_Phone_412; port=5556; size=1236x2472 ;;
  *) echo 'Usage: test_phone_profile.sh 360|412' >&2; exit 2 ;;
esac
serial="emulator-$port"
adb="$ANDROID_HOME/platform-tools/adb"
mkdir -p docs/evidence/phase1
bimbi_emulator_pid=''
cleanup() {
  if [ -n "$bimbi_emulator_pid" ]; then
    kill "$bimbi_emulator_pid" 2>/dev/null || true
    wait "$bimbi_emulator_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
if "$adb" -s "$serial" get-state >/dev/null 2>&1; then
  active_profile=$("$adb" -s "$serial" emu avd name | head -1 | tr -d '\r')
  if [ "$active_profile" != "$profile" ]; then
    echo "Port $port is occupied by another emulator. Stop that emulator or select a different port." >&2
    exit 1
  fi
else
  "$ANDROID_HOME/emulator/emulator" -avd "$profile" -port "$port" -no-window -no-audio -no-boot-anim -no-snapshot -gpu software > "${TMPDIR:-/tmp}/bimbi-phone-$1-emulator.log" 2>&1 &
  bimbi_emulator_pid=$!
fi
booted=false
for attempt in $(seq 1 90); do
  if [ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then booted=true; break; fi
  if [ -n "$bimbi_emulator_pid" ] && ! kill -0 "$bimbi_emulator_pid" 2>/dev/null; then break; fi
  sleep 2
done
if [ "$booted" != true ]; then echo 'Phone emulator did not finish booting.' >&2; exit 1; fi
"$adb" -s "$serial" shell wm size "$size"
"$adb" -s "$serial" shell wm density 480
"$adb" -s "$serial" shell input keyevent KEYCODE_WAKEUP
"$adb" -s "$serial" shell wm dismiss-keyguard
if command -v fvm >/dev/null 2>&1; then F=(fvm flutter); else F=(flutter); fi
"${F[@]}" test --disable-dds integration_test/shell_test.dart -d "$serial"

printf '%s\n' 'Phone interaction test passed. Rebuild lib/main.dart before distributing an APK: flutter build apk --debug --dart-define-from-file=config/dev.json'
