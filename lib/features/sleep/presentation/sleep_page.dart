import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/clock.dart';
import '../application/sleep_diary.dart';

class SleepPage extends ConsumerWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = WindowScope.of(context);
    const header = PageHeader(
      title: 'Sleep',
      subtitle: 'Your self-reported diary',
    );
    if (window.isExpanded) {
      return const TwoPane(
        primary: [header, _LastNight(), _HonestyNote()],
        secondary: [_ThisWeek(), _DiaryList()],
      );
    }
    return const PageBody(
      children: [
        header,
        _LastNight(),
        _ThisWeek(),
        _HonestyNote(),
        _DiaryList(),
      ],
    );
  }
}

Future<void> showDiaryEntrySheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DiaryEntrySheet(),
    );

class _LastNight extends ConsumerWidget {
  const _LastNight();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(sleepDiaryProvider);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final last = entries.where((e) => e.day == today).firstOrNull;
    final c = context.bimbi;
    final loc = MaterialLocalizations.of(context);
    if (last == null) {
      return BuddyHeaderCard(
        night: true,
        mood: BuddyMood.sleepy,
        title: 'How was last night?',
        message: 'Add when you went to bed and woke up.',
        action: FilledButton(
          onPressed: () => showDiaryEntrySheet(context, ref),
          child: const Text('Add last night'),
        ),
      );
    }
    return BimbiCard(
      color: c.night,
      borderColor: c.night,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BimbiBuddy(mood: BuddyMood.happy, size: 88),
              const SizedBox(width: BimbiSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last night',
                      style: context.text.labelMedium?.copyWith(
                        color: c.onNightMuted,
                      ),
                    ),
                    Text(
                      formatHoursMinutes(last.timeInBed),
                      style: context.text.displaySmall?.copyWith(
                        color: c.onNight,
                      ),
                    ),
                    Text(
                      'Time in bed',
                      style: context.text.bodyMedium?.copyWith(
                        color: c.onNightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BimbiSpace.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  night: true,
                  icon: BimbiIcons.bedtime,
                  value: loc.formatTimeOfDay(
                    TimeOfDay.fromDateTime(last.bedtime),
                  ),
                  label: 'Bedtime',
                ),
              ),
              const SizedBox(width: BimbiSpace.sm),
              Expanded(
                child: StatTile(
                  night: true,
                  icon: BimbiIcons.wakeUp,
                  value: loc.formatTimeOfDay(TimeOfDay.fromDateTime(last.wake)),
                  label: 'Woke up',
                ),
              ),
            ],
          ),
          const SizedBox(height: BimbiSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: BimbiPalette.darkAccent,
              ),
              onPressed: () => showDiaryEntrySheet(context, ref),
              child: const Text('Edit entry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThisWeek extends ConsumerWidget {
  const _ThisWeek();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(sleepDiaryProvider);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final values = [
      for (final d in days)
        entries.where((e) => e.day == d).firstOrNull?.timeInBed,
    ];
    final logged = values.whereType<Duration>().toList();
    final average = logged.isEmpty
        ? null
        : Duration(
            minutes:
                logged.fold<int>(0, (s, d) => s + d.inMinutes) ~/ logged.length,
          );
    return BimbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('This week', style: context.text.headlineSmall),
              ),
              if (average != null)
                StatusPill(
                  'Avg ${formatHoursMinutes(average)}',
                  tone: PillTone.accent,
                ),
            ],
          ),
          const SizedBox(height: BimbiSpace.md),
          WeekBars(
            labels: [for (final d in days) weekdayLetters[d.weekday - 1]],
            values: values,
            highlight: 6,
          ),
          if (logged.isEmpty) ...[
            const SizedBox(height: BimbiSpace.sm),
            Text(
              'Your nights appear here as you log them.',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _HonestyNote extends StatelessWidget {
  const _HonestyNote();
  @override
  Widget build(BuildContext context) => const InlineBanner(
    icon: BimbiIcons.info,
    title: 'Self-reported, not measured',
    message:
        'Bimbi shows time in bed from your diary. It does not detect '
        'sleep stages or diagnose sleep.',
  );
}

class _DiaryList extends ConsumerWidget {
  const _DiaryList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(sleepDiaryProvider);
    final loc = MaterialLocalizations.of(context);
    return BimbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Diary', style: context.text.headlineSmall)),
              TextButton.icon(
                onPressed: () => showDiaryEntrySheet(context, ref),
                icon: BimbiIcon(BimbiIcons.plus),
                label: const Text('Add'),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BimbiSpace.sm),
              child: Text(
                'No entries yet.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.bimbi.textMuted,
                ),
              ),
            ),
          for (final e in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const BimbiIcon(BimbiIcons.diary),
              title: Text(loc.formatMediumDate(e.day)),
              subtitle: Text(
                '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(e.bedtime))} – '
                '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(e.wake))}',
              ),
              trailing: Text(
                formatHoursMinutes(e.timeInBed),
                style: context.text.titleSmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Transient form values for the diary sheet.
class DiaryFormController extends Notifier<(TimeOfDay, TimeOfDay)> {
  @override
  (TimeOfDay, TimeOfDay) build() => (
    const TimeOfDay(hour: 23, minute: 0),
    const TimeOfDay(hour: 7, minute: 0),
  );
  void setBed(TimeOfDay t) => state = (t, state.$2);
  void setWake(TimeOfDay t) => state = (state.$1, t);
}

final diaryFormProvider =
    NotifierProvider.autoDispose<DiaryFormController, (TimeOfDay, TimeOfDay)>(
      DiaryFormController.new,
    );

class _DiaryEntrySheet extends ConsumerWidget {
  const _DiaryEntrySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = MaterialLocalizations.of(context);
    final (bed, wake) = ref.watch(diaryFormProvider);
    final form = ref.read(diaryFormProvider.notifier);
    final now = ref.read(clockProvider)();
    final entry = entryFromTimes(
      wakeDay: now,
      bedHour: bed.hour,
      bedMinute: bed.minute,
      wakeHour: wake.hour,
      wakeMinute: wake.minute,
    );
    Future<void> pick(bool bedtime) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: bedtime ? bed : wake,
        helpText: bedtime ? 'Went to bed' : 'Woke up',
      );
      if (picked == null) return;
      bedtime ? form.setBed(picked) : form.setWake(picked);
    }

    Widget row(String label, BimbiIcons icon, TimeOfDay t, bool isBed) =>
        BimbiCard(
          onTap: () => pick(isBed),
          semanticLabel: '$label, ${loc.formatTimeOfDay(t)}',
          padding: const EdgeInsets.all(BimbiSpace.md),
          child: Row(
            children: [
              BimbiIcon(icon),
              const SizedBox(width: BimbiSpace.sm),
              Expanded(child: Text(label, style: context.text.titleMedium)),
              ClockText(t, style: context.text.headlineMedium),
            ],
          ),
        );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        BimbiSpace.lg,
        0,
        BimbiSpace.lg,
        BimbiSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Last night', style: context.text.headlineMedium),
          const SizedBox(height: BimbiSpace.md),
          row('Went to bed', BimbiIcons.bedtime, bed, true),
          const SizedBox(height: BimbiSpace.sm),
          row('Woke up', BimbiIcons.wakeUp, wake, false),
          const SizedBox(height: BimbiSpace.md),
          Text(
            'Time in bed: ${formatHoursMinutes(entry.timeInBed)}',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: BimbiSpace.lg),
          FilledButton(
            onPressed: () {
              ref.read(sleepDiaryProvider.notifier).save(entry);
              Navigator.of(context).pop();
            },
            child: const Text('Save entry'),
          ),
        ],
      ),
    );
  }
}
