# Phase 1 acceptance matrix

Every manual result must record date, actual device/API, exact build/checksum, permissions, steps, observed state, logs/video and verdict. Use UNVERIFIED until executed. Passing mocks is not native proof.

| ID | Steps | Expected result |
|---|---|---|
| UI-01 | Navigate five tabs at 360/412/700/900 logical widths, text scales 1/1.3/2, light and dark | No layout exception; NavigationBar < 600, Rail ≥ 600, two panes ≥ 840; page header matches tab; all labels accessible |
| UI-02 | Tablet portrait/landscape, Back, keyboard and TalkBack | Controls reachable; readable layout; no trap |
| UI-03 | Brand tokens: text/background pairs in light and dark | ≥ 4.5:1 contrast (`test/unit/design_tokens_test.dart`); Tangerine always with Ink text |
| UI-04 | Onboarding: four steps, Back, Skip, name and buddy colour | Reaches the shell; no permission requested; Back steps backwards |
| UI-05 | Golden baselines: five tabs at four widths (light) and two widths (dark), onboarding, design gallery | `flutter test test/golden` matches committed images |
| UI-06 | Restyled native wake screen over the lock screen | Shows Night screen, buddy, time; Dismiss ≥ 72dp; Dismiss and Back stop AlarmService |
| FOCUS-01 | Kill the process mid-session and reopen | Same remaining time, task and windows from saved timestamps; history recorded once |
| FOCUS-02 | Focus timer pause/resume/complete with injected clock | Remaining time derived from timestamps; dial 5-min steps over up to four 2 h turns; typed 1–480 min |
| FOCUS-03 | Split a session into windows and run it | Current window and next window time shown; chime at each window end and sparkle at the end; pause cancels chimes |
| SLEEP-01 | Diary across DST (`TZ=America/New_York`, 1 Nov 2026) | Fall-back night 9 h, spring-forward 7 h, same date key after save/restore |
| SYNC-01 | Guest entries, sign-in, offline edit, reconnect, account switch | Guest rows adopted once; offline edits pending then confirmed; other account never sees them |
| DATA-02 | Sleep/focus rules in emulator | Owner read/write; other, anonymous, unverified denied; stages, scores, bad durations rejected |
| SHIELD-01 | Choose an app to pause, start Focus, open the app | Pause screen within about 1 s; Go home and Back go home; lifts at session end |
| SHIELD-02 | Daily limit reached | Pause screen until midnight; app shows "paused until midnight" |
| SHIELD-03 | Revoke Usage Access or overlay mid-session | Overlay removed, service stopped, reason shown in Bimbi; Focus unaffected |
| SHIELD-04 | Reboot with daily limits set | Service restored after unlock |
| ALARM-01 | Deny exact access and schedule | Explicit denial, no false pending success |
| ALARM-02 | Grant notifications/exact access; schedule 30s, background and screen off | Native alert at recorded time; sound confirmed; Dismiss ends audio |
| ALARM-03 | Schedule; kill only Bimbi process without force-stop | New process delivers persisted occurrence; no cloud dependency |
| ALARM-04 | Schedule 3min; reboot and unlock before due | Future schedule restored; native alert; no duplicate |
| ALARM-05 | Repeat every minute; dismiss each; cancel next | Subsequent occurrence re-armed; cancel removes next occurrence |
| ALARM-06 | Deny full-screen, revoke exact access, battery saver, disconnected network | Clear capability state; supported fallback and limits recorded individually |
| AUTH-01 | Each of email/Google/GitHub sign-in, sign-out and relaunch | Actual provider identity, restored authenticated session |
| AUTH-02 | Unverified → resend → verify → refresh; reset password | Probe/payment gated before verification, authorized after fresh token |
| DATA-01 | Owner writes/reads/removes probe; other user/anonymous tries | Own readback matches; other access denied |
| FCM-01 | Topic sends in foreground/background/normal terminated; tap notification | Handler/notification visible; allowed destination opens |
| FCM-02 | Force-stop then send | Document platform limitation; reopen restores registration |
| RUN-01 | Deny GPS then allow; outdoor walk; stop/background | Real accepted samples, noisy jumps ignored, subscriptions end |
| SENSOR-01 | Start accelerometer and gently move tablet | Real signal changes; stop cancels sensor |
| PAY-01 | Success/decline/cancel/disconnect/retry with test card | Server-verifiable success only; no paid entitlement |
| PAY-02 | Missing auth, wrong owner, extra price fields, live mode | Server rejects; retry does not duplicate same attempt |
| USAGE-01 | Deny/grant/revoke Usage Access | Optional aggregate available only with grant; Focus unaffected |

Physical reboot, consent, outdoor walk and account interactions are coordinated with the owner. Do not alter unrelated device state or claim observed sound without human confirmation.
