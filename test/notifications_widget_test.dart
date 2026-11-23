import 'package:bimbi/data/services/messaging_service.dart';
import 'package:bimbi/ui/notifications/view_models/notifications.dart';
import 'package:bimbi/ui/notifications/widgets/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_messaging.dart';
import 'helpers/fake_platform.dart';
import 'helpers/pump.dart';

void main() {
  testWidgets('Tips and Updates switches subscribe from the screen', (
    tester,
  ) async {
    final m = FakeMessaging();
    await pumpBimbi(
      tester,
      platform: FakePlatform(capabilities: {'notifications': true}),
      overrides: [messagingServiceProvider.overrideWithValue(m)],
    );
    // ignore: unawaited_futures
    openNotifications(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(find.text('Allowed'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(m.subscribed, {Topics.tips});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a foreground message shows a banner that opens its tab', (
    tester,
  ) async {
    final m = FakeMessaging();
    await pumpBimbi(
      tester,
      overrides: [messagingServiceProvider.overrideWithValue(m)],
    );
    m.deliver(
      const InboxMessage(
        title: 'Wind down tonight',
        body: 'Try logging last night.',
        destination: 'sleep',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wind down tonight'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Wind down tonight'), findsNothing);
    expect(find.text('Last night'), findsWidgets);
  });

  testWidgets(
    'the banner shows over a pushed screen and Open returns to tabs',
    (tester) async {
      final m = FakeMessaging();
      await pumpBimbi(
        tester,
        width: 800,
        platform: FakePlatform(capabilities: {'notifications': true}),
        overrides: [messagingServiceProvider.overrideWithValue(m)],
      );
      // ignore: unawaited_futures
      openNotifications(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
      m.deliver(const InboxMessage(title: 'Focus tip', destination: 'focus'));
      await tester.pumpAndSettle();
      expect(find.text('Focus tip'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.text('Focus tip'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('without the online build the switches explain why', (
    tester,
  ) async {
    await pumpBimbi(tester, width: 360, textScale: 2);
    // ignore: unawaited_futures
    openNotifications(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Notifications need the online build of Bimbi.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
