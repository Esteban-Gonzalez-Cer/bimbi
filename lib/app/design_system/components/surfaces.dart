import 'package:flutter/material.dart';

import '../../theme/bimbi_colors.dart';
import '../../theme/bimbi_tokens.dart';
import '../bimbi_icon.dart';
import '../buddy/bimbi_buddy.dart';

/// Soft white card on Cream (Night-raised in dark mode), radius 28.
class BimbiCard extends StatelessWidget {
  const BimbiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BimbiSpace.lg),
    this.color,
    this.borderColor,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BimbiRadius.cardBorder,
        border: Border.all(color: borderColor ?? c.cardBorder, width: 1.5),
        boxShadow: color == null ? c.shadows : BimbiShadows.none,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BimbiRadius.cardBorder,
                child: Semantics(
                  button: true,
                  label: semanticLabel,
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Small uppercase group label ("TOGGLES AND SELECTION").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: context.text.labelMedium?.copyWith(
        letterSpacing: 1.5,
        color: color ?? context.bimbi.textMuted,
      ),
    ),
  );
}

/// Screen title. The text carries `Semantics.header` and the
/// [PageHeader.titleKey] so tests and TalkBack resolve the destination.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  static const titleKey = ValueKey('page-title');
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BimbiSpace.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  key: titleKey,
                  style: context.text.headlineLarge,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: BimbiSpace.xxs),
                Text(
                  subtitle!,
                  style: context.text.bodyLarge?.copyWith(
                    color: context.bimbi.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Buddy card that opens a screen: buddy first, then one line, one action.
class BuddyHeaderCard extends StatelessWidget {
  const BuddyHeaderCard({
    super.key,
    required this.title,
    required this.message,
    this.mood = BuddyMood.happy,
    this.action,
    this.night = false,
    this.buddySize = 112,
  });

  final String title;
  final String message;
  final BuddyMood mood;
  final Widget? action;

  /// Bedtime cards use the Night surface in both themes.
  final bool night;
  final double buddySize;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final fg = night ? c.onNight : c.text;
    final muted = night ? c.onNightMuted : c.textMuted;
    return BimbiCard(
      color: night ? c.night : null,
      borderColor: night ? c.night : null,
      padding: const EdgeInsets.all(BimbiSpace.lg),
      child: LayoutBuilder(
        builder: (context, box) {
          final stack = box.maxWidth < 300;
          final text = Column(
            crossAxisAlignment: stack
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: stack ? TextAlign.center : TextAlign.start,
                style: context.text.headlineMedium?.copyWith(color: fg),
              ),
              const SizedBox(height: BimbiSpace.xs),
              Text(
                message,
                textAlign: stack ? TextAlign.center : TextAlign.start,
                style: context.text.bodyLarge?.copyWith(color: muted),
              ),
              if (action != null) ...[
                const SizedBox(height: BimbiSpace.md),
                action!,
              ],
            ],
          );
          final buddy = BimbiBuddy(mood: mood, size: buddySize, zzzColor: fg);
          if (stack) {
            return Column(
              children: [
                buddy,
                const SizedBox(height: BimbiSpace.sm),
                text,
              ],
            );
          }
          return Row(
            children: [
              buddy,
              const SizedBox(width: BimbiSpace.md),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }
}

/// Number + label tile ("7 h 12 m · Time in bed").
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.night = false,
  });

  final String value;
  final String label;
  final BimbiIcons? icon;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(BimbiSpace.md),
        decoration: BoxDecoration(
          color: night ? c.onNight.withValues(alpha: 0.08) : c.accentTint,
          borderRadius: BimbiRadius.inputBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              BimbiIcon(icon!, size: 22, onAccent: night),
              const SizedBox(height: BimbiSpace.xs),
            ],
            Text(
              value,
              style: context.text.headlineSmall?.copyWith(
                color: night ? c.onNight : c.text,
              ),
            ),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: night ? c.onNightMuted : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BannerTone { neutral, success, danger, night }

/// Notification-style inline feedback (brand "Navigation and feedback").
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.title,
    this.message,
    this.icon = BimbiIcons.bell,
    this.tone = BannerTone.neutral,
    this.action,
    this.liveRegion = false,
  });

  final String title;
  final String? message;
  final BimbiIcons icon;
  final BannerTone tone;
  final Widget? action;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final (bg, fg, badge) = switch (tone) {
      BannerTone.neutral => (c.card, c.text, c.accentTint),
      BannerTone.success => (c.card, c.text, c.successTint),
      BannerTone.danger => (c.card, c.text, c.dangerTint),
      BannerTone.night => (c.night, c.onNight, c.onNight),
    };
    return Semantics(
      liveRegion: liveRegion,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BimbiSpace.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(
            Radius.circular(BimbiRadius.banner),
          ),
          border: Border.all(
            color: tone == BannerTone.night ? c.night : c.cardBorder,
            width: 1.5,
          ),
          boxShadow: c.shadows,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: badge,
                borderRadius: const BorderRadius.all(Radius.circular(11)),
              ),
              alignment: Alignment.center,
              child: BimbiIcon(icon, size: 22),
            ),
            const SizedBox(width: BimbiSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(color: fg),
                  ),
                  if (message != null)
                    Text(
                      message!,
                      style: context.text.bodyMedium?.copyWith(
                        color: tone == BannerTone.night
                            ? c.onNightMuted
                            : c.textMuted,
                      ),
                    ),
                  if (action != null) ...[
                    const SizedBox(height: BimbiSpace.xs),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meaningful empty state: buddy, one line, one clear action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.mood = BuddyMood.thinking,
    this.action,
    this.buddySize = 120,
  });

  final String title;
  final String message;
  final BuddyMood mood;
  final Widget? action;
  final double buddySize;

  @override
  Widget build(BuildContext context) => BimbiCard(
    child: Column(
      children: [
        BimbiBuddy(mood: mood, size: buddySize),
        const SizedBox(height: BimbiSpace.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: BimbiSpace.xxs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: context.bimbi.textMuted,
          ),
        ),
        if (action != null) ...[const SizedBox(height: BimbiSpace.md), action!],
      ],
    ),
  );
}

enum PillTone { neutral, success, danger, accent }

/// Small rounded status pill ("Email verified", "TEST MODE").
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
  });
  final String label;
  final PillTone tone;
  final BimbiIcons? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (c.background, c.textMuted),
      PillTone.success => (c.successTint, c.success),
      PillTone.danger => (c.dangerTint, c.danger),
      PillTone.accent => (c.accentTint, c.onAccentTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BimbiRadius.chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            BimbiIcon(icon!, size: 16),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + switch row; the whole row is the touch target.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });
  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: detail == null ? null : Text(detail!),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    ),
  );
}
