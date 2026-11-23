import 'dart:async';

import 'package:bimbi/features/running/domain/run.dart';
import 'package:bimbi/features/running/tracking_adapter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FakeRunLocation implements TrackingAdapter {
  final fixes = StreamController<Position>.broadcast(sync: true);
  Future<void> Function()? permission;

  @override
  Future<void> requestLocation() async => permission?.call();

  @override
  Stream<Position> positions() => fixes.stream;

  @override
  Stream<UserAccelerometerEvent> motion() => const Stream.empty();

  @override
  Future<void> openLocationSettings({required bool app}) async {}

  void emit(RunPoint p, {bool mocked = false}) => fixes.add(
    Position(
      longitude: p.longitude,
      latitude: p.latitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: mocked,
    ),
  );
}
