#!/usr/bin/env bash
set -euo pipefail
# No device serial, private routes, accounts, tokens or unfiltered logcat exported.
mkdir -p docs/evidence/phase1
adb shell 'getprop ro.product.model; getprop ro.build.version.release; getprop ro.build.version.sdk; wm size; wm density; settings get global low_power' > docs/evidence/phase1/device.txt
adb shell pm list features | rg 'location.gps|sensor.accelerometer|sensor.gyroscope|sensor.step' >> docs/evidence/phase1/device.txt
adb logcat -d -s BimbiAlarm:I '*:S' > docs/evidence/phase1/alarm-events.txt
