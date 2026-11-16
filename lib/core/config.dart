import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

abstract final class AppConfig {
  static const harness =
      kDebugMode && bool.fromEnvironment('PHASE1_HARNESS', defaultValue: true);
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const paymentBaseUrl = String.fromEnvironment('PAYMENT_BASE_URL');
  static const stripeKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  static bool get firebaseConfigured =>
      [projectId, appId, apiKey, senderId].every((v) => v.isNotEmpty);
  static FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}
