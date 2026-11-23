# Phase gates

| Date (Mexico City) | Phase | Verdict | Evidence | Outstanding |
|---|---|---|---|---|
| 2026-11-16 | Phase 1 setup + feasibility | PASS — first tablet feasibility pass | `docs/evidence/phase1/REPORT.md` | All seven experiments and requested short tablet cases recorded. Longer overnight/OEM behavior and API 26 runtime remain unverified; security checks retain emulator/unit/live scopes. Hosted CI awaits a remote. Budget alerts owner-confirmed |
| 2026-11-22 | Phase 2 Material design system | CONDITIONAL PASS — brand design system, buddy, adaptive five-tab UI, onboarding, Focus dial, native wake screen | `docs/evidence/phase2/REPORT.md` | TalkBack walkthrough of new screens pending owner; golden baselines are macOS-rendered |
| 2026-11-22 | Phase 2 visual closeout | CLOSED — Wake styling applied to the five permanent tabs | `docs/evidence/phase2/REFINAMIENTO_VISUAL.md` | Spoken TalkBack and native alarm delivery remain unverified on this visual build |
| 2026-11-22 | Phase 3 Firebase profile | PASS — private profile sync, avatar authorization and offline restoration | `docs/evidence/phase3/REPORT.md` | Hosted CI awaits a remote. Account isolation and OAuth-origin password linking were verified in the Firebase emulators. |
| 2026-11-22 | Phase 4 wake alarms | PASS — local recurrence, challenge completion, 15-second rollback and two five-minute snoozes | `docs/evidence/phase4/REPORT.md` | Reboot recovery, notification fallback and the real accelerometer were verified on the Galaxy Tab A9. The two-snooze limit was verified on the emulator. |
| 2026-11-22 | Phase 5 sleep and Focus | CONDITIONAL PASS — saved diary and Focus timer, verified-account sync, DST-safe nights, multi-turn dial, windows with chimes, soft Focus shield and daily limits (ADR-009) | `docs/evidence/phase5/REPORT.md` | Pending owner checks: the new RTDB rules deployed to the development project and synced between two devices, the chimes heard on the Galaxy Tab A9, the shield driven from its screen on the tablet, reboot restore of limits and a TalkBack pass. |

No CORE-DEMO tag exists. Gamification remains absent. A human review of actual evidence is required before the final project milestone is declared complete.
