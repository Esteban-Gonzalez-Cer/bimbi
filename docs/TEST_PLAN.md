# Phase 1 acceptance matrix

Every manual result must record date, actual device/API, exact build/checksum, permissions, steps, observed state, logs/video and verdict. Use UNVERIFIED until executed. Passing mocks is not native proof.

| ID | Steps | Expected result |
|---|---|---|
| UI-01 | Navigate five tabs at 360/412/700/900 logical widths, text scales 1/1.3/2 | No layout exception; correct NavigationBar/Rail; all labels accessible |
| UI-02 | Tablet portrait/landscape, Back, keyboard and TalkBack | Controls reachable; readable layout; no trap |
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
