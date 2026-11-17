# Bimbi · Android Phase 1

A Flutter/Riverpod development app for proving Android wellbeing capabilities before building the complete product. Android phone + tablet only. Final project deadline: November 22, 2026, 23:59 America/Mexico_City.

## What is implemented

- Five adaptive destinations; Material 3 light/dark themes, 48dp controls and scroll-safe layouts.
- Native AlarmManager experiment with durable local schedule, boot restoration, recurrence, audible foreground service, native wake screen, notification dismissal and emergency Back dismissal.
- Email/password, Google and GitHub Firebase adapters; verification/resend/reset and restored session UI.
- Opt-in FCM topic and lifecycle handlers, foreground status and notification-tap navigation.
- Foreground GPS, bounded in-memory route, bad-sample filtering and accelerometer experiment.
- Native Google map with a public Chapultepec marker when a restricted key is configured.
- Strict owner-only Firebase probe rules and small data/image readback experiment.
- Stripe test PaymentSheet and authenticated TypeScript backend with server-owned prices, ownership verification and durable retry mapping.
- Automated Flutter, backend, security-rule tests and an Android CI workflow.

**The first tablet feasibility pass completed on November 16, 2026.** See [Phase 1 evidence](docs/evidence/phase1/REPORT.md) for device, owner-confirmed, unit/emulator results and verification limits; the current development APK is identified by its [checksum](docs/evidence/phase1/apk-sha256.txt). The finished sleep diary, Focus timer, production alarm editing, recurring subscriptions, avatar policy, cloud synchronization and gamification are later phases.

## Run

Flutter 3.47.5 / Dart 3.13.4; Android API 26 minimum, compile/target 36. Node 22 for backend/CI; JDK 21 for Gradle and Firebase emulators.

```sh
flutter pub get
flutter run -d <android-device>
```

The unconfigured build works offline for native experiments. Use `.fvmrc` with FVM to reproduce the SDK (`fvm install`, then `fvm flutter ...`). To connect services, follow [SETUP](docs/SETUP.md); never paste secrets into tracked files.

```sh
cp config/dev.example.json config/dev.json
flutter run -d <android-device> --dart-define-from-file=config/dev.json
```

The harness is enabled only in debug builds and can be disabled with `--dart-define=PHASE1_HARNESS=false`. Release builds do not expose experimental controls. This is a **debug-signed sideload APK**, not a production release.

## Validate and build

```sh
npm ci --prefix payment_demo/server
npm ci --prefix firebase/emulator-tests
./scripts/check.sh
flutter test integration_test/shell_test.dart -d <android-device>
flutter build apk --debug --dart-define-from-file=config/dev.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Device integration tests may reinstall/reset app permissions. Regrant through Android settings before alarm testing. The shared check script uses emulated project `demo-bimbi`; it never deploys rules or sends live payments.

## Safety and privacy boundaries

Alarm execution and dismissal never use Firebase or gamification. One-shot test audio has a two-minute timeout; use Cancel pending alarm to end a recurrence experiment. Device permissions are explicit. GPS samples are not uploaded. Payment fields remain in PaymentSheet; Stripe secret keys only belong in the server secret store. Paid access is never granted by this experiment.

See [architecture](docs/ARCHITECTURE.md), [setup](docs/SETUP.md), [test plan](docs/TEST_PLAN.md), [limitations](docs/LIMITATIONS.md), and [security](docs/SECURITY.md).
