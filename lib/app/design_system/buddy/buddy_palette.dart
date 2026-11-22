import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Colour ramp for the soft-gradient buddy, ported from the brand canvas
/// `derive()` (HSL adjustments of one base colour).
@immutable
class BuddyPalette {
  const BuddyPalette({
    required this.base,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.edge,
    required this.splash,
    required this.bloom,
    required this.hand,
  });

  factory BuddyPalette.from(Color base) {
    final hsl = _toHsl(base);
    final h = hsl.$1, s = hsl.$2, l = hsl.$3;
    return BuddyPalette(
      base: base,
      p0: _fromHsl(h, s * 0.9, math.min(l + 0.24, 0.95)),
      p1: _fromHsl(h, s, math.min(l + 0.04, 0.9)),
      p2: _fromHsl(h, s * 1.05, math.max(l - 0.07, 0.12)),
      edge: _fromHsl(h, s * 1.1, math.max(l - 0.3, 0.12)),
      splash: _fromHsl(h, s, math.min(l + 0.14, 0.92)),
      bloom: _fromHsl(h, s * 0.7, 0.96),
      hand: _fromHsl(h, s * 0.85, math.min(l + 0.2, 0.93)),
    );
  }

  final Color base;
  final Color p0;
  final Color p1;
  final Color p2;
  final Color edge;
  final Color splash;
  final Color bloom;
  final Color hand;

  static (double, double, double) _toHsl(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    var h = 0.0, s = 0.0;
    final l = (maxV + minV) / 2;
    if (maxV != minV) {
      final d = maxV - minV;
      s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
      if (maxV == r) {
        h = (g - b) / d + (g < b ? 6 : 0);
      } else if (maxV == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h /= 6;
    }
    return (h, s, l);
  }

  static Color _fromHsl(double h, double s, double l) {
    s = s.clamp(0.0, 1.0);
    l = l.clamp(0.0, 1.0);
    double f(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    double r, g, b;
    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      r = f(p, q, h + 1 / 3);
      g = f(p, q, h);
      b = f(p, q, h - 1 / 3);
    }
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return Color.fromARGB(255, ch(r), ch(g), ch(b));
  }
}
