#!/usr/bin/env bash
set -euo pipefail
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK directory}"
case "$(uname -m)" in arm64|aarch64) ABI=arm64-v8a;; *) ABI=x86_64;; esac
IMAGE="system-images;android-36;google_apis_playstore;$ABI"
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "$IMAGE"
for NAME in Bimbi_Phone_360 Bimbi_Phone_412; do
  if "$ANDROID_HOME/emulator/emulator" -list-avds | rg -qx "$NAME"; then continue; fi
  echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd --name "$NAME" --package "$IMAGE" --device pixel_6
 done
# Launch separately and use Android's display overrides as documented in SETUP.md.
