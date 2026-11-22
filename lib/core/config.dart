import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

abstract final class AppConfig {
  static const harness =
      kDebugMode && bool.fromEnvironment('PHASE1_HARNESS', defaultValue: true);
  static const firebaseEmulators =
      kDebugMode && bool.fromEnvironment('FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
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
      firebaseEmulators ||
      [projectId, appId, apiKey, senderId].every((v) => v.isNotEmpty);
  static bool get profileDatabaseConfigured =>
      firebaseEmulators || databaseUrl.isNotEmpty;
  static bool get profileStorageConfigured =>
      firebaseEmulators || storageBucket.isNotEmpty;
  static String get firebaseProject =>
      firebaseEmulators ? 'demo-bimbi' : projectId;
  static FirebaseOptions get firebaseOptions => firebaseEmulators
      ? const FirebaseOptions(
          apiKey: 'demo-key',
          appId: '1:1234567890:android:b1b1',
          messagingSenderId: '1234567890',
          projectId: 'demo-bimbi',
          databaseURL: 'https://demo-bimbi.firebaseio.com',
          storageBucket: 'demo-bimbi.appspot.com',
        )
      : FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        );
}
