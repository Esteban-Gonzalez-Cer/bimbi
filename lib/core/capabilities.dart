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
}
