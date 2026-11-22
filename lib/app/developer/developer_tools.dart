import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/operation.dart';
import '../../core/platform.dart';
import '../../features/auth/auth_adapter.dart';
import '../../features/cloud/cloud_probe.dart';
import '../../features/notifications/messaging.dart';
import '../../features/running/tracking.dart';
import '../design_system/design_system.dart';
import '../preferences.dart';
import 'design_gallery.dart';

/// Runs an action through [operationProvider]; disabled while busy.
class ActionButton extends ConsumerWidget {
  const ActionButton(
    this.label,
    this.action, {
    super.key,
    this.enabled = true,
    this.primary = false,
  });
  final String label;
  final Future<String> Function() action;
  final bool enabled;
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onPressed = enabled && !ref.watch(operationProvider).busy
        ? () => ref.read(operationProvider.notifier).run(action)
        : null;
    final child = Text(label, textAlign: TextAlign.center);
    return primary
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// Phase 1 device experiments, unchanged in behaviour. Debug builds only
/// (`AppConfig.harness`); never part of the product UI.
class DeveloperTools extends ConsumerWidget {
  const DeveloperTools({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final op = ref.watch(operationProvider);
    return BimbiCard(
      padding: const EdgeInsets.symmetric(
        horizontal: BimbiSpace.md,
        vertical: BimbiSpace.xs,
      ),
      child: ExpansionTile(
        leading: const BimbiIcon(BimbiIcons.developer),
        title: Text('Developer tools', style: context.text.titleMedium),
        subtitle: Text('Debug build only', style: context.text.bodySmall),
        childrenPadding: const EdgeInsets.only(bottom: BimbiSpace.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: StatusPill(op.busy ? 'Working…' : op.message),
          ),
          const SizedBox(height: BimbiSpace.md),
          const _AlarmExperiments(),
          const _RunningExperiments(),
          const _UsageExperiments(),
          const _CloudExperiments(),
          const SizedBox(height: BimbiSpace.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DesignGallery()),
            ),
            child: const Text('Open design gallery'),
          ),
          const SizedBox(height: BimbiSpace.xs),
          OutlinedButton(
            onPressed: () => ref.read(onboardingProvider.notifier).restart(),
            child: const Text('Replay onboarding'),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BimbiSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        const SizedBox(height: BimbiSpace.xs),
        Wrap(
          spacing: BimbiSpace.xs,
          runSpacing: BimbiSpace.xs,
          children: children,
        ),
      ],
    ),
  );
}

class _AlarmExperiments extends ConsumerWidget {
  const _AlarmExperiments();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.read(platformProvider);
    final caps = ref.watch(capabilitiesProvider).asData?.value;
    Future<String> schedule(Duration delay, Duration repeat) async {
      await platform.schedule(
        id: 'phase1-alarm',
        at: DateTime.now().add(delay),
        repeat: repeat,
      );
      ref.invalidate(capabilitiesProvider);
      return 'Exact alarm scheduled. Test audio lasts at most two minutes.';
    }

    return _Group('Native alarm', [
      if (caps != null)
        Text(
          'Last event: ${caps['lastEvent']} · API ${caps['api']}',
          style: context.text.bodySmall,
        ),
      ActionButton(
        'Alarm in 30 seconds',
        () => schedule(const Duration(seconds: 30), Duration.zero),
      ),
      ActionButton(
        'Alarm in 3 minutes',
        () => schedule(const Duration(minutes: 3), Duration.zero),
      ),
      ActionButton(
        'Repeat every minute',
        () => schedule(const Duration(minutes: 1), const Duration(minutes: 1)),
      ),
      ActionButton('Cancel pending alarm', () async {
        await platform.cancel();
        ref.invalidate(capabilitiesProvider);
        return 'Pending alarm cancelled.';
      }),
      ActionButton('Refresh alarm status', () async {
        ref.invalidate(capabilitiesProvider);
        return 'Alarm status refreshed.';
      }),
    ]);
  }
}

class _RunningExperiments extends ConsumerWidget {
  const _RunningExperiments();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    return _Group('Motion sensor', [
      Text(
        'Movement: ${tracking.movement.toStringAsFixed(1)} m/s²',
        style: context.text.bodySmall,
      ),
      ActionButton('Start motion sensor', () async {
        await ref.read(trackingProvider.notifier).startMotion();
        return 'Accelerometer experiment started.';
      }, enabled: !tracking.motionActive),
      ActionButton('Stop tracking', () async {
        await ref.read(trackingProvider.notifier).stop();
        return 'GPS and motion subscriptions stopped.';
      }),
    ]);
  }
}

class _UsageExperiments extends ConsumerWidget {
  const _UsageExperiments();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Group('Usage Access', [
    ActionButton('Check usage permission', () async {
      final values = await ref.read(platformProvider).usageSummary();
      return 'Usage Access granted. ${values['observedApps']} apps observed; ${values['totalForegroundSeconds']} foreground seconds in the daily query. Nothing uploaded.';
    }),
  ]);
}

class _CloudExperiments extends ConsumerWidget {
  const _CloudExperiments();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(firebaseReadyProvider);
    final user = ref.watch(sessionProvider).asData?.value;
    return _Group('Cloud and notifications', [
      Text(ref.watch(messagingProvider), style: context.text.bodySmall),
      ActionButton('Enable test topic', () async {
        await ref.read(messagingProvider.notifier).subscribe();
        return 'Notification experiment updated.';
      }, enabled: ready),
      ActionButton('Disable test topic', () async {
        await ref.read(messagingProvider.notifier).unsubscribe();
        return 'Test topic disabled.';
      }, enabled: ready),
      ActionButton('Test private data and image', () async {
        await ref.read(cloudProbeProvider).run();
        return 'Private record and image matched after readback; probe data deleted.';
      }, enabled: user?.emailVerified == true),
    ]);
  }
}
