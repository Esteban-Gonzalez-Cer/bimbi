import 'package:flutter/material.dart';

/// Raw brand values from the Bimbi brand board (Brand Buddy canvas).
///
/// Widgets should read colours through [Theme] / `BimbiColors`; these raw
/// values exist for theme construction, tests and the native-alarm parity
/// check.
abstract final class BimbiPalette {
  // Light lavender surfaces and plum accents, adapted from Wake.
  static const lightBackground = Color(0xFFF3ECFA);
  static const paper = Color(0xFFFFFCFF);
  static const lightTint = Color(0xFFECE1F8);
  static const lightLine = Color(0xFFE1D2EF);
  static const inputLine = Color(0xFFB4A1C4);
  static const lightAccent = Color(0xFF5D437A);
  static const lightPressed = Color(0xFF4D3569);
  static const ink = Color(0xFF31233F);
  static const inkSoft = Color(0xFF655472);
  static const white = Color(0xFFFFFFFF);

  // Dark lavender surfaces and accents.
  static const night = Color(0xFF191421);
  static const nightRaised = Color(0xFF282032);
  static const nightHigh = Color(0xFF3A2C4C);
  static const nightLine = Color(0xFF514163);
  static const lavenderMist = Color(0xFFF5EAFD);
  static const lavender = Color(0xFFD0BBDD);
  static const darkAccent = Color(0xFFE3C9F5);
  static const darkPressed = Color(0xFFD2B1E9);
  static const darkOnAccent = Color(0xFF321C45);

  // Feedback.
  static const mint = Color(0xFF1E7A52);
  static const mintTint = Color(0xFFDDF5EA);
  static const mintBright = Color(0xFF6FD3A8);
  static const coral = Color(0xFFB3261E);
  static const coralTint = Color(0xFFFDE2E0);
  static const coralBright = Color(0xFFFF8577);
  static const honey = Color(0xFFE8B400); // reserved for Phase 9 rewards

  // Sunrise (Premium theme): the original Brand Buddy palette.
  static const cream = Color(0xFFFFF5EA);
  static const tangerine = Color(0xFFF99A41);
  static const peachTint = Color(0xFFFFE3C4);
  static const ember = Color(0xFFA84A08);
  static const brandInk = Color(0xFF2A221E);
  static const brandMuted = Color(0xFF6B5A4E);
  static const brandLine = Color(0xFFF7EADB);
  static const brandInput = Color(0xFFEEDCC8);
  static const brandNight = Color(0xFF231E45);
  static const brandNightRaised = Color(0xFF302A5C);
  static const brandNightHigh = Color(0xFF4A4380);
  static const brandNightMuted = Color(0xFFCFC8E6);

  // Buddy face.
  static const blush = Color(0xFFF2A09B);
  static const freckle = Color(0xFFD9706B);
  static const tongue = Color(0xFFF26B8F);
  static const pupil = Color(0xFF221B17);
}

/// Buddy colour presets people can pick. The brand buddy defaults to Lilac.
enum BuddyColorPreset {
  tangerine('Tangerine', Color(0xFFF99A41)),
  sunflower('Sunflower', Color(0xFFFFD647)),
  lilac('Lilac', Color(0xFFB39DFF)),
  mint('Mint', Color(0xFF6FD3A8)),
  sky('Sky', Color(0xFF6CB8F0)),
  coral('Coral', Color(0xFFFF8577)),
  // Plus colours: offered with a verified Plus or Premium pass.
  rose('Rose', Color(0xFFFF9EC7), plus: true),
  peach('Peach', Color(0xFFFFB38A), plus: true),
  violet('Violet', Color(0xFF8E7CFF), plus: true);

  const BuddyColorPreset(this.label, this.color, {this.plus = false});
  final String label;
  final Color color;
  final bool plus;
}

/// 4 / 8 based spacing scale: 4 8 12 16 24 32 48.
abstract final class BimbiSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Everything is round, like the buddy.
abstract final class BimbiRadius {
  static const chip = 12.0;
  static const input = 20.0;
  static const banner = 24.0;
  static const card = 28.0;
  static const pill = 999.0;
  static const chipBorder = BorderRadius.all(Radius.circular(chip));
  static const inputBorder = BorderRadius.all(Radius.circular(input));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
}

abstract final class BimbiShadows {
  /// Soft shadow: 0 10 30, Ink at 8%.
  static const soft = [
    BoxShadow(color: Color(0x1431233F), offset: Offset(0, 10), blurRadius: 30),
  ];

  /// Lavender glow used under the primary floating action.
  static const glow = [
    BoxShadow(color: Color(0x40A980D4), offset: Offset(0, 8), blurRadius: 20),
  ];
  static const none = <BoxShadow>[];
}

abstract final class BimbiMotion {
  static const quick = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 260);
  static const gentle = Duration(milliseconds: 420);

  /// Ease used by every brand keyframe (SVG keySplines 0.45 0 0.55 1).
  static const ease = Cubic(0.45, 0, 0.55, 1);
  static const spring = Curves.easeOutBack;
}

abstract final class BimbiFonts {
  static const display = 'InstrumentSerif';
  static const body = 'Nunito';
}

/// Minimum interactive size (spec: 48x48dp).
const kBimbiMinTarget = 48.0;
