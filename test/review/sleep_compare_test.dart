// Side-by-side review render of the Sleep report with artboard-like content.
// Not part of the suite: run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/domain/models/sleep_entry.dart';
import 'package:bimbi/ui/sleep/view_models/sleep_diary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

SleepEntry _night(int wakeDay, int bh, int bm, int wh, int wm) =>
    entryFromTimes(
      wakeDay: DateTime(2026, 11, wakeDay),
      bedHour: bh,
      bedMinute: bm,
      wakeHour: wh,
      wakeMinute: wm,
    );

Future<void> _render(
  WidgetTester tester,
  Brightness brightness,
  String name, {
  double width = 390,
  double height = 844,
  DateTime? now,
}) async {
  final entries = [
    _night(24, 23, 28, 7, 8), // Tue, 7 h 40 m
    _night(23, 23, 0, 7, 24),
    _night(22, 0, 10, 7, 30),
    _night(21, 23, 50, 6, 50),
    _night(20, 23, 40, 6, 10),
    _night(19, 23, 15, 7, 45),
    _night(18, 23, 30, 6, 30),
  ];
  await pumpBimbi(
    tester,
    width: width,
    height: height,
    brightness: brightness,
    now: now ?? DateTime(2026, 11, 24, 8, 15),
    overrides: [
      sleepDiaryProvider.overrideWithValue(entries),
      lastWakeProvider.overrideWithValue(
        LastWake(
          scheduledAt: DateTime(2026, 11, 24, 7),
          completedAt: DateTime(2026, 11, 24, 7, 8),
          snoozes: 0,
        ),
      ),
      phoneUseInBedProvider.overrideWithValue(const AsyncData(6)),
    ],
  );
  await tester.tap(find.text('Sleep').last);
  await settleSnapshotImages(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  testWidgets(
    'sleep 390x844 day',
    (t) => _render(t, Brightness.light, 'sleep_390'),
  );
  testWidgets(
    'sleep 390x844 night',
    (t) => _render(
      t,
      Brightness.light,
      'sleep_390_night',
      now: DateTime(2026, 11, 24, 21),
    ),
  );
  testWidgets(
    'sleep tablet landscape',
    (t) => _render(t, Brightness.light, 'sleep_1006', width: 1006, height: 552),
  );
}
