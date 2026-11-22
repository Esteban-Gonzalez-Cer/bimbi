import 'package:bimbi/features/sleep/application/sleep_diary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 11, 21);

  test('bedtime after wake time belongs to the previous evening', () {
    final e = entryFromTimes(
      wakeDay: day,
      bedHour: 23,
      bedMinute: 5,
      wakeHour: 6,
      wakeMinute: 17,
    );
    expect(e.bedtime, DateTime(2026, 11, 20, 23, 5));
    expect(e.timeInBed, const Duration(hours: 7, minutes: 12));
    expect(e.day, day);
  });

  test('after-midnight bedtime stays on the wake day', () {
    final e = entryFromTimes(
      wakeDay: day,
      bedHour: 1,
      bedMinute: 0,
      wakeHour: 8,
      wakeMinute: 0,
    );
    expect(e.timeInBed, const Duration(hours: 7));
  });

  test('one entry per day, newest first', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final diary = c.read(sleepDiaryProvider.notifier);
    SleepEntry at(int d, int wakeHour) => entryFromTimes(
      wakeDay: DateTime(2026, 11, d),
      bedHour: 23,
      bedMinute: 0,
      wakeHour: wakeHour,
      wakeMinute: 0,
    );
    diary.save(at(20, 7));
    diary.save(at(21, 7));
    diary.save(at(21, 8));
    final entries = c.read(sleepDiaryProvider);
    expect(entries, hasLength(2));
    expect(entries.first.day, DateTime(2026, 11, 21));
    expect(entries.first.timeInBed, const Duration(hours: 9));
  });
}
