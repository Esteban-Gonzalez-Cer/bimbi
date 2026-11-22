import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../auth/auth_adapter.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && AppConfig.firebaseConfigured) {
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
  }
  // Android displays console notification payloads. No message content/token logging.
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

class MessagingController extends Notifier<String> {
  static const topic = 'bimbi_phase1';
  @override
  String build() {
    if (!ref.watch(firebaseReadyProvider) || AppConfig.firebaseEmulators) {
      return 'Firebase Messaging is unavailable in this build.';
    }
    final foreground = FirebaseMessaging.onMessage.listen((_) {
      state = 'Foreground topic message received.';
    });
    final opened = FirebaseMessaging.onMessageOpenedApp.listen(_open);
    ref.onDispose(() {
      unawaited(foreground.cancel());
      unawaited(opened.cancel());
    });
    // Attach listeners at app startup, before any screen or consent action.
    unawaited(
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((m) {
            if (ref.mounted && m != null) _open(m);
          })
          .catchError((Object _) {}),
    );
    return 'Notifications are opt-in.';
  }

  void _open(RemoteMessage message) {
    const destinations = {
      'alarm': 0,
      'sleep': 1,
      'focus': 2,
      'running': 3,
      'profile': 4,
    };
    ref
        .read(destinationProvider.notifier)
        .select(destinations[message.data['destination']] ?? 4);
    state = 'Notification opened the requested tab.';
  }

  Future<void> subscribe() async {
    if (AppConfig.firebaseEmulators) return;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      state = 'Notification permission denied.';
      return;
    }
    await messaging.setAutoInitEnabled(true);
    await messaging.subscribeToTopic(topic);
    state = 'Subscribed to the Phase 1 topic.';
  }

  Future<void> unsubscribe() async {
    if (AppConfig.firebaseEmulators) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    await FirebaseMessaging.instance.unregister();
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    state = 'Unsubscribed; automatic registration disabled.';
  }
}

final messagingProvider = NotifierProvider<MessagingController, String>(
  MessagingController.new,
);
