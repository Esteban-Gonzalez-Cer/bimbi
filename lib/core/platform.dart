import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CapabilityFailure implements Exception {
  const CapabilityFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract interface class PlatformAdapter {
  Future<Map<String, dynamic>> capabilities();
  Future<void> schedule({
    required String id,
    required DateTime at,
    Duration repeat,
  });
  Future<void> cancel();
  Future<Map<String, dynamic>> saveAlarm(Map<String, Object> draft);
  Future<Map<String, dynamic>> enableAlarm(String id, bool enabled);
  Future<void> deleteAlarm(String id);
  Future<void> openChallenge();
  Future<bool> previewAlarmSound({
    required String tone,
    required int volume,
    required String intensity,
  });
  Future<void> stopAlarmPreview();
  Stream<void> alarmChanges();
  Future<void> settings(String kind);
  Future<Map<String, dynamic>> usageSummary();
}

class AndroidPlatform implements PlatformAdapter {
  static const channel = MethodChannel('com.bimbi.app/platform');
  static const _events = EventChannel('com.bimbi.app/alarms');
  Future<T?> _invoke<T>(String method, [Map<String, Object>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      throw const CapabilityFailure(
        'unsupported',
        'This experiment requires Android.',
      );
    } on PlatformException catch (e) {
      throw CapabilityFailure(e.code, e.message ?? 'Android operation failed.');
    }
  }

  @override
  Future<Map<String, dynamic>> capabilities() async =>
      Map<String, dynamic>.from(
        await _invoke<Map<dynamic, dynamic>>('capabilities') ?? {},
      );
  @override
  Future<void> schedule({
    required String id,
    required DateTime at,
    Duration repeat = Duration.zero,
  }) async {
    if (id.isEmpty ||
        !at.isAfter(DateTime.now()) ||
        (repeat != Duration.zero && repeat < const Duration(minutes: 1))) {
      throw const CapabilityFailure(
        'invalid',
        'Choose a future time and a repeat interval of at least one minute.',
      );
    }
    await _invoke<void>('schedule', {
      'id': id,
      'atMillis': at.millisecondsSinceEpoch,
      'intervalSeconds': repeat.inSeconds,
    });
  }

  @override
  Future<void> cancel() => _invoke<void>('cancel');
  @override
  Future<Map<String, dynamic>> saveAlarm(Map<String, Object> draft) =>
      _alarmResult('saveAlarm', draft);
  @override
  Future<Map<String, dynamic>> enableAlarm(String id, bool enabled) =>
      _alarmResult('enableAlarm', {'id': id, 'enabled': enabled});
  Future<Map<String, dynamic>> _alarmResult(
    String method,
    Map<String, Object> args,
  ) async => Map<String, dynamic>.from(
    await _invoke<Map<dynamic, dynamic>>(method, args) ?? {},
  );
  @override
  Future<void> deleteAlarm(String id) =>
      _invoke<void>('deleteAlarm', {'id': id});
  @override
  Future<void> openChallenge() => _invoke<void>('openChallenge');
  @override
  Future<bool> previewAlarmSound({
    required String tone,
    required int volume,
    required String intensity,
  }) async =>
      await _invoke<bool>('previewAlarmSound', {
        'tone': tone,
        'volume': volume,
        'intensity': intensity,
      }) ??
      false;
  @override
  Future<void> stopAlarmPreview() => _invoke<void>('stopAlarmPreview');
  @override
  Stream<void> alarmChanges() => _events.receiveBroadcastStream().map((_) {});
  @override
  Future<void> settings(String kind) => _invoke<void>('${kind}Settings');
  @override
  Future<Map<String, dynamic>> usageSummary() async =>
      Map<String, dynamic>.from(
        await _invoke<Map<dynamic, dynamic>>('usageSummary') ?? {},
      );
}

final platformProvider = Provider<PlatformAdapter>((ref) => AndroidPlatform());
final _alarmChangesProvider = StreamProvider<int>((ref) {
  var revision = 0;
  return ref.watch(platformProvider).alarmChanges().map((_) => ++revision);
});
final capabilitiesProvider = FutureProvider((ref) {
  ref.listen(_alarmChangesProvider, (_, next) {
    if (next.hasValue) ref.invalidateSelf();
  });
  return ref.watch(platformProvider).capabilities();
});
