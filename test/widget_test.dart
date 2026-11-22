import 'package:bimbi/app/design_system/components/surfaces.dart';
import 'package:bimbi/app/shell/adaptive_shell.dart';
import 'package:bimbi/app/shell/layout.dart';
import 'package:bimbi/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_platform.dart';
import 'helpers/pump.dart';

Finder _navLabel(String name) => find.descendant(
  of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
  matching: find.text(name),
);

String _pageTitle(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(PageHeader.titleKey)).data!;

void main() {
  // UI-01: five tabs at 360/412/700/900dp, text scale 1/1.3/2, light/dark.
  for (final width in [360.0, 412.0, 700.0, 900.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'five tabs at ${width}dp, text ${scale}x, ${brightness.name}',
          (tester) async {
            await pumpBimbi(
              tester,
              width: width,
              textScale: scale,
              brightness: brightness,
            );
            final window = WindowClass.fromWidth(width);
            // Keep the dock on phones and the rail available on tablets.
            expect(
              find.byType(NavigationBar),
              window.isCompact ? findsOneWidget : findsNothing,
            );
            expect(
              find.byType(NavigationRail),
              window.isCompact ? findsNothing : findsOneWidget,
            );
            for (final d in [
              ...AppDestination.values.skip(1),
              AppDestination.alarm,
            ]) {
              await tester.tap(_navLabel(d.label));
              await tester.pumpAndSettle();
              if (d == AppDestination.alarm) {
                // Home greets instead of showing a page title.
                expect(find.byType(HomeScreen), findsOneWidget);
                expect(_pageTitle(tester), 'Good morning');
              } else {
                expect(_pageTitle(tester), d.label);
                expect(
                  find.byType(TwoPane),
                  window.isExpanded ? findsOneWidget : findsNothing,
                );
              }
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  testWidgets('unconfigured build keeps sign-in disabled, dismissal ready', (
    tester,
  ) async {
    final fake = await pumpBimbi(tester);
    final dismiss = find.widgetWithText(TextButton, 'Dismiss ringing alarm');
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();
    expect(dismiss, findsOneWidget);
    await tester.tap(dismiss);
    await tester.pump();
    expect(fake.dismissCalls, 1);

    await tester.tap(_navLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Account'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Firebase configuration required'),
      findsOneWidget,
    );
    final signIn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign in'),
    );
    expect(signIn.onPressed, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_navLabel('Profile'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Plans'));
    await tester.pumpAndSettle();
    // Checkout needs a verified account; never a client-side premium flag.
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Try Plus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final tryPlus = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Try Plus'),
    );
    expect(tryPlus.onPressed, isNull);
  });

  testWidgets('Android Back returns to Alarm before leaving the app', (
    tester,
  ) async {
    await pumpBimbi(tester);
    await tester.tap(_navLabel('Focus'));
    await tester.pumpAndSettle();
    expect(_pageTitle(tester), 'Focus');
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Focus start fits a short tablet viewport without scrolling', (
    tester,
  ) async {
    await pumpBimbi(tester, width: 1006, height: 530);
    await tester.tap(_navLabel('Focus'));
    await tester.pumpAndSettle();

    final start = find.ancestor(
      of: find.text('Start focus'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(tester.getBottomLeft(start).dy, lessThan(530));
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
  });

  testWidgets('missing alarm permissions show a direct fix', (tester) async {
    await pumpBimbi(
      tester,
      platform: FakePlatform(capabilities: {'exactAlarm': false}),
    );
    // Permission fixes live in Profile → Permissions; Home stays calm.
    await tester.tap(_navLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Permissions'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Exact alarms'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Exact alarms'), findsOneWidget);
  });

  testWidgets('creating an alarm schedules the native occurrence', (
    tester,
  ) async {
    final fake = await pumpBimbi(tester);
    final create = find.widgetWithText(FilledButton, 'Set alarm');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Gym day');
    await tester.tap(find.bySemanticsLabel('Monday'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save alarm'));
    await tester.tap(find.text('Save alarm'));
    await tester.pumpAndSettle();
    expect(fake.scheduled, hasLength(1));
    // testNow is Saturday 08:30, so the next Monday 07:00 is the 23rd.
    expect(fake.scheduled.single.at, DateTime(2026, 11, 23, 7));
    expect(fake.scheduled.single.repeat, Duration.zero);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Gym day'), findsWidgets);
  });
}
