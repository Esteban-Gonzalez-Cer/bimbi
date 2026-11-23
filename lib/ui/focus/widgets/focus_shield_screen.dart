import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../domain/models/focus_shield.dart';
import '../view_models/focus_shield.dart';
import 'focus_dial.dart';

/// Search text for the app list.
class _Query extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value.trim().toLowerCase();
}

final _queryProvider = NotifierProvider.autoDispose<_Query, String>(_Query.new);

/// Focus shield and daily limits. A gentle pause screen over chosen apps,
/// not a lock: the copy says so, and Android settings can always turn it off.
class FocusShieldScreen extends ConsumerWidget {
  const FocusShieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final status = ref.watch(shieldStatusProvider);
    final expanded = WindowScope.of(context).isExpanded;
    final s = status.value;
    final intro = <Widget>[
      const _Intro(),
      if (s != null) _Permissions(status: s),
    ];
    final apps = <Widget>[
      if (s != null) _AppList(status: s),
      if (s != null && s.hasChoices) _TurnOff(status: s),
    ];

    Widget body;
    if (status.hasError && s == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(BimbiSpace.lg),
          child: EmptyState(
            title: 'Shield unavailable',
            message: 'The Focus shield needs Android. Focus still works.',
          ),
        ),
      );
    } else if (s == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (expanded) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Column(children: intro)),
              Expanded(child: _Column(children: apps)),
            ],
          ),
        ),
      );
    } else {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _Column(children: [...intro, ...apps]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to Focus',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const BimbiIcon(BimbiIcons.chevronLeft),
        ),
        title: Text(
          'Focus shield',
          key: PageHeader.titleKey,
          style: context.text.headlineSmall,
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
    itemCount: children.length,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, i) => children[i],
  );
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return BimbiCard(
      color: c.accentTint,
      borderColor: c.accentTint,
      padding: const EdgeInsets.all(BimbiSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A gentle pause, not a lock',
                  style: context.text.titleLarge?.copyWith(
                    color: c.onAccentTint,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bimbi covers the apps you choose with a pause screen while '
                  'you focus, or after their daily limit. You can turn it off '
                  'anytime here or in Android settings. App use stays on this '
                  'device.',
                  style: context.text.bodyMedium?.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: BimbiSpace.sm),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BimbiPalette.lightBackground.withValues(alpha: .68),
            ),
            child: const BimbiBuddy(
              size: 84,
              mood: BuddyMood.thinking,
              glow: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _Permissions extends ConsumerWidget {
  const _Permissions({required this.status});
  final ShieldStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final actions = ref.read(shieldActionsProvider);
    Widget row({
      required BimbiIcons icon,
      required String title,
      required String detail,
      required bool granted,
      required VoidCallback onAllow,
    }) => MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BimbiSpace.xs),
            granted
                ? const StatusPill('Allowed', tone: PillTone.success)
                : OutlinedButton(
                    onPressed: onAllow,
                    child: const Text('Allow'),
                  ),
          ],
        ),
      ),
    );

    final stopped = status.lastStop == 'permission_revoked' && !status.ready;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                  'Android access',
                  style: context.text.titleLarge?.copyWith(fontSize: 20),
                ),
              ),
              StatusPill(
                status.ready ? 'Shield ready' : 'Shield off',
                tone: status.ready ? PillTone.success : PillTone.neutral,
              ),
            ],
          ),
          if (stopped)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Access was turned off, so the shield stopped. Allow it again '
                'to resume.',
                style: context.text.bodyMedium?.copyWith(color: c.danger),
              ),
            ),
          const SizedBox(height: 4),
          row(
            icon: BimbiIcons.phoneFree,
            title: 'Usage Access',
            detail: 'To see which app is open and today\'s minutes.',
            granted: status.usageAccess,
            onAllow: actions.openUsageSettings,
          ),
          row(
            icon: BimbiIcons.shield,
            title: 'Display over other apps',
            detail: 'To show the pause screen over a chosen app.',
            granted: status.overlay,
            onAllow: actions.openOverlaySettings,
          ),
        ],
      ),
    );
  }
}

class _TurnOff extends ConsumerWidget {
  const _TurnOff({required this.status});
  final ShieldStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    onPressed: () => ref.read(shieldActionsProvider).clearAll(status),
    icon: const BimbiIcon(BimbiIcons.close, size: 20),
    label: const Text('Turn off the shield for all apps'),
  );
}

class _AppList extends ConsumerWidget {
  const _AppList({required this.status});
  final ShieldStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final apps = ref.watch(shieldAppsProvider);
    final query = ref.watch(_queryProvider);
    final chosen = status.focusApps.length + status.limits.length;

    final list = apps.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(BimbiSpace.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        'Bimbi could not list your apps.',
        style: context.text.bodyMedium?.copyWith(color: c.textMuted),
      ),
      data: (all) {
        bool picked(ShieldApp a) =>
            status.focusApps.contains(a.package) ||
            status.limits.containsKey(a.package);
        final shown =
            [
              for (final a in all)
                if (query.isEmpty || a.label.toLowerCase().contains(query)) a,
            ]..sort((a, b) {
              final byPick = (picked(b) ? 1 : 0) - (picked(a) ? 1 : 0);
              if (byPick != 0) return byPick;
              final byUse =
                  (status.todayMinutes[b.package] ?? 0) -
                  (status.todayMinutes[a.package] ?? 0);
              if (byUse != 0) return byUse;
              return a.label.toLowerCase().compareTo(b.label.toLowerCase());
            });
        if (shown.isEmpty) {
          return Text(
            query.isEmpty ? 'No apps to show.' : 'No apps match "$query".',
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          );
        }
        return Column(
          children: [
            for (final a in shown) ...[
              _AppTile(app: a, status: status),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: BimbiSpace.sm,
          children: [
            Semantics(
              header: true,
              child: Text('Your apps', style: context.text.headlineSmall),
            ),
            Text(
              chosen == 0
                  ? 'None chosen yet'
                  : '${status.focusApps.length} in Focus · '
                        '${status.limits.length} with a limit',
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(hintText: 'Search apps'),
          textInputAction: TextInputAction.search,
          onChanged: ref.read(_queryProvider.notifier).set,
        ),
        const SizedBox(height: 12),
        list,
      ],
    );
  }
}

class _AppTile extends ConsumerWidget {
  const _AppTile({required this.app, required this.status});
  final ShieldApp app;
  final ShieldStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final actions = ref.read(shieldActionsProvider);
    final inFocus = status.focusApps.contains(app.package);
    final limit = status.limits[app.package];
    final today = status.todayMinutes[app.package];
    final over = limit != null && today != null && today >= limit;
    final usage = !status.usageAccess
        ? null
        : today == null || today == 0
        ? 'Not used today'
        : '${formatMinutes(today)} today';

    Future<void> chooseLimit() async {
      ref.read(limitDraftProvider.notifier).start(limit);
      final picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => LimitSheet(app: app, current: limit),
      );
      if (picked == null) return;
      await actions.setLimit(status, app.package, picked == 0 ? null : picked);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
          color: inFocus || limit != null
              ? c.link.withValues(alpha: .35)
              : c.card,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: app.icon == null
                    ? Container(
                        width: 40,
                        height: 40,
                        color: c.accentTint,
                        alignment: Alignment.center,
                        child: Text(
                          app.label.isEmpty ? '?' : app.label[0],
                          style: context.text.titleMedium,
                        ),
                      )
                    : Image.memory(
                        app.icon!,
                        width: 40,
                        height: 40,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (usage != null)
                      Text(
                        over ? '$usage · paused until midnight' : usage,
                        style: context.text.bodyMedium?.copyWith(
                          color: over ? c.danger : c.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: BimbiSpace.sm,
            runSpacing: 4,
            children: [
              Semantics(
                toggled: inFocus,
                label: 'Pause ${app.label} during Focus',
                excludeSemantics: true,
                onTap: () =>
                    actions.pauseDuringFocus(status, app.package, !inFocus),
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: () =>
                      actions.pauseDuringFocus(status, app.package, !inFocus),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: inFocus,
                          onChanged: (on) =>
                              actions.pauseDuringFocus(status, app.package, on),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pause during Focus',
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: chooseLimit,
                icon: const BimbiIcon(BimbiIcons.alarm, size: 18),
                label: Text(
                  limit == null
                      ? 'Daily limit: off'
                      : 'Daily limit: ${formatMinutes(limit)}',
                  semanticsLabel: limit == null
                      ? 'Daily limit for ${app.label}: off. Change'
                      : 'Daily limit for ${app.label}: ${formatMinutes(limit)}. Change',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hours and minutes typed in the daily-limit sheet.
class LimitDraft extends Notifier<(int, int)> {
  @override
  (int, int) build() => (0, 30);

  void start(int? minutes) {
    final m = minutes ?? 30;
    state = (m ~/ 60, m % 60);
  }

  void hours(String text) => state = (int.tryParse(text.trim()) ?? 0, state.$2);
  void minutes(String text) =>
      state = (state.$1, int.tryParse(text.trim()) ?? 0);
}

final limitDraftProvider = NotifierProvider<LimitDraft, (int, int)>(
  LimitDraft.new,
);

/// Any daily limit from 1 minute to 23 h 59 min, typed as hours + minutes.
/// Pops the total in minutes, or 0 to remove the limit.
class LimitSheet extends ConsumerWidget {
  const LimitSheet({super.key, required this.app, required this.current});
  final ShieldApp app;
  final int? current;

  static const maxMinutes = 23 * 60 + 59;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final (h, m) = ref.watch(limitDraftProvider);
    final draft = ref.read(limitDraftProvider.notifier);
    final total = h * 60 + m;
    final error = h < 0 || h > 23
        ? 'Hours go from 0 to 23.'
        : m < 0 || m > 59
        ? 'Minutes go from 0 to 59.'
        : total < 1
        ? 'Set at least 1 minute.'
        : null;
    final valid = error == null && total <= maxMinutes;

    Widget field(String label, int value, ValueChanged<String> onChanged) =>
        Expanded(
          child: TextFormField(
            initialValue: '$value',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: context.text.headlineMedium,
            decoration: InputDecoration(labelText: label, counterText: ''),
            onChanged: onChanged,
          ),
        );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 +
            (MediaQuery.viewInsetsOf(context).bottom >
                    MediaQuery.viewPaddingOf(context).bottom
                ? MediaQuery.viewInsetsOf(context).bottom
                : MediaQuery.viewPaddingOf(context).bottom),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Daily limit for ${app.label}',
                  style: context.text.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'After this much use today, Bimbi pauses the app until '
                'midnight.',
                style: context.text.bodyMedium?.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: BimbiSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field('Hours', h, draft.hours),
                  const SizedBox(width: BimbiSpace.sm),
                  field('Minutes', m, draft.minutes),
                ],
              ),
              const SizedBox(height: BimbiSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  error ?? 'Limit: ${formatMinutes(total)} a day',
                  style: context.text.titleLarge?.copyWith(
                    fontSize: 20,
                    color: error == null
                        ? null
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: BimbiSpace.md),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.of(context).pop(total)
                    : null,
                child: const Text('Save limit'),
              ),
              if (current != null)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(0),
                  child: const Text('Remove limit'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
