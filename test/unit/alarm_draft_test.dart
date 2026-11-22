import 'package:bimbi/features/alarm/application/alarm_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Saturday 21 November 2026, 08:30.
  final now = DateTime(2026, 11, 21, 8, 30);

  test('once: later today, otherwise tomorrow', () {
    expect(
      const AlarmDraft(time: TimeOfDay(hour: 9, minute: 0)).nextOccurrence(now),
      DateTime(2026, 11, 21, 9),
    );
    expect(
      const AlarmDraft(time: TimeOfDay(hour: 7, minute: 0)).nextOccurrence(now),
      DateTime(2026, 11, 22, 7),
    );
    expect(
      const AlarmDraft(time: TimeOfDay(hour: 8, minute: 30))
          .nextOccurrence(now),
      DateTime(2026, 11, 22, 8, 30),
    );
  });

  test('weekdays skip to the next allowed day', () {
    const weekdays = AlarmDraft(
      time: TimeOfDay(hour: 7, minute: 0),
      days: {0, 1, 2, 3, 4},
    );
    expect(weekdays.nextOccurrence(now), DateTime(2026, 11, 23, 7));
    expect(weekdays.nativeRepeat, Duration.zero);
  });

  test('every day maps to a native 24 h interval', () {
    const daily = AlarmDraft(days: {0, 1, 2, 3, 4, 5, 6});
    expect(daily.nativeRepeat, const Duration(days: 1));
  });

  test('only implemented wake missions are selectable', () {
    expect(kAvailableMissions, hasLength(1));
  });
}
