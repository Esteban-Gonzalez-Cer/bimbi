import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/platform.dart';
import '../../../data/repositories/collection_sync.dart';
import '../../../data/services/focus_guard_service.dart';
import '../../../data/repositories/local_collection.dart';
import '../../../domain/models/sleep_entry.dart';

/// Diary rows saved on the device and synced for verified accounts.
class SleepRows extends CollectionController {
  @override
  String get storageKey => 'bimbi.sleep.diary';

  /// One entry per wake day; saving the same day replaces it.
  void save(SleepEntry entry) {
    if (!entry.isValid) return;
    put(entry.dateKey, entry.toRow());
  }

  void delete(SleepEntry entry) => remove(entry.dateKey);
}

final sleepRowsProvider = NotifierProvider<SleepRows, CollectionState>(
  SleepRows.new,
);

/// Diary entries, newest wake day first.
final sleepDiaryProvider = Provider<List<SleepEntry>>((ref) {
  final rows = ref.watch(sleepRowsProvider).visible;
  return [for (final row in rows.values) ?SleepEntry.fromRow(row)]
    ..sort((a, b) => b.day.compareTo(a.day));
});

/// The seven days ending today, oldest first, with each day's time in bed.
@immutable
class SleepWeek {
  const SleepWeek(this.days, this.entries);
  final List<DateTime> days;
  final Map<DateTime, SleepEntry> entries;

  Duration? get average {
    if (entries.isEmpty) return null;
    final total = entries.values.fold<int>(
      0,
      (sum, e) => sum + e.timeInBed.inMinutes,
    );
    return Duration(minutes: total ~/ entries.length);
  }
}

final sleepWeekProvider = Provider<SleepWeek>((ref) {
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final days = [
    for (var i = 6; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
  final byDay = {for (final e in ref.watch(sleepDiaryProvider)) e.day: e};
  return SleepWeek(days, {
    for (final d in days)
      if (byDay[d] != null) d: byDay[d]!,
  });
});

/// The most recent alarm challenge finished on this device.
@immutable
class LastWake {
  const LastWake({
    required this.scheduledAt,
    required this.completedAt,
    required this.snoozes,
  });
  final DateTime scheduledAt;
  final DateTime completedAt;
  final int snoozes;

  static LastWake? fromNative(Object? value) {
    if (value is! Map) return null;
    final scheduled = value['scheduledAt'];
    final completed = value['completedAt'];
    final snoozes = value['snoozes'];
    if (scheduled is! num || completed is! num) return null;
    return LastWake(
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(scheduled.toInt()),
      completedAt: DateTime.fromMillisecondsSinceEpoch(completed.toInt()),
      snoozes: snoozes is num ? snoozes.toInt() : 0,
    );
  }
}

/// Today's finished alarm, used to prefill the diary's wake time. Older
/// wakes are ignored so an old alarm never suggests a wrong morning.
final lastWakeProvider = Provider<LastWake?>((ref) {
  final wake = LastWake.fromNative(
    ref.watch(capabilitiesProvider).value?['lastWake'],
  );
  if (wake == null) return null;
  final now = ref.watch(clockProvider)();
  final sameDay =
      wake.completedAt.year == now.year &&
      wake.completedAt.month == now.month &&
      wake.completedAt.day == now.day;
  return sameDay ? wake : null;
});

class SleepSync extends CollectionSync {
  @override
  String get name => 'sleep';
  @override
  NotifierProvider<CollectionController, CollectionState> get rows =>
      sleepRowsProvider;
}

/// Sync state of the diary for the verified account.
final sleepSyncProvider = NotifierProvider<SleepSync, SyncStatus>(
  SleepSync.new,
);

/// Minutes spent in other apps between bedtime and wake for the latest
/// night, from Usage Access. Computed on the device and never synced; null
/// without access or without an entry.
final phoneUseInBedProvider = FutureProvider<int?>((ref) async {
  final entries = ref.watch(sleepDiaryProvider);
  if (entries.isEmpty) return null;
  final latest = entries.first;
  try {
    return await ref
        .watch(focusGuardProvider)
        .phoneUseBetween(latest.bedtime, latest.wake);
  } on Object {
    return null;
  }
});
