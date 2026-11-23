# ADR-010: Console notification topics, channels and in-app banner

Date: 2026-11-22 · Status: accepted (Phase 7)

## Context
Spec v0.4 F5 asks for:
- Firebase Android FCM with `POST_NOTIFICATIONS`;
- global handlers;
- console-origin topic sends;
- physical evidence in the foreground, background and ordinary terminated states, with force-stop distinguished.

It allows no custom FCM send backend. Phase 1 proved delivery to the test topic `bimbi_phase1`. FCM is never an alarm mechanism.

## Decision
- **Topics.**
  - Two opt-in topics, `bimbi_tips` and `bimbi_updates`. Each has an Android channel of the same id, so it can be muted in Android settings; the console campaign names the channel.
  - The Phase 1 topic is unsubscribed once on upgrade.
- **Consent.** Turning a topic on asks for Android's notification permission first. A denial keeps it off and says so. Nothing is requested at launch or in onboarding.
- **Preferences.**
  - Saved on the device.
  - Verified accounts also keep `users/{uid}/preferences/notificationTopics {tips, updates}`, owner-only with booleans only. A second device signed in to the same account subscribes to the same topics.
- **Handlers** (`InboxController`):
  - Listeners attach at start-up.
  - `onMessage` (foreground) becomes an in-app banner with Dismiss and Open, because Android shows nothing while the app is in front. The banner sits in `MaterialApp.builder`, above every route, so it also shows over Plans, Notifications or a run's detail. Open returns to the tabs first.
  - `onMessageOpenedApp` and `getInitialMessage` open the message's screen.
  - The background isolate entry point only initialises Firebase.
- **Deep links.** Data key `destination` with an allowlist: `alarm`, `sleep`, `focus`, `running`, `profile`, `plans` and `notifications`. Anything else opens Home.
- **Privacy.** No token, message id or message text is stored or logged. Payloads must not carry personal data.

## Alternatives
- **Per-user tokens with a send backend:** forbidden by the spec.
- **`flutter_local_notifications` for foreground display:** a new dependency, and a system notification over an open app adds little.
- **One topic:** simpler, but gives people less control.

## Consequences
- **Force-stop:** after it, Android delivers nothing until Bimbi is opened again. This is documented, not a defect.
- **Delivery timing:** depends on Google Play services and Doze; no latency is promised.

## Revisit trigger
Personalised messages, scheduled reminders (they would be local notifications, not FCM), or store publication.
