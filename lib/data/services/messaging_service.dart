import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../features/auth/auth_adapter.dart';

/// A console message as Bimbi shows it. No token or message id is kept.
@immutable
class InboxMessage {
  const InboxMessage({this.title, this.body, this.destination});
  final String? title;
  final String? body;

  /// Allowlisted screen to open, from the message data `destination`.
  final String? destination;

  static InboxMessage from(RemoteMessage m) => InboxMessage(
    title: m.notification?.title,
    body: m.notification?.body,
    destination: m.data['destination'] is String
        ? m.data['destination'] as String
        : null,
  );
}

/// Firebase Cloud Messaging, behind an interface so tests can drive it.
abstract interface class MessagingService {
  /// Messages that arrive while Bimbi is in front (Android shows nothing).
  Stream<InboxMessage> get foreground;

  /// Notifications tapped while Bimbi was in the background.
  Stream<InboxMessage> get opened;

  /// The notification that launched Bimbi from a terminated state, if any.
  Future<InboxMessage?> initial();

  /// Asks for Android's notification permission; true when allowed.
  Future<bool> requestPermission();
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
}

class FirebaseMessagingService implements MessagingService {
  FirebaseMessaging get _m => FirebaseMessaging.instance;

  @override
  Stream<InboxMessage> get foreground =>
      FirebaseMessaging.onMessage.map(InboxMessage.from);

  @override
  Stream<InboxMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(InboxMessage.from);

  @override
  Future<InboxMessage?> initial() async {
    final m = await _m.getInitialMessage();
    return m == null ? null : InboxMessage.from(m);
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _m.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> subscribe(String topic) async {
    await _m.setAutoInitEnabled(true);
    await _m.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribe(String topic) => _m.unsubscribeFromTopic(topic);
}

/// Null when Firebase is not configured or the build targets the emulators.
final messagingServiceProvider = Provider<MessagingService?>((ref) {
  if (!ref.watch(firebaseReadyProvider) || AppConfig.firebaseEmulators) {
    return null;
  }
  return FirebaseMessagingService();
});
