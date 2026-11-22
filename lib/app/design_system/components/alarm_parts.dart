import 'package:flutter/material.dart';

import '../../theme/bimbi_colors.dart';
import '../../theme/bimbi_tokens.dart';
import '../bimbi_icon.dart';
import 'surfaces.dart';

const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Splits "7:00 AM" into ("7:00", "AM") using the device's locale/24h choice.
(String, String) splitTime(BuildContext context, TimeOfDay time) {
  final formatted = MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final parts = formatted.split(RegExp(r'\s+'));
  if (parts.length < 2) return (formatted, '');
  return (parts.first, parts.sublist(1).join(' '));
}

/// Large clock numerals with the period in a smaller weight.
class ClockText extends StatelessWidget {
  const ClockText(this.time, {super.key, this.style, this.color});
  final TimeOfDay time;
  final TextStyle? style;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final (digits, period) = splitTime(context, time);
    final base = (style ?? context.text.headlineLarge)!.copyWith(color: color);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: digits, style: base),
          if (period.isNotEmpty)
            TextSpan(
              text: ' $period',
              style: context.text.labelLarge?.copyWith(
                color: base.color,
                fontSize: (base.fontSize ?? 34) * 0.26,
              ),
            ),
        ],
      ),
    );
  }
}

/// Seven round day toggles. Index 0 = Monday.
class DayChips extends StatelessWidget {
  const DayChips({super.key, required this.selected, this.onChanged});
  final Set<int> selected;
  final ValueChanged<Set<int>>? onChanged;

  VoidCallback? _toggle(int day) {
    final change = onChanged;
    if (change == null) return null;
    return () {
      final next = {...selected};
      if (!next.remove(day)) next.add(day);
      change(next);
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < 7; i++)
          Semantics(
            label: weekdayNames[i],
            selected: selected.contains(i),
            button: onChanged != null,
            onTap: _toggle(i),
            excludeSemantics: true,
            child: InkResponse(
              onTap: _toggle(i),
              radius: 26,
              child: AnimatedContainer(
                duration: BimbiMotion.quick,
                width: kBimbiMinTarget,
                height: kBimbiMinTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected.contains(i)
                      ? Theme.of(context).colorScheme.primary
                      : c.card,
                  border: Border.all(
                    color: selected.contains(i)
                        ? Theme.of(context).colorScheme.primary
                        : c.inputBorder,
                    width: 2,
                  ),
                ),
                child: Text(
                  weekdayLetters[i],
                  style: context.text.labelLarge?.copyWith(
                    color: selected.contains(i)
                        ? Theme.of(context).colorScheme.onPrimary
                        : c.text,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact, read-only day letters for alarm cards.
class DayLetters extends StatelessWidget {
  const DayLetters({super.key, required this.days, this.color});
  final Set<int> days;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                weekdayLetters[i],
                style: context.text.labelMedium?.copyWith(
                  color: days.contains(i)
                      ? (color ?? c.link)
                      : (color ?? c.textMuted).withValues(alpha: 0.55),
                  fontWeight: days.contains(i)
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String describeDays(Set<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.every((d) => d < 5)) return 'Weekdays';
  if (days.length == 2 && days.containsAll({5, 6})) return 'Weekends';
  if (days.length == 1) return '${weekdayNames[days.first]}s';
  return (days.toList()..sort()).map((d) => weekdayNames[d]).join(', ');
}

enum WakeMission {
  none('No mission', BimbiIcons.alarm, 'Dismiss right away'),
  shake('Shake', BimbiIcons.shake, 'Move your device'),
  math('Math', BimbiIcons.math, 'Solve operations'),
  ballMonte('Ball Monte', BimbiIcons.focus, 'Find the ball'),
  pattern('Follow the pattern', BimbiIcons.edit, 'Repeat the sequence'),
  memory('Memorama', BimbiIcons.card, 'Find the pairs');

  const WakeMission(this.label, this.icon, this.detail);
  final String label;
  final BimbiIcons icon;
  final String detail;
}

/// Alarm card: on, off and bedtime variants.
class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.time,
    required this.label,
    required this.days,
    required this.enabled,
    this.mission = WakeMission.none,
    this.bedtime = false,
    this.status,
    this.onToggle,
    this.onTap,
  });

  final TimeOfDay time;
  final String label;
  final Set<int> days;
  final bool enabled;
  final WakeMission mission;
  final bool bedtime;
  final String? status;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final fg = bedtime ? c.onNight : c.text;
    final muted = bedtime ? c.onNightMuted : c.textMuted;
    final (digits, period) = splitTime(context, time);
    return Semantics(
      container: true,
      label:
          '${bedtime ? 'Bedtime' : 'Alarm'} $digits $period, $label, '
          '${describeDays(days)}${enabled ? '' : ', off'}',
      child: BimbiCard(
        color: bedtime ? c.night : null,
        borderColor: bedtime ? c.night : null,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(
          BimbiSpace.lg,
          BimbiSpace.md,
          BimbiSpace.md,
          BimbiSpace.md,
        ),
        child: AnimatedOpacity(
          duration: BimbiMotion.standard,
          opacity: enabled ? 1 : 0.55,
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (bedtime) ...[
                            const BimbiIcon(
                              BimbiIcons.bedtime,
                              onAccent: true,
                              size: 22,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: ClockText(
                              time,
                              color: fg,
                              style: context.text.displaySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$label · ${describeDays(days)}',
                        style: context.text.titleSmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: BimbiSpace.xs),
                      Wrap(
                        spacing: BimbiSpace.sm,
                        runSpacing: BimbiSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (days.isNotEmpty)
                            DayLetters(
                              days: days,
                              color: bedtime ? c.onNight : null,
                            ),
                          if (mission != WakeMission.none)
                            StatusPill(
                              mission.detail,
                              icon: mission.icon,
                              tone: PillTone.accent,
                            ),
                          if (status != null)
                            StatusPill(status!, tone: PillTone.neutral),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (onToggle != null)
                Semantics(
                  label: '$label alarm',
                  child: Switch(value: enabled, onChanged: onToggle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Select a wake-up challenge from the available missions.
class WakeMissionSelector extends StatelessWidget {
  const WakeMissionSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.available = const {
      WakeMission.shake,
      WakeMission.math,
      WakeMission.ballMonte,
      WakeMission.pattern,
      WakeMission.memory,
    },
  });

  final WakeMission value;
  final ValueChanged<WakeMission> onChanged;
  final Set<WakeMission> available;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return Wrap(
      spacing: BimbiSpace.xs,
      runSpacing: BimbiSpace.xs,
      children: [
        for (final m in WakeMission.values.where(available.contains))
          Semantics(
            selected: value == m,
            button: true,
            onTap: () => onChanged(m),
            label: '${m.label}, ${m.detail}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BimbiRadius.inputBorder,
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: BimbiMotion.quick,
                constraints: const BoxConstraints(minWidth: 96, minHeight: 88),
                padding: const EdgeInsets.all(BimbiSpace.sm),
                decoration: BoxDecoration(
                  color: value == m ? c.accentTint : c.card,
                  borderRadius: BimbiRadius.inputBorder,
                  border: Border.all(
                    color: value == m
                        ? Theme.of(context).colorScheme.primary
                        : c.inputBorder,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BimbiIcon(m.icon),
                    const SizedBox(height: 6),
                    Text(m.label, style: context.text.labelLarge),
                    Text(
                      m.detail,
                      style: context.text.labelSmall?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Mission progress bar ("Shake mission 18 / 30").
class MissionProgress extends StatelessWidget {
  const MissionProgress({
    super.key,
    required this.label,
    required this.current,
    required this.total,
    this.night = false,
  });
  final String label;
  final int current;
  final int total;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final fg = night ? c.onNight : c.text;
    final value = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '$current of $total',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall?.copyWith(color: fg),
                ),
              ),
              Text(
                '$current / $total',
                style: context.text.titleSmall?.copyWith(color: fg),
              ),
            ],
          ),
          const SizedBox(height: BimbiSpace.xs),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 14,
              backgroundColor: night
                  ? c.onNight.withValues(alpha: 0.15)
                  : c.accentTint,
            ),
          ),
        ],
      ),
    );
  }
}
