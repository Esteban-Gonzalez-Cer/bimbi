export const PLANS = { plus: 1000, premium: 2000 } as const; // MXN minor units, test only.
export type Plan = keyof typeof PLANS;
export class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}
export type Identity = { uid: string; email_verified?: boolean };
export type Intent = { id: string; client_secret: string | null; status: string; amount: number; currency: string; livemode: boolean; metadata: Record<string, string> };
export type Attempt = { plan: Plan; createdAt: number; paymentIntentId?: string };
/** One test payment buys a 30-day pass. */
export const PASS_MS = 30 * 24 * 60 * 60 * 1000;
const RANK: Record<Plan, number> = { plus: 1, premium: 2 };
/** Server-written plan state at `users/{uid}/entitlements`. `grants` lists the PaymentIntents already counted. */
export type Entitlement = { tier: Plan; source: 'stripe_test'; verifiedAt: number; expiresAt: number; grants?: Record<string, number> };
export type Receipt = { plan: Plan; amount: number; currency: 'mxn'; verifiedAt: number; testMode: true };
export function activeTier(current: Entitlement | null | undefined, now: number): Plan | null {
  return current && current.expiresAt > now && Object.hasOwn(RANK, current.tier) ? current.tier : null;
}
/**
 * Applies one verified payment. Same plan still active: extend from its expiry. Upgrade or
 * expired: 30 days from now. A lower plan never replaces an active higher one. A PaymentIntent
 * already listed in `grants` changes nothing, so repeated verification cannot add days twice.
 */
export function applyGrant(current: Entitlement | null | undefined, plan: Plan, paymentIntentId: string, now: number): { entitlement: Entitlement; changed: boolean } {
  if (current?.grants && Object.hasOwn(current.grants, paymentIntentId)) return { entitlement: current, changed: false };
  const grants = { ...(current?.grants ?? {}), [paymentIntentId]: now };
  const active = activeTier(current, now);
  let entitlement: Entitlement;
  if (active && current && RANK[active] > RANK[plan]) entitlement = { ...current, grants };
  else if (active === plan && current) entitlement = { tier: plan, source: 'stripe_test', verifiedAt: now, expiresAt: current.expiresAt + PASS_MS, grants };
  else entitlement = { tier: plan, source: 'stripe_test', verifiedAt: now, expiresAt: now + PASS_MS, grants };
  return { entitlement, changed: true };
}
export interface PaymentDependencies {
  authenticate(token: string): Promise<Identity>;
  reserve(uid: string, requestId: string, plan: Plan): Promise<Attempt>;
  save(uid: string, requestId: string, id: string): Promise<void>;
  create(plan: Plan, uid: string, requestId: string): Promise<Intent>;
  retrieve(id: string): Promise<Intent>;
  /** Current entitlement, or null. */
  entitlement(uid: string): Promise<Entitlement | null>;
  /** Atomically applies `applyGrant` and writes the receipt; returns the resulting entitlement. */
  grant(uid: string, plan: Plan, intent: Intent, now: number): Promise<Entitlement>;
  now?(): number;
}
function bodyObject(body: unknown, keys: string[]): Record<string, string> {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new ApiError(400, 'invalid_request');
  const record = body as Record<string, unknown>;
  if (Object.keys(record).length !== keys.length || !keys.every(k => typeof record[k] === 'string')) throw new ApiError(400, 'invalid_request');
  return record as Record<string, string>;
}
function validateIntent(intent: Intent, uid: string, expectedPlan?: Plan) {
  const plan = intent.metadata.plan;
  if (intent.metadata.uid !== uid) throw new ApiError(403, 'not_owner');
  if (!Object.hasOwn(PLANS, plan) || intent.livemode || intent.currency !== 'mxn' || intent.amount !== PLANS[plan as Plan] || (expectedPlan && expectedPlan !== plan)) throw new ApiError(409, 'invalid_test_payment');
}
export async function handlePayment(deps: PaymentDependencies, route: string, authorization: string | undefined, input: unknown): Promise<Record<string, unknown>> {
  if (!authorization?.startsWith('Bearer ') || authorization.length < 8) throw new ApiError(401, 'unauthenticated');
  let identity: Identity;
  try { identity = await deps.authenticate(authorization.slice(7)); } catch { throw new ApiError(401, 'unauthenticated'); }
  if (!identity.email_verified) throw new ApiError(403, 'email_unverified');
  if (route === 'createPaymentIntent') {
    const body = bodyObject(input, ['plan', 'requestId']);
    if (!Object.hasOwn(PLANS, body.plan) || !/^[a-zA-Z0-9_-]{16,80}$/.test(body.requestId)) throw new ApiError(400, 'invalid_request');
    const plan = body.plan as Plan;
    const now = deps.now?.() ?? Date.now();
    const active = activeTier(await deps.entitlement(identity.uid), now);
    if (active && RANK[active] > RANK[plan]) throw new ApiError(409, 'higher_plan_active');
    const attempt = await deps.reserve(identity.uid, body.requestId, plan);
    if (attempt.plan !== plan) throw new ApiError(409, 'attempt_conflict');
    // Stripe drops idempotency keys after 24h. Never silently recreate an old unknown attempt.
    if (!attempt.paymentIntentId && Date.now() - attempt.createdAt > 23 * 60 * 60 * 1000) throw new ApiError(409, 'attempt_expired');
    const intent = attempt.paymentIntentId ? await deps.retrieve(attempt.paymentIntentId) : await deps.create(plan, identity.uid, body.requestId);
    validateIntent(intent, identity.uid, plan);
    await deps.save(identity.uid, body.requestId, intent.id);
    return {id: intent.id, clientSecret: intent.client_secret, status: intent.status};
  }
  if (route === 'verifyPaymentIntent') {
    const body = bodyObject(input, ['paymentIntentId']);
    if (!/^pi_[a-zA-Z0-9]+$/.test(body.paymentIntentId)) throw new ApiError(400, 'invalid_request');
    const intent = await deps.retrieve(body.paymentIntentId);
    validateIntent(intent, identity.uid);
    if (intent.status !== 'succeeded') return {verified: false, status: intent.status, testMode: true};
    const entitlement = await deps.grant(identity.uid, intent.metadata.plan as Plan, intent, deps.now?.() ?? Date.now());
    return {verified: true, status: intent.status, testMode: true, entitlement: {tier: entitlement.tier, expiresAt: entitlement.expiresAt, verifiedAt: entitlement.verifiedAt}};
  }
  throw new ApiError(404, 'not_found');
}
