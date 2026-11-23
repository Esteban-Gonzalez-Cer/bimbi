# ADR-009: Soft Focus shield and daily app limits

Date: 2026-11-22 · Status: accepted (Phase 5) · Amends spec v0.4 §5.1 F3, §11 "Android Usage Access privacy" and the Focus row of §3

## Context
Spec v0.4 treated Usage Access as opt-in monitoring only: "No claim of blocking all apps", "never impersonate app blocking", "no Accessibility-service workaround". During Phase 5 planning the owner asked whether Bimbi could pause chosen apps during a Focus session and enforce a per-app daily limit, and chose to build it after reviewing the trade-offs below.

Android offers third-party apps no public API to block other apps. Digital Wellbeing app timers are private, and package suspension needs a device-owner app. Since Android 15, a holder of `SYSTEM_ALERT_WINDOW` may start a foreground service from the background only while one of its overlay windows is visible, and background activity starts are restricted. A pause screen is therefore drawn as an overlay window from a foreground service, not as an activity. ([Android 15 behavior changes](https://developer.android.com/about/versions/15/behavior-changes-15), [background activity starts](https://developer.android.com/guide/components/activities/background-starts), [foreground service types](https://developer.android.com/guide/components/foreground-services))

## Decision
- **Soft shield, no Accessibility service.** `FocusGuardService` is a `specialUse` foreground service with a declared subtype. It runs only while there is something to enforce: a running Focus session with chosen apps, or at least one daily limit.
- **Detection.** Every second while the screen is on, the service folds `UsageStatsManager` `ACTIVITY_RESUMED`/`ACTIVITY_PAUSED` events into per-app foreground time since local midnight and finds the app in front (`UsageTracker`, pure and unit-tested).
- **Pause screen.** `ShieldOverlay` is a `TYPE_APPLICATION_OVERLAY` window in the wake-screen style. Its only action, and Android Back, go home.
- **Exempt apps, always.** Bimbi, launchers, Settings, the default dialer, emergency apps, the system UI and the active keyboard are never covered. Settings stays reachable so the person can always turn the shield off.
- **Honest copy.** "A gentle pause, not a lock" appears in Bimbi and on the overlay, together with how to turn it off. A permanent low-importance notification shows while the service runs.
- **Permissions.** Usage Access and Display over other apps are requested only from the Focus shield screen, with an explanation. Without either one, the shield is off and Focus still works. Revoking either one mid-session removes the overlay, stops the service and records why.
- **Privacy.** Chosen apps, limits and usage minutes stay in app-private storage on the device and never reach Firebase. App lists use `<queries>` for launcher intents, not `QUERY_ALL_PACKAGES`.
- **Restoration.** Boot, app update and time/zone changes restart the service when rules still need it.

## Alternatives
- **Accessibility service:** faster events, but forbidden by the spec, and Play policy restricts it to accessibility tools.
- **Device-owner package suspension:** needs a dedicated or work-profile device.
- **Monitoring only (the original spec):** kept as the fallback the cut order allows.

## Consequences
- **Delay:** the shield appears about 0.7 s after a covered app opens (measured on the Galaxy Tab A9).
- **Battery:** polling runs only while the screen is on and only while rules need it.
- **Bypassing is possible:** revoking a permission, force-stopping Bimbi or safe mode all turn it off, and the copy says so.
- **OEM behaviour:** may stop the service. Android reports `lastStop`, which Bimbi shows.
- **Play Store:** publishing would need a `specialUse` justification and the Usage Access and overlay declarations. The APK-only MVP is not published.

## Revisit trigger
A public Android API for app limits, a Play policy change on `specialUse` or overlays, or the spec cut order removing Usage Access restrictions under schedule pressure.
