import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../core/config.dart';
import '../../../data/repositories/collection_sync.dart';
import '../../../data/services/messaging_service.dart';
import '../../../features/auth/auth_adapter.dart';
import '../../../features/notifications/messaging.dart';

/// Console topics. Each matches an Android channel of the same id.
abstract final class Topics {
  static const tips = 'bimbi_tips';
  static const updates = 'bimbi_updates';

  /// The Phase 1 test topic, unsubscribed once on upgrade.
  static const legacy = 'bimbi_phase1';
}

@immutable
class TopicChoice {
  const TopicChoice({this.tips = false, this.updates = false});
  final bool tips;
  final bool updates;

  Map<String, bool> toRow() => {'tips': tips, 'updates': updates};
  static TopicChoice? fromRow(Object? value) {
    if (value is! Map) return null;
    final tips = value['tips'];
    final updates = value['updates'];
    if (tips is! bool || updates is! bool) return null;
    return TopicChoice(tips: tips, updates: updates);
  }

  @override
  bool operator ==(Object other) =>
      other is TopicChoice && other.tips == tips && other.updates == updates;
  @override
  int get hashCode => Object.hash(tips, updates);
}

/// Cloud copy of the choice at `users/{uid}/preferences/notificationTopics`,
/// so a second device signed in to the same account subscribes the same way.
abstract interface class TopicPrefsCloud {
  Stream<TopicChoice?> watch(String uid);
  Future<void> write(String uid, TopicChoice choice);
}

class FirebaseTopicPrefsCloud implements TopicPrefsCloud {
  FirebaseTopicPrefsCloud(this.database);
  final FirebaseDatabase database;
  DatabaseReference _ref(String uid) =>
      database.ref('users/$uid/preferences/notificationTopics');

  @override
  Stream<TopicChoice?> watch(String uid) =>
      _ref(uid).onValue.map((e) => TopicChoice.fromRow(e.snapshot.value));

  @override
  Future<void> write(String uid, TopicChoice choice) =>
      _ref(uid).set(choice.toRow());
}

final topicPrefsCloudProvider = Provider<TopicPrefsCloud?>((ref) {
  if (!ref.watch(firebaseReadyProvider) ||
      !AppConfig.profileDatabaseConfigured) {
    return null;
  }
  return FirebaseTopicPrefsCloud(FirebaseDatabase.instance);
});

abstract final class _Keys {
  static const tips = 'notify.tips';
  static const updates = 'notify.updates';
  static const migrated = 'notify.legacy_removed';
}

/// Which topics this device follows. Saved locally; verified accounts also
/// keep a cloud copy. Subscriptions follow the choice on every change.
class TopicController extends Notifier<TopicChoice> {
  StreamSubscription<TopicChoice?>? _remote;

  MessagingService? get _service => ref.read(messagingServiceProvider);

  @override
  TopicChoice build() {
    final prefs = ref.watch(preferencesProvider);
    final cloud = ref.watch(topicPrefsCloudProvider);
    final uid = ref.watch(syncAccountProvider);
    ref.onDispose(() => unawaited(_remote?.cancel()));
    final local = TopicChoice(
      tips: prefs?.getBool(_Keys.tips) ?? false,
      updates: prefs?.getBool(_Keys.updates) ?? false,
    );
    scheduleMicrotask(() async {
      if (!ref.mounted) return;
      await _migrate();
      if (cloud != null && uid != null) {
        _remote = cloud.watch(uid).listen((remote) {
          if (!ref.mounted) return;
          if (remote == null) {
            // First device for this account: publish this device's choice.
            unawaited(cloud.write(uid, state).catchError((Object _) {}));
          } else if (remote != state) {
            unawaited(_apply(remote, sync: false));
          }
        }, onError: (Object _) {});
      }
    });
    return local;
  }

  Future<void> _migrate() async {
    final prefs = ref.read(preferencesProvider);
    final service = _service;
    if (service == null || prefs == null) return;
    if (prefs.getBool(_Keys.migrated) == true) return;
    try {
      await service.unsubscribe(Topics.legacy);
      await prefs.setBool(_Keys.migrated, true);
    } on Object {
      // Retried on the next launch.
    }
  }

  /// Turns a topic on or off. Turning one on asks for Android's notification
  /// permission first; a denial leaves the topic off.
  Future<String> set({bool? tips, bool? updates}) async {
    final next = TopicChoice(
      tips: tips ?? state.tips,
      updates: updates ?? state.updates,
    );
    final service = _service;
    if (service == null) {
      return 'Notifications need the online build of Bimbi.';
    }
    final turningOn =
        (next.tips && !state.tips) || (next.updates && !state.updates);
    if (turningOn && !await service.requestPermission()) {
      return 'Notifications are off for Bimbi in Android settings.';
    }
    await _apply(next, sync: true);
    return 'Notification choices saved.';
  }

  Future<void> _apply(TopicChoice next, {required bool sync}) async {
    final previous = state;
    state = next;
    final prefs = ref.read(preferencesProvider);
    await prefs?.setBool(_Keys.tips, next.tips);
    await prefs?.setBool(_Keys.updates, next.updates);
    final service = _service;
    if (service != null) {
      Future<void> follow(String topic, bool on, bool was) async {
        if (on == was) return;
        on ? await service.subscribe(topic) : await service.unsubscribe(topic);
      }

      try {
        await follow(Topics.tips, next.tips, previous.tips);
        await follow(Topics.updates, next.updates, previous.updates);
      } on Object {
        // FCM retries topic changes itself once the device is online.
      }
    }
    final cloud = ref.read(topicPrefsCloudProvider);
    final uid = ref.read(syncAccountProvider);
    if (sync && cloud != null && uid != null) {
      unawaited(cloud.write(uid, next).catchError((Object _) {}));
    }
  }
}

final topicsProvider = NotifierProvider<TopicController, TopicChoice>(
  TopicController.new,
);

/// Screens a notification may open. Anything else opens Bimbi's Home.
enum NotificationTarget {
  alarm,
  sleep,
  focus,
  running,
  profile,
  plans,
  notifications,
}

NotificationTarget targetOf(String? destination) =>
    NotificationTarget.values.where((t) => t.name == destination).firstOrNull ??
    NotificationTarget.alarm;

/// Bimbi's root navigator, so a notification can return to the tabs from a
/// pushed screen (Plans, Notifications, a run's detail).
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (_) => GlobalKey<NavigatorState>(),
);

/// A pushed screen the shell should open (Plans or Notifications).
class PendingScreen extends Notifier<NotificationTarget?> {
  @override
  NotificationTarget? build() => null;
  void open(NotificationTarget target) => state = target;
  void clear() => state = null;
}

final pendingScreenProvider =
    NotifierProvider<PendingScreen, NotificationTarget?>(PendingScreen.new);

/// Global FCM handling. The foreground message becomes an in-app banner;
/// a tapped notification (background or terminated) opens its allowlisted
/// screen. Listeners attach at start-up, before any screen.
class InboxController extends Notifier<InboxMessage?> {
  @override
  InboxMessage? build() {
    final service = ref.watch(messagingServiceProvider);
    if (service == null) return null;
    final foreground = service.foreground.listen((m) => state = m);
    final opened = service.opened.listen(open);
    ref.onDispose(() {
      unawaited(foreground.cancel());
      unawaited(opened.cancel());
    });
    unawaited(
      service
          .initial()
          .then((m) {
            if (ref.mounted && m != null) open(m);
          })
          .catchError((Object _) {}),
    );
    return null;
  }

  void dismiss() => state = null;

  /// Opens the message's screen and clears the banner.
  void open(InboxMessage message) {
    state = null;
    ref
        .read(navigatorKeyProvider)
        .currentState
        ?.popUntil((route) => route.isFirst);
    final target = targetOf(message.destination);
    final tab = switch (target) {
      NotificationTarget.alarm => 0,
      NotificationTarget.sleep => 1,
      NotificationTarget.focus => 2,
      NotificationTarget.running => 3,
      _ => 4,
    };
    ref.read(destinationProvider.notifier).select(tab);
    if (target == NotificationTarget.plans ||
        target == NotificationTarget.notifications) {
      ref.read(pendingScreenProvider.notifier).open(target);
    }
  }
}

final inboxProvider = NotifierProvider<InboxController, InboxMessage?>(
  InboxController.new,
);
