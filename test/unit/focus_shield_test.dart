import 'package:bimbi/core/clock.dart';
import 'package:bimbi/data/services/focus_guard_service.dart';
import 'package:bimbi/ui/focus/view_models/focus_session.dart';
import 'package:bimbi/ui/focus/view_models/focus_shield.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_focus_guard.dart';

void main() {
  late DateTime now;
  late FakeFocusGuard guard;
  late ProviderContainer c;

  setUp(() {
    now = DateTime(2026, 11, 22, 9);
    guard = FakeFocusGuard(usageAccess: true, overlay: true);
    c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        focusGuardProvider.overrideWithValue(guard),
      ],
    );
    addTearDown(c.dispose);
    c.listen(focusShieldLinkProvider, (_, _) {});
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'the shield follows the session: on while running, off otherwise',
    () async {
      await settle();
      expect(guard.focusCalls.last, isNull);
      c.read(focusProvider.notifier).start();
      await settle();
      expect(guard.focusCalls.last, DateTime(2026, 11, 22, 9, 25));

      now = now.add(const Duration(minutes: 10));
      c.read(focusProvider.notifier).pause();
      await settle();
      expect(guard.focusCalls.last, isNull);

      now = now.add(const Duration(minutes: 30));
      c.read(focusProvider.notifier).start();
      await settle();
      expect(guard.focusCalls.last, DateTime(2026, 11, 22, 9, 55));

      c.read(focusProvider.notifier).end();
      await settle();
      expect(guard.focusCalls.last, isNull);
    },
  );

  test('window ends are sent for chimes and cleared on pause', () async {
    c.read(focusProvider.notifier).setWindows([10, 20, 30]);
    c.read(focusProvider.notifier).start();
    await settle();
    expect(guard.windowCalls.last, [
      DateTime(2026, 11, 22, 9, 10),
      DateTime(2026, 11, 22, 9, 30),
    ]);
    expect(guard.focusCalls.last, DateTime(2026, 11, 22, 10));
    c.read(focusProvider.notifier).pause();
    await settle();
    expect(guard.focusCalls.last, isNull);
    expect(guard.windowCalls.last, isEmpty);
  });

  test('choosing apps and limits stays on the device guard', () async {
    final actions = c.read(shieldActionsProvider);
    var status = await c.read(shieldStatusProvider.future);
    await actions.pauseDuringFocus(status, 'com.video', true);
    status = await c.read(shieldStatusProvider.future);
    await actions.setLimit(status, 'com.video', 30);
    status = await c.read(shieldStatusProvider.future);
    expect(status.focusApps, {'com.video'});
    expect(status.limits, {'com.video': 30});
    await actions.setLimit(status, 'com.video', null);
    await actions.pauseDuringFocus(
      await c.read(shieldStatusProvider.future),
      'com.video',
      false,
    );
    status = await c.read(shieldStatusProvider.future);
    expect(status.hasChoices, isFalse);
  });

  test('a missing shield never breaks the timer', () async {
    final broken = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        focusGuardProvider.overrideWithValue(AndroidFocusGuard()),
      ],
    );
    addTearDown(broken.dispose);
    broken.listen(focusShieldLinkProvider, (_, _) {});
    broken.read(focusProvider.notifier).start();
    await settle();
    expect(broken.read(focusProvider).phase, FocusPhase.running);
  });
}
