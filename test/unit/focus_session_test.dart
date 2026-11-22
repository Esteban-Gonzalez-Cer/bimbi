import 'package:bimbi/core/clock.dart';
import 'package:bimbi/features/focus/application/focus_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late ProviderContainer container;
  FocusController controller() => container.read(focusProvider.notifier);
  FocusSession session() => container.read(focusProvider);

  setUp(() {
    now = DateTime(2026, 11, 21, 9);
    container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
  });

  test('target snaps to 5-minute steps within 5–120 minutes', () {
    controller().setTarget(const Duration(minutes: 23));
    expect(session().target, const Duration(minutes: 25));
    controller().setTarget(const Duration(minutes: 1));
    expect(session().target, const Duration(minutes: 5));
    controller().setTarget(const Duration(hours: 5));
    expect(session().target, const Duration(minutes: 120));
  });

  test('remaining time derives from timestamps across pause and resume', () {
    controller().setTarget(const Duration(minutes: 25));
    controller().start();
    now = now.add(const Duration(minutes: 10));
    expect(session().remaining(now), const Duration(minutes: 15));
    controller().pause();
    now = now.add(const Duration(hours: 1)); // paused time does not count
    expect(session().remaining(now), const Duration(minutes: 15));
    controller().start();
    now = now.add(const Duration(minutes: 5));
    expect(session().remaining(now), const Duration(minutes: 10));
    expect(session().progress(now), closeTo(0.6, 1e-9));
  });

  test('a session survives a rebuilt controller from its timestamps', () {
    controller().start();
    final persisted = session();
    now = now.add(const Duration(minutes: 10));
    // FOCUS-01: a new process reads startedAt/banked, not a countdown.
    final restored = FocusSession(
      target: persisted.target,
      phase: persisted.phase,
      startedAt: persisted.startedAt,
      banked: persisted.banked,
    );
    expect(restored.remaining(now), const Duration(minutes: 15));
  });

  test('completes at the target and never goes negative', () {
    controller().start();
    now = now.add(const Duration(hours: 2));
    expect(session().remaining(now), Duration.zero);
    expect(session().isComplete(now), isTrue);
    controller().end();
    expect(session().phase, FocusPhase.idle);
  });

  test('target cannot change while running', () {
    controller().start();
    controller().setTarget(const Duration(minutes: 60));
    expect(session().target, const Duration(minutes: 25));
  });
}
