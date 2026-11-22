import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../core/operation.dart';
import '../application/alarm_draft.dart';

/// Full-screen editor route used on compact and medium windows.
class AlarmEditorPage extends ConsumerWidget {
  const AlarmEditorPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) ref.read(alarmEditorProvider.notifier).close();
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: context.bimbi.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const BimbiIcon(BimbiIcons.close),
        ),
        title: Text('Alarm', style: context.text.titleLarge),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 48),
              child: AlarmEditor(embedded: false),
            ),
          ),
        ),
      ),
    ),
  );
}

class AlarmEditor extends ConsumerStatefulWidget {
  const AlarmEditor({super.key, required this.embedded});

  /// True inside the expanded two-pane layout (no route to pop).
  final bool embedded;

  @override
  ConsumerState<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends ConsumerState<AlarmEditor> {
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: ref.read(alarmEditorProvider)?.label);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _update(AlarmDraft draft) =>
      ref.read(alarmEditorProvider.notifier).update(draft);

  void _close() {
    ref.read(alarmEditorProvider.notifier).close();
    if (!widget.embedded) Navigator.of(context).maybePop();
  }

  Future<void> _pickTime(AlarmDraft draft) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: draft.time,
      helpText: 'Wake-up time',
    );
    if (picked != null) _update(draft.copyWith(time: picked));
  }

  Future<void> _save(AlarmDraft draft) async {
    final label = _label.text.trim().isEmpty ? 'Wake up' : _label.text.trim();
    final toSave = draft.copyWith(label: label);
    var saved = false;
    await ref.read(operationProvider.notifier).run(() async {
      final result = await ref.read(alarmActionsProvider).save(toSave);
      saved = true;
      return result;
    });
    if (saved && mounted) _close();
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep alarm'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    var deleted = false;
    await ref.read(operationProvider.notifier).run(() async {
      final result = await ref.read(alarmActionsProvider).delete(id);
      deleted = true;
      return result;
    });
    if (deleted && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(alarmEditorProvider);
    if (draft == null) return const SizedBox.shrink();
    final busy = ref.watch(operationProvider).busy;
    final c = context.bimbi;
    return BimbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.embedded) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Edit alarm', style: context.text.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Close editor',
                  onPressed: _close,
                  icon: const BimbiIcon(BimbiIcons.close),
                ),
              ],
            ),
            const SizedBox(height: BimbiSpace.xs),
          ],
          Semantics(
            button: true,
            label: 'Wake-up time',
            child: InkWell(
              borderRadius: BimbiRadius.inputBorder,
              onTap: () => _pickTime(draft),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: BimbiSpace.md),
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BimbiRadius.inputBorder,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ClockText(
                    draft.time,
                    style: context.text.displayLarge,
                    color: c.onAccentTint,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: BimbiSpace.lg),
          TextField(
            controller: _label,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alarm label',
              helperText: 'Shown when the alarm rings',
              counterText: '',
            ),
          ),
          const SizedBox(height: BimbiSpace.lg),
          const SectionLabel('Repeat'),
          const SizedBox(height: BimbiSpace.xs),
          DayChips(
            selected: draft.days,
            onChanged: (d) => _update(draft.copyWith(days: d)),
          ),
          const SizedBox(height: BimbiSpace.xs),
          Text(describeDays(draft.days), style: context.text.bodySmall),
          const SizedBox(height: BimbiSpace.lg),
          const SectionLabel('Wake-up challenge'),
          const SizedBox(height: BimbiSpace.xs),
          WakeMissionSelector(
            value: draft.mission,
            onChanged: (m) => _update(draft.copyWith(mission: m)),
          ),
          if (draft.mission == WakeMission.none) ...[
            const SizedBox(height: BimbiSpace.xs),
            const Text('Choose a challenge to save this alarm.'),
          ],
          const SizedBox(height: BimbiSpace.md),
          const SectionLabel('Difficulty'),
          const SizedBox(height: BimbiSpace.xs),
          Wrap(
            spacing: BimbiSpace.xs,
            runSpacing: BimbiSpace.xs,
            children: [
              for (final difficulty in WakeDifficulty.values)
                ChoiceChip(
                  label: Text(difficulty.label),
                  selected: draft.difficulty == difficulty,
                  onSelected: (_) =>
                      _update(draft.copyWith(difficulty: difficulty)),
                ),
            ],
          ),
          const SizedBox(height: BimbiSpace.xl),
          FilledButton(
            onPressed: busy || draft.mission == WakeMission.none
                ? null
                : () => _save(draft),
            child: const Text('Save alarm'),
          ),
          const SizedBox(height: BimbiSpace.xs),
          if (draft.id case final id?)
            TextButton(
              onPressed: busy ? null : () => _delete(id),
              child: const Text('Delete alarm'),
            ),
          TextButton(onPressed: _close, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
