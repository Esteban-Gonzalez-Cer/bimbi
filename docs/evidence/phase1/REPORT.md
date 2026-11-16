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
| Firebase rules emulators | 6 scenarios passed; rerun after gRPC patch passed | Database and Storage rules deployed; live owner readback passed; real two-account denial remains pending |
| Android debug APK | Latest native source rebuilt and installed successfully with Google auth and confirmed database URL | Maps tiles/marker and live private record/image readback passed |
| 360dp phone emulator | Five-destination integration test passed on managed rerun | UI interaction only; no emulator claim for physical alarm/GPS reliability |
| 412dp phone emulator | Five-destination integration test passed on managed rerun | UI interaction only; no emulator claim for physical alarm/GPS reliability |

Phone screenshot evidence: phone-360.png and phone-412.png. Rule test output: rules-tests.txt. Initial phone runner error is preserved in phone-360-test.txt. Managed reruns passed using a software-rendered emulator kept alive for the complete test and --disable-dds. Successful outputs are phone-360-managed-test.txt and phone-412-managed-test.txt. Both recorded actual five-destination assertions; screenshots are supplementary evidence.

## Physical tablet evidence

Samsung Galaxy Tab A9 SM-X115, Android 16 / API 36. Physical display 800×1340 at 213dpi (~601 logical pixels wide). GPS and accelerometer features reported; no gyroscope feature reported. Battery saver initially off. OEM power exemptions, TalkBack and outdoor GPS not yet verified. See device.txt.

### Basic alarm — PASS for background/screen-off scenario

Exact alarm, notification and full-screen access granted. Scheduled epoch 1794811105053; receiver recorded actual epoch 1794811105127: **74ms after the scheduled time**. Native wake screen and Dismiss button observed; owner confirmed audible sound. Native dismissal recorded and AlarmService absent afterward.

Evidence: tablet-native-alarm.png and alarm-events.txt. An am-kill request in this first attempt did not actually terminate the process (PID remained 29206), so this result is not counted as process-death proof.

### Process death without force-stop — PASS for delivery

A second alarm was scheduled for epoch 1794811774652 by PID 29206. Only Bimbi's process was terminated using the app UID. Delivery occurred at epoch 1794811776186 in **new PID 31486**, 1534ms after scheduled time, including cold startup. Native dismissal was invoked afterward. This proves the observed scenario, not all OEM/battery conditions.

### Google identity — PASS by owner confirmation

Owner completed Google account consent on the installed Firebase-connected build and confirmed that Profile shows their account and **Email verified**. Personal account details were not exported into evidence. Email/password verification/reset, GitHub, session restoration and sign-out still require separate tests.

### Live private database and image probe — PASS

On the signed-in physical tablet, the verified session was refreshed and the real Firebase probe executed. The app reported: “Private record and image matched after readback; probe data deleted.” This establishes the owner roundtrip for the scoped record and PNG, including cleanup. Emulator cross-user denials are separately tested; actual second-account denial has not yet been exercised.

### Accelerometer — PASS by owner confirmation

The foreground motion experiment was started on the physical tablet. The owner gently moved the tablet and confirmed the Movement number changed. This establishes a real signal on this unit; it does not yet prove every lifecycle cancellation/denial scenario.

### Native Google map — PASS for rendering

The Maps-configured build was installed successfully. The native map displayed real tiles and the Bosque de Chapultepec marker on the physical tablet; visually inspected screenshot: tablet-map.png. This does not establish outdoor GPS tracking.

### FCM subscription and foreground delivery — PASS

Bimbi Profile was inspected on the physical tablet after enabling the test topic. It displayed “Subscribed to the Phase 1 topic.” The topic is bimbi_phase1. The owner published a Firebase Console notification campaign to this topic while Bimbi was foreground. The owner clarified that an initial campaign missed the topic, then published a corrected topic-targeted campaign. A subsequent device inspection confirmed “Foreground topic message received.” The initial absence is not counted as an FCM delivery failure or measured latency. No precise send-to-receive latency was measured. The new project initially displayed the Create your first campaign onboarding page.

### FCM background delivery and notification tap — PASS

After Bimbi was put in the background using Home, the owner published another console notification to bimbi_phase1 and reported that it arrived approximately 1–2 minutes later. That timing is an owner estimate, not instrumented latency. The owner tapped the notification and confirmed that Bimbi opened. Device inspection independently confirmed Bimbi Profile and “Notification opened the requested tab.” The running app PID at that inspection was 5395. The ordinary terminated-state case is documented below.

### FCM ordinary terminated delivery and notification tap — PASS

After the background case, Bimbi was backgrounded using Home and only its app process (PID 5395) was terminated using the app UID. A subsequent pidof check returned no running Bimbi process. Android Force stop was not used. The owner published the closed-app test campaign to bimbi_phase1, confirmed notification arrival, and tapped it. Device inspection then independently confirmed Bimbi Profile, “Notification opened the requested tab,” and new PID 5836. This establishes the normal terminated/cold-start case on this device; it does not establish force-stop support.

FCM-01 is now PASS for the three tested lifecycle cases and notification-open handling. The background arrival time of approximately 1–2 minutes remains an owner estimate. No absolute latency or always-on delivery guarantee is claimed.

## Cloud configuration state

- Development project bimbi-26ae2 and Android com.bimbi.app registration confirmed through Firebase CLI.
- Owner refreshed the local Firebase sign-in and enabled Email/Password + Google.
- Debug SHA-1/SHA-256 registered; web OAuth client downloaded to ignored local config. Google login confirmed above.
- Realtime Database and Storage are provisioned. The tested owner-only rules were successfully deployed to both.
- The default us-central1 database was confirmed active, and the tested database rules were successfully deployed. Storage bucket bimbi-26ae2.firebasestorage.app is now provisioned and its rules deployed successfully. Use the continuation instructions in docs/CONTINUE_PHASE1.md to inspect the new resources before deployment.
- Owner supplied a billing-linked Maps Android key privately. It was moved from the tracked Gradle settings into ignored android/secrets.properties before any commit; the rebuilt APK displayed native map tiles and the Bosque de Chapultepec marker on the physical tablet (tablet-map.png). GitHub OAuth and Stripe sandbox/deployment remain pending. FCM topic subscription, foreground/background/ordinary terminated delivery and notification-open handling passed on the physical tablet.

## Remaining physical checks

Reboot/unlock restoration; recurrence across multiple deliveries; exact-access revocation; notification/channel/full-screen denial; battery saver/Doze; offline alarm; native Back dismissal after the latest patch; TalkBack and tablet landscape; real outdoor GPS and permission denial; optional Usage Access grant/revoke; Stripe test success/decline/cancel.

## Build and dependency notes

The current APK is debug-signed and installable, not a final signed release. Its checksum is in apk-sha256.txt. It includes Google identity and persistent payment attempt IDs. The latest native source (predictive Back dismissal and blocked-channel detection) rebuilt successfully and all 22 Flutter tests passed. The latest locally configured APK was rebuilt and installed with the confirmed database URL; Maps and Storage are configured and their basic live checks passed.

Pinned Flutter build warns about FlutterFire plugins applying legacy Kotlin Gradle Plugin behavior. Current compilation succeeds; retest before upgrading Flutter. Firebase emulator development dependencies retain 14 moderate advisories after patching high-severity gRPC issues; those npm packages are not shipped in the APK or backend. Backend installation audit reported zero vulnerabilities. CI workflow is prepared; no remote/hosted Actions run exists.

## Execution interruption

Automatic approval review initially could not complete due to a reported usage limit. A later account-status check showed ordinary usage available (3% five-hour, 22% weekly used), and the same escalated validation command was accepted on retry. Final Node 22 tests, Flutter checks and rebuild then passed. No credits or reset were required, and the restriction was not bypassed.
