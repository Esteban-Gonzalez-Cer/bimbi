const fs = require('node:fs');
const {setTimeout: pause} = require('node:timers/promises');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword,
  signInWithEmailAndPassword, sendEmailVerification, applyActionCode} = require('firebase/auth');
const {connectDatabaseEmulator, getDatabase, goOffline, ref, set} = require('firebase/database');
const {connectStorageEmulator, getStorage, ref: storageRef, uploadBytes} = require('firebase/storage');

async function seed(photoPath) {
  if (!photoPath) throw new Error('Pass a synthetic test JPEG.');
  const photo = fs.readFileSync(photoPath);
  if (photo.length > 256 * 1024 || photo[0] !== 255 || photo[1] !== 216) {
    throw new Error('Use a JPEG of at most 256 KiB.');
  }
  const app = initializeApp({
    apiKey: 'demo-key',
    projectId: 'demo-bimbi',
    databaseURL: 'https://demo-bimbi.firebaseio.com',
    storageBucket: 'demo-bimbi.appspot.com',
  });
  let database;
  try {
    const auth = getAuth(app);
    const host = 'http://127.0.0.1:9099';
    connectAuthEmulator(auth, host, {disableWarnings: true});
    const email = 'phase3-avatar@example.test';
    const password = 'SyntheticBimbiProfile2026';
    let credential;
    try {
      credential = await createUserWithEmailAndPassword(auth, email, password);
    } catch (error) {
      if (error.code !== 'auth/email-already-in-use') throw error;
      credential = await signInWithEmailAndPassword(auth, email, password);
    }
    const {user} = credential;
    if (!user.emailVerified) {
      await sendEmailVerification(user);
      const response = await fetch(host + '/emulator/v1/projects/demo-bimbi/oobCodes');
      const verification = (await response.json()).oobCodes.find(code => code.email === email);
      await applyActionCode(auth, verification.oobCode);
      await user.reload();
    }
    let stamped = false;
    for (let attempt = 0; attempt < 24; attempt++) {
      const {claims} = await user.getIdTokenResult(true);
      if (claims.bimbiAuthOrigin === 'password' && claims.email_verified === true) {
        stamped = true;
        break;
      }
      await pause(250);
    }
    if (!stamped) throw new Error('Start the Functions emulator before seeding.');
    database = getDatabase(app);
    connectDatabaseEmulator(database, '127.0.0.1', 9000);
    const cloudStorage = getStorage(app);
    connectStorageEmulator(cloudStorage, '127.0.0.1', 9199);
    await set(ref(database, `users/${user.uid}/profile/displayName`), 'Bimbi Profile Demo');
    await uploadBytes(storageRef(cloudStorage, `users/${user.uid}/avatar.jpg`), photo, {
      contentType: 'image/jpeg',
    });
    console.log('Verified synthetic profile seeded in demo-bimbi.');
  } finally {
    if (database) goOffline(database);
    await deleteApp(app);
  }
}

seed(process.argv[2]).then(
  () => process.exit(0),
  error => {
    console.error('Could not seed the synthetic profile.', error.code ?? error.name);
    process.exit(1);
  },
);
