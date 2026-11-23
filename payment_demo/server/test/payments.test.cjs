const {test} = require('node:test');
const assert = require('node:assert/strict');
const {handlePayment, applyGrant, activeTier, PASS_MS} = require('../lib/payments.js');
const DAY = 24 * 60 * 60 * 1000;
function fixture() {
  const attempts = new Map(); let creates = 0;
  const store = {entitlement: null, receipts: {}};
  const clock = {now: Date.UTC(2026, 10, 22, 12)};
  const intent = {id:'pi_test123',client_secret:'test-secret',status:'requires_payment_method',amount:1000,currency:'mxn',livemode:false,metadata:{uid:'alice',plan:'plus'}};
  const deps = {
    authenticate: async token => { if (token !== 'valid') throw Error(); return {uid:'alice',email_verified:true}; },
    reserve: async (uid,key,plan) => { if (!attempts.has(key)) attempts.set(key,{plan,createdAt:Date.now()}); return attempts.get(key); },
    save: async (uid,key,id) => { attempts.get(key).paymentIntentId=id; },
    create: async () => { creates++; return {...intent}; }, retrieve: async () => ({...intent}),
    entitlement: async () => store.entitlement,
    grant: async (uid, plan, pi, now) => { store.entitlement = applyGrant(store.entitlement, plan, pi.id, now).entitlement; store.receipts[pi.id] = {plan, amount: pi.amount, currency: 'mxn', verifiedAt: store.entitlement.grants[pi.id], testMode: true}; return store.entitlement; },
    now: () => clock.now,
  };
  return {deps,intent,attempts,store,clock,get creates(){return creates;}};
}
const body = {plan:'plus',requestId:'request_1234567890'};
test('rejects missing and invalid authentication before creating a payment', async () => {
  const f=fixture(); for (const token of [undefined,'Bearer invalid']) await assert.rejects(handlePayment(f.deps,'createPaymentIntent',token,body),{status:401}); assert.equal(f.creates,0);
});
test('rejects unverified accounts', async () => {
  const f=fixture(); f.deps.authenticate=async()=>({uid:'alice',email_verified:false}); await assert.rejects(handlePayment(f.deps,'createPaymentIntent','Bearer valid',body),{status:403});
});
test('rejects client prices, unknown plans and invalid attempt identifiers', async () => {
  for (const input of [{...body,amount:1},{...body,plan:'free'},{...body,plan:'__proto__'},{...body,requestId:'bad/path'}]) { const f=fixture(); await assert.rejects(handlePayment(f.deps,'createPaymentIntent','Bearer valid',input),{status:400}); assert.equal(f.creates,0); }
});
test('retries return the same payment and do not recreate it', async () => {
  const f=fixture(); const first=await handlePayment(f.deps,'createPaymentIntent','Bearer valid',body); const second=await handlePayment(f.deps,'createPaymentIntent','Bearer valid',body); assert.equal(first.id,second.id); assert.equal(f.creates,1);
});
test('same attempt cannot change plans', async () => {
  const f=fixture(); await handlePayment(f.deps,'createPaymentIntent','Bearer valid',body); await assert.rejects(handlePayment(f.deps,'createPaymentIntent','Bearer valid',{...body,plan:'premium'}),{status:409});
});
test('stale unrecorded attempt cannot recreate a payment after Stripe key expiry', async () => {
  const f=fixture(); f.attempts.set(body.requestId,{plan:'plus',createdAt:Date.now()-86400000}); await assert.rejects(handlePayment(f.deps,'createPaymentIntent','Bearer valid',body),{status:409}); assert.equal(f.creates,0);
});
test('only the owner can verify a test payment', async () => {
  const f=fixture(); f.intent.metadata.uid='bob'; await assert.rejects(handlePayment(f.deps,'verifyPaymentIntent','Bearer valid',{paymentIntentId:f.intent.id}),{status:403});
});
test('only server-observed success verifies payment; decline/cancel/pending do not', async () => {
  const f=fixture(); for(const status of ['requires_payment_method','canceled','processing','succeeded']) { f.intent.status=status; const response=await handlePayment(f.deps,'verifyPaymentIntent','Bearer valid',{paymentIntentId:f.intent.id}); assert.equal(response.verified,status==='succeeded'); }
});
test('live mode, wrong price and wrong currency cannot verify', async () => {
  for (const change of [{livemode:true},{amount:1},{currency:'usd'}]) { const f=fixture(); Object.assign(f.intent,change); await assert.rejects(handlePayment(f.deps,'verifyPaymentIntent','Bearer valid',{paymentIntentId:f.intent.id}),{status:409}); }
});
test('unavailable Stripe does not produce a success response', async()=>{const f=fixture();f.deps.retrieve=async()=>{throw Error('unreachable');};await assert.rejects(handlePayment(f.deps,'verifyPaymentIntent','Bearer valid',{paymentIntentId:f.intent.id}));});
test('concurrent retries use exactly the same Stripe idempotency inputs',async()=>{const f=fixture();const keys=[];f.deps.create=async(plan,uid,key)=>{keys.push(`${uid}:${key}`);await new Promise(r=>setTimeout(r,10));return {...f.intent};};const results=await Promise.all([handlePayment(f.deps,'createPaymentIntent','Bearer valid',body),handlePayment(f.deps,'createPaymentIntent','Bearer valid',body)]);assert.equal(new Set(keys).size,1);assert.equal(results[0].id,results[1].id);});

const verify = (f, id = f.intent.id) => handlePayment(f.deps, 'verifyPaymentIntent', 'Bearer valid', {paymentIntentId: id});
test('a verified payment grants a 30-day pass and writes a test receipt', async () => {
  const f = fixture(); f.intent.status = 'succeeded';
  const response = await verify(f);
  assert.equal(response.verified, true);
  assert.deepEqual(response.entitlement, {tier: 'plus', verifiedAt: f.clock.now, expiresAt: f.clock.now + PASS_MS});
  assert.deepEqual(f.store.receipts[f.intent.id], {plan: 'plus', amount: 1000, currency: 'mxn', verifiedAt: f.clock.now, testMode: true});
});
test('verifying the same payment again never adds days', async () => {
  const f = fixture(); f.intent.status = 'succeeded';
  const first = await verify(f); f.clock.now += DAY; const second = await verify(f);
  assert.equal(second.entitlement.expiresAt, first.entitlement.expiresAt);
});
test('a new payment for the same active plan extends from its expiry', async () => {
  const f = fixture(); f.intent.status = 'succeeded';
  const first = await verify(f); f.clock.now += 10 * DAY;
  f.intent.id = 'pi_second'; const second = await verify(f, 'pi_second');
  assert.equal(second.entitlement.expiresAt, first.entitlement.expiresAt + PASS_MS);
});
test('an expired pass restarts from now; an upgrade starts a fresh Premium pass', async () => {
  const start = Date.UTC(2026, 0, 1);
  const expired = {tier: 'plus', source: 'stripe_test', verifiedAt: start, expiresAt: start + PASS_MS};
  const later = start + 40 * DAY;
  assert.equal(activeTier(expired, later), null);
  assert.equal(applyGrant(expired, 'plus', 'pi_b', later).entitlement.expiresAt, later + PASS_MS);
  const upgraded = applyGrant(expired, 'premium', 'pi_c', start + DAY).entitlement;
  assert.equal(upgraded.tier, 'premium');
  assert.equal(upgraded.expiresAt, start + DAY + PASS_MS);
});
test('a lower plan never replaces an active higher one', async () => {
  const now = Date.UTC(2026, 0, 1);
  const premium = {tier: 'premium', source: 'stripe_test', verifiedAt: now, expiresAt: now + PASS_MS};
  const result = applyGrant(premium, 'plus', 'pi_low', now + DAY).entitlement;
  assert.equal(result.tier, 'premium'); assert.equal(result.expiresAt, premium.expiresAt);
  const f = fixture(); f.store.entitlement = {...premium, verifiedAt: f.clock.now, expiresAt: f.clock.now + DAY};
  await assert.rejects(handlePayment(f.deps, 'createPaymentIntent', 'Bearer valid', body), {status: 409, code: 'higher_plan_active'});
  assert.equal(f.creates, 0);
});
test('declined, cancelled and pending payments grant nothing', async () => {
  const f = fixture();
  for (const status of ['requires_payment_method', 'canceled', 'processing']) { f.intent.status = status; const r = await verify(f); assert.equal(r.verified, false); }
  assert.equal(f.store.entitlement, null); assert.deepEqual(f.store.receipts, {});
});
