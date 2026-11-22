import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/components/alarm_parts.dart';
import '../../../core/clock.dart';
import '../../../core/platform.dart';
import '../../../features/alarm/application/alarm_draft.dart';
import '../../../features/sleep/application/sleep_diary.dart';
import '../../../features/profile/application/cloud_profile.dart';

/// One alarm row on Home.
@immutable
class HomeAlarm {
  const HomeAlarm({
    required this.time,
    required this.label,
    required this.days,
    required this.enabled,
    required this.mission,
    required this.draft,
    this.status = AlarmScheduleStatus.armed,
  });
  final TimeOfDay time;
  final String label;
  final Set<int> days;
  final bool enabled;
  final WakeMission mission;
  final AlarmDraft draft;
  final AlarmScheduleStatus status;
}

/// Everything the Home screen shows, derived in one place so the widgets
/// stay declarative (Flutter architecture guide: view + view model).
@immutable
class HomeState {
  const HomeState({
    required this.greeting,
    required this.name,
    required this.night,
    required this.nextAlarmIn,
    required this.nextAlarmAt,
    required this.averageSleep,
    required this.alarms,
    required this.loading,
    this.active = false,
  });

  /// "Good morning" / "Good afternoon" / "Good evening".
  final String greeting;
  final String name;

  /// Night surfaces from 19:00 to 05:00.
  final bool night;
  final Duration? nextAlarmIn;
  final DateTime? nextAlarmAt;
  final Duration? averageSleep;
  final List<HomeAlarm> alarms;
  final bool loading;
  final bool active;
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 19) return 'Good afternoon';
  return 'Good evening';
}

final homeViewModelProvider = Provider<HomeState>((ref) {
  final now = ref.watch(clockProvider)();
  final caps = ref.watch(capabilitiesProvider);
  final snapshot = caps.value;
  final nativeAlarms = (snapshot?['alarms'] as List? ?? const [])
      .map(NativeAlarm.fromNative)
      .whereType<NativeAlarm>();
  final snooze = snapshot?['snoozedUntil'];
  final next = <DateTime>[
    for (final alarm in nativeAlarms) ?alarm.next,
    if (snooze is int) DateTime.fromMillisecondsSinceEpoch(snooze),
  ]..sort();
  final nextAt = next.firstOrNull;
  final diary = ref.watch(sleepDiaryProvider);

  final week = diary.where(
    (e) => now.difference(e.wake) < const Duration(days: 7),
  );
  final average = week.isEmpty
      ? null
      : Duration(
          minutes:
              week.fold<int>(0, (s, e) => s + e.timeInBed.inMinutes) ~/
              week.length,
        );

  final alarms = <HomeAlarm>[
    for (final alarm in nativeAlarms)
      HomeAlarm(
        time: alarm.draft.time,
        label: alarm.draft.label,
        days: alarm.draft.days,
        enabled: alarm.enabled,
        mission: alarm.draft.mission,
        draft: alarm.draft,
        status: alarm.status,
      ),
  ];

  return HomeState(
    greeting: greetingFor(now),
    name: ref.watch(visibleProfileNameProvider),
    night: now.hour >= 19 || now.hour < 5,
    nextAlarmIn: nextAt?.difference(now),
    nextAlarmAt: nextAt,
    averageSleep: average,
    alarms: alarms,
    loading: caps.isLoading && snapshot == null,
    active: snapshot?['active'] == true,
  );
});

/// "8 h 30 min", "45 min".
String formatUntil(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
