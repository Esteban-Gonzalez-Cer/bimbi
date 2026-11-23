@Tags(['tz'])
library;

import 'package:bimbi/domain/models/sleep_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run with `TZ=America/New_York flutter test --tags tz` (scripts/check.sh).
/// On 1 Nov 2026 clocks fall back from 02:00 to 01:00 in New York.
void main() {
  final inNewYork =
      DateTime(2026, 11, 1, 12).timeZoneOffset !=
      DateTime(2026, 10, 31, 12).timeZoneOffset;

  test('a fall-back night reports one extra hour in bed', () {
    final e = entryFromTimes(
      wakeDay: DateTime(2026, 11, 1),
      bedHour: 23,
      bedMinute: 0,
      wakeHour: 7,
      wakeMinute: 0,
    );
    expect(e.bedtime.day, 31);
    expect(e.bedtime.hour, 23);
    expect(e.timeInBed, const Duration(hours: 9));
    final restored = SleepEntry.fromRow(e.toRow())!;
    expect(restored.timeInBed, const Duration(hours: 9));
    expect(restored.dateKey, '2026-11-01');
  }, skip: inNewYork ? false : 'needs TZ=America/New_York');

  test('a spring-forward night reports one hour less', () {
    final e = entryFromTimes(
      wakeDay: DateTime(2026, 3, 8),
      bedHour: 23,
      bedMinute: 0,
      wakeHour: 7,
      wakeMinute: 0,
    );
    expect(e.timeInBed, const Duration(hours: 7));
  }, skip: inNewYork ? false : 'needs TZ=America/New_York');
}
