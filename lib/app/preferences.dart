import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/entitlement_repository.dart';
import '../domain/models/plan.dart';

import 'theme/bimbi_tokens.dart';

/// Local, non-sensitive UI preferences. Overridden in `main` with the loaded
/// instance; when absent (tests, failures) values live in memory only.
final preferencesProvider = Provider<SharedPreferences?>((ref) => null);

abstract final class _Keys {
  static const appTheme = 'ui.app_theme';
  static const themeMode = 'ui.theme_mode';
  static const buddyColor = 'ui.buddy_color';
  static const displayName = 'ui.display_name';
  static const onboarding = 'ui.onboarding_done';
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(preferencesProvider)?.getString(_Keys.themeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(preferencesProvider)?.setString(_Keys.themeMode, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class BuddyColorController extends Notifier<BuddyColorPreset> {
  @override
  BuddyColorPreset build() {
    final stored = ref.watch(preferencesProvider)?.getString(_Keys.buddyColor);
    final preset = BuddyColorPreset.values.firstWhere(
      (p) => p.name == stored,
      orElse: () => BuddyColorPreset.lilac,
    );
    // A Plus colour is used only while a verified pass is active; the choice
    // is kept, so it returns when the pass is renewed.
    final unlocked = ref.watch(planTierProvider).includes(PlanTier.plus);
    return preset.plus && !unlocked ? BuddyColorPreset.lilac : preset;
  }

  void set(BuddyColorPreset preset) {
    if (preset.plus && !ref.read(planTierProvider).includes(PlanTier.plus)) {
      return;
    }
    state = preset;
    ref.read(preferencesProvider)?.setString(_Keys.buddyColor, preset.name);
  }
}

final buddyColorProvider =
    NotifierProvider<BuddyColorController, BuddyColorPreset>(
      BuddyColorController.new,
    );

/// What Bimbi calls the person. Stored on this device only.
class DisplayNameController extends Notifier<String> {
  @override
  String build() =>
      ref.watch(preferencesProvider)?.getString(_Keys.displayName) ?? '';

  void set(String value) {
    final name = value.trim();
    state = name.length > 40 ? name.substring(0, 40) : name;
    ref.read(preferencesProvider)?.setString(_Keys.displayName, state);
  }
}

final displayNameProvider = NotifierProvider<DisplayNameController, String>(
  DisplayNameController.new,
);

class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(preferencesProvider)?.getBool(_Keys.onboarding) ?? false;

  void complete() {
    state = true;
    ref.read(preferencesProvider)?.setBool(_Keys.onboarding, true);
  }

  void restart() {
    state = false;
    ref.read(preferencesProvider)?.setBool(_Keys.onboarding, false);
  }
}

/// True once onboarding was completed or skipped.
final onboardingProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);

/// App colour themes. Sunrise is the original Brand Buddy palette and comes
/// with a verified Premium pass.
enum AppTheme {
  lavender('Lavender'),
  sunrise('Sunrise');

  const AppTheme(this.label);
  final String label;
}

class AppThemeController extends Notifier<AppTheme> {
  @override
  AppTheme build() {
    final stored = ref.watch(preferencesProvider)?.getString(_Keys.appTheme);
    final theme = AppTheme.values.firstWhere(
      (t) => t.name == stored,
      orElse: () => AppTheme.lavender,
    );
    final premium = ref.watch(planTierProvider).includes(PlanTier.premium);
    return theme == AppTheme.sunrise && !premium ? AppTheme.lavender : theme;
  }

  void set(AppTheme theme) {
    if (theme == AppTheme.sunrise &&
        !ref.read(planTierProvider).includes(PlanTier.premium)) {
      return;
    }
    state = theme;
    ref.read(preferencesProvider)?.setString(_Keys.appTheme, theme.name);
  }
}

final appThemeProvider = NotifierProvider<AppThemeController, AppTheme>(
  AppThemeController.new,
);
