import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/core/clock.dart';
import 'package:bimbi/core/platform.dart';
import 'package:bimbi/data/services/focus_guard_service.dart';
import 'package:bimbi/domain/models/sleep_entry.dart';
import 'package:bimbi/ui/sleep/view_models/sleep_diary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_focus_guard.dart';

void main() {
  final day = DateTime(2026, 11, 21);
  var now = DateTime(2026, 11, 22, 8);
  late SharedPreferences prefs;

  ProviderContainer process({Map<String, dynamic>? capabilities}) {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        preferencesProvider.overrideWithValue(prefs),
        if (capabilities != null)
          capabilitiesProvider.overrideWithValue(AsyncData(capabilities)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    now = DateTime(2026, 11, 22, 8);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  SleepEntry at(int d, int wakeHour, {int bedHour = 23}) => entryFromTimes(
    wakeDay: DateTime(2026, 11, d),
    bedHour: bedHour,
    bedMinute: 0,
    wakeHour: wakeHour,
    wakeMinute: 0,
  );

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
    expect(e.dateKey, '2026-11-21');
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

  test('one entry per day, newest first, and it survives a restart', () {
    final c = process();
    c.read(sleepRowsProvider.notifier)
      ..save(at(20, 7))
      ..save(at(21, 7))
      ..save(at(21, 8));
    final entries = process().read(sleepDiaryProvider);
    expect(entries, hasLength(2));
    expect(entries.first.day, DateTime(2026, 11, 21));
    expect(entries.first.timeInBed, const Duration(hours: 9));
    expect(process().read(sleepRowsProvider).pending, {
      '2026-11-20',
      '2026-11-21',
    });
  });

  test('notes are trimmed and bounded; impossible nights are rejected', () {
    final e = entryFromTimes(
      wakeDay: day,
      bedHour: 22,
      bedMinute: 0,
      wakeHour: 6,
      wakeMinute: 0,
      note: '  ${'z' * 400}  ',
    );
    expect(e.note, hasLength(SleepEntry.maxNote));
    final c = process();
    c
        .read(sleepRowsProvider.notifier)
        .save(
          SleepEntry(
            bedtime: DateTime(2026, 11, 20, 8),
            wake: DateTime(2026, 11, 21, 8),
          ),
        );
    expect(c.read(sleepDiaryProvider), isEmpty);
  });

  test('the week covers seven days and averages logged nights only', () {
    final c = process();
    c.read(sleepRowsProvider.notifier)
      ..save(at(22, 7)) // 8 h
      ..save(at(20, 6)) // 7 h
      ..save(at(10, 7)); // outside the week
    final week = c.read(sleepWeekProvider);
    expect(week.days.first, DateTime(2026, 11, 16));
    expect(week.days.last, DateTime(2026, 11, 22));
    expect(week.entries, hasLength(2));
    expect(week.average, const Duration(hours: 7, minutes: 30));
  });

  test('only a wake finished today prefills the diary', () {
    final today = {
      'lastWake': {
        'scheduledAt': DateTime(2026, 11, 22, 7).millisecondsSinceEpoch,
        'completedAt': DateTime(2026, 11, 22, 7, 12).millisecondsSinceEpoch,
        'snoozes': 2,
      },
    };
    final wake = process(capabilities: today).read(lastWakeProvider);
    expect(wake?.snoozes, 2);
    expect(wake?.completedAt, DateTime(2026, 11, 22, 7, 12));
    now = DateTime(2026, 11, 23, 8);
    expect(process(capabilities: today).read(lastWakeProvider), isNull);
  });

  test('phone use in bed needs Usage Access and an entry', () async {
    final guard = FakeFocusGuard(phoneUse: 14);
    ProviderContainer withGuard() {
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          preferencesProvider.overrideWithValue(prefs),
          focusGuardProvider.overrideWithValue(guard),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    var c = withGuard();
    expect(await c.read(phoneUseInBedProvider.future), isNull);
    c.read(sleepRowsProvider.notifier).save(at(22, 7));
    expect(await c.read(phoneUseInBedProvider.future), isNull);
    guard.usageAccess = true;
    c = withGuard();
    expect(await c.read(phoneUseInBedProvider.future), 14);
  });
}
