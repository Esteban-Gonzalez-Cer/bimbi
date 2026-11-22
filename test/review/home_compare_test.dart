// Side-by-side review render of Home with the artboard's sample content.
// Not part of the suite: run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/app/design_system/components/alarm_parts.dart';
import 'package:bimbi/features/alarm/application/alarm_draft.dart';
import 'package:bimbi/ui/home/view_models/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

void main() {
  testWidgets('home 390x844 like the artboard', (tester) async {
    const gym = AlarmDraft(
      time: TimeOfDay(hour: 7, minute: 0),
      label: 'Gym day',
      days: {0, 1, 2, 3, 4},
      mission: WakeMission.shake,
    );
    const lazy = AlarmDraft(
      time: TimeOfDay(hour: 9, minute: 30),
      label: 'Lazy Sunday',
      days: {6},
    );
    await pumpBimbi(
      tester,
      width: 390,
      height: 844,
      now: DateTime(2026, 11, 23, 22, 30),
      overrides: [
        homeViewModelProvider.overrideWithValue(
          HomeState(
            greeting: 'Good evening',
            name: 'Sofía',
            night: true,
            nextAlarmIn: Duration(hours: 8, minutes: 30),
            nextAlarmAt: DateTime(2026, 11, 24, 7),
            averageSleep: Duration(hours: 7, minutes: 12),
            loading: false,
            alarms: const [
              HomeAlarm(
                time: TimeOfDay(hour: 7, minute: 0),
                label: 'Gym day',
                days: {0, 1, 2, 3, 4},
                enabled: true,
                mission: WakeMission.shake,
                draft: gym,
              ),
              HomeAlarm(
                time: TimeOfDay(hour: 9, minute: 30),
                label: 'Lazy Sunday',
                days: {6},
                enabled: false,
                mission: WakeMission.none,
                draft: lazy,
              ),
            ],
          ),
        ),
      ],
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/home_390.png'),
    );
  });
}
