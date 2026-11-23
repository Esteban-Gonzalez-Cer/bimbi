import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../data/services/focus_guard_service.dart';
import '../../../domain/models/focus_shield.dart';
import 'focus_session.dart';

/// Shield permissions, choices and today's usage, read from Android.
/// Invalidate it after returning from Android settings.
final shieldStatusProvider = FutureProvider<ShieldStatus>(
  (ref) => ref.watch(focusGuardProvider).status(),
);

/// Launchable apps for the picker, loaded once per visit.
final shieldAppsProvider = FutureProvider.autoDispose<List<ShieldApp>>(
  (ref) => ref.watch(focusGuardProvider).installedApps(),
);

class ShieldActions {
  ShieldActions(this.ref);
  final Ref ref;

  FocusGuard get _guard => ref.read(focusGuardProvider);

  Future<void> _save(
    ShieldStatus current, {
    Set<String>? focusApps,
    Map<String, int>? limits,
  }) async {
    await _guard.setRules(
      focusApps: focusApps ?? current.focusApps,
      limits: limits ?? current.limits,
    );
    ref.invalidate(shieldStatusProvider);
    // A running session now covers the newly chosen apps too.
    await syncFocusShield(ref);
  }

  Future<void> pauseDuringFocus(ShieldStatus s, String pkg, bool on) => _save(
    s,
    focusApps: on ? {...s.focusApps, pkg} : ({...s.focusApps}..remove(pkg)),
  );

  Future<void> setLimit(ShieldStatus s, String pkg, int? minutes) => _save(
    s,
    limits: minutes == null
        ? ({...s.limits}..remove(pkg))
        : {...s.limits, pkg: minutes},
  );

  /// Removes every choice; the service stops when nothing is left.
  Future<void> clearAll(ShieldStatus s) =>
      _save(s, focusApps: const {}, limits: const {});

  Future<void> openUsageSettings() => _guard.usageSettings();
  Future<void> openOverlaySettings() => _guard.overlaySettings();
}

final shieldActionsProvider = Provider<ShieldActions>(ShieldActions.new);

/// Tells Android until when chosen apps are paused: the end of the running
/// Focus session, or nothing while idle or paused.
Future<void> syncFocusShield(Ref ref) async {
  final session = ref.read(focusProvider);
  final now = ref.read(clockProvider)();
  final until = session.endsAt(now);
  try {
    await ref
        .read(focusGuardProvider)
        .focusUntil(until, windowEnds: session.windowEnds(now));
  } on Object {
    // The shield is optional; Focus works without it.
  }
}

/// Keeps the native shield in step with the Focus timer, including a
/// session restored after the app was killed. Watched by the shell.
final focusShieldLinkProvider = Provider<void>((ref) {
  ref.listen(
    focusProvider.select(
      (s) => (s.phase, s.startedAt, s.banked, s.target, s.windows.length),
    ),
    (_, _) => unawaited(syncFocusShield(ref)),
    fireImmediately: true,
  );
});
