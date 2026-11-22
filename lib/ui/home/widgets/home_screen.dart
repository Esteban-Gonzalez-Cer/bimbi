import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/clock.dart';
import '../../../core/operation.dart';
import '../../../core/platform.dart';
import '../../../features/alarm/application/alarm_draft.dart';
import '../../../features/profile/presentation/profile_picture.dart';
import '../../../features/alarm/presentation/alarm_editor.dart';
import '../../../features/notifications/messaging.dart';
import '../view_models/home_view_model.dart';

/// Alarms opens with the next real wake time and its primary action.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _pad = EdgeInsets.fromLTRB(20, 28, 20, 32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final window = WindowScope.of(context);

    void openEditor([AlarmDraft draft = const AlarmDraft()]) {
      ref.read(alarmEditorProvider.notifier).open(draft);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const AlarmEditorPage(),
        ),
      );
    }

    final top = <Widget>[
      _Header(state: state),
      _HeroCard(state: state, onCreate: openEditor),
      _Stats(state: state),
    ];
    final alarms = <Widget>[
      _SectionHeader(onAdd: openEditor),
      if (state.loading)
        const LinearProgressIndicator()
      else if (state.alarms.isEmpty)
        const _NoAlarms()
      else
        for (final a in state.alarms)
          _AlarmTile(alarm: a, onTap: () => openEditor(a.draft)),
      const _EmergencyDismiss(),
    ];

    if (window.isExpanded) {
      // Tablet landscape: today on the left, alarms on the right.
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Column(padding: _pad, children: top),
              ),
              Expanded(
                child: _Column(
                  padding: _pad.copyWith(top: 32 + 58),
                  children: alarms,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Phones and tablet portrait: one column at phone proportions.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _Column(padding: _pad, children: [...top, ...alarms]),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.padding, required this.children});
  final EdgeInsets padding;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding,
    itemCount: children.length,
    separatorBuilder: (_, _) => const SizedBox(height: 16),
    itemBuilder: (_, i) => children[i],
  );
}

class _Header extends ConsumerWidget {
  const _Header({required this.state});
  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final hasName = state.name.isNotEmpty;
    final date = MaterialLocalizations.of(context)
        .formatFullDate(ref.watch(clockProvider)());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: context.text.labelLarge?.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: BimbiSpace.xs),
                if (hasName)
                  Text(
                    '${state.greeting},',
                    style: context.text.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
                Text(
                  hasName ? state.name : state.greeting,
                  key: PageHeader.titleKey,
                  style: context.text.headlineLarge?.copyWith(
                    fontSize: 36,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: BimbiSpace.xs),
        IconButton.filledTonal(
          tooltip: 'Open profile',
          onPressed: () => ref.read(destinationProvider.notifier).select(4),
          style: IconButton.styleFrom(
            backgroundColor: c.accentTint,
            foregroundColor: c.link,
          ),
          icon: const ProfilePicture(
            size: 26,
            fallback: BimbiIcon(BimbiIcons.profile, size: 22),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state, required this.onCreate});
  final HomeState state;
  final void Function([AlarmDraft]) onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final loc = MaterialLocalizations.of(context);
    final night =
        state.night || Theme.of(context).brightness == Brightness.dark;
    final fg = night ? c.onNight : c.onAccentTint;
    final muted = night ? c.onNightMuted : c.textMuted;
    final at = state.nextAlarmAt;
    final alarm = at == null || state.alarms.isEmpty
        ? null
        : state.alarms.first;
    final title = state.loading
        ? 'Checking alarm…'
        : alarm == null
        ? 'No alarm set'
        : loc.formatTimeOfDay(
            alarm.time,
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final detail = alarm == null
        ? 'Choose a time to wake up.'
        : '${alarm.label} · ${loc.formatShortDate(at!)}';

    return BimbiCard(
      color: night ? c.night : c.accentTint,
      borderColor: night ? c.cardBorder : c.accentTint,
      padding: const EdgeInsets.all(BimbiSpace.lg),
      child: LayoutBuilder(
        builder: (context, box) {
          final stack =
              box.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(16) > 24;
          final buddySize = box.maxWidth < 292 ? 88.0 : 104.0;
          final buddy = Container(
            width: buddySize,
            height: buddySize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: night
                  ? BimbiPalette.lavender.withValues(alpha: .12)
                  : BimbiPalette.lightBackground.withValues(alpha: .68),
            ),
            child: BimbiBuddy(
              size: buddySize,
              mood: night ? BuddyMood.sleepy : BuddyMood.happy,
              glow: false,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel('Next alarm', color: muted),
              const SizedBox(height: BimbiSpace.xs),
              Text(
                title,
                style: context.text.headlineLarge?.copyWith(
                  color: fg,
                  fontSize: alarm == null ? 28 : 38,
                  height: 1.1,
                ),
              ),
              if (!state.loading) ...[
                const SizedBox(height: BimbiSpace.xs),
                Text(
                  detail,
                  style: context.text.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: BimbiSpace.md),
                FilledButton(
                  onPressed: () =>
                      alarm == null ? onCreate() : onCreate(alarm.draft),
                  child: Text(alarm == null ? 'Set alarm' : 'Edit alarm'),
                ),
              ],
            ],
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.centerRight, child: buddy),
                copy,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: BimbiSpace.sm),
              buddy,
            ],
          );
        },
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.state});
  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final next = state.nextAlarmIn;
    final metrics = [
      if (next != null && !next.isNegative)
        _StatChip(
          icon: BimbiIcons.alarm,
          value: formatUntil(next),
          label: 'Until alarm',
        ),
      _StatChip(
        icon: BimbiIcons.bedtime,
        value: state.averageSleep == null
            ? 'No entries'
            : formatHoursMinutes(state.averageSleep!),
        label: 'Avg time in bed',
      ),
    ];
    if (metrics.length == 1) return metrics.single;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 24) {
          return Column(
            children: [
              metrics.first,
              const SizedBox(height: BimbiSpace.xs),
              metrics.last,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: metrics.first),
            const SizedBox(width: BimbiSpace.sm),
            Expanded(child: metrics.last),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });
  final BimbiIcons icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              alignment: Alignment.center,
              child: BimbiIcon(icon, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: context.text.titleLarge?.copyWith(
                      fontSize: 18,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text('Alarms', style: context.text.headlineSmall),
          ),
        ),
        IconButton.filled(
          tooltip: 'Add alarm',
          onPressed: onAdd,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          icon: const BimbiIcon(BimbiIcons.plus, size: 22, onAccent: true),
        ),
      ],
    ),
  );
}

/// White alarm card, radius 28, padding 20/22, soft shadow.
class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({required this.alarm, required this.onTap});
  final HomeAlarm alarm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final (digits, period) = splitTime(context, alarm.time);
    final repeat = describeDays(alarm.days);
    return Semantics(
      container: true,
      label: 'Alarm $digits $period, ${alarm.label}, $repeat',
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          boxShadow: c.shadows,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ExcludeSemantics(
                          child: Opacity(
                            opacity: alarm.enabled ? 1 : 0.55,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClockText(
                                  alarm.time,
                                  style: context.text.displayMedium?.copyWith(
                                    fontSize: 46,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${alarm.label} · $repeat',
                                  style: context.text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Semantics(
                        label: '${alarm.label} alarm',
                        child: Switch(
                          value: alarm.enabled,
                          onChanged: (on) {
                            if (on) return;
                            ref.read(operationProvider.notifier).run(() async {
                              await ref
                                  .read(savedAlarmProvider.notifier)
                                  .cancel();
                              return 'Alarm turned off.';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Off alarms show only time and label, as in the artboard.
                  if (alarm.enabled &&
                      (alarm.days.isNotEmpty ||
                          alarm.mission != WakeMission.none)) ...[
                    const SizedBox(height: 14),
                    ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (alarm.days.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < 7; i++)
                                  _DayDot(
                                    letter: weekdayLetters[i],
                                    on: alarm.days.contains(i),
                                  ),
                              ],
                            ),
                          if (alarm.mission != WakeMission.none) ...[
                            const SizedBox(height: 10),
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: c.accentTint,
                                borderRadius: BimbiRadius.chipBorder,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BimbiIcon(alarm.mission.icon, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    alarm.mission.detail,
                                    style: context.text.labelMedium?.copyWith(
                                      color: c.link,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.letter, required this.on});
  final String letter;
  final bool on;
  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? Theme.of(context).colorScheme.primary : c.card,
        border: on ? null : Border.all(color: c.inputBorder, width: 2),
      ),
      child: Text(
        letter,
        style: context.text.labelSmall?.copyWith(
          fontSize: 10,
          color: on ? Theme.of(context).colorScheme.onPrimary : c.text,
        ),
      ),
    );
  }
}

class _NoAlarms extends StatelessWidget {
  const _NoAlarms();
  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return BimbiCard(
      padding: const EdgeInsets.all(BimbiSpace.md),
      child: Row(
        children: [
          BimbiIcon(BimbiIcons.alarm),
          const SizedBox(width: BimbiSpace.sm),
          Expanded(
            child: Text(
              'No saved alarms',
              style: context.text.bodyLarge?.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Safety net kept visible: dismissal never depends on anything else.
/// Shown as a quiet text action unless an alarm is actually ringing.
class _EmergencyDismiss extends ConsumerWidget {
  const _EmergencyDismiss();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringing =
        ref.watch(capabilitiesProvider).asData?.value['active'] == true;
    Future<void> dismiss() async {
      await ref.read(platformProvider).dismiss();
      ref.invalidate(capabilitiesProvider);
    }

    if (ringing) {
      return FilledButton(
        onPressed: dismiss,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        child: const Text('Dismiss ringing alarm'),
      );
    }
    return Center(
      child: TextButton(
        onPressed: dismiss,
        child: const Text('Dismiss ringing alarm'),
      ),
    );
  }
}
