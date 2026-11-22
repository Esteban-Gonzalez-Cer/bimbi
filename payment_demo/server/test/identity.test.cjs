const {test} = require('node:test');
const assert = require('node:assert/strict');
const {originAtCreation, recordAuthOrigin} = require('../lib/identity');

const created = (...ids) => ({
  uid: 'example',
  providerData: ids.map(providerId => ({providerId})),
});

test('only unequivocal password origin makes an account eligible', () => {
  assert.equal(originAtCreation(created('password')), 'password');
  assert.equal(originAtCreation(created('password', 'google.com')), 'google.com');
  assert.equal(originAtCreation(created('github.com')), 'github.com');
  assert.equal(originAtCreation(created()), 'unknown');
});

test('uses the creation event and preserves unrelated claims on retry', async () => {
  let writes = 0;
  const account = {...created('password'), customClaims: {otherClaim: true}};
  const auth = {
    getUser: async () => account,
    setCustomUserClaims: async (uid, claims) => {
      assert.equal(uid, 'example');
      account.customClaims = claims;
      writes++;
    },
  };
  await recordAuthOrigin(created('google.com'), auth);
  await recordAuthOrigin(created('password'), auth);
  assert.deepEqual(account.customClaims, {
    otherClaim: true, bimbiAuthOrigin: 'google.com',
  });
  assert.equal(writes, 1);
});
