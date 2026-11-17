# Phase 1 completion checkpoint

The first tablet feasibility pass completed on November 16, 2026. See [the evidence report](evidence/phase1/REPORT.md) for case-level results, actual build hashes, initial failed attempts and verification limits. Work is on local branch `feat/phase1-feasibility`.

## Existing configuration

- Firebase development project `bimbi-26ae2`, Android package `com.bimbi.app`; debug SHA-1/SHA-256 registered.
- Email/password, Google and GitHub are enabled and physically tested. Verification/resend, password reset, sign-out and restored sessions passed. GitHub required a fresh-session retry after its first browser-state failure.
- Realtime Database `bimbi-26ae2-default-rtdb` in us-central1 and Storage `bimbi-26ae2.firebasestorage.app` have deployed owner-only rules. Live owner record/image probes passed readback and cleanup; cross-user denials were tested in emulators.
- Maps key remains in ignored `android/secrets.properties`; service definitions and the Stripe publishable test key remain in ignored `config/dev.json`. Use the existing configuration rather than requesting new accounts/keys again.
- `STRIPE_SECRET_KEY` is bound server-side to `paymentApi` at `https://us-central1-bimbi-26ae2.cloudfunctions.net/paymentApi`: Node 22, configured minInstances 0/maxInstances 1, one-day artifact cleanup. Native cancel/decline/server-verified success and same-intent reuse passed. The earlier misnamed-secret test-key rotation guidance is in the evidence report; rotation was not independently verified.
- FCM topic `bimbi_phase1` passed foreground/background/ordinary terminated delivery and notification tap handling. Force-stop requires reopening.
- Owner confirmed monthly project budget alerts at 50/90/100%. Alerts-only budgets notify rather than cap spend.

## Completed tablet checks

- Native alarm sound/alert/dismissal; cold app process; reboot/unlock restoration; locked full-screen presentation and Back dismissal.
- Exact access denial/revocation; notification runtime denial/revocation; active channel blocking; full-screen-denied notification dismissal while locked. Permission/channel settings were restored.
- Two one-minute recurrence deliveries and fresh one-shot rearming; dismiss preserved recurrence; cancel prevented a third delivery.
- Unplugged offline/power-saving alarm: native powerSave=true, deviceIdle=false, interactive=false; owner confirmed sound, alert and manual dismissal while sounding.
- Native public-park map, seven accepted outdoor location samples, GPS denial, real accelerometer movement and stop/background handling. In-memory trace cleared to zero; no coordinates or private route screenshots exported.
- All five destinations in portrait/landscape, font scales 1.0/2.0; adjusted badge visually verified; enlarged-text dismissal controls reachable; Android Back and owner-operated TalkBack labels/native dismissal passed.
- Optional Usage Access adapter grant/deny/revoke passed. Original denied state restored. No app names or usage totals exported/uploaded; Focus remains a later-phase timer placeholder.
- One configured APK contains all integrations; verified session, private data probe, navigation, tracking lifecycle and native alarm checks coexist. Check `evidence/phase1/apk-sha256.txt` for the final artifact and prior test-build hashes.

Final restored state: no pending/active alarm or AlarmService; TalkBack OFF; font scale 1.0; free rotation; Power saving OFF; Airplane mode OFF; Wi-Fi ON; optional Usage Access at its original denied/default setting.

## Automated results and reproduction

Formatting and analyzer clean; 22 Flutter tests, 11 Node 22 backend tests and 6 Firebase rule-emulator scenarios passed. Five-destination interaction passed on the physical tablet and managed 360dp/412dp phone emulators. Later native-only compatibility changes have their own build/smoke evidence.

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --fatal-infos
flutter test --coverage
npm test --prefix payment_demo/server
(cd firebase/emulator-tests && npm run emulators)
flutter build apk --debug --dart-define-from-file=config/dev.json
```

Use Flutter 3.47.5 / Dart 3.13.4 (`.fvmrc`), Node 22, JDK 21; Android min 26, compile/target 36. Install with `adb install -r` to preserve app data. Integration tests can replace the normal APK/reset permissions; rebuild the configured app afterward. Run completed checks again when a relevant change warrants regression.

## Follow-up scope

Natural overnight Doze, Samsung-specific sleeping policies, physical phone/older-API native alarm behavior and a real two-account live denial remain unverified. The API 26 lock-screen flag fallback is source/build checked. Modern lock-screen API calls are unchanged; native Dismiss now uses a 72dp minimum (96px on this tablet). The final packaged native alert/button and restored-state checks passed. These limits are separate from the completed first tablet pass.

Hosted Actions/branch protection await a remote repository. Phase 2 visual design and later business workflows, full synchronization, recurring billing, production entitlements, release signing and gamification remain in their planned phases. No CORE-DEMO/final project milestone is declared here.
