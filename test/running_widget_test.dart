import 'package:bimbi/features/running/application/run_controller.dart';
import 'package:bimbi/features/running/domain/run.dart';
import 'package:bimbi/features/running/presentation/running_page.dart';
import 'package:bimbi/features/running/tracking_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_run_location.dart';
import 'helpers/pump.dart';

void main() {
  testWidgets('a 360 dp run saves and reopens without map tiles', (
    tester,
  ) async {
    final gps = FakeRunLocation();
    var elapsed = Duration.zero;
    await pumpBimbi(
      tester,
      width: 360,
      textScale: 2,
      overrides: [
        trackingAdapterProvider.overrideWithValue(gps),
        runElapsedProvider.overrideWithValue(() => elapsed),
      ],
    );
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(gps.fixes.hasListener, isTrue);
    gps.emit(RunPoint(0, 0, 4, testNow));
    elapsed = const Duration(seconds: 5);
    gps.emit(RunPoint(0, .0001, 4, testNow.add(elapsed)));
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(gps.fixes.hasListener, isFalse);
    expect(find.text('Review your run'), findsOneWidget);
    await tester.ensureVisible(find.text('Save run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save run'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RunningPage)),
    );
    expect(container.read(runControllerProvider).phase, RunPhase.idle);
    expect(
      container.read(runControllerProvider).runs.single.summary!.distanceM,
      11,
    );

    final entry = find.text('11 m · 0:05');
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Saved run'), findsOneWidget);
    expect(find.text('11 m'), findsOneWidget);
    expect(find.bySemanticsLabel('Recorded route'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Delete run'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Delete run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(entry, findsNothing);
  });

  testWidgets('leaving Running pauses before another tab is shown', (
    tester,
  ) async {
    final gps = FakeRunLocation();
    await pumpBimbi(
      tester,
      width: 900,
      height: 650,
      overrides: [trackingAdapterProvider.overrideWithValue(gps)],
    );
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(gps.fixes.hasListener, isTrue);
    await tester.tap(find.text('Sleep'));
    await tester.pumpAndSettle();
    expect(gps.fixes.hasListener, isFalse);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    expect(find.text('Run paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(gps.fixes.hasListener, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(gps.fixes.hasListener, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Run paused'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
