import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_page.dart';
import '../features/running/application/run_controller.dart';
import 'preferences.dart';
import 'shell/adaptive_shell.dart';
import 'theme/bimbi_theme.dart';

class BimbiApp extends ConsumerWidget {
  const BimbiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(onboardingProvider);
    // Keep account isolation and pending run sync active across tabs.
    if (onboarded) ref.watch(runControllerProvider.select((_) => null));
    return MaterialApp(
      title: 'Bimbi',
      debugShowCheckedModeBanner: false,
      theme: BimbiTheme.light(),
      darkTheme: BimbiTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: onboarded ? const AdaptiveShell() : const OnboardingPage(),
    );
  }
}
