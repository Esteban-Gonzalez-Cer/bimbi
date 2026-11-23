const {test,before,after,beforeEach}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {ref,set,get,update}=require('firebase/database');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-bimbi-plans',database:{host:'127.0.0.1',port:9000,rules:fs.readFileSync('../database.rules.json','utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearDatabase();});
const alice=()=>env.authenticatedContext('alice',{email_verified:true});
const pass={tier:'plus',source:'stripe_test',verifiedAt:Date.now(),expiresAt:Date.now()+30*86400000,grants:{pi_1:Date.now()}};
const receipt={plan:'plus',amount:1000,currency:'mxn',verifiedAt:Date.now(),testMode:true};

async function seed(){await env.withSecurityRulesDisabled(async ctx=>{await set(ref(ctx.database(),'users/alice/entitlements'),pass);await set(ref(ctx.database(),'users/alice/payments/pi_1'),receipt);});}

test('the verified owner reads the server-written plan and receipts', async()=>{
  await seed();
  await assertSucceeds(get(ref(alice().database(),'users/alice/entitlements')));
  await assertSucceeds(get(ref(alice().database(),'users/alice/payments')));
});

test('no client can grant itself a plan or a receipt', async()=>{
  await seed();
  for (const ctx of [alice(),env.authenticatedContext('bob',{email_verified:true}),env.authenticatedContext('alice',{email_verified:false}),env.unauthenticatedContext()]) {
    const db=ctx.database();
    await assertFails(set(ref(db,'users/alice/entitlements'),{...pass,tier:'premium'}));
    await assertFails(update(ref(db,'users/alice/entitlements'),{expiresAt:Date.now()+999*86400000}));
    await assertFails(set(ref(db,'users/alice/entitlements'),null));
    await assertFails(set(ref(db,'users/alice/payments/pi_fake'),receipt));
  }
});

test('other, unverified and anonymous accounts cannot read plans or receipts', async()=>{
  await seed();
  for (const ctx of [env.authenticatedContext('bob',{email_verified:true}),env.authenticatedContext('alice',{email_verified:false}),env.unauthenticatedContext()]) {
    await assertFails(get(ref(ctx.database(),'users/alice/entitlements')));
    await assertFails(get(ref(ctx.database(),'users/alice/payments')));
  }
});

test('notification topic choices are owner-only booleans', async()=>{
  const path='users/alice/preferences/notificationTopics';
  await assertSucceeds(set(ref(alice().database(),path),{tips:true,updates:false}));
  await assertSucceeds(get(ref(alice().database(),path)));
  for (const bad of [{tips:'yes',updates:false},{tips:true},{tips:true,updates:false,token:'abc'}]) {
    await assertFails(set(ref(alice().database(),path),bad));
  }
  await assertFails(set(ref(alice().database(),'users/alice/preferences/themeMode'),'dark'));
  for (const ctx of [env.authenticatedContext('bob',{email_verified:true}),env.authenticatedContext('alice',{email_verified:false}),env.unauthenticatedContext()]) {
    await assertFails(get(ref(ctx.database(),path)));
    await assertFails(set(ref(ctx.database(),path),{tips:true,updates:true}));
  }
});
