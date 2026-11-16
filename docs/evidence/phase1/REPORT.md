# Phase 1 evidence — November 16, 2026

Verdict: **CONDITIONAL / IN PROGRESS**. The app and experiments are implemented; full platform acceptance remains incomplete. Implementation checkpoint: local commit 8ee3d96 on feat/phase1-feasibility. No Phase 1 PASS or CORE-DEMO tag has been issued.

## Confirmed automated results

| Check | Result | Limit |
|---|---|---|
| Flutter analyzer | No issues in final run | Full cloud/device acceptance remains separate |
| Flutter unit/widget tests | 22 passed | Four logical widths (360/412/700/900), text scales 1/1.3/2; platform and tracking adapters |
| Physical tablet navigation | 1 integration test passed | All five destinations; cloud configuration absent in that specific test build |
| TypeScript build | Passed after latest backend test additions | Runtime cloud deployment not executed |
| Payment backend | 11 scenarios passed on Node 22.23.5 | Cloud deployment and real Stripe receipts pending |
| Firebase rules emulators | 6 scenarios passed; rerun after gRPC patch passed | Actual deployed rules and live readback still pending |
| Android debug APK | Latest native source rebuilt and installed successfully with Google auth and confirmed database URL | Maps/Storage configuration remains pending |
| 360dp phone emulator | Screenshot captured; interaction test blocked by Dart Development Service startup failure | No application assertion executed in that failed test |
| 412dp phone emulator | Screenshot captured | Independent retry could not locate the emulator after it disconnected |

Phone screenshot evidence: phone-360.png and phone-412.png. Rule test output: rules-tests.txt. Phone runner error: phone-360-test.txt. Widget tests provide automated responsive interaction coverage; emulator screenshots alone do not prove full interaction acceptance.

## Physical tablet evidence

Samsung Galaxy Tab A9 SM-X115, Android 16 / API 36. Physical display 800×1340 at 213dpi (~601 logical pixels wide). GPS and accelerometer features reported; no gyroscope feature reported. Battery saver initially off. OEM power exemptions, TalkBack and outdoor GPS not yet verified. See device.txt.

### Basic alarm — PASS for background/screen-off scenario

Exact alarm, notification and full-screen access granted. Scheduled epoch 1794811105053; receiver recorded actual epoch 1794811105127: **74ms after the scheduled time**. Native wake screen and Dismiss button observed; owner confirmed audible sound. Native dismissal recorded and AlarmService absent afterward.

Evidence: tablet-native-alarm.png and alarm-events.txt. An am-kill request in this first attempt did not actually terminate the process (PID remained 29206), so this result is not counted as process-death proof.

### Process death without force-stop — PASS for delivery

A second alarm was scheduled for epoch 1794811774652 by PID 29206. Only Bimbi's process was terminated using the app UID. Delivery occurred at epoch 1794811776186 in **new PID 31486**, 1534ms after scheduled time, including cold startup. Native dismissal was invoked afterward. This proves the observed scenario, not all OEM/battery conditions.

### Google identity — PASS by owner confirmation

Owner completed Google account consent on the installed Firebase-connected build and confirmed that Profile shows their account and **Email verified**. Personal account details were not exported into evidence. Email/password verification/reset, GitHub, session restoration and sign-out still require separate tests.

## Cloud configuration state

- Development project bimbi-26ae2 and Android com.bimbi.app registration confirmed through Firebase CLI.
- Owner refreshed the local Firebase sign-in and enabled Email/Password + Google.
- Debug SHA-1/SHA-256 registered; web OAuth client downloaded to ignored local config. Google login confirmed above.
- Owner reports Realtime Database and Storage were created in locked mode. This readiness report does not establish deployment or live readback.
- The default us-central1 database was confirmed active, and the tested database rules were successfully deployed. Firebase Storage still reports setup incomplete; its rule deployment remains pending. Use the continuation instructions in docs/CONTINUE_PHASE1.md to inspect the new resources before deployment.
- Owner reports a billing-linked Maps Android key is ready; private local key configuration and actual map display remain pending. GitHub OAuth, Stripe sandbox/deployment and FCM topic sends remain pending.

## Remaining physical checks

Reboot/unlock restoration; recurrence across multiple deliveries; exact-access revocation; notification/channel/full-screen denial; battery saver/Doze; offline alarm; native Back dismissal after the latest patch; TalkBack and tablet landscape; real outdoor GPS and permission denial; accelerometer signal; optional Usage Access grant/revoke; live cloud probe; three-state FCM; Maps tiles; Stripe test success/decline/cancel.

## Build and dependency notes

The current APK is debug-signed and installable, not a final signed release. Its checksum is in apk-sha256.txt. It includes Google identity and persistent payment attempt IDs. The latest native source (predictive Back dismissal and blocked-channel detection) rebuilt successfully and all 22 Flutter tests passed. The latest locally configured APK was rebuilt and installed with the confirmed database URL; Maps/Storage require their remaining configuration.

Pinned Flutter build warns about FlutterFire plugins applying legacy Kotlin Gradle Plugin behavior. Current compilation succeeds; retest before upgrading Flutter. Firebase emulator development dependencies retain 14 moderate advisories after patching high-severity gRPC issues; those npm packages are not shipped in the APK or backend. Backend installation audit reported zero vulnerabilities. CI workflow is prepared; no remote/hosted Actions run exists.

## Execution interruption

Automatic approval review initially could not complete due to a reported usage limit. A later account-status check showed ordinary usage available (3% five-hour, 22% weekly used), and the same escalated validation command was accepted on retry. Final Node 22 tests, Flutter checks and rebuild then passed. No credits or reset were required, and the restriction was not bypassed.
