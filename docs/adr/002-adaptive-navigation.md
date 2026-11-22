# ADR-002: Adaptive Material 3 navigation and window classes

Date: 2026-11-21 · Status: accepted (Phase 2)

## Context
Bimbi targets Android phones and tablets (spec v0.4 §9.3). The physical device is a Samsung Galaxy Tab A9 (~601dp wide portrait, ~1006dp landscape). The brand canvas shows a floating white bottom dock. Spec risk register: custom translucent navigation must not break Back or TalkBack.

## Decision
- Window class from the shell's available logical width (`LayoutBuilder`), never device model: compact < 600, medium 600–839, expanded ≥ 840.
- Compact: Material `NavigationBar` wrapped in a rounded, bordered, soft-shadowed container (the brand dock). No blur.
- Medium and expanded: Material `NavigationRail` with the buddy as leading mark; it scrolls in short landscape windows and at large text.
- Expanded: pages switch to `TwoPane` master/detail; medium stays single column with a 720dp readable width.
- Android Back closes the current editor or detail page first, then returns to Alarm from another tab. The alarm editor uses a route at every width. Profile groups open routes on compact and medium windows and share the expanded window with their detail pane.
- `WindowScope` exposes the class to pages.

## Alternatives
Custom painted dock with blur (rejected: TalkBack/Back risk, cost on large displays); `adaptive_scaffold` package (rejected: new dependency for little gain).

## Consequences
Standard semantics ("Tab 1 of 5") on both bar and rail; same routes at every width. Tablet portrait is medium (rail, single column) and landscape is expanded (two panes).

## Evidence
`test/widget_test.dart` (4 widths × 3 text scales × 2 themes), goldens in `test/golden/`, tablet captures in `docs/evidence/phase2/`.

## Revisit trigger
Foldable/split-screen support or a second physical tablet with a different width class.
