import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'application/run_controller.dart';
import 'tracking_adapter.dart';

export 'tracking_adapter.dart';

class TrackingState {
  const TrackingState({this.motionActive = false, this.movement = 0});

  final bool motionActive;
  final double movement;
}

/// Developer-tools motion probe. The shell also uses stop() to pause the
/// production run when the user leaves Running or backgrounds the app.
class TrackingController extends Notifier<TrackingState> {
  StreamSubscription<UserAccelerometerEvent>? _motion;

  @override
  TrackingState build() {
    ref.onDispose(() => unawaited(_motion?.cancel()));
    return const TrackingState();
  }

  Future<void> startMotion() async {
    if (state.motionActive) return;
    state = const TrackingState(motionActive: true);
    _motion = ref
        .read(trackingAdapterProvider)
        .motion()
        .listen(
          (event) {
            if (!ref.mounted || !state.motionActive) return;
            state = TrackingState(
              motionActive: true,
              movement: sqrt(
                event.x * event.x + event.y * event.y + event.z * event.z,
              ),
            );
          },
          onError: (Object _) => unawaited(_stopMotion()),
          onDone: () => unawaited(_stopMotion()),
        );
  }

  Future<void> _stopMotion() async {
    final motion = _motion;
    _motion = null;
    if (ref.mounted) state = const TrackingState();
    await motion?.cancel();
  }

  Future<void> stop() async {
    final pause = ref.read(runControllerProvider.exists)
        ? ref.read(runControllerProvider.notifier).pause()
        : null;
    await _stopMotion();
    await pause;
  }
}

final trackingProvider = NotifierProvider<TrackingController, TrackingState>(
  TrackingController.new,
);
