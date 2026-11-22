/// Typed read-only view over the native `capabilities` map.
class DeviceCapabilities {
  const DeviceCapabilities(this.raw);
  final Map<String, dynamic> raw;

  bool _flag(String key) => raw[key] == true;
  bool get exactAlarm => _flag('exactAlarm');
  bool get notifications => _flag('notifications');
  bool get fullScreen => _flag('fullScreen');
  bool get alarmActive => _flag('active');
  bool get mapsConfigured => _flag('mapsConfigured');
  bool get accelerometer => _flag('accelerometer');
  bool get gps => _flag('gps');
  bool get usageAccess => _flag('usageAccess');

  /// All permissions a reliable wake alarm needs on Android 14+.
  bool get alarmReady => exactAlarm && notifications;

  PendingAlarm? get pending {
    final value = raw['pending'];
    if (value is! Map || value['atMillis'] is! int) return null;
    return PendingAlarm(
      id: '${value['id']}',
      at: DateTime.fromMillisecondsSinceEpoch(value['atMillis'] as int),
      repeat: Duration(
        seconds: (value['intervalSeconds'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class PendingAlarm {
  const PendingAlarm({
    required this.id,
    required this.at,
    required this.repeat,
  });
  final String id;
  final DateTime at;
  final Duration repeat;
}
