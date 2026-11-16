const {test} = require('node:test');
const assert = require('node:assert/strict');
const {handlePayment} = require('../lib/payments.js');
function fixture() {
  const attempts = new Map(); let creates = 0;
  const intent = {id:'pi_test123',client_secret:'test-secret',status:'requires_payment_method',amount:1000,currency:'mxn',livemode:false,metadata:{uid:'alice',plan:'plus'}};
  const deps = {
    authenticate: async token => { if (token !== 'valid') throw Error(); return {uid:'alice',email_verified:true}; },
    reserve: async (uid,key,plan) => { if (!attempts.has(key)) attempts.set(key,{plan,createdAt:Date.now()}); return attempts.get(key); },
    save: async (uid,key,id) => { attempts.get(key).paymentIntentId=id; },
    create: async () => { creates++; return {...intent}; }, retrieve: async () => ({...intent}),
  };
  return {deps,intent,attempts,get creates(){return creates;}};
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
