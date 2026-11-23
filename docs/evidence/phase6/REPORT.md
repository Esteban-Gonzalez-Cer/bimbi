# Bimbi · Phase 6 Running and native maps

## How to use it

1. Open **Running** and tap **Start**. Allow precise location while using the app. The map opens at Bosque de Chapultepec and moves to the first accepted location. **Center map** returns to the most recent accepted point.
2. Use **Pause** and **Resume** to stop and restart GPS. Leaving Running, locking the screen, or putting Bimbi in the background pauses the run. Open Running again and press **Resume** when ready.
3. Tap **Finish** to review the distance and active time. **Save run** becomes available after two accepted points in one segment. **Discard** removes the draft.
4. Open a saved workout in **Run history** to view its totals and route outline offline. **Delete run** removes its data. Verified accounts can see the date, distance, and active time on another device. The route is available on the recording device.

## Implementation

- The Riverpod controller owns the recording, pause, review, and save states. The adapter uses Android’s location provider with foreground access. The existing shell stop hook stops foreground GPS, including when a location permission result arrives after navigation. The development accelerometer probe remains available. [Session controller](../../../lib/features/running/application/run_controller.dart) · [Android tracking adapter](../../../lib/features/running/tracking_adapter.dart)
- GPS filtering rejects simulated, stale, out-of-order, inaccurate, and implausibly fast fixes. Pauses and gaps create separate line segments. Active time is measured independently of GPS timestamps. An active draft is saved at most five seconds apart under normal recording and reopens paused after relaunch. [Route processing](../../../lib/features/running/domain/run.dart)
- Run files are stored in Android's private application directory and separated by account. A verified account's sync queue serializes only the start timestamp, distance in meters, and active seconds. Deleting a synced workout leaves only its random identifier and a deletion marker in Firebase, so delayed retries cannot restore the summary. [Local store](../../../lib/features/running/data/run_store.dart) · [Cloud adapter](../../../lib/features/running/data/run_cloud.dart) · [Firebase rules](../../../firebase/database.rules.json)

## Verification and delivery

| Check | Standalone Phase 6 result |
|---|---|
| Flutter format, analysis and tests | Passed. 77 tests, including GPS quality, pause and resume, local recovery, saved offline routes, and the 360 dp flow at 200% text. The visual baselines cover 360, 412, 700 and 900 dp. Snapshot tests now wait for bundled icons to decode. |
| Android JVM and debug build | Passed. 12 JVM tests. The configured APK passed Android signature verification. |
| Backend and Firebase emulators | Passed. 13 server tests and 15 Firebase emulator tests on dedicated ports. The new rules were verified with two clients, other-account and unverified-account denials, coordinate rejection, and deletion followed by a stale retry. |
| Android emulator | The native map displayed the public park marker. Location denial kept the controls recoverable at 360 dp, history was reachable at 412 dp with enlarged text, and Running opened in portrait and landscape at Galaxy Tab A9 dimensions. Pressing Android Home paused the active session. A synthetic draft saved in airplane mode, then its totals and route reopened after process restart and were deleted through the UI. |

The standalone branch starts from Phase 4 commit `0cc2163`. APK SHA-256 `4f4bcc7391652b50897871c8ccc17b4c459262de99e663c45f18b40832fdd958`. [Signed debug APK](../../../build/review/bimbi-phase6-running-debug.apk) · [Tablet-sized portrait](../../../build/review/phase6-tablet-size-portrait.png) · [Tablet-sized landscape](../../../build/review/phase6-tablet-size-landscape.png) · [Offline route fixture](../../../build/review/phase6-412dp-offline-route.png)

## Phase 5 integration

Phase 5 commit `6d9b12c` brings Sleep, Focus and the Focus shield into `codex/phase6-running`. The combined navigation keeps the Running lifecycle checks. The merged Realtime Database rules cover the Sleep diary, Focus history and Running totals. The merged screenshot tests wait for bundled images to decode before comparing pixels.

The combined checks passed formatting, analysis, 117 Flutter tests, two daylight-saving tests, 19 Android JVM tests, 13 payment server tests, and 17 Firebase emulator tests. [Check log](../../../build/review/phase5-phase6-checks.txt)

The development APK passed Android signature verification. Its SHA-256 is `582d52e8904b0aaa3ecca1b0fcb352b939e2ce2c7c74bbfab07ac86bb59fef05`. [Combined APK](../../../build/review/bimbi-phase5-phase6-debug.apk)

The signed APK installed on a separate Android phone emulator. All five destinations opened. A Sleep entry survived a process restart, a Focus session started, paused and ended, and Running showed the park map and run history. [Android smoke test log](../../../build/review/phase5-phase6-android-smoke.txt)

**Gate verdict · Conditional.** Deployment of the merged development database rules, a two-device live sync check, and the Galaxy Tab A9 outdoor GPS and TalkBack checks are outstanding.
