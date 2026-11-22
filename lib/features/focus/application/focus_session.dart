import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';

enum FocusPhase { idle, running, paused }

/// Focus session derived from absolute timestamps, never from an in-memory
/// countdown. Phase 5 persists [startedAt] / [banked] so a restarted process
/// reconstructs the same remaining time.
@immutable
class FocusSession {
  const FocusSession({
    this.target = const Duration(minutes: 25),
    this.phase = FocusPhase.idle,
    this.startedAt,
    this.banked = Duration.zero,
  });

  static const minTarget = Duration(minutes: 5);
  static const maxTarget = Duration(minutes: 120);

  final Duration target;
  final FocusPhase phase;

  /// Start of the current running stretch.
  final DateTime? startedAt;

  /// Focus time completed before the current stretch (across pauses).
  final Duration banked;

  Duration elapsed(DateTime now) {
    final live = phase == FocusPhase.running && startedAt != null
        ? now.difference(startedAt!)
        : Duration.zero;
    final total = banked + (live.isNegative ? Duration.zero : live);
    return total > target ? target : total;
  }

  Duration remaining(DateTime now) => target - elapsed(now);
  bool isComplete(DateTime now) =>
      phase != FocusPhase.idle && remaining(now) == Duration.zero;
  double progress(DateTime now) => target.inMilliseconds == 0
      ? 0
      : elapsed(now).inMilliseconds / target.inMilliseconds;
}

class FocusController extends Notifier<FocusSession> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  FocusSession build() => const FocusSession();

  /// Snaps to 5-minute steps within 5–120 minutes. Idle only.
  void setTarget(Duration value) {
    if (state.phase != FocusPhase.idle) return;
    final minutes = (value.inMinutes / 5).round() * 5;
    final clamped = minutes.clamp(
      FocusSession.minTarget.inMinutes,
      FocusSession.maxTarget.inMinutes,
    );
    state = FocusSession(target: Duration(minutes: clamped));
  }

  void start() {
    if (state.phase == FocusPhase.running) return;
    state = FocusSession(
      target: state.target,
      phase: FocusPhase.running,
      startedAt: _now(),
      banked: state.phase == FocusPhase.paused ? state.banked : Duration.zero,
    );
  }

  void pause() {
    if (state.phase != FocusPhase.running) return;
    state = FocusSession(
      target: state.target,
      phase: FocusPhase.paused,
      banked: state.elapsed(_now()),
    );
  }

  void end() => state = FocusSession(target: state.target);
}

final focusProvider = NotifierProvider<FocusController, FocusSession>(
  FocusController.new,
);

/// One-second UI tick while a session runs. Display only; time is always
/// recomputed from timestamps.
final focusTickProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
);
