import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/platform.dart';

abstract interface class TrackingAdapter {
  Future<void> requestLocation();
  Stream<Position> positions();
  Stream<UserAccelerometerEvent> motion();
}

class AndroidTracking implements TrackingAdapter {
  @override
  Future<void> requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CapabilityFailure(
        'service_off',
        'Turn on device location to start the GPS experiment.',
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
  }

  @override
  Stream<Position> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    ),
  );
  @override
  Stream<UserAccelerometerEvent> motion() =>
      userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);
}

final trackingAdapterProvider = Provider<TrackingAdapter>(
  (ref) => AndroidTracking(),
);

class TrackingState {
  const TrackingState({
    this.running = false,
    this.motionActive = false,
    this.points = const [],
    this.movement = 0,
    this.status = 'Ready. Location stays on this device.',
  });
  final bool running;
  final bool motionActive;
  final List<Position> points;
  final double movement;
  final String status;
  TrackingState copy({
    bool? running,
    bool? motionActive,
    List<Position>? points,
    double? movement,
    String? status,
  }) => TrackingState(
    running: running ?? this.running,
    motionActive: motionActive ?? this.motionActive,
    points: points ?? this.points,
    movement: movement ?? this.movement,
    status: status ?? this.status,
  );
}

class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<Position>? _gps;
  StreamSubscription<UserAccelerometerEvent>? _motion;
  int _generation = 0;
  @override
  TrackingState build() {
    ref.onDispose(() {
      _generation++;
      unawaited(_gps?.cancel());
      unawaited(_motion?.cancel());
    });
    return const TrackingState();
  }

  Future<void> startGps() async {
    if (state.running) return;
    final generation = ++_generation;
    await ref.read(trackingAdapterProvider).requestLocation();
    if (!ref.mounted || generation != _generation) return;
    state = state.copy(running: true, status: 'Waiting for a GPS fix…');
    _gps = ref
        .read(trackingAdapterProvider)
        .positions()
        .listen(
          (point) {
            if (!ref.mounted || generation != _generation) return;
            if (point.accuracy > 50 || point.isMocked) {
              state = state.copy(
                status: 'GPS accuracy is low or location is simulated; sample ignored.',
              );
              return;
            }
            final points = state.points;
            if (points.isNotEmpty) {
              final last = points.last;
              final seconds =
                  point.timestamp.difference(last.timestamp).inMilliseconds /
                  1000;
              if (seconds <= 0 ||
                  Geolocator.distanceBetween(
                            last.latitude,
                            last.longitude,
                            point.latitude,
                            point.longitude,
                          ) /
                          seconds >
                      15) {
                state = state.copy(status: 'Unreliable GPS jump ignored.');
                return;
              }
            }
            state = state.copy(
              points: [...points.skip(points.length >= 1000 ? 1 : 0), point],
              status: 'Recording foreground GPS.',
            );
          },
          onError: (Object _) {
            unawaited(stop());
          },
        );
  }

  Future<void> startMotion() async {
    if (state.motionActive) return;
    state = state.copy(motionActive: true, status: 'Move the tablet gently.');
    _motion = ref
        .read(trackingAdapterProvider)
        .motion()
        .listen(
          (event) {
            if (ref.mounted && state.motionActive) {
              state = state.copy(
                movement: sqrt(
                  event.x * event.x + event.y * event.y + event.z * event.z,
                ),
              );
            }
          },
          onError: (Object _) {
            unawaited(stop());
          },
        );
  }

  Future<void> stop() async {
    _generation++;
    await _gps?.cancel();
    _gps = null;
    await _motion?.cancel();
    _motion = null;
    if (ref.mounted) {
      state = state.copy(
        running: false,
        motionActive: false,
        status: 'Tracking stopped.',
      );
    }
  }

  Future<void> clear() async {
    await stop();
    if (ref.mounted) state = const TrackingState();
  }
}

final trackingProvider = NotifierProvider<TrackingController, TrackingState>(
  TrackingController.new,
);
