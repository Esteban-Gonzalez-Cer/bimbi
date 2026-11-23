# Changelog

## Unreleased — Phase 4 wake alarms

Multiple local alarms with weekday recurrence, native restoration and a required wake-up challenge per alarm. Shake, Math, Ball Monte, Follow the pattern and Memorama each have four difficulty levels. The native alert supports two five-minute snoozes and a fifteen-second interaction window that rolls back the challenge when it expires. The native challenge screen uses one centred column in portrait and two panes in landscape, equal 56dp buttons, a clear type hierarchy, boards that shrink to keep every action on screen, and Spring Vibes artwork (CC BY 4.0) for Memorama.

## Unreleased — Phase 3 Firebase profile

Verified accounts sync their profile name and avatar. Firebase rules isolate private data by UID and require a server-recorded email/password origin for custom avatar writes. Profile photos have a private, time-limited disk cache. Debug builds can connect to the Firebase Emulator Suite.

## Unreleased — Phase 2 design system
Bimbi brand design system (lavender light/dark tokens from Wake, bundled Instrument Serif + Nunito, themed Material 3 components, Icons8 Claude Hand Drawn icons), animated Bimbi buddy in Lilac by default, with six moods and the wake-up sequence, adaptive navigation (bar / rail / two panes), onboarding, light/dark with an in-app toggle, circular Focus timer, designed Alarm/Sleep/Focus/Running/Profile screens, restyled native wake screen, launcher icon, splash and notification icon. The Wake design prototype was retired after its palette and typography moved to the main app. Phase 1 experiments moved to debug-only Developer tools. Evidence in `docs/evidence/phase2/REPORT.md`.

## 0.1.0 — Phase 1 development harness
Adaptive five-tab Android shell, native alarm experiment, Firebase/FCM adapters and probe rules, foreground GPS/motion, Stripe test payment backend, automated validation and setup/evidence documentation. Configuration and physical acceptance status are recorded in the Phase 1 report; this is not the final product release.
