import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One self-reported night. Time in bed only; never a sleep-stage or
/// diagnostic measurement.
@immutable
class SleepEntry {
  const SleepEntry({required this.bedtime, required this.wake});
  final DateTime bedtime;
  final DateTime wake;

  Duration get timeInBed => wake.difference(bedtime);

  /// The calendar day the person woke up; one entry per day.
  DateTime get day => DateTime(wake.year, wake.month, wake.day);
}

/// Builds an entry from clock times, placing bedtime on the previous evening
/// when it is later than the wake time.
SleepEntry entryFromTimes({
  required DateTime wakeDay,
  required int bedHour,
  required int bedMinute,
  required int wakeHour,
  required int wakeMinute,
}) {
  final wake = DateTime(
    wakeDay.year,
    wakeDay.month,
    wakeDay.day,
    wakeHour,
    wakeMinute,
  );
  var bed = DateTime(
    wakeDay.year,
    wakeDay.month,
    wakeDay.day,
    bedHour,
    bedMinute,
  );
  if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
  return SleepEntry(bedtime: bed, wake: wake);
}

/// In-memory diary for Phase 2 screens. Phase 5 adds local persistence and
/// RTDB sync behind this same interface.
class SleepDiaryController extends Notifier<List<SleepEntry>> {
  @override
  List<SleepEntry> build() => const [];

  void save(SleepEntry entry) {
    state = [
      for (final e in state)
        if (e.day != entry.day) e,
      entry,
    ]..sort((a, b) => b.day.compareTo(a.day));
  }

  void remove(SleepEntry entry) => state = [
    for (final e in state)
      if (e.day != entry.day) e,
  ];
}

final sleepDiaryProvider =
    NotifierProvider<SleepDiaryController, List<SleepEntry>>(
      SleepDiaryController.new,
    );
