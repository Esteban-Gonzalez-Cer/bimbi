import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bimbi_app.dart';
import 'core/config.dart';
import 'features/auth/auth_adapter.dart';
import 'features/notifications/messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var ready = false;
  if (AppConfig.harness && AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      FirebaseMessaging.onBackgroundMessage(backgroundMessage);
      ready = true;
    } catch (_) {
      /* The offline alarm shell remains available. */
    }
  }
  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(ready)],
      child: const BimbiApp(),
    ),
  );
}
