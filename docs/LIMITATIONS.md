# Phase 1 limitations

- Development harness, not a complete wellbeing app. No Phase 8 core-demo claim or release tag.
- Native test alarm supports one pending occurrence and fixed-minute recurrence. One-shot audio has a two-minute timeout; repeating tests re-trigger and require Cancel pending alarm to end future occurrences. No production schedule editor, DST/wall-clock policy, pre-unlock Direct Boot or guarantee while powered off/force-stopped.
- Alarm and accessibility results are case-specific in evidence/phase1/REPORT.md. Reboot, permission revocation, locked full-screen and denied-full-screen notification dismissal, recurrence/cancellation, foreground GPS, unplugged offline/battery-saver and TalkBack have their own evidence. Natural overnight Doze, Samsung-specific sleeping policies and API 26 native runtime remain unverified. A short test is not an overnight reliability guarantee.
- Firebase configuration, console providers, native Maps key/billing, Storage, GitHub OAuth, Stripe account/secret/deployment and console FCM sends must be independently verified. Unconfigured components remain disabled or display an explicit setup state.
- FCM force-stop is unsupported until reopening. Topic delivery is not an alarm mechanism. No custom notification sending backend.
- GPS is foreground-only, stores at most 1000 in-memory samples, and is lost on process death. This is deliberate for feasibility; durable run sessions belong to Phase 6.
- Cloud probe is a tiny private PNG/record roundtrip. It does not prove offline image caching, full production schemas or avatar editing policy.
- Stripe sandbox uses one-time test prices and server-verified status; no recurring subscription, webhook-driven entitlement, production payment or paid-access unlock.
- Local CI configuration is prepared, but no remote repository/Actions run or branch protection exists yet.
- Desktop rubric exception is still pending instructor approval.

## Phase 2 (design system) limitations

- The Alarm editor schedules one native alarm (the bridge holds one pending occurrence). "Every day" maps to a 24 h native interval; other weekday sets schedule only the next matching day until Phase 4 recurrence. Label, days and mission shown on the card live in memory for the session.
- Wake missions (Shake, Math, Light) are designed but not selectable until Phase 4 implements them, so no alarm promises a mission it will not require.
- The sleep diary and Focus session are in-memory (Phase 5 adds persistence/sync). Focus state is already timestamp-derived.
- Running "Finish" stops GPS and keeps the in-memory trace on screen; saved runs are Phase 6.
- Display name, theme mode, buddy colour and onboarding completion are stored locally in SharedPreferences, never uploaded.
- The Phase 2 APK uses the provider photo URL without offline caching. Phase 3 adds a per-account disk cache and private custom photos.
- Golden baselines are rendered on macOS; Linux CI may need its own baselines.
- The native wake screen shows a static buddy with a bell wiggle (disabled when Android animations are off), not the full Flutter wake-up animation.

## Phase 3 profile

- Only the account profile name and avatar sync. Appearance settings and the guest name are local. New edits require connectivity; an interrupted name transaction stays pending for that session.
- Avatar authorization requires a trusted Auth creation event for the original account. Legacy accounts without that claim can sync their name after verification and have read-only photos. The sign-in method alone never authorizes an avatar write.
- An offline photo requires a previously downloaded copy for the restored account. The device cache expires on access seven days after the last successful fetch and is cleared on sign-out, account switch or photo removal.

## Phase 4 alarms

- Android controls playback volume, notification delivery and foreground app stopping. Bimbi requires exact alarm access and an available notification channel to register wake-up occurrences. Full-screen access controls presentation over the lock screen.
- Alarm recovery uses credential-protected storage and runs after the first unlock following a reboot. An expired one-time alarm or snooze after an unavailable period is reported as missed.
- The app stores alarm definitions, active occurrences and snoozes on the device. The native service keeps round progress while the alarm is active. After the service process is stopped, reopening the challenge starts a round from the beginning.
- The developer alarm uses a bounded audio test. Alarms configured in the editor finish in Bimbi when the selected challenge is completed.
