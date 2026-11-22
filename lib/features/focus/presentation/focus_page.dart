import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/capabilities.dart';
import '../../../core/clock.dart';
import '../../../core/operation.dart';
import '../../../core/platform.dart';
import '../application/focus_session.dart';
import 'focus_dial.dart';

class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) {
      final window = WindowScope.of(context);
      final content = [
        PageHeader(
          title: 'Focus',
          trailing: window.isCompact
              ? const BimbiBuddy(
                  size: 56,
                  mood: BuddyMood.thinking,
                  glow: false,
                )
              : null,
        ),
        _TimerCard(viewportHeight: viewport.maxHeight),
      ];
      if (window.isExpanded) {
        return TwoPane(
          primaryFlex: 6,
          primary: content,
          secondary: const [_Presets(), _UsageCard()],
        );
      }
      return PageBody(
        children: [...content, const _Presets(), const _UsageCard()],
      );
    },
  );
}

class _TimerCard extends ConsumerWidget {
  const _TimerCard({required this.viewportHeight});

  final double viewportHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(focusProvider);
    if (session.phase == FocusPhase.running) ref.watch(focusTickProvider);
    final now = ref.watch(clockProvider)();
    final controller = ref.read(focusProvider.notifier);
    final complete = session.isComplete(now);
    final idle = session.phase == FocusPhase.idle;
    final caption = complete
        ? 'Done!'
        : switch (session.phase) {
            FocusPhase.idle => 'minutes',
            FocusPhase.running => 'Focusing',
            FocusPhase.paused => 'Paused',
          };
    final colors = context.bimbi;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dark ? colors.night : BimbiPalette.lavenderMist,
            colors.card,
          ],
        ),
        border: Border.all(color: colors.cardBorder),
        borderRadius: BimbiRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: LayoutBuilder(
          builder: (context, box) {
            // The shell has already reserved room for system bars and the
            // phone dock. Leave space in the actual viewport for the action.
            final dialSize = math.min(
              math.min(336.0, box.maxWidth),
              math.max(148.0, viewportHeight - 260),
            );
            return Column(
              children: [
                FocusDial(
                  size: dialSize,
                  target: session.target,
                  remaining: session.remaining(now),
                  progress: session.progress(now),
                  caption: caption,
                  onTargetChanged: idle ? controller.setTarget : null,
                ),
                const SizedBox(height: BimbiSpace.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    complete
                        ? 'Session complete'
                        : idle
                        ? 'Drag the dial to set your time'
                        : session.phase == FocusPhase.paused
                        ? 'Paused. Pick up where you left off.'
                        : 'Session in progress',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(
                      color: context.bimbi.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: BimbiSpace.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: BimbiSpace.sm,
                  runSpacing: BimbiSpace.sm,
                  children: [
                    if (idle)
                      FilledButton.icon(
                        onPressed: controller.start,
                        icon: const BimbiIcon(BimbiIcons.play, onAccent: true),
                        label: const Text('Start focus'),
                      )
                    else if (complete)
                      FilledButton(
                        onPressed: controller.end,
                        child: const Text('Finish'),
                      )
                    else ...[
                      if (session.phase == FocusPhase.running)
                        FilledButton.icon(
                          onPressed: controller.pause,
                          icon: const BimbiIcon(
                            BimbiIcons.pause,
                            onAccent: true,
                          ),
                          label: const Text('Pause'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: controller.start,
                          icon: const BimbiIcon(
                            BimbiIcons.play,
                            onAccent: true,
                          ),
                          label: const Text('Resume'),
                        ),
                      OutlinedButton.icon(
                        onPressed: controller.end,
                        icon: const BimbiIcon(BimbiIcons.stop),
                        label: const Text('End'),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Presets extends ConsumerWidget {
  const _Presets();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(focusProvider);
    final idle = session.phase == FocusPhase.idle;
    return BimbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Session length'),
          const SizedBox(height: BimbiSpace.sm),
          Wrap(
            spacing: BimbiSpace.xs,
            runSpacing: BimbiSpace.xs,
            children: [
              for (final m in const [15, 25, 45, 60, 90])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: session.target.inMinutes == m,
                  onSelected: idle
                      ? (_) => ref
                            .read(focusProvider.notifier)
                            .setTarget(Duration(minutes: m))
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Optional, opt-in phone-use awareness. Focus works fully without it.
class _UsageCard extends ConsumerWidget {
  const _UsageCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref
        .watch(capabilitiesProvider)
        .whenData(DeviceCapabilities.new)
        .asData
        ?.value;
    final granted = caps?.usageAccess ?? false;
    return BimbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BimbiIcon(BimbiIcons.phoneFree),
              const SizedBox(width: BimbiSpace.sm),
              Expanded(
                child: Text(
                  'Phone-use awareness',
                  style: context.text.titleMedium,
                ),
              ),
              StatusPill(
                granted ? 'On' : 'Off',
                tone: granted ? PillTone.success : PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: BimbiSpace.xs),
          Text(
            'Optional. With Android Usage Access, Bimbi can count your '
            'phone time on this device. It never blocks apps or uploads it.',
            style: context.text.bodyMedium?.copyWith(
              color: context.bimbi.textMuted,
            ),
          ),
          const SizedBox(height: BimbiSpace.sm),
          OutlinedButton(
            onPressed: () => ref.read(operationProvider.notifier).run(() async {
              await ref.read(platformProvider).settings('usage');
              return 'Usage Access is optional. Denying it will not disable Focus.';
            }),
            child: Text(granted ? 'Manage access' : 'Review Usage Access'),
          ),
        ],
      ),
    );
  }
}
