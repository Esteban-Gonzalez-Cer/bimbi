import 'dart:async';

import 'package:bimbi/features/running/tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FakeTracking implements TrackingAdapter {
  final gps = StreamController<Position>.broadcast();
  final accelerometer = StreamController<UserAccelerometerEvent>.broadcast();
  Completer<void>? permission;
  @override
  Future<void> requestLocation() async {
    await permission?.future;
  }

  @override
  Stream<Position> positions() => gps.stream;
  @override
  Stream<UserAccelerometerEvent> motion() => accelerometer.stream;
}

void main() {
  test('stop cancels GPS and motion subscriptions', () async {
    final fake = FakeTracking();
    final container = ProviderContainer(
      overrides: [trackingAdapterProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final controller = container.read(trackingProvider.notifier);
    await controller.startGps();
    await controller.startMotion();
    expect(fake.gps.hasListener, true);
    expect(fake.accelerometer.hasListener, true);
    await controller.stop();
    expect(fake.gps.hasListener, false);
    expect(fake.accelerometer.hasListener, false);
  });
  test(
    'permission resolving after leaving foreground cannot restart tracking',
    () async {
      final fake = FakeTracking()..permission = Completer<void>();
      final container = ProviderContainer(
        overrides: [trackingAdapterProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final controller = container.read(trackingProvider.notifier);
      final starting = controller.startGps();
      await controller.stop();
      fake.permission!.complete();
      await starting;
      expect(fake.gps.hasListener, false);
      expect(container.read(trackingProvider).running, false);
    },
  );
}
