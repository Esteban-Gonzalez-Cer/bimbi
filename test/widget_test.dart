import 'dart:ui' show SemanticsAction;

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

void _expectSemanticTap(WidgetTester tester, String label) {
  final semantics = tester.ensureSemantics();
  try {
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
      reason: label,
    );
  } finally {
    semantics.dispose();
  }
}

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

  testWidgets(
    'unconfigured build keeps sign-in disabled, active challenge reachable',
    (tester) async {
      final fake = await pumpBimbi(
        tester,
        platform: FakePlatform(capabilities: {'active': true}),
      );
      final open = find.text('Open wake-up challenge');
      await tester.scrollUntilVisible(
        open,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(open);
      await tester.pump();
      expect(fake.openChallengeCalls, 1);
      expect(find.text('Dismiss ringing alarm'), findsNothing);

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
    },
  );

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

  testWidgets(
    'creating an alarm requires and persists the selected challenge',
    (tester) async {
      final fake = await pumpBimbi(tester);
      final create = find.widgetWithText(FilledButton, 'Set alarm');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gym day');
      _expectSemanticTap(tester, 'Monday');
      await tester.tap(find.bySemanticsLabel('Monday'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save alarm'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save alarm'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Ball Monte'),
        -220,
        scrollable: find.byType(Scrollable).first,
      );
      _expectSemanticTap(tester, 'Ball Monte, Find the ball');
      await tester.tap(find.text('Ball Monte'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Extreme'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Extreme'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save alarm'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save alarm'));
      await tester.pumpAndSettle();
      final alarm = fake.alarms.values.single;
      expect(alarm['challenge'], 'ballMonte');
      expect(alarm['difficulty'], 'extreme');
      expect(alarm['days'], [0]);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Gym day'), findsWidgets);
    },
  );

  testWidgets('previews, saves and reopens per-alarm sound at 360dp and 2x', (
    tester,
  ) async {
    final fake = await pumpBimbi(
      tester,
      width: 360,
      textScale: 2,
      platform: FakePlatform(
        capabilities: {
          'alarmTones': [
            {'id': 'system', 'title': 'Android default'},
            {'id': 'soft_bells', 'title': 'Soft Bells'},
          ],
          'alarmIntensities': [
            {'id': 'softest', 'title': 'Softest'},
            {'id': 'normal', 'title': 'Normal'},
            {'id': 'noisy', 'title': 'Noisy'},
            {'id': 'heavy', 'title': 'Heavy'},
            {'id': 'jackhammer', 'title': 'Jackhammer'},
          ],
        },
      ),
    );
    final create = find.widgetWithText(FilledButton, 'Set alarm');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Monday wake');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final math = find.text('Math');
    await tester.scrollUntilVisible(
      math,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(math);
    await tester.pumpAndSettle();

    final pickers = find.byType(DropdownButtonFormField<String>);
    final tone = pickers.first;
    await tester.scrollUntilVisible(
      tone,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tone);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soft Bells').last);
    await tester.pumpAndSettle();

    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(find.text('Alarm volume · 60%'), findsOneWidget);
    final intensity = pickers.last;
    await tester.ensureVisible(intensity);
    await tester.tap(intensity);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jackhammer').last);
    await tester.pumpAndSettle();
    final preview = find.text('Preview sound');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(fake.previews, [
      (tone: 'soft_bells', volume: 60, intensity: 'jackhammer'),
    ]);

    final save = find.widgetWithText(FilledButton, 'Save alarm');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(fake.stopAlarmPreviewCalls, greaterThan(1));
    expect(fake.alarms.values.single['tone'], 'soft_bells');
    expect(fake.alarms.values.single['volume'], 60);
    expect(fake.alarms.values.single['intensity'], 'jackhammer');

    final edit = find.widgetWithText(FilledButton, 'Edit alarm');
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.ensureVisible(tone);
    expect(
      tester.widget<DropdownButtonFormField<String>>(tone).initialValue,
      'soft_bells',
    );
    expect(tester.widget<Slider>(slider).value, 60);
    expect(
      tester.widget<DropdownButtonFormField<String>>(intensity).initialValue,
      'jackhammer',
    );
    expect(tester.takeException(), isNull);
  });
}
