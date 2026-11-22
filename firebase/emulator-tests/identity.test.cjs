const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {
  getAuth, connectAuthEmulator, createUserWithEmailAndPassword,
  signInWithCredential, GoogleAuthProvider,
} = require('firebase/auth');
const {setTimeout: pause} = require('node:timers/promises');

test('auth emulator origin is stamped from actual email and federated creation events',
  {timeout: 20000}, async () => {
    const app = initializeApp({projectId: 'demo-bimbi', apiKey: 'demo-key'}, 'origin-test');
    try {
      const auth = getAuth(app);
      connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
      const timestamp = Date.now();
      const password = await createUserWithEmailAndPassword(
        auth, `email-${timestamp}@example.test`, 'synthetic-test-password',
      );
      assert.equal(await origin(password.user), 'password');
      const google = await signInWithCredential(auth, GoogleAuthProvider.credential(
        JSON.stringify({
          sub: `google-${timestamp}`,
          email: `google-${timestamp}@example.test`,
          email_verified: true,
        }),
      ));
      assert.equal(await origin(google.user), 'google.com');
    } finally {
      await deleteApp(app);
    }
  });

async function origin(user) {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    const {claims} = await user.getIdTokenResult(true);
    if (claims.bimbiAuthOrigin) return claims.bimbiAuthOrigin;
    await pause(200);
  }
  throw new Error('Auth creation did not produce an origin claim');
}
