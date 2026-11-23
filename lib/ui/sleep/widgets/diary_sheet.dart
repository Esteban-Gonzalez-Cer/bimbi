import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../core/clock.dart';
import '../../../domain/models/sleep_entry.dart';
import '../view_models/sleep_diary.dart';

/// Values in the open diary sheet.
@immutable
class DiaryForm {
  const DiaryForm({
    required this.wakeDay,
    this.bed = const TimeOfDay(hour: 23, minute: 0),
    this.wake = const TimeOfDay(hour: 7, minute: 0),
    this.note = '',
    this.editing = false,
    this.fromAlarm,
  });

  final DateTime wakeDay;
  final TimeOfDay bed;
  final TimeOfDay wake;
  final String note;
  final bool editing;

  /// Set when the wake time was suggested by today's finished alarm.
  final LastWake? fromAlarm;

  SleepEntry get entry => entryFromTimes(
    wakeDay: wakeDay,
    bedHour: bed.hour,
    bedMinute: bed.minute,
    wakeHour: wake.hour,
    wakeMinute: wake.minute,
    note: note,
  );

  DiaryForm copyWith({TimeOfDay? bed, TimeOfDay? wake, String? note}) =>
      DiaryForm(
        wakeDay: wakeDay,
        bed: bed ?? this.bed,
        wake: wake ?? this.wake,
        note: note ?? this.note,
        editing: editing,
        fromAlarm: wake == null ? fromAlarm : null,
      );
}

class DiaryFormController extends Notifier<DiaryForm> {
  @override
  DiaryForm build() => DiaryForm(wakeDay: ref.read(clockProvider)());

  /// Opens with an existing night, or a new one for today with the wake time
  /// taken from this morning's finished alarm when there is one.
  void start({SleepEntry? editing, LastWake? alarm}) {
    final now = ref.read(clockProvider)();
    if (editing != null) {
      state = DiaryForm(
        wakeDay: editing.day,
        bed: TimeOfDay.fromDateTime(editing.bedtime),
        wake: TimeOfDay.fromDateTime(editing.wake),
        note: editing.note ?? '',
        editing: true,
      );
      return;
    }
    state = DiaryForm(
      wakeDay: now,
      wake: alarm == null
          ? const TimeOfDay(hour: 7, minute: 0)
          : TimeOfDay.fromDateTime(alarm.completedAt),
      fromAlarm: alarm,
    );
  }

  void setBed(TimeOfDay t) => state = state.copyWith(bed: t);
  void setWake(TimeOfDay t) => state = state.copyWith(wake: t);
  void setNote(String text) => state = state.copyWith(note: text);
}

final diaryFormProvider = NotifierProvider<DiaryFormController, DiaryForm>(
  DiaryFormController.new,
);

Future<void> showDiarySheet(
  BuildContext context,
  WidgetRef ref, {
  SleepEntry? editing,
}) {
  ref
      .read(diaryFormProvider.notifier)
      .start(editing: editing, alarm: ref.read(lastWakeProvider));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const DiarySheet(),
  );
}

class DiarySheet extends ConsumerWidget {
  const DiarySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final loc = MaterialLocalizations.of(context);
    final form = ref.watch(diaryFormProvider);
    final actions = ref.read(diaryFormProvider.notifier);
    final entry = form.entry;

    Future<void> pick(bool bedtime) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: bedtime ? form.bed : form.wake,
        helpText: bedtime ? 'Went to bed' : 'Woke up',
      );
      if (picked == null) return;
      bedtime ? actions.setBed(picked) : actions.setWake(picked);
    }

    Widget row(String label, BimbiIcons icon, TimeOfDay t, bool isBed) =>
        BimbiCard(
          onTap: () => pick(isBed),
          semanticLabel: '$label, ${loc.formatTimeOfDay(t)}. Change',
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                child: BimbiIcon(icon, size: 20),
              ),
              const SizedBox(width: 12),
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
        // Keyboard, or the navigation bar / Samsung taskbar when it is closed.
        BimbiSpace.lg +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  form.editing ? 'Edit night' : 'Last night',
                  style: context.text.headlineMedium,
                ),
              ),
              Text(
                'Wake day: ${loc.formatFullDate(form.wakeDay)}',
                style: context.text.bodyMedium?.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: BimbiSpace.md),
              row('Went to bed', BimbiIcons.bedtime, form.bed, true),
              const SizedBox(height: 10),
              row('Woke up', BimbiIcons.wakeUp, form.wake, false),
              if (form.fromAlarm != null) ...[
                const SizedBox(height: 6),
                Text(
                  'From this morning\'s alarm · '
                  '${form.fromAlarm!.snoozes} '
                  '${form.fromAlarm!.snoozes == 1 ? 'snooze' : 'snoozes'}',
                  style: context.text.bodyMedium?.copyWith(color: c.textMuted),
                ),
              ],
              const SizedBox(height: BimbiSpace.md),
              TextFormField(
                initialValue: form.note,
                maxLength: SleepEntry.maxNote,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Late coffee, noisy street…',
                ),
                onChanged: actions.setNote,
              ),
              const SizedBox(height: BimbiSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  entry.isValid
                      ? 'Time in bed: ${formatHoursMinutes(entry.timeInBed)}'
                      : 'Time in bed must be under 16 hours.',
                  style: context.text.titleMedium?.copyWith(
                    color: entry.isValid
                        ? null
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: BimbiSpace.lg),
              FilledButton(
                onPressed: entry.isValid
                    ? () {
                        ref.read(sleepRowsProvider.notifier).save(entry);
                        Navigator.of(context).pop();
                      }
                    : null,
                child: Text(form.editing ? 'Save changes' : 'Save night'),
              ),
              if (form.editing) ...[
                const SizedBox(height: BimbiSpace.sm),
                TextButton(
                  onPressed: () {
                    ref.read(sleepRowsProvider.notifier).delete(entry);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Delete night'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
