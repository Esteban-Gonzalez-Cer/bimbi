// Review renders of the Running screen. Not part of the suite:
// run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/features/running/application/run_controller.dart';
import 'package:bimbi/features/running/data/run_store.dart';
import 'package:bimbi/features/running/domain/run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

class _Fixed extends RunController {
  _Fixed(this.fixed, {this.meters = 0});
  final RunningState fixed;
  final double meters;
  @override
  RunningState build() => fixed;
  @override
  double get distanceMeters => meters;
  @override
  List<List<RunPoint>> get visibleSegments => const [];
}

final _runs = [
  SavedRun(
    id: 'a',
    summary: RunSummary('a', DateTime(2026, 11, 23, 7, 5), 4210, 1688),
  ),
  SavedRun(
    id: 'b',
    summary: RunSummary('b', DateTime(2026, 11, 21, 18, 40), 2850, 1214),
  ),
];

Future<void> _render(
  WidgetTester tester,
  String name,
  RunningState state, {
  double meters = 0,
  double width = 390,
  double height = 844,
}) async {
  await pumpBimbi(
    tester,
    width: width,
    height: height,
    now: DateTime(2026, 11, 24, 7, 30),
    overrides: [
      runControllerProvider.overrideWith(() => _Fixed(state, meters: meters)),
    ],
  );
  await tester.tap(find.text('Running').last);
  await tester.pumpAndSettle();
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
  testWidgets(
    'running idle',
    (t) => _render(t, 'running_390', RunningState(loading: false, runs: _runs)),
  );
  testWidgets(
    'running recording',
    (t) => _render(
      t,
      'running_390_recording',
      RunningState(
        loading: false,
        phase: RunPhase.recording,
        active: const Duration(minutes: 12, seconds: 41),
        accuracy: 6,
        runs: _runs,
      ),
      meters: 1730,
    ),
  );
  testWidgets(
    'running review',
    (t) => _render(
      t,
      'running_390_review',
      RunningState(
        loading: false,
        phase: RunPhase.review,
        active: const Duration(minutes: 21, seconds: 3),
        runs: _runs,
      ),
      meters: 3120,
    ),
  );
  testWidgets(
    'running tablet landscape',
    (t) => _render(
      t,
      'running_1006',
      RunningState(
        loading: false,
        phase: RunPhase.recording,
        active: const Duration(minutes: 12, seconds: 41),
        accuracy: 6,
        runs: _runs,
      ),
      meters: 1730,
      width: 1006,
      height: 552,
    ),
  );
}
