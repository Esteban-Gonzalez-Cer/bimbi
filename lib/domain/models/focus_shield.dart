import 'package:flutter/foundation.dart';

/// An app the person can pause during Focus or give a daily limit.
@immutable
class ShieldApp {
  const ShieldApp({required this.package, required this.label, this.icon});
  final String package;
  final String label;
  final Uint8List? icon;
}

/// Shield permissions and choices, read from the device. None of this is
/// synced: app usage stays on the phone or tablet.
@immutable
class ShieldStatus {
  const ShieldStatus({
    this.usageAccess = false,
    this.overlay = false,
    this.focusApps = const {},
    this.limits = const {},
    this.focusUntil,
    this.todayMinutes = const {},
    this.lastStop = '',
  });

  final bool usageAccess;
  final bool overlay;
  final Set<String> focusApps;

  /// Daily limit in minutes per package.
  final Map<String, int> limits;
  final DateTime? focusUntil;

  /// Foreground minutes per package since midnight (needs Usage Access).
  final Map<String, int> todayMinutes;

  /// Why the service last stopped, e.g. `permission_revoked`.
  final String lastStop;

  bool get ready => usageAccess && overlay;
  bool get hasChoices => focusApps.isNotEmpty || limits.isNotEmpty;

  static ShieldStatus fromNative(Map<dynamic, dynamic> json) {
    Map<String, int> ints(Object? value) => {
      if (value is Map)
        for (final e in value.entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
    };
    final until = json['focusUntil'];
    return ShieldStatus(
      usageAccess: json['usageAccess'] == true,
      overlay: json['overlay'] == true,
      focusApps: {
        if (json['focusApps'] is List)
          for (final p in json['focusApps'] as List) '$p',
      },
      limits: ints(json['limits']),
      focusUntil: until is num
          ? DateTime.fromMillisecondsSinceEpoch(until.toInt())
          : null,
      todayMinutes: ints(json['todayMinutes']),
      lastStop: json['lastStop'] is String ? json['lastStop'] as String : '',
    );
  }
}
