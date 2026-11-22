import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/bimbi_colors.dart';
import '../../theme/bimbi_tokens.dart';
import '../bimbi_icon.dart';
import 'surfaces.dart';

/// "7 h 12 m" style duration.
String formatHoursMinutes(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m m';
  return '$h h ${m.toString().padLeft(2, '0')} m';
}

/// Weekly bars of self-reported time in bed. Null = no entry that day.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.labels,
    required this.values,
    this.night = false,
    this.highlight,
  });

  final List<String> labels;
  final List<Duration?> values;
  final bool night;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final maxMinutes = math.max(
      8 * 60,
      values.whereType<Duration>().fold<int>(
        0,
        (m, d) => math.max(m, d.inMinutes),
      ),
    );
    final label = [
      for (var i = 0; i < labels.length; i++)
        '${labels[i]}: ${values[i] == null ? 'no entry' : formatHoursMinutes(values[i]!)}',
    ].join('; ');
    return Semantics(
      label: 'Time in bed this week. $label',
      excludeSemantics: true,
      child: SizedBox(
        height: 132,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: values[i] == null
                              ? 0.06
                              : (values[i]!.inMinutes / maxMinutes).clamp(
                                  0.06,
                                  1.0,
                                ),
                          child: Container(
                            width: 18,
                            decoration: BoxDecoration(
                              color: values[i] == null
                                  ? (night
                                        ? c.onNight.withValues(alpha: 0.15)
                                        : c.inputBorder)
                                  : (i == highlight
                                        ? Theme.of(context).colorScheme.primary
                                        : (night
                                              ? BimbiPalette.lavender
                                              : BimbiPalette.lightTint)),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: context.text.labelSmall?.copyWith(
                          color: night ? c.onNightMuted : c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Subscription plan card. Prices come from the trusted test endpoint; the
/// TEST MODE badge is always visible while billing is sandboxed.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    this.current = false,
    this.featured = false,
    this.actionLabel,
    this.onPressed,
    this.testMode = true,
  });

  final String name;
  final String price;
  final String period;
  final List<String> features;
  final bool current;
  final bool featured;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final bool testMode;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return BimbiCard(
      borderColor: featured ? Theme.of(context).colorScheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: BimbiSpace.xs,
            runSpacing: BimbiSpace.xs,
            children: [
              if (featured)
                const StatusPill('Recommended', tone: PillTone.accent),
              if (current) const StatusPill('Current plan'),
              if (testMode && !current)
                const StatusPill('Test mode', tone: PillTone.neutral),
            ],
          ),
          const SizedBox(height: BimbiSpace.sm),
          Text(name, style: context.text.headlineSmall),
          const SizedBox(height: BimbiSpace.xxs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: price, style: context.text.headlineLarge),
                TextSpan(
                  text: ' $period',
                  style: context.text.bodyMedium?.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: BimbiSpace.sm),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BimbiIcon(BimbiIcons.check, size: 20),
                  const SizedBox(width: BimbiSpace.xs),
                  Expanded(child: Text(f, style: context.text.bodyMedium)),
                ],
              ),
            ),
          if (actionLabel != null) ...[
            const SizedBox(height: BimbiSpace.sm),
            SizedBox(
              width: double.infinity,
              child: featured
                  ? FilledButton(
                      onPressed: onPressed,
                      child: Text(actionLabel!),
                    )
                  : OutlinedButton(
                      onPressed: onPressed,
                      child: Text(actionLabel!),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
