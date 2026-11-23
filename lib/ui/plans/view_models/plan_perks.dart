import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform.dart';
import '../../../data/repositories/entitlement_repository.dart';
import '../../../domain/models/plan.dart';
import '../../../features/alarm/application/alarm_draft.dart';

/// Tone used when a Plus tone is no longer covered by an active pass.
const fallbackTone = 'dawn_chime';

/// Keeps paid perks honest after a pass ends: alarms that use a Plus tone are
/// re-saved with [fallbackTone]. It acts only once the server's entitlement
/// has loaded, so a paying account is never downgraded during start-up.
/// Watched by the shell.
final plusToneGuardProvider = Provider<void>((ref) {
  final entitlement = ref.watch(entitlementProvider);
  if (!entitlement.hasValue || entitlement.isLoading) return;
  if (ref.watch(planTierProvider).includes(PlanTier.plus)) return;
  final plusTones = {
    for (final t in ref.watch(alarmTonesProvider))
      if (t.plus) t.id,
  };
  if (plusTones.isEmpty) return;
  final alarms = (ref.watch(capabilitiesProvider).value?['alarms'] as List?)
      ?.map(NativeAlarm.fromNative)
      .whereType<NativeAlarm>()
      .where((a) => plusTones.contains(a.draft.tone))
      .toList();
  if (alarms == null || alarms.isEmpty) return;
  final actions = ref.read(alarmActionsProvider);
  for (final alarm in alarms) {
    unawaited(
      actions
          .save(alarm.draft.copyWith(tone: fallbackTone))
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
});
