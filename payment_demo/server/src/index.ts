import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getDatabase} from 'firebase-admin/database';
import {defineSecret} from 'firebase-functions/params';
import {onRequest} from 'firebase-functions/v2/https';
import Stripe from 'stripe';
import {ApiError, Attempt, handlePayment, PaymentDependencies, PLANS} from './payments.js';
initializeApp();
const stripeSecret = defineSecret('STRIPE_SECRET_KEY');

// One deployment, zero idle instances, authenticated test traffic only.
export const paymentApi = onRequest({region: 'us-central1', minInstances: 0, maxInstances: 1, concurrency: 10, memory: '256MiB', timeoutSeconds: 30, secrets: [stripeSecret]}, async (request, response) => {
  response.set('Cache-Control', 'no-store');
  if (request.method !== 'POST') { response.status(405).json({error: 'method_not_allowed'}); return; }
  if (!request.is('application/json') || Number(request.get('content-length') ?? '0') > 2048) { response.status(400).json({error: 'invalid_request'}); return; }
  const secret = stripeSecret.value();
  if (!secret.startsWith('sk_test_')) { response.status(503).json({error: 'test_configuration_required'}); return; }
  const stripe = new Stripe(secret, {maxNetworkRetries: 1, timeout: 15000});
  const attempts = getDatabase().ref('server/paymentAttempts');
  const dependencies: PaymentDependencies = {
    authenticate: token => getAuth().verifyIdToken(token, true),
    reserve: async (uid, requestId, plan) => {
      const result = await attempts.child(uid).child(requestId).transaction(current => current ?? {plan, createdAt: Date.now()});
      return result.snapshot.val() as Attempt;
    },
    save: async (uid, requestId, id) => { await attempts.child(uid).child(requestId).child('paymentIntentId').set(id); },
    create: async (plan, uid, requestId) => stripe.paymentIntents.create({amount: PLANS[plan], currency: 'mxn', allowed_payment_method_types: ['card'], metadata: {uid, plan}}, {idempotencyKey: `bimbi:${uid}:${requestId}`}),
    retrieve: id => stripe.paymentIntents.retrieve(id),
  };
  try {
    const route = request.path.replace(/^\//, '');
    response.status(200).json(await handlePayment(dependencies, route, request.get('authorization'), request.body));
  } catch (error) {
    // Deliberately omit SDK error messages, request bodies, tokens and client secrets.
    const known = error instanceof ApiError;
    response.status(known ? error.status : 502).json({error: known ? error.code : 'payment_unavailable'});
  }
});
