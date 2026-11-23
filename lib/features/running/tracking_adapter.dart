import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/platform.dart';

abstract interface class TrackingAdapter {
  Future<void> requestLocation();
  Stream<Position> positions();
  Future<void> openLocationSettings({required bool app});
  Stream<UserAccelerometerEvent> motion();
}

class AndroidTracking implements TrackingAdapter {
  @override
  Future<void> requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CapabilityFailure(
        'service_off',
        'Turn on device location to record a run.',
      );
    }
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    if (status == LocationPermission.denied ||
        status == LocationPermission.deniedForever) {
      throw const CapabilityFailure(
        'permission_denied',
        'Location permission is unavailable. You can enable it in Android settings.',
      );
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      throw const CapabilityFailure(
        'approximate',
        'Allow precise location in Android settings to record a route.',
      );
    }
  }

  @override
  Future<void> openLocationSettings({required bool app}) async {
    if (app) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
  }

  @override
  Stream<Position> positions() => Geolocator.getPositionStream(
    // Use Android's location provider even when Google's optional network
    // accuracy setting is off, so recording is available during offline runs.
    locationSettings: AndroidSettings(
      forceLocationManager: true,
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
    ),
  );
  @override
  Stream<UserAccelerometerEvent> motion() =>
      userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);
}

final trackingAdapterProvider = Provider<TrackingAdapter>(
  (ref) => AndroidTracking(),
);
