import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/clock.dart';
import '../../../data/repositories/collection_sync.dart';
import '../../../domain/models/focus_record.dart';
import '../../../domain/models/focus_shield.dart';
import '../view_models/focus_session.dart';
import '../view_models/focus_shield.dart';
import 'focus_dial.dart';
import 'focus_shield_screen.dart';

/// Focus: the timer up top, today's focus below, the optional shield and the
/// sessions you finished. Same language as Home and the Sleep report.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  static const _pad = EdgeInsets.fromLTRB(20, 28, 20, 32);

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, viewport) {
      final expanded = WindowScope.of(context).isExpanded;
      final top = <Widget>[
        const _Header(),
        _TimerCard(viewportHeight: viewport.maxHeight, compact: expanded),
      ];
      const details = <Widget>[_ShieldCard(), _Sessions()];
      if (expanded) {
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
    },
  );
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

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final now = ref.watch(clockProvider)();
    final running = ref.watch(focusProvider).phase == FocusPhase.running;
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
                  '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}',
                  style: context.text.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                ),
                Text(
                  'Focus',
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
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accentTint,
          ),
          child: BimbiBuddy(
            size: 50,
            mood: running ? BuddyMood.thinking : BuddyMood.happy,
            glow: false,
          ),
        ),
      ],
    );
  }
}

class _TimerCard extends ConsumerWidget {
  const _TimerCard({required this.viewportHeight, required this.compact});

  final double viewportHeight;

  /// Landscape tablets: the dial shares the height with the header.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(focusProvider);
    if (session.phase == FocusPhase.running) ref.watch(focusTickProvider);
    final now = ref.watch(clockProvider)();
    final controller = ref.read(focusProvider.notifier);
    final c = context.bimbi;
    final complete = session.isComplete(now);
    final idle = session.phase == FocusPhase.idle;
    final night = Theme.of(context).brightness == Brightness.dark;
    final fg = night ? c.onNight : c.onAccentTint;
    final muted = night ? c.onNightMuted : c.textMuted;
    String clock(DateTime t) =>
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(t),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
    final window = session.windowAt(now);
    final windowLabel = window == null
        ? null
        : 'Window ${window.$1 + 1} of ${session.windows.length}';
    final caption = complete
        ? 'Done!'
        : switch (session.phase) {
            FocusPhase.idle => 'minutes',
            FocusPhase.running => windowLabel ?? 'Focusing',
            FocusPhase.paused =>
              windowLabel == null ? 'Paused' : '$windowLabel · paused',
          };
    final ends = session.endsAt(now);
    final nextWindow = session.windowEnds(now).firstOrNull;
    final split = session.windows.length > 1;
    final status = complete
        ? 'Session complete. Nice work!'
        : idle && split
        ? 'Edit the windows to change the length'
        : idle
        ? 'Wind the ring to set your time'
        : session.phase == FocusPhase.paused
        ? 'Paused. Pick up where you left off.'
        : nextWindow != null
        ? 'Next window at ${clock(nextWindow)} · ends ${clock(ends!)}'
        : 'Ends at ${clock(ends!)}';

    final actions = <Widget>[
      if (idle)
        FilledButton.icon(
          onPressed: controller.start,
          icon: const BimbiIcon(BimbiIcons.play, onAccent: true),
          label: const Text('Start focus'),
        )
      else if (complete)
        FilledButton.icon(
          onPressed: controller.end,
          icon: const BimbiIcon(BimbiIcons.check, onAccent: true),
          label: const Text('Finish'),
        )
      else ...[
        session.phase == FocusPhase.running
            ? FilledButton.icon(
                onPressed: controller.pause,
                icon: const BimbiIcon(BimbiIcons.pause, onAccent: true),
                label: const Text('Pause'),
              )
            : FilledButton.icon(
                onPressed: controller.start,
                icon: const BimbiIcon(BimbiIcons.play, onAccent: true),
                label: const Text('Resume'),
              ),
        OutlinedButton.icon(
          onPressed: controller.end,
          icon: const BimbiIcon(BimbiIcons.stop),
          label: const Text('End'),
        ),
      ],
    ];

    return BimbiCard(
      color: night ? c.night : c.accentTint,
      borderColor: night ? c.cardBorder : c.accentTint,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: LayoutBuilder(
        builder: (context, box) {
          // Leave room in the real viewport for the header, task and actions.
          final reserved = compact ? 385.0 : 340.0;
          final dialSize = math.min(
            math.min(300.0, box.maxWidth),
            math.max(148.0, viewportHeight - reserved),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskLabel(session: session, color: fg, muted: muted),
              const SizedBox(height: BimbiSpace.sm),
              Center(
                child: FocusDial(
                  size: dialSize,
                  target: session.target,
                  remaining: session.remaining(now),
                  centre: window == null || complete
                      ? null
                      : formatClock(window.$2),
                  caption: caption,
                  idle: idle,
                  windows: session.windows,
                  // A split fixes the length; change it in the windows editor.
                  onTargetChanged: idle && !split ? controller.setTarget : null,
                  onTypeMinutes: idle && !split
                      ? () => typeFocusMinutes(context, ref)
                      : null,
                ),
              ),
              const SizedBox(height: BimbiSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge?.copyWith(
                    fontSize: 22,
                    height: 1.2,
                    color: fg,
                  ),
                ),
              ),
              if (idle || session.windows.length > 1) ...[
                const SizedBox(height: BimbiSpace.sm),
                _Windows(session: session, editable: idle, muted: muted),
              ],
              const SizedBox(height: BimbiSpace.md),
              if (actions.length == 1)
                actions.single
              else
                Row(
                  children: [
                    Expanded(child: actions.first),
                    const SizedBox(width: BimbiSpace.sm),
                    Expanded(child: actions.last),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "What are you focusing on?" — editable while idle, shown while running.
class _TaskLabel extends ConsumerWidget {
  const _TaskLabel({
    required this.session,
    required this.color,
    required this.muted,
  });
  final FocusSession session;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.phase != FocusPhase.idle) {
      return Text(
        session.taskLabel ?? 'Focus session',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.titleLarge?.copyWith(color: color, height: 1.2),
      );
    }
    return TextFormField(
      key: const ValueKey('focus-task'),
      initialValue: session.taskLabel,
      maxLength: FocusSession.maxLabel,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'What are you focusing on?',
        counterText: '',
        isDense: true,
      ),
      onChanged: ref.read(focusProvider.notifier).setTaskLabel,
    );
  }
}

class _ShieldCard extends ConsumerWidget {
  const _ShieldCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final status = ref.watch(shieldStatusProvider).value;
    final (title, detail, action) = _describe(status);
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FocusShieldScreen()));
    return BimbiCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: open,
      semanticLabel: 'Focus shield. $title. $detail. $action',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentTint,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: const BimbiIcon(BimbiIcons.shield, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: context.text.bodyMedium?.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: BimbiSpace.xs),
          Text(action, style: context.text.labelLarge?.copyWith(color: c.link)),
          const BimbiIcon(BimbiIcons.chevronRight, size: 20),
        ],
      ),
    );
  }

  static (String, String, String) _describe(ShieldStatus? s) {
    if (s == null || !s.hasChoices) {
      return ('Focus shield', 'Pause chosen apps while you focus.', 'Set up');
    }
    if (!s.ready) {
      return ('Focus shield is off', 'Android access is needed.', 'Fix');
    }
    final parts = [
      if (s.focusApps.isNotEmpty)
        '${s.focusApps.length} ${s.focusApps.length == 1 ? 'app' : 'apps'} paused in Focus',
      if (s.limits.isNotEmpty)
        '${s.limits.length} daily ${s.limits.length == 1 ? 'limit' : 'limits'}',
    ];
    return ('Focus shield on', parts.join(' · '), 'Manage');
  }
}

class _Sessions extends ConsumerWidget {
  const _Sessions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final records = ref.watch(focusRecordsProvider);
    final sync = ref.watch(focusSyncProvider);
    final status = switch (sync.phase) {
      SyncPhase.local => 'Saved on this device',
      SyncPhase.synced => 'Synced',
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.offline =>
        sync.pending == 0 ? 'Offline' : 'Offline · ${sync.pending} to sync',
      SyncPhase.unavailable => 'Sync unavailable',
    };
    final loc = MaterialLocalizations.of(context);
    String time(DateTime t) => loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
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
                child: Text('Sessions', style: context.text.headlineSmall),
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
        if (records.isEmpty)
          Text(
            'Sessions you finish appear here.',
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          ),
        for (final r in records.take(8)) ...[
          MergeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.taskLabel ?? 'Focus session',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_weekdays[r.startedAt.weekday - 1]} ${r.startedAt.day} · '
                          '${time(r.startedAt)} · '
                          '${r.outcome == FocusOutcome.completed ? 'Completed' : 'Ended early'}',
                          style: context.text.bodyMedium?.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: BimbiSpace.sm),
                  Text(
                    formatHoursMinutes(r.duration),
                    style: context.text.titleLarge?.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Asks for exact minutes, e.g. 7. The dial itself moves in 5-minute steps.
Future<void> typeFocusMinutes(BuildContext context, WidgetRef ref) async {
  var text = '${ref.read(focusProvider).target.inMinutes}';
  final minutes = await showDialog<int>(
    context: context,
    builder: (dialog) {
      void submit() {
        final value = int.tryParse(text.trim());
        if (value != null &&
            value >= FocusSession.minTarget.inMinutes &&
            value <= FocusSession.maxTarget.inMinutes) {
          Navigator.of(dialog).pop(value);
        }
      }

      return AlertDialog(
        title: const Text('Focus length'),
        content: TextFormField(
          initialValue: text,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            helperText: '1 to 480 minutes',
            suffixText: 'min',
          ),
          onChanged: (value) => text = value,
          onFieldSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: const Text('Set')),
        ],
      );
    },
  );
  if (minutes != null) {
    ref
        .read(focusProvider.notifier)
        .setTarget(Duration(minutes: minutes), exact: true);
  }
}

/// The split into windows: chips under the dial, editable while idle.
class _Windows extends ConsumerWidget {
  const _Windows({
    required this.session,
    required this.editable,
    required this.muted,
  });
  final FocusSession session;
  final bool editable;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final current = session.windowAt(now)?.$1;
    if (session.windows.length < 2) {
      return Center(
        child: TextButton.icon(
          onPressed: () => showWindowsSheet(context, ref),
          icon: const BimbiIcon(BimbiIcons.plus, size: 20),
          label: const Text('Split into windows'),
        ),
      );
    }
    final c = context.bimbi;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, w) in session.windows.indexed)
              Semantics(
                label:
                    'Window ${i + 1}, ${formatMinutes(w)}'
                    '${!editable && i == current ? ', current' : ''}',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: !editable && i == current ? c.link : c.card,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Text(
                    formatMinutes(w),
                    style: context.text.labelLarge?.copyWith(
                      fontSize: 14,
                      color: !editable && i == current ? c.card : c.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (editable)
          TextButton(
            onPressed: () => showWindowsSheet(context, ref),
            child: const Text('Edit windows'),
          ),
      ],
    );
  }
}

/// Draft windows while the editor is open.
class WindowsDraft extends Notifier<List<int>> {
  @override
  List<int> build() => const [];

  void start(FocusSession session) {
    if (session.windows.length > 1) {
      state = [...session.windows];
      return;
    }
    // Start from two halves of the current length.
    final total = math.max(2, session.target.inMinutes);
    state = [total - total ~/ 2, total ~/ 2];
  }

  void set(int index, int minutes) => state = [
    for (final (i, w) in state.indexed)
      i == index
          ? minutes.clamp(1, FocusSession.maxTarget.inMinutes).toInt()
          : w,
  ];

  void add() {
    if (state.length >= FocusSession.maxWindows) return;
    state = [...state, 10];
  }

  void remove(int index) {
    if (state.length <= 2) return;
    state = [...state]..removeAt(index);
  }
}

final windowsDraftProvider = NotifierProvider<WindowsDraft, List<int>>(
  WindowsDraft.new,
);

Future<void> showWindowsSheet(BuildContext context, WidgetRef ref) {
  ref.read(windowsDraftProvider.notifier).start(ref.read(focusProvider));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const WindowsSheet(),
  );
}

class WindowsSheet extends ConsumerWidget {
  const WindowsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final windows = ref.watch(windowsDraftProvider);
    final draft = ref.read(windowsDraftProvider.notifier);
    final total = windows.fold<int>(0, (a, b) => a + b);
    final tooLong = total > FocusSession.maxTarget.inMinutes;
    final hasSplit = ref.watch(focusProvider).windows.length > 1;

    Future<void> type(int index) async {
      var text = '${windows[index]}';
      final value = await showDialog<int>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Window ${index + 1}'),
          content: TextFormField(
            initialValue: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutes',
              suffixText: 'min',
            ),
            onChanged: (v) => text = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(int.tryParse(text)),
              child: const Text('Set'),
            ),
          ],
        ),
      );
      if (value != null && value > 0) draft.set(index, value);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        BimbiSpace.lg,
        0,
        BimbiSpace.lg,
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
                  'Split into windows',
                  style: context.text.headlineMedium,
                ),
              ),
              Text(
                'Bimbi chimes when each window ends and keeps going.',
                style: context.text.bodyMedium?.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: BimbiSpace.md),
              for (final (i, w) in windows.indexed) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Window ${i + 1}',
                          style: context.text.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Window ${i + 1}: 5 minutes less',
                        onPressed: w > 1 ? () => draft.set(i, w - 5) : null,
                        icon: Text(
                          '−5',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: w > 1
                                ? c.text
                                : c.textMuted.withValues(alpha: .4),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => type(i),
                        child: Text(
                          formatMinutes(w),
                          semanticsLabel:
                              'Window ${i + 1}, ${formatMinutes(w)}. Type minutes',
                          style: context.text.titleLarge?.copyWith(
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Window ${i + 1}: 5 minutes more',
                        onPressed: () => draft.set(i, w + 5),
                        icon: const Text(
                          '+5',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove window ${i + 1}',
                        onPressed: windows.length > 2
                            ? () => draft.remove(i)
                            : null,
                        icon: const BimbiIcon(BimbiIcons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (windows.length < FocusSession.maxWindows)
                OutlinedButton.icon(
                  onPressed: draft.add,
                  icon: const BimbiIcon(BimbiIcons.plus, size: 20),
                  label: const Text('Add window'),
                ),
              const SizedBox(height: BimbiSpace.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  tooLong
                      ? 'Total ${formatMinutes(total)} · the most is 8 h'
                      : 'Total ${formatMinutes(total)}',
                  style: context.text.titleLarge?.copyWith(
                    fontSize: 22,
                    color: tooLong ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ),
              const SizedBox(height: BimbiSpace.md),
              FilledButton(
                onPressed: tooLong
                    ? null
                    : () {
                        ref.read(focusProvider.notifier).setWindows(windows);
                        Navigator.of(context).pop();
                      },
                child: const Text('Save windows'),
              ),
              if (hasSplit)
                TextButton(
                  onPressed: () {
                    ref.read(focusProvider.notifier).setWindows(const []);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Remove split'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
