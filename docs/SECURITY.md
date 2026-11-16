# Phase 1 security and privacy

- No secrets, private keystores, OAuth refresh tokens, account exports, full routes or personal health records in Git. Local configuration is ignored.
- Firebase user probe paths require authenticated matching UID and verified email; schema, PNG content type and 2 KiB size are restricted. All other paths, including server payment attempts and entitlements, are denied to clients.
- The server accepts only known plan IDs and prices, validates auth and ownership, rejects live Stripe mode and unexpected currency/amount. Provider client secrets are returned only to the owner and not logged.
- Logs intentionally exclude SDK error bodies and request payloads. Only native alarm timing and generic statuses are retained as evidence. Use personal-free test screenshots.
- Android location is foreground-only; no background location permission. No raw app usage package list leaves native Android. No Accessibility-service workaround.
- Alarm safe dismissal is native, independent of Firebase/Flutter. Exact access and notification consent are checked. Full-screen denial remains a visible degraded capability.
- The only cloud environment used in this phase is an isolated development project. Production environments, production App Check/Crashlytics and release signing are not configured.
- Dependency review: package lockfiles are committed. Development-only Firebase emulator tools may have transitive advisories; see evidence. Never expose emulators to the internet or reuse their demo project identity in production.
