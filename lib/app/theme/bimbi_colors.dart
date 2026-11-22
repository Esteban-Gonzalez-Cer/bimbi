import 'package:flutter/material.dart';

import 'bimbi_tokens.dart';

/// Semantic brand roles that Material's [ColorScheme] does not cover.
@immutable
class BimbiColors extends ThemeExtension<BimbiColors> {
  const BimbiColors({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.inputBorder,
    required this.text,
    required this.textMuted,
    required this.link,
    required this.accentTint,
    required this.onAccentTint,
    required this.success,
    required this.successTint,
    required this.danger,
    required this.dangerTint,
    required this.night,
    required this.onNight,
    required this.onNightMuted,
    required this.navActive,
    required this.navInactive,
    required this.focusRing,
    required this.reward,
    required this.shadows,
  });

  final Color background;
  final Color card;
  final Color cardBorder;
  final Color inputBorder;
  final Color text;
  final Color textMuted;

  /// High-contrast accent for text and links.
  final Color link;

  /// Lavender highlight behind active nav icons, chips and badges.
  final Color accentTint;
  final Color onAccentTint;
  final Color success;
  final Color successTint;
  final Color danger;
  final Color dangerTint;

  /// Bedtime surfaces stay Night in both themes.
  final Color night;
  final Color onNight;
  final Color onNightMuted;
  final Color navActive;
  final Color navInactive;
  final Color focusRing;

  /// Honey. Reserved for Phase 9 rewards; no core screen uses it.
  final Color reward;
  final List<BoxShadow> shadows;

  static const light = BimbiColors(
    background: BimbiPalette.lightBackground,
    card: BimbiPalette.paper,
    cardBorder: BimbiPalette.lightLine,
    inputBorder: BimbiPalette.inputLine,
    text: BimbiPalette.ink,
    textMuted: BimbiPalette.inkSoft,
    link: BimbiPalette.lightAccent,
    accentTint: BimbiPalette.lightTint,
    onAccentTint: BimbiPalette.ink,
    success: BimbiPalette.mint,
    successTint: BimbiPalette.mintTint,
    danger: BimbiPalette.coral,
    dangerTint: BimbiPalette.coralTint,
    night: BimbiPalette.night,
    onNight: BimbiPalette.lavenderMist,
    onNightMuted: BimbiPalette.lavender,
    navActive: BimbiPalette.lightAccent,
    navInactive: BimbiPalette.inkSoft,
    focusRing: BimbiPalette.ink,
    reward: BimbiPalette.honey,
    shadows: BimbiShadows.soft,
  );

  static const dark = BimbiColors(
    background: BimbiPalette.night,
    card: BimbiPalette.nightRaised,
    cardBorder: BimbiPalette.nightLine,
    inputBorder: BimbiPalette.nightLine,
    text: BimbiPalette.lavenderMist,
    textMuted: BimbiPalette.lavender,
    link: BimbiPalette.darkAccent,
    accentTint: BimbiPalette.nightHigh,
    onAccentTint: BimbiPalette.lavenderMist,
    success: BimbiPalette.mintBright,
    successTint: Color(0xFF1F3B3A),
    danger: BimbiPalette.coralBright,
    dangerTint: Color(0xFF4A2337),
    night: BimbiPalette.night,
    onNight: BimbiPalette.lavenderMist,
    onNightMuted: BimbiPalette.lavender,
    navActive: BimbiPalette.darkAccent,
    navInactive: BimbiPalette.lavender,
    focusRing: BimbiPalette.darkAccent,
    reward: BimbiPalette.honey,
    shadows: BimbiShadows.none,
  );

  @override
  BimbiColors copyWith({Color? background}) => BimbiColors(
    background: background ?? this.background,
    card: card,
    cardBorder: cardBorder,
    inputBorder: inputBorder,
    text: text,
    textMuted: textMuted,
    link: link,
    accentTint: accentTint,
    onAccentTint: onAccentTint,
    success: success,
    successTint: successTint,
    danger: danger,
    dangerTint: dangerTint,
    night: night,
    onNight: onNight,
    onNightMuted: onNightMuted,
    navActive: navActive,
    navInactive: navInactive,
    focusRing: focusRing,
    reward: reward,
    shadows: shadows,
  );

  @override
  BimbiColors lerp(BimbiColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BimbiColors(
      background: l(background, other.background),
      card: l(card, other.card),
      cardBorder: l(cardBorder, other.cardBorder),
      inputBorder: l(inputBorder, other.inputBorder),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      link: l(link, other.link),
      accentTint: l(accentTint, other.accentTint),
      onAccentTint: l(onAccentTint, other.onAccentTint),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      danger: l(danger, other.danger),
      dangerTint: l(dangerTint, other.dangerTint),
      night: l(night, other.night),
      onNight: l(onNight, other.onNight),
      onNightMuted: l(onNightMuted, other.onNightMuted),
      navActive: l(navActive, other.navActive),
      navInactive: l(navInactive, other.navInactive),
      focusRing: l(focusRing, other.focusRing),
      reward: l(reward, other.reward),
      shadows: t < 0.5 ? shadows : other.shadows,
    );
  }
}

extension BimbiThemeContext on BuildContext {
  BimbiColors get bimbi =>
      Theme.of(this).extension<BimbiColors>() ?? BimbiColors.light;
  TextTheme get text => Theme.of(this).textTheme;
}
