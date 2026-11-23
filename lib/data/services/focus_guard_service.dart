import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../domain/models/focus_shield.dart';

/// Native Focus shield and daily limits (Android only, opt-in).
abstract interface class FocusGuard {
  Future<ShieldStatus> status();
  Future<List<ShieldApp>> installedApps();
  Future<void> setRules({
    required Set<String> focusApps,
    required Map<String, int> limits,
  });

  /// Covers chosen apps until [until] and chimes at each of [windowEnds]
  /// and at [until]; null stops the Focus part and cancels the chimes.
  Future<void> focusUntil(
    DateTime? until, {
    List<DateTime> windowEnds = const [],
  });
  Future<void> usageSettings();
  Future<void> overlaySettings();

  /// Foreground minutes in other apps between two instants, or null without
  /// Usage Access.
  Future<int?> phoneUseBetween(DateTime from, DateTime to);
}

class AndroidFocusGuard implements FocusGuard {
  static const _channel = AndroidPlatform.channel;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      throw const CapabilityFailure(
        'unsupported',
        'The Focus shield needs Android.',
      );
    } on PlatformException catch (e) {
      throw CapabilityFailure(e.code, e.message ?? 'Android error');
    }
  }

  @override
  Future<ShieldStatus> status() async => ShieldStatus.fromNative(
    await _call<Map<dynamic, dynamic>>('guardStatus') ?? {},
  );

  @override
  Future<List<ShieldApp>> installedApps() async {
    final list = await _call<List<dynamic>>('installedApps') ?? const [];
    return [
      for (final item in list.whereType<Map<dynamic, dynamic>>())
        ShieldApp(
          package: '${item['package']}',
          label: '${item['label']}',
          icon: item['icon'] is Uint8List ? item['icon'] as Uint8List : null,
        ),
    ];
  }

  @override
  Future<void> setRules({
    required Set<String> focusApps,
    required Map<String, int> limits,
  }) => _call<void>('setGuardRules', {
    'focusApps': focusApps.toList(),
    'limits': limits,
  });

  @override
  Future<void> focusUntil(
    DateTime? until, {
    List<DateTime> windowEnds = const [],
  }) => _call<void>('focusShield', {
    'until': until?.millisecondsSinceEpoch,
    'windowEnds': [for (final t in windowEnds) t.millisecondsSinceEpoch],
  });

  @override
  Future<void> usageSettings() => _call<void>('usageSettings');

  @override
  Future<void> overlaySettings() => _call<void>('overlaySettings');

  @override
  Future<int?> phoneUseBetween(DateTime from, DateTime to) => _call<int>(
    'phoneUseBetween',
    {'from': from.millisecondsSinceEpoch, 'to': to.millisecondsSinceEpoch},
  );
}

final focusGuardProvider = Provider<FocusGuard>((ref) => AndroidFocusGuard());
