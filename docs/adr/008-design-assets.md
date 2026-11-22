# ADR-008: Bundled fonts, Icons8 artwork and native buddy vectors

Date: 2026-11-21 · Status: accepted (Phase 2)

## Context
The rubric requires a licensed custom font; the app must work offline; golden tests need deterministic fonts. The mascot comes from the Brand Buddy canvas. The closing design review selected Instrument Serif and Claude Hand Drawn icons.

## Decision
- **Fonts**: bundle Instrument Serif Regular and Nunito (500, 600, 700, 800) TTFs from Google Fonts with their SIL OFL 1.1 licences in `assets/fonts/`. Instrument Serif Regular and Nunito Medium/ExtraBold are also copied to `android/app/src/main/res/font/` for the native alarm screen. No `google_fonts` package (runtime download).
- **Icons** use unmodified PNGs from the [Claude Hand Drawn collection](https://icons8.com/icons/claude-hand-drawn). Each `BimbiIcons` slug identifies an asset at `https://img.icons8.com/claude-hand-drawn/100/{slug}.png`. Profile links to Icons8 using `url_launcher`. Include the Icons8 credit in any future store listing under the [free license terms](https://icons8.com/license).
- **Buddy in Flutter**: `CustomPainter` port of the canvas geometry and keyframes; no animation package.
- **Buddy on Android**: `scripts/generate_native_buddy.py` generates VectorDrawables (wake-screen buddy, adaptive launcher foreground and monochrome, notification small icon) from the same geometry.

## Alternatives
Material Icons (off-brand); Lottie/Rive for the buddy (new runtime, binary assets, harder accessibility control); converting icons to a font (tooling overhead).

## Consequences
Fonts, original icons and mascot artwork render offline. The credit link opens in the browser.

## Revisit trigger
Licence change, APK size budget, or a need for richer buddy animation than keyframed vectors.
