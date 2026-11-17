# Development service setup

Project selected by owner: `bimbi-26ae2`. Android application ID: `com.bimbi.app`. Use development accounts and Stripe test mode exclusively.

## Firebase and Google sign-in

1. Install dependencies (`npm ci --prefix firebase/emulator-tests`). Run `./scripts/firebase.sh login --reauth` when needed.
2. Register an Android app with the exact package name. Add SHA-1 and SHA-256 from the debug signing certificate. Each developer/CI/release certificate needs its own registration; do not commit private signing keys.
3. Enable Authentication email/password and Google. Select a support email. Google sign-in requires the **web OAuth client ID** as `GOOGLE_SERVER_CLIENT_ID`, not the Android OAuth client ID.
4. Download the Android SDK config and place it in ignored `android/app/google-services.json`. Fill ignored `config/dev.json` from the example. Firebase mobile API keys identify the project; they do not replace Security Rules. This app initializes Firebase explicitly using Dart configuration, so no Google Services Gradle plugin is required.
5. For GitHub, create an OAuth App in GitHub Developer Settings. Copy the callback URL shown by the Firebase GitHub provider exactly. Store its client ID/secret in Firebase Console, never in Flutter. Enable the provider. Do not request private-repository scopes.
6. Create a Realtime Database in `us-central1` in locked mode. Fill its actual URL (do not guess). Provision Storage on Blaze with locked rules. Fill the actual bucket name.
7. Inspect and deploy only the scoped rules after emulator tests pass:

```sh
./scripts/firebase.sh deploy --only database,storage --project bimbi-26ae2
```

These Phase 1 rules intentionally deny all product paths other than the verified owner's small probe. Do not reuse them unchanged as a complete Phase 3 schema.

8. Rebuild with `--dart-define-from-file=config/dev.json`. On Profile create an account, check email, refresh verification, then run the private-data/image probe. Use two separate accounts for cross-user testing. Screenshots of actual account data must stay private.

### GitHub browser-state troubleshooting

A physical-tablet test encountered the hosted handler's “missing initial state” page after consent with the correct Firebase callback. Closing the failed Chrome custom tab and starting a new GitHub attempt from Bimbi succeeded; native-session restoration also passed. Treat this as an observed recovery, not a proven permanent fix.

Keep the callback Firebase supplies. Start sign-in from the app and complete it within the same browser context. If this error occurs, close the failed custom tab and retry from the app; do not open the callback URL directly, disable OAuth state validation, clear all browser data, or change database rules as a workaround. Repeated occurrences require recording browser/SDK versions and sanitized redirect diagnostics before choosing a change. Never export OAuth codes, state values, or credentials in evidence.

## FCM console experiment

Open Profile → Enable test topic and grant notification consent. Firebase Console → Messaging → notification campaign → topic `bimbi_phase1`; optionally add custom data `destination=profile` (or alarm/sleep/focus/running). Use generic test text without private information.

For a new Firebase project the Messaging landing page shows **Create your first campaign**. Select **Firebase Notification messages** (not In-App Messaging), then Create. Enter a generic title/body, continue to Target, choose Topic, and enter/select `bimbi_phase1`. The topic is created by the client subscription; it is not a manually provisioned database resource. Confirm Bimbi shows **Subscribed to the Phase 1 topic** before targeting it. The separate Send test message dialog asks for a registration identifier and is not the topic-send path. Console autocomplete may not immediately reflect a new subscription; do not switch to all users as a workaround.

Send independently with Bimbi foreground, background, and terminated normally. Tap background/terminated notifications and confirm the destination. Force-stop in Android settings is a separate negative case; reopen before expecting delivery. No custom sending backend is installed. Disable the topic when finished.

## Maps and cost controls

Enable Maps SDK for Android only, with a billing account and an Android-restricted key for `com.bimbi.app` + the registered signing SHA-1. Restrict the key to Maps SDK for Android. Put `MAPS_API_KEY=...` in ignored `android/secrets.properties`, local `~/.gradle/gradle.properties`, or pass it as an environment variable during build. Never put it in tracked `android/gradle.properties`. Never commit it to a tracked file. The app checks whether the native manifest has a key; a key's presence does not establish authorization or billing success.

Use the included public Chapultepec marker without Places/Directions requests. Source: https://mexicocity.cdmx.gob.mx/locations/chapultepec-park/?lang=es . Its coordinate is a representative point within the park, not a verified route or a user's position.

Configure a monthly alerts-only budget scoped to the development project, email thresholds (50/90/100% are the defaults), supported request quotas, and review usage after each session. An alerts-only budget sends warnings as costs rise; it does not impose a spend cap. Free allowances do not guarantee zero cost. Keep large media, live traffic, paid map services and production environments out of Phase 1. See [Google Cloud budget setup](https://docs.cloud.google.com/billing/docs/how-to/budgets).

## Stripe

1. Create/open a Stripe sandbox and use test keys only. The app rejects a publishable key without `pk_test_`; the backend rejects a secret without `sk_test_`.
2. Run `./scripts/firebase.sh functions:secrets:set STRIPE_SECRET_KEY --project bimbi-26ae2` exactly as written. `STRIPE_SECRET_KEY` is the literal resource name, not a placeholder for the key value. Paste the actual sandbox secret only when the private prompt says `Enter a value for STRIPE_SECRET_KEY:`. A successful resource path ends in `/secrets/STRIPE_SECRET_KEY/versions/<number>`. Never put the key itself in the command arguments or resource name. If that happens, rotate the test key before saving it correctly.
3. `npm ci --prefix payment_demo/server && npm test --prefix payment_demo/server`.
4. Deploy the `paymentApi` function after reviewing the backend and its billing settings. It uses Node 22, us-central1, minInstances 0, maxInstances 1, concurrency 10. Set Artifact Registry cleanup to avoid accumulating deployment images. These settings reduce costs but are not a hard financial cap.
5. Set `PAYMENT_BASE_URL` to the deployed function URL without a trailing slash and `STRIPE_PUBLISHABLE_KEY` to its matching test key. Sign in with verified email first.
6. Plus uses MXN 10.00, Premium MXN 20.00 as **one-time synthetic test amounts**, not real prices or subscriptions. Use Stripe's official test cards for success/decline; cancel directly in PaymentSheet. Check the server result and Stripe test dashboard. Never enter a real card.

Creation accepts only `plan` and `requestId`; verification accepts only `paymentIntentId`. The backend reads the authenticated UID and server plan prices. Test receipts do not grant product entitlements. No webhook or production billing workflow is claimed.

## Phone emulator profiles

Run `ANDROID_HOME=<sdk> ./scripts/create_phone_emulators.sh`. Launch each separately or select the right serial with `adb -s`:

- Bimbi_Phone_360: `wm size 1080x2160`, `wm density 480` → 360×720 logical pixels.
- Bimbi_Phone_412: `wm size 1236x2472`, `wm density 480` → 412×824 logical pixels.

The script chooses ARM64 on Apple Silicon and x86_64 on Linux CI. Android images require a download on a clean machine. Keep both profiles separate from your personal emulator.

### Managed interaction tests

Keep emulator startup and testing within the same managed run to avoid a disconnected device between commands. The runner starts a dedicated Bimbi profile using the installed software renderer, waits for boot, sets its logical width, runs the five-tab integration test, and stops only the emulator it started. It leaves the physical tablet untouched.

```sh
ANDROID_HOME=<sdk-directory> ./scripts/test_phone_profile.sh 360
ANDROID_HOME=<sdk-directory> ./scripts/test_phone_profile.sh 412
# Integration tests build a test entrypoint; restore the distributable app afterward.
flutter build apk --debug --dart-define-from-file=config/dev.json
```

Run these independently so a failure on one profile does not suppress the other. A failure in the device/graphics runner is not an application PASS; preserve its output and investigate before changing feature code.
