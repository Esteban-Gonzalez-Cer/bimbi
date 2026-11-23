// Review renders of Notifications. Not part of the suite:
// run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/data/services/messaging_service.dart';
import 'package:bimbi/ui/notifications/widgets/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_messaging.dart';
import '../helpers/fake_platform.dart';
import '../helpers/pump.dart';

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  testWidgets('notifications screen', (tester) async {
    final m = FakeMessaging();
    await pumpBimbi(
      tester,
      width: 390,
      height: 844,
      platform: FakePlatform(capabilities: {'notifications': true}),
      overrides: [messagingServiceProvider.overrideWithValue(m)],
    );
    // ignore: unawaited_futures
    openNotifications(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await _shot(tester, 'notifications_390');
  });

  testWidgets('foreground banner', (tester) async {
    final m = FakeMessaging();
    await pumpBimbi(
      tester,
      width: 390,
      height: 844,
      overrides: [messagingServiceProvider.overrideWithValue(m)],
    );
    m.deliver(
      const InboxMessage(
        title: 'A calmer bedtime',
        body: 'Put your phone across the room tonight and log the night tomorrow.',
        destination: 'sleep',
      ),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'notifications_banner_390');
  });
}
