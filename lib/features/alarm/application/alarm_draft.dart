import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/components/alarm_parts.dart';
import '../../../core/clock.dart';
import '../../../core/platform.dart';

const bimbiAlarmId = 'bimbi-alarm';
const dailyAlarmDays = {0, 1, 2, 3, 4, 5, 6};

/// Editable alarm. Phase 2 schedules one native alarm from it; full
/// multi-alarm persistence and weekday recurrence arrive in Phase 4.
@immutable
class AlarmDraft {
  const AlarmDraft({
    this.time = const TimeOfDay(hour: 7, minute: 0),
    this.label = 'Wake up',
    this.days = const {},
    this.mission = WakeMission.none,
  });

  final TimeOfDay time;
  final String label;

  /// 0 = Monday … 6 = Sunday. Empty = once.
  final Set<int> days;
  final WakeMission mission;

  AlarmDraft copyWith({
    TimeOfDay? time,
    String? label,
    Set<int>? days,
    WakeMission? mission,
  }) => AlarmDraft(
    time: time ?? this.time,
    label: label ?? this.label,
    days: days ?? this.days,
    mission: mission ?? this.mission,
  );

  /// Every day maps to a native 24 h interval; other patterns schedule only
  /// the next matching occurrence until Phase 4 recurrence lands.
  Duration get nativeRepeat =>
      days.length == 7 ? const Duration(days: 1) : Duration.zero;

  /// Next local occurrence strictly after [now] on an allowed weekday.
  DateTime nextOccurrence(DateTime now) {
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      final weekdayOk = days.isEmpty || days.contains(candidate.weekday - 1);
      if (weekdayOk && candidate.isAfter(now)) return candidate;
    }
    throw StateError('No occurrence within a week');
  }
}

/// Wake missions the native alarm can enforce today. Shake and Math are
/// designed but only become selectable when Phase 4 implements them, so the
/// UI never promises a mission the alarm will not require.
const kAvailableMissions = {WakeMission.none};

/// The draft currently open in the editor; null when closed.
class AlarmEditorController extends Notifier<AlarmDraft?> {
  @override
  AlarmDraft? build() => null;
  void open([AlarmDraft draft = const AlarmDraft()]) => state = draft;
  void update(AlarmDraft draft) => state = draft;
  void close() => state = null;
}

final alarmEditorProvider =
    NotifierProvider<AlarmEditorController, AlarmDraft?>(
      AlarmEditorController.new,
    );

/// Display details (label, days, mission) of the alarm saved this session.
/// The native pending occurrence remains the source of truth for timing.
class SavedAlarmController extends Notifier<AlarmDraft?> {
  @override
  AlarmDraft? build() => null;

  Future<DateTime> schedule(AlarmDraft draft) async {
    final at = draft.nextOccurrence(ref.read(clockProvider)());
    await ref
        .read(platformProvider)
        .schedule(id: bimbiAlarmId, at: at, repeat: draft.nativeRepeat);
    state = draft;
    ref.invalidate(capabilitiesProvider);
    return at;
  }

  Future<void> cancel() async {
    await ref.read(platformProvider).cancel();
    state = null;
    ref.invalidate(capabilitiesProvider);
  }
}

final savedAlarmProvider = NotifierProvider<SavedAlarmController, AlarmDraft?>(
  SavedAlarmController.new,
);
