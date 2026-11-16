import 'package:bimbi/core/platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(AndroidPlatform.channel, null),
  );
  test('schedule/cancel use one native source of truth', () async {
    Map<String, Object?>? pending;
    messenger.setMockMethodCallHandler(AndroidPlatform.channel, (call) async {
      switch (call.method) {
        case 'schedule':
          pending = Map<String, Object?>.from(call.arguments as Map);
          return null;
        case 'cancel':
          pending = null;
          return null;
        case 'capabilities':
          return {'pending': pending};
        default:
          return null;
      }
    });
    final adapter = AndroidPlatform();
    await adapter.schedule(
      id: 'test',
      at: DateTime.now().add(const Duration(minutes: 1)),
    );
    expect((await adapter.capabilities())['pending']['id'], 'test');
    await adapter.cancel();
    expect((await adapter.capabilities())['pending'], isNull);
  });
  test(
    'permission denial remains explicit and does not report scheduling success',
    () async {
      messenger.setMockMethodCallHandler(AndroidPlatform.channel, (call) async {
        throw PlatformException(code: 'permission_denied', message: 'Denied');
      });
      await expectLater(
        AndroidPlatform().schedule(
          id: 'test',
          at: DateTime.now().add(const Duration(minutes: 1)),
        ),
        throwsA(
          isA<CapabilityFailure>().having(
            (e) => e.code,
            'code',
            'permission_denied',
          ),
        ),
      );
    },
  );
  test('unsupported native bridge is a capability failure', () async {
    await expectLater(
      AndroidPlatform().capabilities(),
      throwsA(
        isA<CapabilityFailure>().having((e) => e.code, 'code', 'unsupported'),
      ),
    );
  });
  test('past alarm and rapid repeat rejected before native call', () async {
    final adapter = AndroidPlatform();
    await expectLater(
      adapter.schedule(id: 'test', at: DateTime(2020)),
      throwsA(isA<CapabilityFailure>()),
    );
    await expectLater(
      adapter.schedule(
        id: 'test',
        at: DateTime.now().add(const Duration(minutes: 1)),
        repeat: const Duration(seconds: 2),
      ),
      throwsA(isA<CapabilityFailure>()),
    );
  });
}
