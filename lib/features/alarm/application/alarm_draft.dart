import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/components/alarm_parts.dart';
import '../../../core/platform.dart';

enum WakeDifficulty {
  easy('Easy'),
  normal('Normal'),
  difficult('Difficult'),
  extreme('Extreme');

  const WakeDifficulty(this.label);
  final String label;
}

@immutable
class AlarmDraft {
  const AlarmDraft({
    this.id,
    this.time = const TimeOfDay(hour: 7, minute: 0),
    this.label = 'Wake up',
    this.days = const {},
    this.mission = WakeMission.none,
    this.difficulty = WakeDifficulty.normal,
  });

  final String? id;
  final TimeOfDay time;
  final String label;

  /// 0 = Monday … 6 = Sunday. Empty = once.
  final Set<int> days;
  final WakeMission mission;
  final WakeDifficulty difficulty;

  AlarmDraft copyWith({
    TimeOfDay? time,
    String? label,
    Set<int>? days,
    WakeMission? mission,
    WakeDifficulty? difficulty,
  }) => AlarmDraft(
    id: id,
    time: time ?? this.time,
    label: label ?? this.label,
    days: days ?? this.days,
    mission: mission ?? this.mission,
    difficulty: difficulty ?? this.difficulty,
  );

  Map<String, Object> toNative() => {
    'id': ?id,
    'hour': time.hour,
    'minute': time.minute,
    'label': label.trim(),
    'days': days.toList()..sort(),
    'challenge': mission.name,
    'difficulty': difficulty.name,
  };
}

enum AlarmScheduleStatus {
  off,
  armed,
  exact,
  notifications,
  error,
  finished,
  missed,
  ringing,
  snoozed;

  static AlarmScheduleStatus parse(Object? value) =>
      values.where((status) => status.name == value).firstOrNull ?? error;

  String? get message => switch (this) {
    off || armed => null,
    exact => 'Allow exact alarms',
    notifications => 'Allow alarm notifications',
    error => 'Android could not schedule this alarm',
    finished => 'Completed',
    missed => 'Missed while unavailable',
    ringing => 'Wake-up challenge active',
    snoozed => 'Snoozed',
  };

  String? get setting => switch (this) {
    exact => 'exact',
    notifications => 'notification',
    _ => null,
  };
}

@immutable
class NativeAlarm {
  const NativeAlarm({
    required this.draft,
    required this.enabled,
    required this.status,
    required this.next,
  });

  final AlarmDraft draft;
  final bool enabled;
  final AlarmScheduleStatus status;
  final DateTime? next;

  static NativeAlarm? fromNative(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['hour'] is! int ||
        value['minute'] is! int) {
      return null;
    }
    final next = value['nextAt'];
    return NativeAlarm(
      draft: AlarmDraft(
        id: value['id'] as String,
        time: TimeOfDay(
          hour: value['hour'] as int,
          minute: value['minute'] as int,
        ),
        label: value['label'] as String? ?? 'Wake up',
        days: (value['days'] as List? ?? const []).whereType<int>().toSet(),
        mission:
            WakeMission.values
                .where((mission) => mission.name == value['challenge'])
                .firstOrNull ??
            WakeMission.math,
        difficulty:
            WakeDifficulty.values
                .where((difficulty) => difficulty.name == value['difficulty'])
                .firstOrNull ??
            WakeDifficulty.normal,
      ),
      enabled: value['enabled'] == true,
      status: AlarmScheduleStatus.parse(value['status']),
      next: next is int ? DateTime.fromMillisecondsSinceEpoch(next) : null,
    );
  }
}

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

/// Persists definitions through Android and refreshes the observed catalogue.
class AlarmActions {
  const AlarmActions(this._platform, this._refresh);
  final PlatformAdapter _platform;
  final VoidCallback _refresh;

  Future<String> save(AlarmDraft draft) async {
    if (draft.mission == WakeMission.none) {
      throw const CapabilityFailure(
        'challenge_required',
        'Choose a wake-up challenge.',
      );
    }
    return _report(await _platform.saveAlarm(draft.toNative()));
  }

  Future<String> enable(String id, bool enabled) async =>
      _report(await _platform.enableAlarm(id, enabled));

  Future<String> delete(String id) async {
    await _platform.deleteAlarm(id);
    _refresh();
    return 'Alarm deleted.';
  }

  String _report(Map<String, Object?> result) {
    _refresh();
    return switch (AlarmScheduleStatus.parse(result['status'])) {
      AlarmScheduleStatus.armed => 'Alarm scheduled.',
      AlarmScheduleStatus.off => 'Alarm saved and turned off.',
      AlarmScheduleStatus.exact =>
        'Alarm saved. Allow exact alarms to schedule it.',
      AlarmScheduleStatus.notifications =>
        'Alarm saved. Allow notifications to schedule it.',
      AlarmScheduleStatus.missed => 'This occurrence has already passed.',
      AlarmScheduleStatus.finished ||
      AlarmScheduleStatus.ringing ||
      AlarmScheduleStatus.snoozed => 'Alarm saved.',
      AlarmScheduleStatus.error =>
        'Alarm saved. Android could not schedule it.',
    };
  }
}

final alarmActionsProvider = Provider<AlarmActions>(
  (ref) => AlarmActions(
    ref.watch(platformProvider),
    () => ref.invalidate(capabilitiesProvider),
  ),
);
