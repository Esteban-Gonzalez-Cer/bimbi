# Bimbi architecture

Widgets → Riverpod state/controllers → adapters → Android/Firebase/Stripe. Handwritten providers, no application setState or ValueNotifier. `lib/app` composes adaptive navigation (`shell/`), the theme (`theme/`), the design system and buddy (`design_system/`), local UI preferences (`preferences.dart`) and debug-only developer tools (`developer/`). Feature screens live in `lib/features/<feature>/presentation/` with their Riverpod controllers in `application/`. Screens rebuilt from Phase 2 onward follow the Flutter architecture guide: `lib/ui/<screen>/{view_models,widgets}` (Home, Sleep, Focus), shared widgets in `lib/ui/core/widgets`, domain models in `lib/domain/models` and repositories/services in `lib/data`. See `docs/DESIGN_SYSTEM.md` and ADR-002/008. `lib/core` owns configuration, operation status and typed platform failures. Features own their SDK adapters. No gamification dependency exists.

## Android alarm authority

`com.bimbi.app/platform` exposes capabilities, `saveAlarm`, `enableAlarm`, `deleteAlarm`, `openChallenge`, permission settings and a usage summary. Riverpod uses the native catalogue for the list and next wake time. `com.bimbi.app/alarms` emits invalidations when Android changes that catalogue. Each alarm has a stable ID, local time, active days, challenge and difficulty. The bounded developer experiment has its own schedule and cancel actions.

The native catalogue, occurrence queue and snooze deadlines are kept in private SharedPreferences. Android registers exact occurrences with `setAlarmClock` and keys pending intents by alarm and occurrence. The receiver checks the current record before delivery and schedules the next recurrence. The foreground service owns one audio stream, a local challenge session and the monotonic 15-second activity window. A completed challenge closes its occurrence. A successful snooze registers a new exact wake-up five minutes later before pausing audio and keeps the count for that occurrence. The native activity and its notification open the challenge even when Flutter is inactive.

The app re-registers future occurrences on boot after unlock, package replacement and exact alarm permission grant. Time and timezone changes recalculate local schedules. A one-time occurrence missed while the device was unavailable is recorded as missed. Recurring alarms advance to the next local occurrence. Android controls execution while the device is locked, stopped or powered off.

## Integration boundaries

Firebase initialization failure leaves offline alarms available. FCM listeners register at startup; notification destination data is allowlisted. Permission/topic enablement is explicit. GPS/motion are stopped when leaving the foreground or Running tab. GPS route is bounded to 1000 accepted in-memory points and never uploaded.

## Account profile

Firebase Auth restores the session. The profile controller subscribes to the verified owner's name at `users/{uid}/profile/displayName` and submits a transaction without optimistic local updates. An interrupted write stays pending until confirmation or the session is closed. The local guest name and device appearance preferences use SharedPreferences.

The Auth creation event sets `bimbiAuthOrigin` with the Admin SDK. Storage permits custom avatar writes only for a verified owner with password origin and a current password sign-in. A single JPEG per account lives at `users/{uid}/avatar.jpg`. Google and GitHub photos come from the respective provider profile. The application-private disk cache is keyed by Firebase project and UID, and uses a seven-day expiry for images. Account transitions retire listeners and disregard results from earlier sessions.

Payment creation/verification are authenticated HTTPS endpoints, backed by server-private RTDB attempt records and Stripe test PaymentIntents. A transaction reserves uid/requestId/plan before creating with Stripe idempotency. Retries with a recorded PaymentIntent retrieve it. Unrecorded attempts older than 23 hours are rejected to avoid recreation after Stripe's idempotency expiry. The UI does not write an entitlement.

## Sleep diary and Focus sessions

Both are device-first. `CollectionController` (`lib/data/repositories/local_collection.dart`) saves rows to SharedPreferences, marks each change as pending and keeps deletion markers until the cloud confirms. `CollectionSync` (`collection_sync.dart`) binds a collection to the verified account: the first account adopts guest rows, another account starts empty, the `onValue` snapshot is merged (a newer pending local edit wins) and pending rows are pushed with `set` when the connection returns. Paths: `users/{uid}/sleep/{yyyy-MM-dd}` and `users/{uid}/focus/{firstStartMillis}`.

Sleep entries store bedtime and wake as instants plus the wake UTC offset, so daylight-saving nights report real time in bed. The diary suggests today's wake time from the last finished alarm, which `AlarmEngine.complete()` records natively with its snooze count. The Focus session (target, phase, start, banked time, task, windows) is saved on every change and rebuilt after process death. Finishing records history: sessions under a minute are not recorded, the rest are completed or ended early.

## Focus shield and chimes

See ADR-009. Flutter tells Android until when chosen apps are paused (`focusShield` with the session end and window ends) whenever the session starts, pauses, resumes or ends. `GuardStore` keeps chosen apps, daily limits and that end time in app-private storage. `FocusGuardService` runs only while rules need it, polls Usage Access events once a second with the screen on and shows `ShieldOverlay` over a chosen app. `FocusChime` registers a short sound at each window end and at the session end with `AlarmManager` (exact when allowed), cancels them on pause or end, and restores them after reboot. App usage never leaves the device.
