# ADR-005: Stripe test plans through a trusted endpoint

Date: 2026-11-22 · Status: accepted (Phase 7; the endpoint itself dates from Phase 1)

## Context
Spec v0.4 requires three visible plans (Free, Plus, Premium) and an instructor-approved Stripe PaymentSheet demonstration in TEST mode:
- server-created PaymentIntents and verified completion;
- no card data handled by Flutter;
- no live charges;
- "never trust a client-only premium flag".

Phase 1 deployed `paymentApi` (Firebase Functions v2) to create and verify test PaymentIntents, but no plan was ever granted.

## Decision
- **Passes, not subscriptions.** One test payment buys a 30-day pass: Plus MX$10, Premium MX$20, with the amount set on the server. Store-managed and Stripe recurring subscriptions stay out of scope.
- **Server-written entitlement.** When `verifyPaymentIntent` sees `succeeded` and the existing checks pass (owner, amount, `mxn`, `livemode=false`), the function writes `users/{uid}/entitlements` with `{tier, source:'stripe_test', verifiedAt, expiresAt, grants}`. This happens in a single RTDB transaction. It then writes the receipt `users/{uid}/payments/{paymentIntentId}` with `{plan, amount, currency, verifiedAt, testMode:true}`.
- **Pass rules** (`applyGrant`, pure and unit-tested):
  - The same tier still active extends from its expiry.
  - An upgrade, or an expired pass, starts 30 days from now.
  - A lower plan never replaces an active higher one.
  - `createPaymentIntent` refuses Plus while Premium is active (`higher_plan_active`).
- **Idempotency.**
  - `grants` lists every PaymentIntent already counted, so repeated verification never adds days.
  - Creation keeps the Phase 1 attempt reservation and Stripe idempotency key.
- **Rules.** `entitlements` and `payments` are readable only by the verified owner and writable by no client. The Admin SDK bypasses rules.
- **Client.**
  - Flutter streams the entitlement read-only. `effectiveAt(now)` treats an expired pass as Free.
  - Perks are cosmetic and gated by that value only:
    - Plus: three buddy colours and two alarm tones;
    - Premium: the Sunrise theme and a badge.
  - When a pass lapses, the colour and theme fall back without erasing the choice. Plus alarm tones are re-saved as Dawn Chime, but only after the entitlement has loaded.
- **Recovery without a webhook.** The app keeps the request id of an unfinished attempt. **Restore purchases** asks the server again (same PaymentIntent) and verifies it.

## Alternatives
- **Stripe webhook (`payment_intent.succeeded`):** more robust when the app dies right after paying, but needs a webhook secret and endpoint. Deferred; Restore covers the demo.
- **Stripe Billing subscriptions:** customers, prices and webhooks, out of MVP scope.
- **Client-side flag:** forbidden by the spec.

## Consequences
- A pass is honoured until its `expiresAt` even if Stripe later refunds the test payment. That's acceptable in test mode.
- Without a webhook, a successful payment is granted only when the app verifies it or Restore runs.
- Cosmetic perks are enforced in the client. Data that matters (entitlements, receipts) is enforced on the server.

## Revisit trigger
Production billing, Play distribution (Google Play Billing policy), or a need for automatic renewal.
