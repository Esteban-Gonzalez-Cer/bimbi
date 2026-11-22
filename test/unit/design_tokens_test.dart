import 'dart:math' as math;

import 'package:bimbi/app/design_system/buddy/buddy_motion.dart';
import 'package:bimbi/app/design_system/buddy/buddy_palette.dart';
import 'package:bimbi/app/theme/bimbi_colors.dart';
import 'package:bimbi/app/theme/bimbi_theme.dart';
import 'package:bimbi/app/theme/bimbi_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('WCAG contrast', () {
    for (final (name, c) in [
      ('light', BimbiColors.light),
      ('dark', BimbiColors.dark),
    ]) {
      test('$name text pairs reach 4.5:1', () {
        final pairs = {
          'text/background': (c.text, c.background),
          'text/card': (c.text, c.card),
          'muted/background': (c.textMuted, c.background),
          'muted/card': (c.textMuted, c.card),
          'link/background': (c.link, c.background),
          'link/card': (c.link, c.card),
          'navActive/accentTint': (c.navActive, c.accentTint),
          'navInactive/card': (c.navInactive, c.card),
          'success/successTint': (c.success, c.successTint),
          'danger/dangerTint': (c.danger, c.dangerTint),
          'onNight/night': (c.onNight, c.night),
          'onNightMuted/night': (c.onNightMuted, c.night),
          'onAccentTint/accentTint': (c.onAccentTint, c.accentTint),
        };
        for (final MapEntry(:key, :value) in pairs.entries) {
          expect(
            contrast(value.$1, value.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$name $key',
          );
        }
      });
    }

    test('lavender primary controls meet text contrast in both themes', () {
      for (final theme in [BimbiTheme.light(), BimbiTheme.dark()]) {
        final scheme = theme.colorScheme;
        expect(contrast(scheme.primary, scheme.onPrimary), greaterThan(4.5));
      }
    });
  });

  test('theme uses bundled brand fonts', () {
    final t = BimbiTheme.light().textTheme;
    expect(t.displayLarge!.fontFamily, BimbiFonts.display);
    expect(t.displayLarge!.fontSize, 72);
    expect(t.headlineLarge!.fontSize, 34);
    expect(t.headlineSmall!.fontSize, 22);
    expect(t.bodyLarge!.fontFamily, BimbiFonts.body);
    expect(t.bodyLarge!.fontSize, 16);
    expect(t.labelMedium!.fontSize, 13);
  });

  test('buddy palette matches the canvas derive() for Lilac', () {
    final p = BuddyPalette.from(BuddyColorPreset.lilac.color);
    // Values the brand canvas computes for #B39DFF.
    expect(p.p0, const Color(0xFFECE7FE));
    expect(p.p1, const Color(0xFFC3B1FF));
    expect(p.splash, const Color(0xFFDFD6FF));
    expect(p.bloom, const Color(0xFFF1EEFC));
  });

  test('every mood samples a finite, bounded face over its loop', () {
    for (final mood in BuddyMood.values) {
      final script = MoodScript.of(mood);
      final secs = script.duration.inMilliseconds / 1000;
      for (var i = 0; i <= 200; i++) {
        final t = i / 200;
        final f = script.frame(t, t * secs);
        expect(f.blink, inInclusiveRange(0.05, 1.2), reason: '$mood $t');
        expect(f.eyeScale.dy, inInclusiveRange(0.05, 1.3), reason: '$mood $t');
        expect(
          f.mouth.v.every((v) => v.isFinite && v > 100 && v < 220),
          isTrue,
        );
        expect(f.starEyes, inInclusiveRange(0, 1));
      }
    }
  });
}
