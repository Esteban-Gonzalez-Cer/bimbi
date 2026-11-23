import 'package:flutter/foundation.dart';

/// One self-reported night. Time in bed only; never a sleep-stage or
/// diagnostic measurement. Times are absolute instants, so a night that
/// crosses a daylight-saving change reports the real duration.
@immutable
class SleepEntry {
  const SleepEntry({required this.bedtime, required this.wake, this.note});

  static const maxNote = 280;
  static const maxTimeInBed = Duration(hours: 16);

  final DateTime bedtime;
  final DateTime wake;
  final String? note;

  Duration get timeInBed => wake.difference(bedtime);

  /// The calendar day the person woke up; one entry per day.
  DateTime get day => DateTime(wake.year, wake.month, wake.day);

  /// `yyyy-MM-dd` of the local wake day (spec `users/{uid}/sleep/{dateKey}`).
  String get dateKey => dateKeyOf(day);

  bool get isValid => wake.isAfter(bedtime) && timeInBed <= maxTimeInBed;

  Map<String, Object?> toRow() => {
    'bedtime': bedtime.millisecondsSinceEpoch,
    'wakeTime': wake.millisecondsSinceEpoch,
    'utcOffsetMin': wake.timeZoneOffset.inMinutes,
    'source': 'diary',
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  static SleepEntry? fromRow(Map<String, Object?> row) {
    final bed = row['bedtime'];
    final wake = row['wakeTime'];
    if (bed is! num || wake is! num) return null;
    final note = row['note'];
    final entry = SleepEntry(
      bedtime: DateTime.fromMillisecondsSinceEpoch(bed.toInt()),
      wake: DateTime.fromMillisecondsSinceEpoch(wake.toInt()),
      note: note is String ? note : null,
    );
    return entry.isValid ? entry : null;
  }
}

String dateKeyOf(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Builds an entry from clock times, placing bedtime on the previous evening
/// when it is later than the wake time.
SleepEntry entryFromTimes({
  required DateTime wakeDay,
  required int bedHour,
  required int bedMinute,
  required int wakeHour,
  required int wakeMinute,
  String? note,
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
  if (!bed.isBefore(wake)) {
    // Calendar arithmetic, not 24 h, so a DST night keeps its clock time.
    bed = DateTime(
      wakeDay.year,
      wakeDay.month,
      wakeDay.day - 1,
      bedHour,
      bedMinute,
    );
  }
  final trimmed = note?.trim();
  return SleepEntry(
    bedtime: bed,
    wake: wake,
    note: trimmed == null || trimmed.isEmpty
        ? null
        : trimmed.length > SleepEntry.maxNote
        ? trimmed.substring(0, SleepEntry.maxNote)
        : trimmed,
  );
}
