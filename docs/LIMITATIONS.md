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
- Profile avatar uses the provider photo URL without offline caching (Phase 3).
- Golden baselines are rendered on macOS; Linux CI may need its own baselines.
- The native wake screen shows a static buddy with a bell wiggle (disabled when Android animations are off), not the full Flutter wake-up animation.
