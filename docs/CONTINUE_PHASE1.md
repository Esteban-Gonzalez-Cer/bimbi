# Resume Phase 1 from the actual checkpoint

See evidence/phase1/REPORT.md for actual outcomes. The approval-review interruption recovered on retry; no credits/reset or permissions change was needed.

## Completed service setup

- Project bimbi-26ae2, Android com.bimbi.app, debug SHA-1/SHA-256 registered.
- Google sign-in with verified email confirmed on the physical tablet. GitHub OAuth is configured; GitHub sign-in and cold-start session restoration passed after retrying an initial browser-state failure. GitHub email verification also passed after the link was opened and the session refreshed.
- Default database bimbi-26ae2-default-rtdb in us-central1, bucket bimbi-26ae2.firebasestorage.app; owner-only rules deployed to both.
- Physical-tablet private record/image probe passed and deleted its test data.
- Maps key is stored only in ignored android/secrets.properties. Native tiles and Chapultepec marker rendered on the tablet. Never put that key back in tracked android/gradle.properties.
- Accelerometer signal changed with physical movement (owner confirmation). FCM console topic delivery passed in foreground, background and ordinary terminated states, including notification taps.
- Maps/Firebase-connected debug APK built and installed successfully. SHA-256 is in evidence/phase1/apk-sha256.txt.

## Validation already completed

22 Flutter tests, 11 backend tests on Node 22.23.5, 6 Firebase security-rule emulator scenarios; analyzer clean; physical tablet five-tab navigation passed. Basic alarm and cold-process alarm delivery passed with native dismissal. Review the report's exact limits before generalizing.

Phone widget coverage and screenshots exist, and managed five-destination interaction tests now pass on both 360dp and 412dp emulator profiles. Initial DDS/disconnection failures are preserved as history. Use scripts/test_phone_profile.sh if a relevant change requires rerunning these tests; restore a normal configured APK afterward because integration tests compile a test entrypoint.

## Remaining external and physical checks

- Finish foreground accelerometer/GPS sampling and stop/background cancellation checks. Ask the owner for a short outdoor walk. Keep private coordinates out of evidence and delete the in-memory trace afterward.
- FCM three-state acceptance is complete on the tablet. Force-stop is a separate negative scenario; do not repeat the completed topic campaigns unless changes justify a regression check.
- Email/password verification/reset/resend, sign-out/session restoration and actual second-user data denial still require live checks.
- Stripe sandbox is not configured. GitHub OAuth setup and actual sign-in are complete; do not recreate that OAuth App. Its email-verification check is also complete; proceed with Stripe using SETUP.md. Keep secrets in provider consoles/server secret storage. Payment endpoint and tests are implemented, but no live Stripe checkout or production billing is established.
- Reboot/unlock, recurrence, exact-access revocation, full-screen denial, offline/battery-saver alarms, native Back dismissal, TalkBack and tablet landscape remain individual acceptance scenarios.

## Reproduce checks when changes justify a rerun

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --fatal-infos
flutter test --coverage
npm test --prefix payment_demo/server
(cd firebase/emulator-tests && npm run emulators)
flutter build apk --debug --dart-define-from-file=config/dev.json
```

Use Node 22 for backend/deployment parity. The temporary local Node runtime under /private/tmp is not a project requirement. FVM pins Flutter 3.47.5. Install with adb install -r to preserve account data; integration-test reinstalls can reset permissions.

Keep the evidence report and gates current. Implementation is on local branch feat/phase1-feasibility; no remote repository/Actions execution or final release exists. Do not declare the full Phase 1 gate passed while mandatory service/device checks remain unverified.
