import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/clock.dart';
import '../../../data/repositories/collection_sync.dart';
import '../../../domain/models/sleep_entry.dart';
import '../view_models/sleep_diary.dart';
import '../../core/widgets/metric_tile.dart';
import 'diary_sheet.dart';

/// Sleep report: last night up top, details below, the week and the diary.
/// Built to the "Sleep report" artboard without scores, streaks or points:
/// Bimbi shows self-reported time in bed, never a sleep judgment.
class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  static const _pad = EdgeInsets.fromLTRB(20, 28, 20, 32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(sleepDiaryProvider);
    final now = ref.watch(clockProvider)();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final latest = entries.firstOrNull;
    final last = latest != null && !latest.day.isBefore(yesterday)
        ? latest
        : null;
    final night =
        now.hour >= 19 ||
        now.hour < 5 ||
        Theme.of(context).brightness == Brightness.dark;

    final top = <Widget>[
      _Header(last: last, now: now),
      _LastNightCard(last: last, night: night),
      if (last != null) _NightTiles(last: last),
    ];
    final details = <Widget>[
      const _WeekCard(),
      const _HonestyCard(),
      const _Diary(),
    ];

    if (WindowScope.of(context).isExpanded) {
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
                  children: details,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _Column(padding: _pad, children: [...top, ...details]),
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
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, i) => children[i],
  );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _day(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}';

/// "Mon 23 to Tue 24 Nov", the night between two calendar days.
String nightRange(SleepEntry e) {
  final bed = e.bedtime;
  final sameDay =
      bed.year == e.wake.year &&
      bed.month == e.wake.month &&
      bed.day == e.wake.day;
  final month = _months[e.wake.month - 1];
  return sameDay
      ? '${_day(e.wake)} $month'
      : '${_day(bed)} to ${_day(e.wake)} $month';
}

class _Header extends ConsumerWidget {
  const _Header({required this.last, required this.now});
  final SleepEntry? last;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final eyebrow = last == null
        ? '${_day(now)} ${_months[now.month - 1]}'
        : nightRange(last!);
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
                  eyebrow,
                  style: context.text.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                ),
                Text(
                  'Last night',
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
          tooltip: last == null ? 'Log last night' : 'Log a night',
          onPressed: () => showDiarySheet(context, ref),
          style: IconButton.styleFrom(
            backgroundColor: c.accentTint,
            foregroundColor: c.link,
            minimumSize: const Size(48, 48),
          ),
          icon: const BimbiIcon(BimbiIcons.plus, size: 22),
        ),
      ],
    );
  }
}

String _clock(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

class _LastNightCard extends ConsumerWidget {
  const _LastNightCard({required this.last, required this.night});
  final SleepEntry? last;
  final bool night;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final fg = night ? c.onNight : c.onAccentTint;
    final muted = night ? c.onNightMuted : c.textMuted;
    final entry = last;
    final buddy = Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: night
            ? BimbiPalette.lavender.withValues(alpha: .12)
            : BimbiPalette.lightBackground.withValues(alpha: .68),
      ),
      child: BimbiBuddy(
        size: 84,
        mood: night || entry == null ? BuddyMood.sleepy : BuddyMood.happy,
        glow: false,
      ),
    );

    final Widget copy;
    if (entry == null) {
      copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was last night?',
            style: context.text.titleLarge?.copyWith(color: fg, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Log when you went to bed and woke up.',
            style: context.text.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: BimbiSpace.md),
          FilledButton(
            onPressed: () => showDiarySheet(context, ref),
            child: const Text('Log last night'),
          ),
        ],
      );
    } else {
      copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatHoursMinutes(entry.timeInBed)} in bed',
            style: context.text.titleLarge?.copyWith(color: fg, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            '${_clock(context, entry.bedtime)} to ${_clock(context, entry.wake)}',
            style: context.text.bodyMedium?.copyWith(color: fg),
          ),
          Text(
            'Self-reported',
            style: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      );
    }

    return BimbiCard(
      color: night ? c.night : c.accentTint,
      borderColor: night ? c.cardBorder : c.accentTint,
      padding: const EdgeInsets.all(BimbiSpace.md),
      onTap: entry == null
          ? null
          : () => showDiarySheet(context, ref, editing: entry),
      semanticLabel: entry == null
          ? null
          : 'Last night, ${formatHoursMinutes(entry.timeInBed)} in bed, '
                'from ${_clock(context, entry.bedtime)} to '
                '${_clock(context, entry.wake)}. Edit entry',
      child: LayoutBuilder(
        builder: (context, box) {
          final stack =
              box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(16) > 24;
          final dial = entry == null
              ? null
              : NightDial(entry: entry, size: 84, night: night);
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [?dial, const Spacer(), buddy]),
                const SizedBox(height: BimbiSpace.sm),
                copy,
              ],
            );
          }
          return Row(
            children: [
              if (dial != null) ...[dial, const SizedBox(width: 14)],
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

/// The night drawn on a 12-hour clock face: an arc from bedtime to wake,
/// with the time in bed in the middle. Shows when, not how well.
class NightDial extends StatelessWidget {
  const NightDial({
    super.key,
    required this.entry,
    this.size = 84,
    this.night = false,
  });
  final SleepEntry entry;
  final double size;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final scheme = Theme.of(context).colorScheme;
    final h = entry.timeInBed.inHours;
    final m = entry.timeInBed.inMinutes.remainder(60);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _NightDialPainter(
            start: entry.bedtime,
            minutes: entry.timeInBed.inMinutes,
            track: night
                ? BimbiPalette.lavender.withValues(alpha: .22)
                : BimbiPalette.paper,
            arc: night ? BimbiPalette.darkAccent : scheme.primary,
          ),
          child: Center(
            child: Text(
              '$h:${m.toString().padLeft(2, '0')}',
              style: context.text.titleLarge?.copyWith(
                fontSize: 24,
                color: night ? c.onNight : c.onAccentTint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NightDialPainter extends CustomPainter {
  _NightDialPainter({
    required this.start,
    required this.minutes,
    required this.track,
    required this.arc,
  });
  final DateTime start;
  final int minutes;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ring, 0, 2 * math.pi, false, paint..color = track);
    final startMinute = (start.hour % 12) * 60 + start.minute;
    final from = startMinute / 720 * 2 * math.pi - math.pi / 2;
    final sweep = math.min(minutes, 719) / 720 * 2 * math.pi;
    canvas.drawArc(ring, from, sweep, false, paint..color = arc);
  }

  @override
  bool shouldRepaint(_NightDialPainter old) =>
      old.start != start ||
      old.minutes != minutes ||
      old.track != track ||
      old.arc != arc;
}

class _NightTiles extends ConsumerWidget {
  const _NightTiles({required this.last});
  final SleepEntry last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wake = ref.watch(lastWakeProvider);
    final phoneUse = ref.watch(phoneUseInBedProvider).value;
    final sameMorning =
        wake != null &&
        wake.completedAt.year == last.wake.year &&
        wake.completedAt.month == last.wake.month &&
        wake.completedAt.day == last.wake.day;
    final tiles = [
      MetricTile(
        icon: BimbiIcons.bedtime,
        value: _clock(context, last.bedtime),
        label: 'Went to bed',
      ),
      MetricTile(
        icon: BimbiIcons.wakeUp,
        value: _clock(context, last.wake),
        label: 'Woke up',
      ),
      if (sameMorning)
        MetricTile(
          icon: BimbiIcons.alarm,
          value: '${wake.snoozes}',
          label: wake.snoozes == 1 ? 'Snooze' : 'Snoozes',
        ),
      if (phoneUse != null)
        MetricTile(
          icon: BimbiIcons.phoneFree,
          value: phoneUse == 0 ? 'None' : '$phoneUse min',
          label: 'Phone use in bed',
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns =
            box.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 24
            ? 1
            : 2;
        final width = (box.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final week = ref.watch(sleepWeekProvider);
    final longest = week.entries.values.fold<int>(
      8 * 60,
      (m, e) => math.max(m, e.timeInBed.inMinutes),
    );
    final summary = [
      for (final d in week.days)
        '${_weekdays[d.weekday - 1]}: '
            '${week.entries[d] == null ? 'no entry' : formatHoursMinutes(week.entries[d]!.timeInBed)}',
    ].join('; ');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BimbiRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: BimbiSpace.sm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'This week',
                  style: context.text.titleLarge?.copyWith(fontSize: 20),
                ),
              ),
              Text(
                week.average == null
                    ? 'No entries yet'
                    : 'Avg ${formatHoursMinutes(week.average!)}',
                style: context.text.labelMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Time in bed this week. $summary',
            excludeSemantics: true,
            child: SizedBox(
              height: 112,
              child: week.entries.isEmpty
                  ? Stack(
                      children: [
                        Positioned.fill(child: _bars(context, week, longest)),
                        Center(
                          child: Text(
                            'Log a few nights to see your week.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium?.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _bars(context, week, longest),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bars(BuildContext context, SleepWeek week, int longest) {
    final c = context.bimbi;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, d) in week.days.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 26,
                  height: week.entries[d] == null
                      ? 6
                      : math.max(
                          10,
                          86 * week.entries[d]!.timeInBed.inMinutes / longest,
                        ),
                  decoration: BoxDecoration(
                    color: i == 6 && week.entries[d] != null
                        ? scheme.primary
                        : c.accentTint.withValues(
                            alpha: week.entries[d] == null ? .6 : 1,
                          ),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _weekdays[d.weekday - 1][0],
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: i == 6 ? c.text : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HonestyCard extends StatelessWidget {
  const _HonestyCard();

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.accentTint,
          borderRadius: BimbiRadius.cardBorder,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: const BimbiIcon(BimbiIcons.info, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time in bed, as you log it',
                    style: context.text.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Bimbi doesn\'t measure sleep stages or score your night.',
                    style: context.text.bodyMedium?.copyWith(
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

class _Diary extends ConsumerWidget {
  const _Diary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final entries = ref.watch(sleepDiaryProvider);
    final sync = ref.watch(sleepSyncProvider);
    final status = switch (sync.phase) {
      SyncPhase.local => 'Saved on this device',
      SyncPhase.synced => 'Synced',
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.offline =>
        sync.pending == 0 ? 'Offline' : 'Offline · ${sync.pending} to sync',
      SyncPhase.unavailable => 'Sync unavailable',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: BimbiSpace.sm,
            children: [
              Semantics(
                header: true,
                child: Text('Your nights', style: context.text.headlineSmall),
              ),
              Text(
                status,
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (entries.isEmpty)
          Text(
            'Nights you log appear here.',
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          ),
        for (final e in entries.take(14)) ...[
          BimbiCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            onTap: () => showDiarySheet(context, ref, editing: e),
            semanticLabel:
                '${nightRange(e)}, ${formatHoursMinutes(e.timeInBed)} in bed. Edit',
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nightRange(e),
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_clock(context, e.bedtime)} to ${_clock(context, e.wake)}'
                        '${e.note == null ? '' : ' · ${e.note}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BimbiSpace.sm),
                Text(
                  formatHoursMinutes(e.timeInBed),
                  style: context.text.titleLarge?.copyWith(fontSize: 18),
                ),
                const SizedBox(width: 4),
                const BimbiIcon(BimbiIcons.chevronRight, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
