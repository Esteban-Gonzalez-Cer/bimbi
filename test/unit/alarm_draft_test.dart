import 'package:bimbi/app/design_system/components/alarm_parts.dart';
import 'package:bimbi/features/alarm/application/alarm_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new alarms require an explicit challenge and start at normal', () {
    const draft = AlarmDraft();
    expect(draft.id, isNull);
    expect(draft.mission, WakeMission.none);
    expect(draft.difficulty, WakeDifficulty.normal);
    expect(draft.copyWith(mission: WakeMission.pattern).toNative(), {
      'hour': 7,
      'minute': 0,
      'label': 'Wake up',
      'days': <int>[],
      'challenge': 'pattern',
      'difficulty': 'normal',
    });
  });

  test('editing keeps the native id and writes stable weekday and difficulty values', () {
    final alarm = NativeAlarm.fromNative({
      'id': 'second-alarm',
      'enabled': true,
      'hour': 7,
      'minute': 20,
      'label': 'Morning',
      'days': [4, 0],
      'challenge': 'ballMonte',
      'difficulty': 'extreme',
      'status': 'notifications',
    })!;
    expect(alarm.enabled, isTrue);
    expect(alarm.status.setting, 'notification');
    expect(alarm.next, isNull);
    expect(
      alarm.draft
          .copyWith(time: const TimeOfDay(hour: 8, minute: 0))
          .toNative(),
      {
        'id': 'second-alarm',
        'hour': 8,
        'minute': 0,
        'label': 'Morning',
        'days': [0, 4],
        'challenge': 'ballMonte',
        'difficulty': 'extreme',
      },
    );
  });
}
