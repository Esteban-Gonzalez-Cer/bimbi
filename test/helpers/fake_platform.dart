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
  var dismissCalls = 0;
  var cancelCalls = 0;

  @override
  Future<Map<String, dynamic>> capabilities() async => caps;
  @override
  Future<void> cancel() async {
    cancelCalls++;
    caps.remove('pending');
  }

  @override
  Future<void> dismiss() async => dismissCalls++;
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
