import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/design_system/design_system.dart';

String formatClock(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Advanced circular Focus timer.
///
/// Idle: drag the knob (or use TalkBack increase/decrease) to choose 5–120
/// minutes. Running: the arc shows progress and the centre the remaining
/// time.
class FocusDial extends StatelessWidget {
  const FocusDial({
    super.key,
    required this.target,
    required this.remaining,
    required this.progress,
    required this.caption,
    this.onTargetChanged,
    this.size = 300,
  });

  final Duration target;
  final Duration remaining;

  /// 0..1 elapsed fraction while running; ignored when idle.
  final double progress;
  final String caption;

  /// Non-null only while idle.
  final ValueChanged<Duration>? onTargetChanged;
  final double size;

  static const _max = 120;

  void _fromPosition(Offset local) {
    final center = Offset(size / 2, size / 2);
    final v = local - center;
    // 0 at 12 o'clock, clockwise.
    var angle = math.atan2(v.dx, -v.dy);
    if (angle < 0) angle += 2 * math.pi;
    final minutes = (angle / (2 * math.pi) * _max).round();
    onTargetChanged?.call(Duration(minutes: math.max(5, minutes)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    final idle = onTargetChanged != null;
    final fraction = idle
        ? target.inMinutes / _max
        : progress.clamp(0.0, 1.0).toDouble();
    final dial = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DialPainter(
          fraction: fraction,
          track: c.accentTint,
          tick: c.textMuted,
          knobOutline: c.link,
          knob: idle,
          knobFill: c.card,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    idle ? '${target.inMinutes}' : formatClock(remaining),
                    style: context.text.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    caption,
                    style: context.text.titleMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
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
        liveRegion: false,
        excludeSemantics: true,
        child: dial,
      );
    }
    return Semantics(
      slider: true,
      label: 'Focus length',
      value: '${target.inMinutes} minutes',
      increasedValue: '${math.min(_max, target.inMinutes + 5)} minutes',
      decreasedValue: '${math.max(5, target.inMinutes - 5)} minutes',
      onIncrease: () => onTargetChanged!(
        Duration(minutes: math.min(_max, target.inMinutes + 5)),
      ),
      onDecrease: () => onTargetChanged!(
        Duration(minutes: math.max(5, target.inMinutes - 5)),
      ),
      excludeSemantics: true,
      child: GestureDetector(
        onPanDown: (d) => _fromPosition(d.localPosition),
        onPanUpdate: (d) => _fromPosition(d.localPosition),
        child: dial,
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.fraction,
    required this.track,
    required this.tick,
    required this.knob,
    required this.knobFill,
    required this.knobOutline,
  });

  final double fraction;
  final Color track;
  final Color tick;
  final bool knob;
  final Color knobFill;
  final Color knobOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.064;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    // Major marks every 15 minutes with finer subdivisions between them.
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
    // Progress arc.
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = knobOutline,
      );
    }
    if (knob) {
      final a = 2 * math.pi * fraction - math.pi / 2;
      final at = center + Offset(math.cos(a), math.sin(a)) * radius;
      final knobRadius = stroke * .7;
      canvas.drawCircle(at, knobRadius, Paint()..color = knobFill);
      canvas.drawCircle(
        at,
        knobRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = knobOutline,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.knob != knob ||
      old.track != track ||
      old.tick != tick ||
      old.knobFill != knobFill ||
      old.knobOutline != knobOutline;
}
