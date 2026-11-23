import 'package:bimbi/core/clock.dart';
import 'package:bimbi/ui/focus/view_models/focus_session.dart';
import 'package:bimbi/ui/focus/widgets/focus_dial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bimbi/app/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('the dial snaps to 5 minutes; typed minutes are exact; 8 h max', () {
    controller().setTarget(const Duration(minutes: 23));
    expect(session().target, const Duration(minutes: 25));
    controller().setTarget(const Duration(minutes: 1));
    expect(session().target, const Duration(minutes: 5));
    controller().setTarget(const Duration(hours: 5));
    expect(session().target, const Duration(minutes: 300));
    controller().setTarget(const Duration(hours: 9));
    expect(session().target, const Duration(minutes: 480));
    controller().setTarget(const Duration(minutes: 7), exact: true);
    expect(session().target, const Duration(minutes: 7));
    controller().setTarget(Duration.zero, exact: true);
    expect(session().target, const Duration(minutes: 1));
  });

  test('winding past a full turn adds layers, unwinding removes them', () {
    // One turn is 120 minutes; the finger position picks the nearest value.
    expect(windMinutes(115, 0.02), 122); // past 12 o'clock: second turn
    expect(windMinutes(122, 0.98), 118); // back again: first turn
    expect(windMinutes(239, 0.01), 241);
    expect(windMinutes(470, 0.1), 480); // capped at four turns
    expect(windMinutes(5, 0.97), 0); // cannot go below zero
  });

  test('a split session reports its window and the window ends ahead', () {
    controller().setWindows([10, 20, 30]);
    expect(session().target, const Duration(minutes: 60));
    controller().start();
    now = now.add(const Duration(minutes: 15));
    expect(session().windowAt(now), (1, const Duration(minutes: 15)));
    expect(session().windowEnds(now), [now.add(const Duration(minutes: 15))]);
    controller().pause();
    expect(session().windows, [10, 20, 30]);
    expect(session().windowEnds(now), isEmpty);
    controller().end();
    expect(session().windows, [10, 20, 30], reason: 'kept for next time');
    controller().setTarget(const Duration(minutes: 45));
    expect(session().windows, isEmpty, reason: 'a new length clears it');
    controller().setWindows([30]);
    expect(session().windows, isEmpty, reason: 'one window is no split');
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

  group('FOCUS-01 persistence', () {
    late SharedPreferences prefs;

    ProviderContainer process() {
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          preferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('a killed process restores the same remaining time', () {
      final first = process();
      first.read(focusProvider.notifier)
        ..setTarget(const Duration(minutes: 30))
        ..setTaskLabel('  Write chapter 3  ')
        ..start();
      now = now.add(const Duration(minutes: 12));
      first.read(focusProvider.notifier).pause();
      now = now.add(const Duration(minutes: 40));
      first.read(focusProvider.notifier).start();
      now = now.add(const Duration(minutes: 3));
      first.dispose(); // process death

      final second = process();
      final restored = second.read(focusProvider);
      expect(restored.phase, FocusPhase.running);
      expect(restored.taskLabel, 'Write chapter 3');
      expect(restored.remaining(now), const Duration(minutes: 15));
    });

    test('finishing records history once, with focused time only', () {
      final c = process();
      final started = now;
      c.read(focusProvider.notifier).start();
      now = now.add(const Duration(minutes: 10));
      c.read(focusProvider.notifier).pause();
      now = now.add(const Duration(hours: 1));
      c.read(focusProvider.notifier).start();
      now = now.add(const Duration(minutes: 20));
      c.read(focusProvider.notifier)
        ..end()
        ..end();
      final records = c.read(focusRecordsProvider);
      expect(records, hasLength(1));
      expect(records.single.startedAt, started);
      expect(records.single.duration, const Duration(minutes: 25));
      expect(records.single.outcome.name, 'completed');
      expect(c.read(focusHistoryProvider).pending, {records.single.id});

      final reopened = process();
      expect(reopened.read(focusRecordsProvider), hasLength(1));
      expect(reopened.read(focusProvider).phase, FocusPhase.idle);
    });

    test('sessions under a minute are not recorded; early end is ended', () {
      final c = process();
      c.read(focusProvider.notifier).start();
      now = now.add(const Duration(seconds: 30));
      c.read(focusProvider.notifier).end();
      expect(c.read(focusRecordsProvider), isEmpty);
      c.read(focusProvider.notifier).start();
      now = now.add(const Duration(minutes: 7));
      c.read(focusProvider.notifier).end();
      expect(c.read(focusRecordsProvider).single.outcome.name, 'ended');
      expect(c.read(focusTodayProvider), const Duration(minutes: 7));
    });

    test('windows survive a restart; a bad split is dropped', () async {
      process().read(focusProvider.notifier).setWindows([10, 20, 30]);
      expect(process().read(focusProvider).windows, [10, 20, 30]);
      await prefs.setString(
        'bimbi.focus.session',
        '{"phase":"idle","targetMin":60,"windows":[10,10]}',
      );
      expect(process().read(focusProvider).windows, isEmpty);
    });

    test('a corrupt saved session falls back to idle', () async {
      await prefs.setString('bimbi.focus.session', '{not json');
      expect(process().read(focusProvider).phase, FocusPhase.idle);
      await prefs.setString(
        'bimbi.focus.session',
        '{"phase":"running","targetMin":25}',
      );
      expect(process().read(focusProvider).phase, FocusPhase.idle);
    });
  });
}
