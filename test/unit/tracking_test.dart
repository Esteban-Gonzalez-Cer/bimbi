import 'dart:async';

import 'package:bimbi/features/running/tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../helpers/fake_run_location.dart';

class _MotionAdapter extends FakeRunLocation {
  final samples = StreamController<UserAccelerometerEvent>.broadcast(
    sync: true,
  );

  @override
  Stream<UserAccelerometerEvent> motion() => samples.stream;
}

void main() {
  test(
    'the development motion proof measures movement and unsubscribes',
    () async {
      final fake = _MotionAdapter();
      final container = ProviderContainer(
        overrides: [trackingAdapterProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final controller = container.read(trackingProvider.notifier);
      await controller.startMotion();
      expect(fake.samples.hasListener, isTrue);
      fake.samples.add(UserAccelerometerEvent(3, 4, 0, DateTime(2026)));
      expect(container.read(trackingProvider).movement, 5);
      await controller.stop();
      expect(fake.samples.hasListener, isFalse);
      expect(container.read(trackingProvider).motionActive, isFalse);
    },
  );
}
