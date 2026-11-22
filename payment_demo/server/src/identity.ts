import {getAuth, type Auth, type UserRecord} from 'firebase-admin/auth';
import {region} from 'firebase-functions/v1';

export function originAtCreation(user: Pick<UserRecord, 'providerData'>): string {
  const providers = new Set(user.providerData.map(provider => provider.providerId));
  if (providers.has('google.com')) return 'google.com';
  if (providers.has('github.com')) return 'github.com';
  return providers.size === 1 && providers.has('password') ? 'password' : 'unknown';
}

export async function recordAuthOrigin(
  created: Pick<UserRecord, 'uid' | 'providerData'>,
  auth: Pick<Auth, 'getUser' | 'setCustomUserClaims'>,
): Promise<void> {
  try {
    const current = await auth.getUser(created.uid);
    const claims = current.customClaims ?? {};
    if ('bimbiAuthOrigin' in claims) return;
    await auth.setCustomUserClaims(created.uid, {
      ...claims,
      bimbiAuthOrigin: originAtCreation(created),
    });
  } catch (error) {
    if (!(error && typeof error === 'object' && 'code' in error &&
          error.code === 'auth/user-not-found')) throw error;
  }
}

export const assignBimbiAuthOrigin = region('us-central1')
  .runWith({minInstances: 0, maxInstances: 1, memory: '128MB'})
  .auth.user().onCreate(user => recordAuthOrigin(user, getAuth()));
