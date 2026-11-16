# Phase 1 architecture

Widgets → Riverpod state/controllers → adapters → Android/Firebase/Stripe. Handwritten providers, no application setState or ValueNotifier. `lib/app` composes adaptive navigation. `lib/core` owns configuration, operation status and typed platform failures. Features own their SDK adapters. No gamification dependency exists.

## Android alarm authority

`com.bimbi.app/platform` exposes capabilities, schedule, cancel, dismiss, permission-settings entrypoints and a usage summary. Method failures map to permission_denied, unsupported or platform_error. Scheduling takes id, future UTC epoch milliseconds and an optional fixed recurrence interval in seconds (minimum 60). This is an elapsed-interval experiment, not the later local-wall-clock/DST daily recurrence editor.

One pending record is synchronously persisted in native app-private SharedPreferences before setAlarmClock. A stable PendingIntent replaces the previous test alarm. Delivery validates the occurrence timestamp, clears the delivered record, schedules the next recurring occurrence, then starts the foreground audio service. The service has a native full-screen notification/activity and a separate notification Dismiss action. Dismiss ends only the active alert; Cancel also removes recurrence. No Dart engine is required.

BOOT_COMPLETED, package replacement and exact-access grant restore pending future occurrences. Missed one-time alarms are marked missed rather than falsely replayed as on-time; missed recurrence advances to the next future interval. Restoration before first unlock, powered-off delivery and force-stop are not guaranteed.

## Integration boundaries

Firebase initialization failure leaves offline alarms available. Cloud paths are verified-owner probes only. FCM listeners register at startup; notification destination data is allowlisted. Permission/topic enablement is explicit. GPS/motion are stopped when leaving the foreground or Running tab. GPS route is bounded to 1000 accepted in-memory points and never uploaded.

Payment creation/verification are authenticated HTTPS endpoints, backed by server-private RTDB attempt records and Stripe test PaymentIntents. A transaction reserves uid/requestId/plan before creating with Stripe idempotency. Retries with a recorded PaymentIntent retrieve it. Unrecorded attempts older than 23 hours are rejected to avoid recreation after Stripe's idempotency expiry. The UI does not write an entitlement.
