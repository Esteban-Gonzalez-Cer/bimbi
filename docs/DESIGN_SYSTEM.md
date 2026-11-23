# Bimbi design system

The **Brand Buddy** canvas defines the mascot and its animation. The Phase 2 visual prototype **Wake** supplied the lavender palette and display type for all five tabs. Code lives in `lib/app/theme/` and `lib/app/design_system/`; native parity in `android/app/src/main/res/values/colors.xml`.

## Decisions taken from the canvas, and deliberate differences

| Canvas | Bimbi | Why |
|---|---|---|
| Working name "Ringo"; buddy "[Character name]" | App **Bimbi**; the buddy is also **Bimbi** | Spec §15.3 freezes the name; owner decision 2026-11-21 |
| 4 tabs: Alarms, Sleep, Rewards, Profile | 5 tabs: Alarm, Sleep, Focus, Running, Profile | Spec §15.1 frozen scope |
| Streaks, points, partner rewards, "snooze costs a streak day" | Not shown | Gamification is Phase 9 only (spec §2.4) |
| Sleep score, "Good sleep!" | "Time in bed", "Self-reported, not measured" | No medical claims (spec §1.2) |
| Plans Free / Plus / Family, "Most popular" | Free / Plus / Premium, "Recommended", visible TEST MODE | Spec plans; no invented popularity claim |
| Tangerine brand palette | Lavender and plum based on Wake | Final visual direction chosen by the owner on 2026-11-22 |

## Tokens (`bimbi_tokens.dart`)

- **Colour** uses lavender `#F3ECFA` for light backgrounds, `#ECE1F8` for tints, and plum `#5D437A` for primary controls with white text. Dark mode uses `#191421` for backgrounds and `#E3C9F5` for primary controls with plum text. Mint and coral keep their feedback roles.
- **Type** uses bundled Instrument Serif for display, headings and clock numerals, and Nunito for body, controls and AM/PM. Both families carry their SIL OFL licenses in `assets/fonts/`. Text scales with the system setting.
- **Shape**: chip 12, input 20, banner 24, card 28, buttons full pill. No sharp corners.
- **Space**: 4 8 12 16 24 32 48. Touch targets ≥ 48dp (native Dismiss ≥ 72dp).
- **Elevation**: one soft shadow `0 10 30` Ink 8% in light mode; flat in dark mode.
- **Motion**: brand ease `cubic(0.45, 0, 0.55, 1)`; 150/260/420 ms. Every animation stops when Android "Remove animations" is on.
- **Icons** use the original 100 px PNGs of [Claude Hand Drawn by Icons8](https://icons8.com/icons/claude-hand-drawn), bundled in `assets/icons/claude/`. A light backing keeps the hand-drawn outlines legible on dark surfaces.

Semantic roles (`BimbiColors` theme extension) carry light and dark values: background, card, cardBorder, inputBorder, text, textMuted, link, accentTint, success/danger (+tints), night/onNight, navActive/navInactive, focusRing. `test/unit/design_tokens_test.dart` asserts ≥ 4.5:1 contrast for every text pair in both themes.

## The buddy (`design_system/buddy/`)

`BimbiBuddy` paints the soft-gradient alarm clock in a 320×320 space ported from the canvas (body, bell ears, knob, blush, freckles, eyes, brows, mouth, nose). Colour ramps come from a port of the canvas `derive()`; Lilac is the default, and saved color preferences are respected. People can pick Tangerine, Sunflower, Lilac, Mint, Sky or Coral.

Moods replay the canvas keyframes exactly (eased tracks): Happy, Excited, Thinking, Sleepy, Grumpy, Surprised, and the Wake-up sequence (asleep → startled with ringing bells → double blink → yawn → smile). Spec mascot states map as sleepy→Sleepy, waking→Wake-up/Surprised, focused→Thinking, active→Excited, celebrating→Excited/Happy.

Accessibility: decorative by default (excluded from TalkBack); pass `semanticLabel` only when the mood carries meaning not in nearby text. Static representative pose when animations are disabled.

## Components (`design_system/components/`)

BimbiCard · SectionLabel · PageHeader (semantic header, `PageHeader.titleKey`) · BuddyHeaderCard (Night variant for bedtime) · StatTile · InlineBanner (neutral/success/danger/night) · EmptyState (buddy + one line + one action) · StatusPill · ToggleRow · ClockText · DayChips · DayLetters · AlarmCard (on/off/bedtime) · WakeMissionSelector · MissionProgress · WeekBars · PlanCard · BuddyColorPicker. Material buttons, inputs, chips, switches, segmented buttons, navigation bar/rail, sheets, dialogs and snackbars are themed in `bimbi_theme.dart`; screens use them directly.

The debug-only **Design gallery** (Profile → Developer tools) renders everything with fixtures; `test/golden/` snapshots it in both themes.

## Layout (`app/shell/`, ADR-002)

Window class by available logical width: compact < 600 (floating Material NavigationBar, single column), medium 600–839 (NavigationRail, content ≤ 720dp), expanded ≥ 840 (rail + two panes: next alarm | alarm list, Sleep summary | week + diary, Focus dial | presets + usage, Running map | controls, Profile sections | detail). All five tab destinations keep their labels and order at every width.

The phone dock sits above the bottom inset with room for all five labeled destinations. Alarms opens with the local date and the next scheduled time. Focus uses a lavender surface in light mode and a Night surface in dark mode. The dial sizes against the viewport after the shell accounts for Android system bars. Profile opens each group in a separate screen on compact and medium windows. The same groups appear beside their detail pane on expanded windows.

## Rules

1. One clear action per card; labels over helper paragraphs.
2. Night surfaces for anything at bedtime or while an alarm rings, in both themes.
3. Never colour alone: status pills carry words; selected chips also change fill and border.
4. The buddy reacts to what the person just did; it never shames.
5. Keep gradients inside the Focus card and the buddy artwork. Reserve reward visuals for Phase 9.

## Phase 5 screens

Sleep, Focus and the Focus shield follow the approved Home layout:
- a header with a date eyebrow, a serif title and one round action on the right;
- a tinted hero card (Night at night or in dark mode);
- white `MetricTile`s (38 px tinted icon box, serif value, bold label);
- white cards with a 28 radius;
- lists of 20-radius rows.

Expanded windows use two columns: the hero on the left, details on the right, offset by the header height. Status lines under the dial use the serif display face at 22 sp. The Sleep report removes the artboard's score, streak and points. The night dial shows when you slept, not how well. Sources and review renders: `docs/evidence/phase5/`.

