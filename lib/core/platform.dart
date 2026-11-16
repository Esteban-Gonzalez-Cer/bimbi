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
  Future<void> dismiss();
  Future<void> settings(String kind);
  Future<Map<String, dynamic>> usageSummary();
}

class AndroidPlatform implements PlatformAdapter {
  static const channel = MethodChannel('com.bimbi.app/platform');
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
  Future<void> dismiss() => _invoke<void>('dismiss');
  @override
  Future<void> settings(String kind) => _invoke<void>('${kind}Settings');
  @override
  Future<Map<String, dynamic>> usageSummary() async =>
      Map<String, dynamic>.from(
        await _invoke<Map<dynamic, dynamic>>('usageSummary') ?? {},
      );
}

final platformProvider = Provider<PlatformAdapter>((ref) => AndroidPlatform());
final capabilitiesProvider = FutureProvider(
  (ref) => ref.watch(platformProvider).capabilities(),
);
