import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_page.dart';
import '../features/running/application/run_controller.dart';
import '../ui/notifications/view_models/notifications.dart';
import '../ui/notifications/widgets/message_banner.dart';
import 'design_system/design_system.dart';
import 'preferences.dart';
import 'shell/adaptive_shell.dart';
import 'theme/bimbi_theme.dart';

class BimbiApp extends ConsumerWidget {
  const BimbiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(onboardingProvider);
    final sunrise = ref.watch(appThemeProvider) == AppTheme.sunrise;
    // Keep account isolation and pending run sync active across tabs.
    if (onboarded) ref.watch(runControllerProvider.select((_) => null));
    return MaterialApp(
      title: 'Bimbi',
      debugShowCheckedModeBanner: false,
      // Sunrise is a Premium theme; the provider falls back to lavender
      // whenever no verified Premium pass is active.
      theme: BimbiTheme.light(sunrise: sunrise),
      darkTheme: BimbiTheme.dark(sunrise: sunrise),
      themeMode: ref.watch(themeModeProvider),
      navigatorKey: ref.watch(navigatorKeyProvider),
      // The foreground message banner floats over every route, so it shows
      // even while Plans, Notifications or a run's detail is open.
      builder: (context, child) =>
          onboarded ? _InboxLayer(child: child!) : child!,
      home: onboarded ? const AdaptiveShell() : const OnboardingPage(),
    );
  }
}

class _InboxLayer extends ConsumerWidget {
  const _InboxLayer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(inboxProvider);
    return Stack(
      children: [
        child,
        if (message != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BimbiSpace.md,
                  BimbiSpace.sm,
                  BimbiSpace.md,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Material(
                      type: MaterialType.transparency,
                      child: MessageBanner(message: message),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
