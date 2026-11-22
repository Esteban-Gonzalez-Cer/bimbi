import 'package:bimbi/core/platform.dart';

/// In-memory Android bridge for widget tests. Records calls; never touches
/// AlarmManager.
class FakePlatform implements PlatformAdapter {
  FakePlatform({Map<String, dynamic>? capabilities})
    : caps = {
        'exactAlarm': true,
        'notifications': true,
        'fullScreen': true,
        'usageAccess': false,
        'active': false,
        'lastEvent': 'none',
        'mapsConfigured': false,
        ...?capabilities,
      };

  final Map<String, dynamic> caps;
  final scheduled = <({String id, DateTime at, Duration repeat})>[];
  final alarms = <String, Map<String, dynamic>>{};
  final previews = <({String tone, int volume, String intensity})>[];
  var _nextId = 0;
  var openChallengeCalls = 0;
  var cancelCalls = 0;
  var stopAlarmPreviewCalls = 0;

  @override
  Future<Map<String, dynamic>> capabilities() async => {
    ...caps,
    'alarms': alarms.values.toList(),
  };
  @override
  Future<void> cancel() async {
    cancelCalls++;
    caps.remove('pending');
  }

  @override
  Future<void> openChallenge() async => openChallengeCalls++;
  @override
  Future<bool> previewAlarmSound({
    required String tone,
    required int volume,
    required String intensity,
  }) async {
    previews.add((tone: tone, volume: volume, intensity: intensity));
    return true;
  }

  @override
  Future<void> stopAlarmPreview() async => stopAlarmPreviewCalls++;
  @override
  Stream<void> alarmChanges() => const Stream.empty();

  @override
  Future<Map<String, dynamic>> saveAlarm(Map<String, Object> draft) async {
    final id = draft['id'] as String? ?? 'alarm-${++_nextId}';
    final enabled = alarms[id]?['enabled'] != false;
    final row = {...draft, 'id': id};
    alarms[id] = row;
    return enableAlarm(id, enabled);
  }

  @override
  Future<Map<String, dynamic>> enableAlarm(String id, bool enabled) async {
    final row = alarms[id]!;
    final status = !enabled
        ? 'off'
        : caps['exactAlarm'] == true
        ? 'armed'
        : 'exact';
    row['enabled'] = enabled;
    row['status'] = status;
    if (status == 'armed') {
      row['nextAt'] = DateTime(
        2026,
        11,
        23,
        row['hour'] as int,
        row['minute'] as int,
      ).millisecondsSinceEpoch;
    } else {
      row.remove('nextAt');
    }
    return row;
  }

  @override
  Future<void> deleteAlarm(String id) async {
    alarms.remove(id);
  }

  @override
  Future<void> schedule({
    required String id,
    required DateTime at,
    Duration repeat = Duration.zero,
  }) async {
    scheduled.add((id: id, at: at, repeat: repeat));
    caps['pending'] = {
      'id': id,
      'atMillis': at.millisecondsSinceEpoch,
      'intervalSeconds': repeat.inSeconds,
    };
  }

  @override
  Future<void> settings(String kind) async {}
  @override
  Future<Map<String, dynamic>> usageSummary() async => {};
}
