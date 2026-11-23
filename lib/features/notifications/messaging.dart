import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && AppConfig.firebaseConfigured) {
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
  }
  // Android displays console notification payloads on the channel the console
  // campaign names (bimbi_tips / bimbi_updates). Nothing is logged or stored.
}

class DestinationController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int value) {
    state = value;
  }
}

final destinationProvider = NotifierProvider<DestinationController, int>(
  DestinationController.new,
);
