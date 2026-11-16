# Bimbi test payment endpoint

Node 22, Firebase HTTPS Functions v2, Stripe sandbox. No production billing or recurring subscriptions.

`npm ci && npm test` builds strict TypeScript and tests the provider boundary using deterministic fakes. Test-mode device checkout still requires deployment and a real Stripe sandbox.

- POST `/createPaymentIntent`: Firebase ID token in Bearer header; JSON `{plan: "plus" | "premium", requestId: string}`. Server fixed amounts: MXN 1000/2000 minor units. Only verified accounts. Returns owner-specific `{id, clientSecret, status}`.
- POST `/verifyPaymentIntent`: same authorization; JSON `{paymentIntentId}`. Server retrieves Stripe state and verifies UID, amount, currency and test mode. Returns `{verified, status, testMode}`. No client entitlement write.
- Other keys (including price/amount/uid) are rejected. Request IDs are 16–80 safe alphanumeric/underscore/hyphen characters.
- RTDB `server/paymentAttempts/{uid}/{requestId}` is Admin-only. Atomically reserved before Stripe create. Stripe idempotency key includes UID/request ID. Old unknown attempts are rejected, not recreated after Stripe's 24-hour key expiry.
- Flutter persists its attempt identifier before networking. Cancel/decline/network failure preserve it; verified success clears it. Clearing app data discards the client attempt and is not an automatic retry.

Deploy only to the owner-approved development project, with `STRIPE_SECRET_KEY` in Secret Manager. See ../../docs/SETUP.md. Budget alerts and maxInstances do not guarantee free usage. This endpoint never sends FCM messages.
