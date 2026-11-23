const {test,before,after,beforeEach}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {ref,set,get,onValue,serverTimestamp}=require('firebase/database');
const {ref:storageRef,uploadBytes,getBytes,deleteObject}=require('firebase/storage');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-bimbi',database:{host:'127.0.0.1',port:9000,rules:fs.readFileSync('../database.rules.json','utf8')},storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync('../storage.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearDatabase();await env.clearStorage();});
const alice=()=>env.authenticatedContext('alice',{email_verified:true});
test('verified owner can write/read/delete the strict probe schema',async()=>{const path=ref(alice().database(),'users/alice/phase1/probe');await assertSucceeds(set(path,{ok:true,updatedAt:serverTimestamp()}));await assertSucceeds(get(path));await assertSucceeds(set(path,null));});
test('anonymous, unverified and other-user reads/writes are denied',async()=>{for(const ctx of [env.unauthenticatedContext(),env.authenticatedContext('alice',{email_verified:false}),env.authenticatedContext('bob',{email_verified:true})]){const path=ref(ctx.database(),'users/alice/phase1/probe');await assertFails(get(path));await assertFails(set(path,{ok:true,updatedAt:serverTimestamp()}));}});
test('unknown fields, future timestamps, entitlements and payment records are denied',async()=>{const db=alice().database();await assertFails(set(ref(db,'users/alice/phase1/probe'),{ok:true,updatedAt:serverTimestamp(),extra:true}));await assertFails(set(ref(db,'users/alice/phase1/probe'),{ok:true,updatedAt:Date.now()+86400000}));await assertFails(set(ref(db,'users/alice/entitlements'),{tier:'premium'}));await assertFails(get(ref(db,'server/paymentAttempts')));});
test('owner can roundtrip a small PNG and remove it',async()=>{const path=storageRef(alice().storage(),'users/alice/phase1/probe.png');await assertSucceeds(uploadBytes(path,new Uint8Array([137,80,78,71]),{contentType:'image/png'}));await assertSucceeds(getBytes(path));await assertSucceeds(deleteObject(path));});
test('other-user, anonymous and unverified image access denied',async()=>{const path='users/alice/phase1/probe.png';await uploadBytes(storageRef(alice().storage(),path),new Uint8Array([137]),{contentType:'image/png'});for(const ctx of [env.unauthenticatedContext(),env.authenticatedContext('bob',{email_verified:true}),env.authenticatedContext('alice',{email_verified:false})]){await assertFails(getBytes(storageRef(ctx.storage(),path)));await assertFails(uploadBytes(storageRef(ctx.storage(),path),new Uint8Array([137]),{contentType:'image/png'}));await assertFails(deleteObject(storageRef(ctx.storage(),path)));}});
test('oversized, wrong-type and out-of-scope image uploads denied',async()=>{const store=alice().storage();await assertFails(uploadBytes(storageRef(store,'users/alice/phase1/probe.png'),new Uint8Array(2049),{contentType:'image/png'}));await assertFails(uploadBytes(storageRef(store,'users/alice/phase1/probe.png'),new Uint8Array([1]),{contentType:'text/plain'}));await assertFails(uploadBytes(storageRef(store,'users/alice/avatar.png'),new Uint8Array([137]),{contentType:'image/png'}));});

test('two verified clients of one account observe confirmed name changes', async () => {
  const path = 'users/alice/profile/displayName';
  const secondDevice = ref(alice().database(), path);
  let stop;
  try {
    const changed = new Promise((resolve, reject) => {
      stop = onValue(secondDevice, snapshot => {
        if (snapshot.val() === 'Bimbi test') resolve(snapshot.val());
      }, reject);
    });
    await assertSucceeds(set(ref(alice().database(), path), 'Bimbi test'));
    let timer;
    try {
      const result = await Promise.race([
        changed,
        new Promise((_, reject) => {
          timer = setTimeout(() => reject(new Error('Name did not propagate')), 5000);
        }),
      ]);
      if (result !== 'Bimbi test') throw new Error('Wrong name');
    } finally {
      clearTimeout(timer);
    }
  } finally {
    stop?.();
  }
});

test('profile rules deny other accounts, parent access and malformed fields', async () => {
  const path = 'users/alice/profile';
  const owner = alice().database();
  await assertSucceeds(set(ref(owner, path + '/displayName'), 'Á'));
  await assertSucceeds(get(ref(owner, path)));
  await assertFails(get(ref(owner, 'users/alice')));
  for (const invalid of ['', '   ', 'name ', 'x'.repeat(41), 4, null]) {
    await assertFails(set(ref(owner, path + '/displayName'), invalid));
  }
  await assertFails(set(ref(owner, path), {displayName: 'Bimbi', authOrigin: 'password'}));
  await assertFails(set(ref(owner, path + '/authOrigin'), 'password'));
  for (const ctx of [env.unauthenticatedContext(), env.authenticatedContext('bob',{email_verified:true}),
    env.authenticatedContext('alice',{email_verified:false})]) {
    await assertFails(get(ref(ctx.database(), path)));
    await assertFails(set(ref(ctx.database(), path + '/displayName'), 'Wrong account'));
  }
});

const avatarContext = (uid, origin, signIn, verified = true) =>
  env.authenticatedContext(uid, {
    email_verified: verified,
    bimbiAuthOrigin: origin,
    firebase: {identities: {}, sign_in_provider: signIn},
  });
const jpeg = new Uint8Array([255, 216, 255, 217]);
const jpegType = {contentType: 'image/jpeg'};
const avatarPath = 'users/alice/avatar.jpg';

test('verified password-origin account can upload, download and remove its avatar', async () => {
  const first = storageRef(avatarContext('alice','password','password').storage(), avatarPath);
  const second = storageRef(avatarContext('alice','password','password').storage(), avatarPath);
  await assertSucceeds(uploadBytes(first, jpeg, jpegType));
  await assertSucceeds(getBytes(second));
  await assertFails(uploadBytes(first, new Uint8Array(256 * 1024 + 1), jpegType));
  await assertFails(uploadBytes(first, jpeg, {contentType: 'image/png'}));
  await assertSucceeds(deleteObject(first));
});

test('avatar writes require a trusted original password account even after provider linking', async () => {
  const owner = storageRef(avatarContext('alice','password','password').storage(), avatarPath);
  await uploadBytes(owner, jpeg, jpegType);
  for (const ctx of [
    avatarContext('alice','google.com','google.com'),
    avatarContext('alice','github.com','password'),
    avatarContext('alice','google.com','password'),
    avatarContext('alice','password','google.com'),
    avatarContext('alice','unknown','password'),
  ]) {
    const avatar = storageRef(ctx.storage(), avatarPath);
    await assertFails(uploadBytes(avatar, jpeg, jpegType));
    await assertFails(deleteObject(avatar));
  }
  for (const ctx of [
    avatarContext('bob','password','password'),
    avatarContext('alice','password','password',false),
    env.unauthenticatedContext(),
  ]) {
    const avatar = storageRef(ctx.storage(), avatarPath);
    await assertFails(getBytes(avatar));
    await assertFails(uploadBytes(avatar, jpeg, jpegType));
    await assertFails(deleteObject(avatar));
  }
});

const night = (extra = {}) => ({
  bedtime: Date.UTC(2026, 10, 21, 5), wakeTime: Date.UTC(2026, 10, 21, 13),
  utcOffsetMin: -360, source: 'diary', updatedAt: Date.now(), ...extra,
});
const session = (extra = {}) => ({
  startedAt: Date.now() - 1500000, durationSec: 1500, status: 'completed', updatedAt: Date.now(), ...extra,
});

test('verified owner keeps a sleep diary and focus history', async () => {
  const db = alice().database();
  await assertSucceeds(set(ref(db, 'users/alice/sleep/2026-11-21'), night({note: 'Late tea'})));
  await assertSucceeds(set(ref(db, 'users/alice/focus/1795370400000'), session({taskLabel: 'Chapter 3'})));
  await assertSucceeds(set(ref(db, 'users/alice/focus/1795370400001'), session({durationSec: 28800})));
  await assertSucceeds(get(ref(db, 'users/alice/sleep')));
  await assertSucceeds(get(ref(db, 'users/alice/focus')));
  await assertSucceeds(set(ref(db, 'users/alice/sleep/2026-11-21'), null));
});

test('sleep and focus deny other accounts and malformed rows', async () => {
  const db = alice().database();
  for (const ctx of [env.unauthenticatedContext(), env.authenticatedContext('bob',{email_verified:true}),
    env.authenticatedContext('alice',{email_verified:false})]) {
    await assertFails(get(ref(ctx.database(), 'users/alice/sleep')));
    await assertFails(set(ref(ctx.database(), 'users/alice/sleep/2026-11-21'), night()));
    await assertFails(get(ref(ctx.database(), 'users/alice/focus')));
    await assertFails(set(ref(ctx.database(), 'users/alice/focus/1795370400000'), session()));
  }
  for (const bad of [
    night({wakeTime: Date.UTC(2026, 10, 21, 4)}),            // wake before bed
    night({wakeTime: Date.UTC(2026, 10, 22, 0)}),            // over 16 h
    night({source: 'tracker'}),                              // not self-reported
    night({stage: 'deep'}),                                  // no sleep stages
    night({note: 'x'.repeat(281)}),
    night({updatedAt: Date.now() + 86400000}),
  ]) await assertFails(set(ref(db, 'users/alice/sleep/2026-11-21'), bad));
  await assertFails(set(ref(db, 'users/alice/sleep/yesterday'), night()));
  for (const bad of [
    session({durationSec: 30000}), session({durationSec: 10}), session({status: 'won'}),
    session({points: 10}), session({taskLabel: 'x'.repeat(41)}),
  ]) await assertFails(set(ref(db, 'users/alice/focus/1795370400000'), bad));
  await assertFails(set(ref(db, 'users/alice/focus/session-one'), session()));
});
