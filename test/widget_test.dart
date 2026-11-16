import 'package:bimbi/app/bimbi_app.dart';
import 'package:bimbi/core/platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlatform implements PlatformAdapter {
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    'exactAlarm': false,
    'notifications': false,
    'fullScreen': false,
    'lastEvent': 'none',
    'mapsConfigured': false,
  };
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dismiss() async {}
  @override
  Future<void> schedule({
    required String id,
    required DateTime at,
    Duration repeat = Duration.zero,
  }) async {}
  @override
  Future<void> settings(String kind) async {}
  @override
  Future<Map<String, dynamic>> usageSummary() async => {};
}

void main() {
  for (final width in [360.0, 412.0, 700.0, 900.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Five tabs at $width dp and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [platformProvider.overrideWithValue(FakePlatform())],
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const BimbiApp(),
            ),
          ),
        );
        // MaterialApp builds its own MediaQuery. Apply the scale through platform data.
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(
          find.byType(width < 600 ? NavigationBar : NavigationRail),
          findsOneWidget,
        );
        for (final name in ['Sleep', 'Focus', 'Running', 'Profile', 'Alarm']) {
          await tester.tap(find.text(name).last);
          await tester.pumpAndSettle();
          expect(find.text('Bimbi · $name'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets(
    'unconfigured app keeps cloud controls disabled and alarm available',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [platformProvider.overrideWithValue(FakePlatform())],
          child: const BimbiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alarm in 30 seconds'), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Firebase configuration required'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign in'),
      );
      expect(button.onPressed, isNull);
    },
  );
}
