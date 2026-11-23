import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/data/repositories/collection_sync.dart';
import 'package:bimbi/data/services/messaging_service.dart';
import 'package:bimbi/features/notifications/messaging.dart';
import 'package:bimbi/ui/notifications/view_models/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_messaging.dart';

void main() {
  // InboxController.open pops the root navigator through a GlobalKey.
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer app(FakeMessaging m, {FakeTopicCloud? cloud, String? uid}) {
    final c = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        messagingServiceProvider.overrideWithValue(m),
        topicPrefsCloudProvider.overrideWithValue(cloud),
        syncAccountProvider.overrideWithValue(uid),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('the Phase 1 test topic is removed once', () async {
    final m = FakeMessaging();
    app(m).read(topicsProvider);
    await settle();
    app(m).read(topicsProvider);
    await settle();
    expect(m.calls.where((c) => c == '-${Topics.legacy}'), hasLength(1));
  });

  test(
    'turning a topic on asks permission and subscribes; off unsubscribes',
    () async {
      final m = FakeMessaging();
      final c = app(m);
      await c.read(topicsProvider.notifier).set(tips: true);
      expect(m.permissionRequests, 1);
      expect(m.subscribed, {Topics.tips});
      await c.read(topicsProvider.notifier).set(updates: true);
      await c.read(topicsProvider.notifier).set(tips: false);
      expect(m.subscribed, {Topics.updates});
      expect(
        app(m).read(topicsProvider).updates,
        isTrue,
        reason: 'the choice survives a restart',
      );
    },
  );

  test('a denied permission leaves the topic off', () async {
    final m = FakeMessaging(allow: false);
    final c = app(m);
    final message = await c.read(topicsProvider.notifier).set(tips: true);
    expect(message, contains('Android settings'));
    expect(c.read(topicsProvider).tips, isFalse);
    expect(m.subscribed, isEmpty);
  });

  test('a second device follows the account choice from the cloud', () async {
    final cloud = FakeTopicCloud()
      ..rows['alice'] = const TopicChoice(tips: true, updates: false);
    final m = FakeMessaging();
    final c = app(m, cloud: cloud, uid: 'alice');
    c.read(topicsProvider);
    await settle();
    await settle();
    expect(c.read(topicsProvider).tips, isTrue);
    expect(m.subscribed, {Topics.tips});
    await c.read(topicsProvider.notifier).set(updates: true);
    expect(cloud.rows['alice'], const TopicChoice(tips: true, updates: true));
  });

  test(
    'foreground messages become a banner; taps open allowlisted screens',
    () async {
      final m = FakeMessaging();
      final c = app(m);
      c.listen(inboxProvider, (_, _) {});
      m.deliver(const InboxMessage(title: 'Sleep tip', destination: 'sleep'));
      await settle();
      expect(c.read(inboxProvider)?.title, 'Sleep tip');
      c.read(inboxProvider.notifier).open(c.read(inboxProvider)!);
      expect(c.read(destinationProvider), 1);
      expect(c.read(inboxProvider), isNull);

      m.tap(const InboxMessage(destination: 'plans'));
      await settle();
      expect(c.read(destinationProvider), 4);
      expect(c.read(pendingScreenProvider), NotificationTarget.plans);

      m.tap(const InboxMessage(destination: 'https://evil.example'));
      await settle();
      expect(c.read(destinationProvider), 0, reason: 'unknown targets go Home');
    },
  );

  test('a notification that launched Bimbi opens its screen', () async {
    final m = FakeMessaging(launch: const InboxMessage(destination: 'focus'));
    final c = app(m);
    c.listen(inboxProvider, (_, _) {});
    await settle();
    expect(c.read(destinationProvider), 2);
  });
}
