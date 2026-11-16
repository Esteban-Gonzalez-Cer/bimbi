# Phase 1 limitations

- Development harness, not a complete wellbeing app. No Phase 8 core-demo claim or release tag.
- Native test alarm supports one pending occurrence and fixed-minute recurrence. It auto-stops audio after two minutes. No production schedule editor, DST/wall-clock policy, pre-unlock Direct Boot or guarantee while powered off/force-stopped.
- Reboot, revoked permission, full-screen-denied, battery saver, TalkBack and outdoor GPS require individual recorded tests. A passing basic alarm cannot imply those results.
- Firebase configuration, console providers, native Maps key/billing, Storage, GitHub OAuth, Stripe account/secret/deployment and console FCM sends must be independently verified. Unconfigured components remain disabled or display an explicit setup state.
- FCM force-stop is unsupported until reopening. Topic delivery is not an alarm mechanism. No custom notification sending backend.
- GPS is foreground-only, stores at most 1000 in-memory samples, and is lost on process death. This is deliberate for feasibility; durable run sessions belong to Phase 6.
- Cloud probe is a tiny private PNG/record roundtrip. It does not prove offline image caching, full production schemas or avatar editing policy.
- Stripe sandbox uses one-time test prices and server-verified status; no recurring subscription, webhook-driven entitlement, production payment or paid-access unlock.
- Local CI configuration is prepared, but no remote repository/Actions run or branch protection exists yet.
- Final typography, mascot, onboarding and polished responsive panels are Phase 2. Sleep/Focus product features remain later phases. Desktop rubric exception is still pending instructor approval.
