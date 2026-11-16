import 'dart:async';

import 'package:bimbi/core/operation.dart';
import 'package:bimbi/core/platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent taps cannot start duplicate experiments', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(operationProvider.notifier);
    final waiting = Completer<String>();
    var calls = 0;
    final first = controller.run(() {
      calls++;
      return waiting.future;
    });
    await controller.run(() async {
      calls++;
      return 'duplicate';
    });
    expect(calls, 1);
    waiting.complete('complete');
    await first;
    expect(container.read(operationProvider).message, 'complete');
  });
  test('typed denial becomes visible without false success', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(operationProvider.notifier).run(() async {
      throw const CapabilityFailure(
        'permission_denied',
        'Exact access required.',
      );
    });
    expect(container.read(operationProvider).message, 'Exact access required.');
    expect(container.read(operationProvider).busy, false);
  });
  test('unexpected provider errors do not expose raw credentials', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(operationProvider.notifier).run(() async {
      throw Exception('sensitive-provider-payload');
    });
    expect(
      container.read(operationProvider).message,
      isNot(contains('sensitive-provider-payload')),
    );
  });
}
