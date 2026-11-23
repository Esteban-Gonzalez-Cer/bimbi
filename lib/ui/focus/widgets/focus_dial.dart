import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/design_system/design_system.dart';

String formatClock(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "2 h 30 min", "45 min".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Picks the value for a finger at [fraction] of a turn that is closest to
/// [current], so winding past 12 o'clock keeps adding (or removing) turns.
int windMinutes(int current, double fraction, {int turn = 120, int max = 480}) {
  final base = current ~/ turn;
  var best = current;
  var bestDistance = 1 << 30;
  // A turn below zero lets unwinding past 12 o'clock stop at the minimum
  // instead of jumping to a full turn.
  for (final t in [base - 1, base, base + 1]) {
    final candidate = (t * turn + fraction * turn).round();
    final distance = (candidate - current).abs();
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best.clamp(0, max);
}

/// Advanced circular Focus timer.
///
/// Idle: wind the ring to choose the length. One turn is two hours; winding
/// on draws a new layer over the previous turn, up to four turns, and
/// unwinding removes it. Tap the number to type exact minutes. Running: the
/// layers show the time left and shrink as it passes.
class FocusDial extends StatelessWidget {
  const FocusDial({
    super.key,
    required this.target,
    required this.remaining,
    required this.caption,
    this.idle = false,
    this.centre,
    this.windows = const [],
    this.onTargetChanged,
    this.onTypeMinutes,
    this.size = 300,
  });

  final Duration target;
  final Duration remaining;
  final String caption;

  /// Before the session starts: shows the chosen length. Winding needs
  /// [onTargetChanged] as well (null while a split locks the length).
  final bool idle;

  /// Big centre text while running; defaults to [remaining].
  final String? centre;

  /// Window lengths in minutes; their boundaries are marked on the ring.
  final List<int> windows;

  /// Non-null while the length can be wound.
  final ValueChanged<Duration>? onTargetChanged;
  final VoidCallback? onTypeMinutes;
  final double size;

  static const _turn = 120;
  static const _max = 480;

  bool _onRing(Offset local) =>
      (local - Offset(size / 2, size / 2)).distance > size * 0.3;

  double _fraction(Offset local) {
    final v = local - Offset(size / 2, size / 2);
    // 0 at 12 o'clock, clockwise.
    var angle = math.atan2(v.dx, -v.dy);
    if (angle < 0) angle += 2 * math.pi;
    return angle / (2 * math.pi);
  }

  void _wind(Offset local) {
    final minutes = windMinutes(
      target.inMinutes,
      _fraction(local),
      turn: _turn,
      max: _max,
    );
    onTargetChanged?.call(Duration(minutes: minutes));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final editable = idle && onTargetChanged != null;
    final shown = idle ? target.inMinutes.toDouble() : remaining.inSeconds / 60;
    // The ring counts down from its far end back to 12 o'clock, so a window
    // that ends B minutes into the session sits at target - B on the ring.
    final boundaries = <double>[];
    var sum = 0;
    for (final w in windows.take(math.max(0, windows.length - 1))) {
      sum += w;
      final atRing = target.inMinutes - sum;
      if (atRing < shown) boundaries.add(atRing.toDouble());
    }
    final minutes = target.inMinutes;
    final dial = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DialPainter(
          minutes: shown,
          turn: _turn.toDouble(),
          boundaries: boundaries,
          track: c.accentTint,
          tick: c.textMuted,
          arc: c.link,
          knob: editable,
          knobFill: c.card,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.17),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    idle ? '$minutes' : centre ?? formatClock(remaining),
                    style: context.text.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    idle
                        ? (minutes >= 60
                              ? formatMinutes(minutes)
                              : minutes == 1
                              ? 'minute'
                              : 'minutes')
                        : caption,
                    style: context.text.titleMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                  if (editable && onTypeMinutes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tap to type',
                      style: context.text.labelSmall?.copyWith(
                        color: c.link,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!idle) {
      return Semantics(
        label: 'Focus timer',
        value:
            '${remaining.inMinutes} minutes ${remaining.inSeconds % 60} '
            'seconds left. $caption',
        excludeSemantics: true,
        child: dial,
      );
    }
    if (!editable) {
      return Semantics(
        label: 'Focus length',
        value: '${formatMinutes(minutes)}, split into windows',
        excludeSemantics: true,
        child: dial,
      );
    }
    int step(int by) => (minutes + by).clamp(1, _max);
    return Semantics(
      slider: true,
      label: 'Focus length',
      value: formatMinutes(minutes),
      increasedValue: formatMinutes(step(5)),
      decreasedValue: formatMinutes(step(-5)),
      onIncrease: () => onTargetChanged!(Duration(minutes: step(5))),
      onDecrease: () => onTargetChanged!(Duration(minutes: step(-5))),
      customSemanticsActions: onTypeMinutes == null
          ? null
          : {
              const CustomSemanticsAction(label: 'Type exact minutes'):
                  onTypeMinutes!,
            },
      excludeSemantics: true,
      child: GestureDetector(
        onTapUp: (d) => _onRing(d.localPosition)
            ? _wind(d.localPosition)
            : onTypeMinutes?.call(),
        onPanStart: (d) {
          if (_onRing(d.localPosition)) _wind(d.localPosition);
        },
        onPanUpdate: (d) => _wind(d.localPosition),
        child: dial,
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.minutes,
    required this.turn,
    required this.boundaries,
    required this.track,
    required this.tick,
    required this.arc,
    required this.knob,
    required this.knobFill,
  });

  /// Minutes to draw: the chosen length while idle, the time left while
  /// running. Every [turn] minutes is one full layer.
  final double minutes;
  final double turn;
  final List<double> boundaries;
  final Color track;
  final Color tick;
  final Color arc;
  final bool knob;
  final Color knobFill;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.064;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // Marks every 2.5 minutes, stronger every 15.
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final major = i % 6 == 0;
      tickPaint
        ..color = tick.withValues(alpha: major ? .68 : .32)
        ..strokeWidth = major ? 2.4 : 1.3;
      canvas.drawLine(
        center + dir * (radius - stroke * .82),
        center + dir * (radius - stroke * (major ? 1.35 : 1.1)),
        tickPaint,
      );
    }

    // Layers: each completed turn is a full ring, deeper the higher it sits;
    // the turn in progress is drawn on top in the full accent colour.
    final full = (minutes / turn).floor();
    final partial = (minutes - full * turn) / turn;
    final layers = full + (partial > 0.0001 ? 1 : 0);
    for (var layer = 0; layer < layers; layer++) {
      final top = layer == layers - 1;
      final sweep = top && partial > 0.0001 ? partial : 1.0;
      final alpha = top ? 1.0 : 0.28 + 0.18 * layer;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        ring..color = arc.withValues(alpha: alpha.clamp(0, 1).toDouble()),
      );
    }

    // Window boundaries: small notches across the ring.
    final notch = Paint()
      ..color = knobFill
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final b in boundaries) {
      final a = (b % turn) / turn * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (radius - stroke * .45),
        center + dir * (radius + stroke * .45),
        notch,
      );
    }

    if (knob) {
      final position = layers == 0 ? 0.0 : (partial > 0.0001 ? partial : 1.0);
      final a = 2 * math.pi * position - math.pi / 2;
      final at = center + Offset(math.cos(a), math.sin(a)) * radius;
      final knobRadius = stroke * .7;
      canvas.drawCircle(at, knobRadius, Paint()..color = knobFill);
      canvas.drawCircle(
        at,
        knobRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = arc,
      );
      if (full > 0 && layers > 1) {
        // Turn count on the knob: "2", "3", "4".
        final text = TextPainter(
          text: TextSpan(
            text: '$layers',
            style: TextStyle(
              color: arc,
              fontFamily: BimbiFonts.body,
              fontSize: knobRadius * 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.minutes != minutes ||
      old.knob != knob ||
      old.track != track ||
      old.tick != tick ||
      old.arc != arc ||
      old.knobFill != knobFill ||
      old.boundaries.length != boundaries.length;
}
