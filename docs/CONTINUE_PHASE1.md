# Resume Phase 1 from the actual checkpoint

The owner confirmed Google sign-in with verified email and created the default Realtime Database. The owner also reported Storage ready, but Firebase deployment still reports its setup incomplete. Database rules are now deployed. Do not request those steps again. Latest status is in evidence/phase1/REPORT.md.

## 1. Validation checkpoint

```sh
dart format lib test integration_test
flutter analyze --fatal-infos
flutter test --coverage
npm test --prefix payment_demo/server
(cd firebase/emulator-tests && npm run emulators)
flutter build apk --debug --dart-define-from-file=config/dev.json
```

Use Node 22 for backend tests. Approval-review access recovered on retry; no credit purchase/reset was needed. The local /private/tmp/bimbi-node22 runtime is temporary and not a reproducibility requirement. FVM 3.47.5 pin, lockfiles and implementation are saved in local commit 8ee3d96 on feat/phase1-feasibility. There is no remote repository yet.

The latest source rebuilt successfully, and 22 Flutter tests plus 11 Node 22 backend tests passed. Rebuild the configured APK again after the actual database/Maps/Storage settings are saved. Install with adb -s <tablet-serial> install -r; do not uninstall or clear data unnecessarily. Native alarm service audio auto-stops after two minutes.

## 2. Complete Firebase setup

Inspect the newly created default instance and actual bucket using Firebase Console/CLI. Confirm region and locked rules. Refresh the downloaded config without printing keys:

```sh
./scripts/firebase.sh apps:sdkconfig ANDROID 1:147648809079:android:abb07034f0a29a3c67de72 --project bimbi-26ae2 --json > /private/tmp/bimbi-firebase-sdk.json
python3 scripts/refresh_firebase_config.py /private/tmp/bimbi-firebase-sdk.json
./scripts/firebase.sh database:instances:list --project bimbi-26ae2
```

Fill the actual database URL and bucket in ignored config/dev.json. If the Firebase CLI requires an explicit database instance mapping, bind the confirmed default instance before deploying; do not create a second database.

After rule emulator tests pass and the target resources are confirmed:

```sh
./scripts/firebase.sh deploy --only database,storage --project bimbi-26ae2
flutter build apk --debug --dart-define-from-file=config/dev.json
```

On the tablet, refresh verification and run the private-data/image probe. Then perform email/password, sign-out/session restore, reset/resend and the separate GitHub setup/test. Configure and test the FCM topic through Firebase Console in each supported state. No custom sending backend is needed.

## 3. Device and remaining services

- Phone 360 test failed before running due to Dart Development Service startup. Retry using flutter test --disable-dds integration_test/shell_test.dart -d <emulator>; run 412 independently so one runner failure cannot suppress the other. Preserve the original failure evidence.
- Complete tablet landscape/Back/TalkBack, offline, recurrence, reboot, permission-revocation and battery-saver alarm cases individually; do not generalize from the two observed deliveries.
- Ask the owner to move the tablet gently for real accelerometer evidence and take a short outdoor foreground GPS trace. Delete the trace afterward; no private coordinates in Git.
- Configure Maps Android-restricted key and confirm tiles/real marker. Use free allowances and supported quotas.
- Set up Stripe sandbox privately, test backend deployment, then success/decline/cancel and interrupted retry. Do not paste secret keys into chat or source.

## 4. Package the checkpoint

Update REPORT.md and gate verdict with actual results. Run git diff --check and review ignored configuration/secret exclusions. Commit small attributable changes on feat/phase1-feasibility (initial main commit 85b7acf). No remote or production release exists. Do not declare Phase 1 complete until all required external/device results are recorded, or explicitly accept remaining conditions with the owner.
