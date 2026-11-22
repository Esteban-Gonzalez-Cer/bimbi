# Phase 2 evidence — November 22, 2026

**Phase 2 is closed for the requested visual scope.** The final build adopts the Wake prototype's lavender palette and Instrument Serif, uses Claude Hand Drawn icons, defaults the buddy to Lilac and returns to five tabs. The [Spanish design refinement record](REFINAMIENTO_VISUAL.md) lists checks and the final APK checksum. The spoken TalkBack walkthrough remains unverified on the final build.

The original Phase 2 run is documented below.

## Owner decisions (2026-11-21)

App and buddy are both named **Bimbi**; keep the five spec tabs with the brand look (no Rewards tab, streaks or points before Phase 9); plans are Free / Plus / Premium; full brand fidelity.

## What was delivered

| Spec item (§13 Phase 2) | Result | Where |
|---|---|---|
| Pastel Material 3 design system | Brand tokens, semantic `BimbiColors` (light/dark), themed Material components | `lib/app/theme/`, `docs/DESIGN_SYSTEM.md` |
| Licensed custom font | Fredoka + Nunito static TTFs bundled with SIL OFL licences; also in native `res/font` | `assets/fonts/`, ADR-008 |
| Mascot | Animated `BimbiBuddy` ported from canvas geometry and keyframes: 6 moods + wake-up sequence, 6 colours, reduced-motion pose | `lib/app/design_system/buddy/` |
| Accessible adaptive five-tab navigation | NavigationBar < 600dp, NavigationRail 600–839dp, rail + two panes ≥ 840dp; Back returns to Alarm | `lib/app/shell/`, ADR-002 |
| Onboarding | Four steps, Skip and Back, name + buddy colour, no permission prompts | `lib/features/onboarding/` |
| Light/dark | Follows system; Profile toggle (System/Light/Dark) persisted locally | `lib/app/preferences.dart` |
| Advanced circular Focus timer | Draggable dial (5–120 min), TalkBack slider actions, timestamp-derived pause/resume | `lib/features/focus/` |
| Screens | Alarm (greeting, permissions fix, one native alarm editor, emergency dismiss), Sleep (self-reported diary, week bars), Running (brand map styles, Start/Pause/Finish, live metrics), Profile (account, appearance, permissions, plans, privacy) | `lib/features/*/presentation/` |
| Native brand | Restyled wake screen (Night, buddy, Fredoka clock, Tangerine Dismiss ≥ 72dp, bell wiggle), brand notification icon, adaptive + themed launcher icon, splash | `android/app/src/main/` |
| Phase 1 harness | All experiment controls preserved in debug-only Developer tools; Design gallery | `lib/app/developer/` |

## Automated results (`scripts/check.sh`, exit 0)

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed` | Clean |
| `flutter analyze --fatal-infos` | No issues |
| Flutter tests | **67 passed**: 24-case responsive matrix (360/412/700/900dp × text 1/1.3/2 × light/dark: correct bar/rail, two panes only ≥ 840dp, header per tab, no exceptions), unconfigured-build gates, Back, permission banner, alarm creation scheduling, onboarding ×3, Focus ×5, alarm math ×4, sleep diary ×3, WCAG contrast (every text pair ≥ 4.5:1 in both themes), fonts, buddy palette parity with canvas, buddy motion bounds, 9 golden groups (33 images), plus the 10 Phase 1 unit tests |
| Payment backend | 11 passed |
| Firebase rules emulator | 7 passed |
| Debug APK build | Built |

Summary lines: `check-summary.txt`. Golden baselines (macOS rendering): `test/golden/goldens/`.

## Physical tablet (Galaxy Tab A9 SM-X115, Android 16 / API 36, 213 dpi)

Builds and hashes: `apk-sha256.txt`. Original display settings were recorded first and restored afterwards (`device-settings-before.txt`, `device-settings-after.txt` match). No account details are in any retained screenshot.

| Case | Result | Evidence |
|---|---|---|
| Onboarding renders, steps, finishes into the shell | PASS | `tablet-onboarding-*.png` |
| Portrait (≈601dp, medium): rail, single column, dark theme, all five tabs | PASS | `tablet-portrait-dark-*.png` |
| Landscape (≈1006dp, expanded): rail + two panes, light theme | PASS | `tablet-landscape-light-*.png` |
| Font scale 2.0, portrait: no clipping; rail labels scale | PASS (one truncated helper text found and fixed: helpers now wrap) | `tablet-portrait-light-text2x-*.png` |
| Native map with brand light/dark style, Tangerine marker | PASS | `tablet-*-running.png` |
| Theme toggle (Profile → Appearance) persists and follows System | PASS | switched Light → System in the app; stored value read back as `system`; app followed system dark |
| Locked-screen alarm: screen off before delivery; restyled wake screen shown over keyguard | PASS | `tablet-native-wake-screen.png` |
| Native Dismiss: tapped on the lock screen; AlarmService and wake screen gone, focus returned to keyguard | PASS | session log |
| Dismiss size ≥ 72dp | PASS by capture (≈96px at 213 dpi); uiautomator could not read the keyguard window, so not independently measured this time | screenshot |
| Landscape Focus: Start visible without scrolling | PASS after fix (bounds y 676–736 of 800) | `tablet-landscape-light-focus.png` |
| TalkBack walkthrough of new screens and onboarding | **PENDING owner** | — |

## Phone emulators

| Profile | Result | Evidence |
|---|---|---|
| Bimbi_Phone_360 (compact) | PASS — integration test: startup, onboarding Skip, all five destinations with matching page headers, no exceptions | `phone-360-test.txt` |
| Bimbi_Phone_412 (compact) | PASS — same test | `phone-412-test.txt` |

UI interaction only; emulators make no claim about alarm, GPS or FCM reliability.

## Limits

- TalkBack is the only open acceptance item for this phase (spec Phase 2 exit). Labels, headers, slider actions and live regions are covered by widget semantics, not by a spoken walkthrough.
- Alarm editor uses the single native occurrence; weekday recurrence, wake missions and persistence are Phase 4/5 (see `docs/LIMITATIONS.md`).
- Back-gesture dismissal on the restyled wake screen was not re-run; its code path is unchanged from Phase 1.
- Goldens are macOS baselines; a Linux CI runner may need its own.
- API 26 runtime of the restyled native screen remains unverified (as in Phase 1).
