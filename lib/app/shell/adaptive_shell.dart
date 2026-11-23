import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/operation.dart';
import '../../core/platform.dart';
import '../../features/auth/auth_adapter.dart';
import '../../features/profile/application/cloud_profile.dart';
import '../../features/notifications/messaging.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/running/presentation/running_page.dart';
import '../../features/running/tracking.dart';
import '../../ui/focus/view_models/focus_session.dart';
import '../../ui/focus/view_models/focus_shield.dart';
import '../../ui/focus/widgets/focus_screen.dart';
import '../../ui/home/widgets/home_screen.dart';
import '../../ui/sleep/view_models/sleep_diary.dart';
import '../../ui/sleep/widgets/sleep_screen.dart';
import '../design_system/design_system.dart';
import 'layout.dart';

/// Keep the original destination indexes stable for FCM payloads and Back.
enum AppDestination {
  alarm('Alarms', BimbiIcons.alarm),
  sleep('Sleep', BimbiIcons.bedtime),
  focus('Focus', BimbiIcons.focus),
  running('Running', BimbiIcons.steps),
  profile('Profile', BimbiIcons.profile);

  const AppDestination(this.label, this.icon);
  final String label;
  final BimbiIcons icon;
}

/// Phones use a floating dock. Wider windows use a labeled rail.
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});
  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () => unawaited(ref.read(trackingProvider.notifier).stop()),
      onHide: () => unawaited(ref.read(trackingProvider.notifier).stop()),
      onResume: () {
        ref.invalidate(capabilitiesProvider);
        ref.invalidate(shieldStatusProvider);
        unawaited(_refreshAccount());
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refreshAccount() async {
    final auth = ref.read(authAdapterProvider);
    if (auth?.user == null) return;
    try {
      await auth!.reload().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Use the restored session and cached photo while disconnected.
    }
    if (mounted) await ref.read(cloudProfileProvider.notifier).refreshPhoto();
  }

  void _select(int index) {
    ref.read(destinationProvider.notifier).select(index);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the profile coordinator active across tabs so account changes
    // always retire listeners and cached media.
    ref.watch(cloudProfileProvider.select((profile) => profile.uid));
    // Diary and Focus history sync for verified accounts while the app runs.
    ref.watch(sleepSyncProvider.select((status) => status.phase));
    ref.watch(focusSyncProvider.select((status) => status.phase));
    ref.watch(focusShieldLinkProvider);
    final selected = ref.watch(destinationProvider);
    final message = ref.watch(messagingProvider);
    ref.listen(destinationProvider, (previous, next) {
      if (next == AppDestination.profile.index) {
        unawaited(ref.read(cloudProfileProvider.notifier).refreshPhoto());
      }
      if (previous == AppDestination.running.index &&
          next != AppDestination.running.index) {
        unawaited(ref.read(trackingProvider.notifier).stop());
      }
    });
    ref.listen(operationProvider, (previous, next) {
      if (next.busy || previous?.message == next.message) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.message)));
    });

    return PopScope(
      canPop: selected == AppDestination.alarm.index,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppDestination.alarm.index);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final window = WindowClass.fromWidth(constraints.maxWidth);
          final reduceMotion =
              MediaQuery.maybeDisableAnimationsOf(context) ?? false;
          final page = KeyedSubtree(
            key: ValueKey(selected),
            child: switch (AppDestination.values[selected]) {
              AppDestination.alarm => const HomeScreen(),
              AppDestination.sleep => const SleepScreen(),
              AppDestination.focus => const FocusScreen(),
              AppDestination.running => const RunningPage(),
              AppDestination.profile => const ProfilePage(),
            },
          );
          final body = Column(
            children: [
              if (message.startsWith('Foreground') ||
                  message.startsWith('Notification opened'))
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    window.gutter,
                    BimbiSpace.sm,
                    window.gutter,
                    0,
                  ),
                  child: InlineBanner(
                    title: 'Bimbi',
                    message: message,
                    liveRegion: true,
                  ),
                ),
              Expanded(
                child: reduceMotion
                    ? page
                    : AnimatedSwitcher(
                        duration: BimbiMotion.standard,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: page,
                      ),
              ),
            ],
          );
          return WindowScope(
            windowClass: window,
            child: Scaffold(
              bottomNavigationBar: window.isCompact
                  ? _BottomNav(selected: selected, onSelect: _select)
                  : null,
              body: SafeArea(
                bottom: !window.isCompact,
                child: window.isCompact
                    ? body
                    : Row(
                        children: [
                          _Rail(selected: selected, onSelect: _select),
                          Expanded(child: body),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(
        left: BimbiSpace.sm,
        right: BimbiSpace.sm,
        bottom: BimbiSpace.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: BimbiSpace.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BimbiRadius.cardBorder,
            border: Border.all(color: c.cardBorder),
            boxShadow: c.shadows,
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(27)),
              child: NavigationBar(
                height: 72,
                selectedIndex: selected,
                onDestinationSelected: onSelect,
                destinations: [
                  for (final d in AppDestination.values)
                    NavigationDestination(
                      icon: BimbiIcon(d.icon),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.cardBorder),
          borderRadius: BimbiRadius.cardBorder,
        ),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: NavigationRail(
                  selectedIndex: selected,
                  onDestinationSelected: onSelect,
                  groupAlignment: -1,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: BimbiSpace.xs),
                    child: BimbiBuddy(size: 56, glow: false),
                  ),
                  destinations: [
                    for (final d in AppDestination.values)
                      NavigationRailDestination(
                        icon: BimbiIcon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
