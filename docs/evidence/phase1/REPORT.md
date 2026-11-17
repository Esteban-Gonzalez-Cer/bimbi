# Phase 1 evidence — November 16, 2026

Verdict: **CONDITIONAL / IN PROGRESS**. The app and experiments are implemented; full platform acceptance remains incomplete. Implementation checkpoint: local commit 8ee3d96 on feat/phase1-feasibility. No Phase 1 PASS or CORE-DEMO tag has been issued.

## Confirmed automated results

| Check | Result | Limit |
|---|---|---|
| Flutter analyzer | No issues in final run | Full cloud/device acceptance remains separate |
| Flutter unit/widget tests | 22 passed | Four logical widths (360/412/700/900), text scales 1/1.3/2; platform and tracking adapters |
| Physical tablet navigation | 1 integration test passed | All five destinations; cloud configuration absent in that specific test build |
| TypeScript build | Passed locally and during Firebase predeploy; endpoint ACTIVE | Native sandbox checkout also passed; production billing excluded |
| Payment backend | 11 unit scenarios and 4 live HTTP rejection checks passed; native sandbox cancel/decline/success and retry reuse passed | Production/recurring billing excluded |
| Firebase rules emulators | 6 scenarios passed; rerun after gRPC patch passed | Database and Storage rules deployed; live owner readback passed; real two-account denial remains pending |
| Android debug APK | Payment/Firebase/Maps-connected build installed; verified GitHub session preserved | Remaining GPS/alarm/accessibility scenarios tracked separately |
| 360dp phone emulator | Five-destination integration test passed on managed rerun | UI interaction only; no emulator claim for physical alarm/GPS reliability |
| 412dp phone emulator | Five-destination integration test passed on managed rerun | UI interaction only; no emulator claim for physical alarm/GPS reliability |

Phone screenshot evidence: phone-360.png and phone-412.png. Rule test output: rules-tests.txt. Initial phone runner error is preserved in phone-360-test.txt. Managed reruns passed using a software-rendered emulator kept alive for the complete test and --disable-dds. Successful outputs are phone-360-managed-test.txt and phone-412-managed-test.txt. Both recorded actual five-destination assertions; screenshots are supplementary evidence.

## Physical tablet evidence

Samsung Galaxy Tab A9 SM-X115, Android 16 / API 36. Physical display 800×1340 at 213dpi (~601 logical pixels wide). GPS and accelerometer features reported; no gyroscope feature reported. Battery saver initially off. Outdoor GPS sampling passed below; OEM power exemptions and TalkBack remain unverified. See device.txt.

### Basic alarm — PASS for background/screen-off scenario

Exact alarm, notification and full-screen access granted. Scheduled epoch 1794811105053; receiver recorded actual epoch 1794811105127: **74ms after the scheduled time**. Native wake screen and Dismiss button observed; owner confirmed audible sound. Native dismissal recorded and AlarmService absent afterward.

Evidence: tablet-native-alarm.png and alarm-events.txt. An am-kill request in this first attempt did not actually terminate the process (PID remained 29206), so this result is not counted as process-death proof.

### Process death without force-stop — PASS for delivery

A second alarm was scheduled for epoch 1794811774652 by PID 29206. Only Bimbi's process was terminated using the app UID. Delivery occurred at epoch 1794811776186 in **new PID 31486**, 1534ms after scheduled time, including cold startup. Native dismissal was invoked afterward. This proves the observed scenario, not all OEM/battery conditions.

### Reboot and unlock restoration — PASS for sound and notification delivery

A three-minute alarm was persisted for epoch 1794881914421, then the tablet was restarted. The owner unlocked it before the due time without opening Bimbi. The boot receiver re-registered the same future occurrence at 20:17:22 Mexico City time. Delivery was recorded at epoch 1794881915486, **1065ms after the scheduled time**. The owner confirmed hearing the alarm and seeing its notification, but did not see a full-screen alarm in this scenario. The native two-minute safety timeout dismissed it at 20:20:35. No duplicate delivery was observed. Evidence: alarm-before-reboot-events.txt and alarm-after-reboot-events.txt.

This establishes persisted reboot/unlock restoration and the audible notification scenario. It does not establish automatic full-screen presentation during that particular reboot test. Android uses an expanded notification while the device is being used; the exact screen state at that delivery was not independently captured. See [Android notification guidance](https://developer.android.com/develop/ui/compose/notifications/create-notification?hl=en).

### Locked-screen presentation and native Back dismissal — PASS

Exact, notification and full-screen capability checks all showed allowed. A new 30-second alarm was scheduled for epoch 1794882539996. The screen was switched off **before** delivery and screenState=SCREEN_STATE_OFF was independently checked. The receiver fired at epoch 1794882540036, **40ms after the scheduled time**. The native full-screen “Good morning / Bimbi wake alarm” activity and clickable “DISMISS ALARM” control were observed over the locked screen. Evidence: tablet-locked-alarm.png and alarm-locked-screen-events.txt.

Android Back was sent while that native activity was visibly active. Dismissal was logged at 20:29:34, well before the two-minute timeout. Independent checks then showed active=false, no pending occurrence and no running AlarmService. This validates the native Back path on the observed build (06ff148c…); the subsequent builds retain that Back implementation. TalkBack operation remains a separate check.

### Permission denial and notification revocation — PASS for the recorded cases

On the badge-adjusted build (SHA-256 fb9e33e28157def3261a3c9dba9240f76c5ba6cc4fa2deb136687a88319e8ffe), actual exact-alarm UID denial was confirmed by the app before attempting to schedule. Scheduling returned exact_permission_denied with no persisted pending alarm. The initial package-only app-op setup did not override the tablet's UID grant and is not counted as a denial test; the ordinary alert from that setup was stopped.

The POST_NOTIFICATIONS runtime permission was then revoked. Bimbi reported notifications not allowed and rejected scheduling with notification_permission_denied and no pending alarm. After restoring permission, another 30-second alarm was scheduled and notification permission was revoked before its due time. Native delivery recorded delivery_notification_permission_denied, cleared the occurrence and left no active alarm or AlarmService. Permission was restored afterward.

A separate alarm was allowed to start. With its service independently observed active, the real Samsung Wake alarms channel's Allow notifications switch was disabled. The new one-second access check stopped the alert, cleared pending recurrence and recorded notification_permission_revoked_alert_stopped. Independent checks found no active alarm or service. The channel switch was restored. These tests validate the new receiver/service access checks; see alarm-permission-observations.txt, alarm-permission-events.txt and alarm-active-channel-revocation-events.txt.

Revoking exact access after scheduling a further 30-second occurrence prevented delivery: no matching fired event, active alarm or service was observed after its due time. On reopening, Bimbi explicitly reported exact access not allowed. The local saved intent was retained while permission was denied; it was not armed in Android. Regranting access triggered the restore receiver, which cleared the now-expired one-time occurrence and recorded missed_during_downtime. Original access was restored. Evidence: alarm-exact-revocation-events.txt.

### Full-screen-denied locked fallback — UNVERIFIED; owner observation pending

Full-screen access was disabled in Samsung Settings and Bimbi confirmed the denied capability while notifications remained allowed. With the screen off before delivery, no automatic native full-screen activity appeared, as expected. Automation did not locate the notification title/action in the locked shade and could not reach the Settings switch through keyguard. This is not counted as a fallback-dismissal PASS or a proven app failure. The test service was stopped through only the app's UID. A fresh three-minute alarm (epoch 1794885571212) is now with the owner for a manual locked-notification dismissal check, followed by unlocking and restoration of full-screen access. See alarm-permission-observations.txt and alarm-fullscreen-denied-events.txt.

### Google identity — PASS by owner confirmation

Owner completed Google account consent on the installed Firebase-connected build and confirmed that Profile shows their account and **Email verified**. Personal account details were not exported into evidence. GitHub, verification and restored-session results are recorded separately below; email/password still requires its own live checks.

### GitHub identity, session restoration and email verification — PASS after fresh-session retry

The owner configured the GitHub OAuth App and enabled Firebase's GitHub provider using the callback shown by Firebase: https://bimbi-26ae2.firebaseapp.com/__/auth/handler. The first physical-tablet attempt reached Chrome's hosted-handler page but showed missing initial state after consent. Bimbi's installed FlutterFire plugin delegates to native Firebase startActivityForSignInWithProvider, and its merged manifest includes GenericIdpActivity with the genericidp return scheme. No callback or SDK configuration change was made.

The failed Chrome custom tab was closed, returning web-context-canceled to Bimbi, and a new GitHub attempt was started from the app. The owner confirmed return to Bimbi; independent UI inspection showed “GitHub sign-in completed,” Provider: github.com, and Email not verified. This demonstrates a successful fresh-session retry, not a permanent fix for browser-state loss. The first failure remains recorded as a reliability risk. A separate process restart completed with LaunchState COLD and new PID 10099 (old PID 5836). Without signing in again, Profile restored Provider: github.com and Email not verified. This establishes session persistence for the observed restart. Firebase accepted the verification-email request. The owner opened the link and confirmed successful verification. The app then refreshed the user record and ID token; independent UI inspection showed Session refreshed, Email verified and Provider: github.com.

### Email/password creation, verification, reset and restored session — PASS

The owner created an account with a controlled unused inbox/alias, entering its password privately on the tablet. Independent UI inspection showed the password provider and Email not verified. The private-data and both payment controls were disabled. Resend verification succeeded without a rate-limit response. After the owner followed the newest verification link, Bimbi refreshed the user and ID token and showed Email verified. The private-data control became enabled; the real record/image readback and cleanup passed for this account.

Only the Bimbi process was terminated without force-stop, then a relaunch reported LaunchState COLD with a new process. The verified password-provider session restored without another sign-in. Sign out then showed Signed out and removed the account/provider controls. The owner requested password reset in Bimbi, followed the inbox link, chose a new password privately and confirmed reset and sign-in. Independent UI inspection then showed Signed in, Email verified and Provider: password. Generic evidence is in auth-observations.txt; no addresses or credentials were exported.

### Tablet navigation and enlarged text — PASS for interaction; badge adjustment pending visual recheck

All five destinations and their matching app-bar headers were independently exercised at portrait and landscape orientations with system font_scale 1.0 and 2.0. Actual rotation was set through wm user-rotation, rather than merely changing a preference that the tablet might ignore. The original free rotation and font_scale 1 were restored. See tablet-layout-observations.txt and tablet-*-text-*.png. No profile or route screenshots were retained.

Visual review found the development-only Phase 1 badge clipped vertically at enlarged text. Its vertical padding was removed and the app passed formatting, analysis, all 22 Flutter tests and a configured debug build. The adjusted badge still needs its installed visual recheck. TalkBack remains unverified. The initial layout automation attempt had no usable UI hierarchy with the screen asleep; the successful run woke the screen and checked each destination explicitly.

### Live private database and image probe — PASS

On the signed-in physical tablet, the verified session was refreshed and the real Firebase probe executed. The app reported: “Private record and image matched after readback; probe data deleted.” This establishes the owner roundtrip for the scoped record and PNG, including cleanup. The probe also passed after GitHub email verification and a forced token refresh, independently confirming that the newly verified GitHub session could access its own scoped data. Emulator cross-user denials are separately tested; actual second-account denial has not yet been exercised.

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

### Stripe native sandbox checkout — PASS

The payment-connected debug APK was installed on the physical tablet and preserved the verified GitHub session. PaymentSheet opened with the server-set MX$10.00 test amount and a visible TEST indicator. Closing it reported “Payment cancelled. No paid access granted.” Reopening reused exactly the same server-recorded PaymentIntent, with one attempt record.

Stripe's published generic-decline card was submitted through its provider-managed fields; the sheet displayed “Your payment method was declined” and stayed open. Replacing it with the published success test card completed checkout. Bimbi then displayed “Test payment verified by the server. Production access remains unchanged.” That message is emitted only after the authenticated backend retrieves Stripe state and validates owner, amount, currency and livemode=false before returning verified=true.

Independent persisted-state reads confirmed one unchanged PaymentIntent reference throughout the sequence and no paid-entitlement record after success. No account IDs, PaymentIntent IDs, card values, CVCs or secrets were exported into evidence. A generic success screenshot is saved as payment-verified-public-screen.png, taken on the public park screen before GPS collection, away from profile data. See payment-observations.txt and payment-endpoint-checks.txt. This establishes F4/PAY-01 for the tested sandbox cases, not production subscriptions, webhooks or real charges.

### GPS permission denial and foreground sample capture — PASS

Device location was enabled at preflight. Start GPS opened Android's location-consent dialog. Selecting Don't allow left Bimbi usable on Running, displayed the permission-unavailable message, and kept Accepted GPS samples at 0. The owner then performed the requested foreground walk and reported seven accepted samples. Independent tablet inspection confirmed Accepted GPS samples: 7 and Tracking stopped; a subsequent inspection still showed the same stopped count. The in-memory trace was cleared before further testing and the following restart discards memory as well. No coordinates or private route screenshots were exported. This verifies the observed sample/stop scenario; distance accuracy and long-running tracking remain outside this spike.

## Cloud configuration state

- Development project bimbi-26ae2 and Android com.bimbi.app registration confirmed through Firebase CLI.
- Owner refreshed the local Firebase sign-in and enabled Email/Password + Google.
- Debug SHA-1/SHA-256 registered; web OAuth client downloaded to ignored local config. Google login confirmed above.
- Realtime Database and Storage are provisioned. The tested owner-only rules were successfully deployed to both.
- The default us-central1 database was confirmed active, and the tested database rules were successfully deployed. Storage bucket bimbi-26ae2.firebasestorage.app is now provisioned and its rules deployed successfully. Use the continuation instructions in docs/CONTINUE_PHASE1.md to inspect the new resources before deployment.
- Owner supplied a billing-linked Maps Android key privately. It was moved from the tracked Gradle settings into ignored android/secrets.properties before any commit; the rebuilt APK displayed native map tiles and the Bosque de Chapultepec marker on the physical tablet (tablet-map.png). GitHub sign-in succeeded after a browser-session retry; its email-verification and cold-start session-restoration checks also passed. A sandbox publishable key is saved in ignored local app configuration and has the required pk_test_ prefix; no server secret was found in that file. The first secret setup used the key as the resource name instead of the literal STRIPE_SECRET_KEY name; correction instructions and test-key rotation guidance were provided without exporting the value. A subsequent metadata-only lookup confirmed the correctly named STRIPE_SECRET_KEY exists. The paymentApi endpoint was then deployed successfully in us-central1 on Node 22 (gcfv2), ACTIVE with maxInstances 1 and configured minInstances 0. Its new artifact repository has one-day image cleanup. Four live HTTP boundary checks passed (405 for GET; 401 for anonymous create/verify and an invalid identity token). Native sandbox checkout has now passed the cancellation, decline and server-verified success cases below. FCM topic subscription, foreground/background/ordinary terminated delivery and notification-open handling passed on the physical tablet.

## Remaining physical checks

Recurrence across multiple deliveries; full-screen denial; battery saver/Doze; offline alarm; TalkBack; optional Usage Access grant/revoke. Exact-access denial/revocation and notification/channel denial/revocation passed individually, with grants restored. Reboot/unlock sound and notification delivery, locked-screen presentation and native Back dismissal passed as individually recorded above. Tablet portrait/landscape and enlarged-text navigation passed, with the small badge fix awaiting its visual recheck.

## Build and dependency notes

The current APK is debug-signed and installable, not a final signed release. Its checksum is in apk-sha256.txt. It includes Google/GitHub identity and persistent payment attempt IDs. A new payment-connected APK compiled successfully after saving the deployed endpoint URL. Initial installation was blocked by disconnection; it was installed successfully after the owner reconnected the tablet. Previous installed builds passed the native/map/auth checks documented above. The latest native source (predictive Back dismissal and blocked-channel detection) rebuilt successfully and all 22 Flutter tests passed. The latest locally configured APK was rebuilt and installed with the confirmed database URL; Maps and Storage are configured and their basic live checks passed.

Pinned Flutter build warns about FlutterFire plugins applying legacy Kotlin Gradle Plugin behavior. Current compilation succeeds; retest before upgrading Flutter. Firebase emulator development dependencies retain 14 moderate advisories after patching high-severity gRPC issues; those npm packages are not shipped in the APK or backend. Backend installation audit reported zero vulnerabilities. CI workflow is prepared; no remote/hosted Actions run exists.

## Execution interruption

Automatic approval review initially could not complete due to a reported usage limit. A later account-status check showed ordinary usage available (3% five-hour, 22% weekly used), and the same escalated validation command was accepted on retry. Final Node 22 tests, Flutter checks and rebuild then passed. No credits or reset were required, and the restriction was not bypassed.
