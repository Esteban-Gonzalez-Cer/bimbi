// Review renders of the Focus screen. Not part of the suite:
// run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/domain/models/focus_record.dart';
import 'package:bimbi/domain/models/focus_shield.dart';
import 'package:bimbi/ui/focus/view_models/focus_session.dart';
import 'package:bimbi/ui/focus/view_models/focus_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

class _Fixed extends FocusController {
  _Fixed(this.session);
  final FocusSession session;
  @override
  FocusSession build() => session;
}

final _now = DateTime(2026, 11, 24, 10, 12);

final _records = [
  FocusRecord(
    id: '1',
    startedAt: DateTime(2026, 11, 24, 8, 30),
    duration: const Duration(minutes: 45),
    outcome: FocusOutcome.completed,
    taskLabel: 'Physics problem set',
  ),
  FocusRecord(
    id: '2',
    startedAt: DateTime(2026, 11, 24, 7, 40),
    duration: const Duration(minutes: 18),
    outcome: FocusOutcome.ended,
  ),
  FocusRecord(
    id: '3',
    startedAt: DateTime(2026, 11, 23, 16, 5),
    duration: const Duration(minutes: 25),
    outcome: FocusOutcome.completed,
    taskLabel: 'Read chapter 4',
  ),
];

Future<void> _render(
  WidgetTester tester,
  String name,
  FocusSession session, {
  double width = 390,
  double height = 844,
  Brightness brightness = Brightness.light,
}) async {
  await pumpBimbi(
    tester,
    width: width,
    height: height,
    brightness: brightness,
    now: _now,
    overrides: [
      focusProvider.overrideWith(() => _Fixed(session)),
      focusRecordsProvider.overrideWithValue(_records),
      focusTodayProvider.overrideWithValue(const Duration(minutes: 63)),
      shieldStatusProvider.overrideWithValue(
        const AsyncData(
          ShieldStatus(
            usageAccess: true,
            overlay: true,
            focusApps: {'a', 'b', 'c'},
            limits: {'a': 30},
          ),
        ),
      ),
    ],
  );
  await tester.tap(find.text('Focus').last);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  const idle = FocusSession(target: Duration(minutes: 45));
  final running = FocusSession(
    target: const Duration(minutes: 45),
    phase: FocusPhase.running,
    startedAt: _now.subtract(const Duration(minutes: 17)),
    firstStartedAt: _now.subtract(const Duration(minutes: 17)),
    taskLabel: 'Chemistry lab report',
  );
  testWidgets('focus idle', (t) => _render(t, 'focus_390', idle));
  testWidgets(
    'focus two turns',
    (t) => _render(
      t,
      'focus_390_turns',
      const FocusSession(target: Duration(minutes: 150)),
    ),
  );
  testWidgets(
    'focus windows idle',
    (t) => _render(
      t,
      'focus_390_windows',
      const FocusSession(target: Duration(minutes: 60), windows: [10, 20, 30]),
    ),
  );
  testWidgets(
    'focus windows running',
    (t) => _render(
      t,
      'focus_390_windows_running',
      FocusSession(
        target: const Duration(minutes: 60),
        windows: const [10, 20, 30],
        phase: FocusPhase.running,
        startedAt: _now.subtract(const Duration(minutes: 14)),
        firstStartedAt: _now.subtract(const Duration(minutes: 14)),
        taskLabel: 'Essay outline',
      ),
    ),
  );
  testWidgets('focus running', (t) => _render(t, 'focus_390_running', running));
  testWidgets(
    'focus running dark',
    (t) => _render(t, 'focus_390_dark', running, brightness: Brightness.dark),
  );
  testWidgets(
    'focus tablet landscape',
    (t) => _render(t, 'focus_1006', running, width: 1006, height: 552),
  );
}
