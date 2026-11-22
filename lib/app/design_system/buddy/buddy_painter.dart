import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../theme/bimbi_tokens.dart';
import 'buddy_motion.dart';
import 'buddy_palette.dart';

/// Paints the soft-gradient alarm-clock buddy in a 320×320 design space,
/// ported from the Brand Buddy canvas ("Rendering test: soft gradient").
class BuddyPainter extends CustomPainter {
  BuddyPainter({
    required this.palette,
    required this.frame,
    this.nose = true,
    this.glow = true,
    this.zzzColor = BimbiPalette.ink,
  });

  final BuddyPalette palette;
  final FaceFrame frame;
  final bool nose;
  final bool glow;

  /// Colour of the floating Zs; must contrast with the surface behind.
  final Color zzzColor;

  static const _design = 320.0;
  static const _bodyCenter = Offset(161, 182);

  /// Canvas source: M-29 10 C-31 -26, 31 -26, 29 10 C20 15, -20 15, -29 10 Z
  static final Path _bellPath = _buildBell();

  static Path _buildBell() => Path()
    ..moveTo(-29, 10)
    ..cubicTo(-31, -26, 31, -26, 29, 10)
    ..cubicTo(20, 15, -20, 15, -29, 10)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / _design;
    canvas.save();
    canvas.translate(
      (size.width - _design * s) / 2,
      (size.height - _design * s) / 2,
    );
    canvas.scale(s);
    _paintBody(canvas);
    _paintFace(canvas);
    canvas.restore();
  }

  ui.Gradient _sheen(Rect box) => ui.Gradient.linear(
    Offset(box.left + box.width * 0.3, box.top),
    Offset(box.left + box.width * 0.7, box.bottom),
    [palette.p1, palette.splash, palette.p0],
    const [0, 0.55, 1],
  );

  Paint _rim(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = palette.bloom.withValues(alpha: 0.6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

  void _ear(Canvas canvas, Offset at, double angle, {required bool fill}) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate((angle + frame.earWiggle) * math.pi / 180);
    if (fill) {
      canvas.drawLine(
        const Offset(0, 10),
        const Offset(0, 30),
        Paint()
          ..color = palette.p1
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
      final bellBox = const Rect.fromLTRB(-31, -17, 31, 14);
      canvas.drawPath(_bellPath, Paint()..shader = _sheen(bellBox));
      canvas.save();
      canvas.translate(0, -3);
      canvas.scale(0.88);
      canvas.translate(0, 3);
      canvas.drawPath(_bellPath, _rim(4));
      canvas.restore();
      const knob = Offset(0, -21);
      canvas.drawCircle(
        knob,
        6.5,
        Paint()..shader = _sheen(Rect.fromCircle(center: knob, radius: 6.5)),
      );
      canvas.drawCircle(knob, 4.5, _rim(2.5));
    } else {
      final halo = Paint()
        ..color = palette.p1.withValues(alpha: 0.45)
        ..strokeWidth = 16
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(_bellPath, halo..style = PaintingStyle.fill);
      canvas.drawPath(_bellPath, halo..style = PaintingStyle.stroke);
      canvas.drawCircle(const Offset(0, -21), 6.5, halo);
    }
    canvas.restore();
  }

  void _paintBody(Canvas canvas) {
    const knobRect = RRect.fromLTRBXY(139, 62, 183, 84, 11, 11);
    if (glow) {
      canvas.drawCircle(
        _bodyCenter,
        112,
        Paint()
          ..color = palette.p1.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      _ear(canvas, const Offset(79, 84), -40, fill: false);
      _ear(canvas, const Offset(243, 84), 40, fill: false);
      canvas.drawRRect(
        knobRect,
        Paint()
          ..color = palette.p1.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawRRect(knobRect, Paint()..shader = _sheen(knobRect.outerRect));
    canvas.drawRRect(const RRect.fromLTRBXY(142, 65, 180, 81, 8, 8), _rim(3.5));
    _ear(canvas, const Offset(79, 84), -40, fill: true);
    _ear(canvas, const Offset(243, 84), 40, fill: true);
    canvas.drawCircle(
      _bodyCenter,
      104,
      Paint()
        ..shader = _sheen(Rect.fromCircle(center: _bodyCenter, radius: 104)),
    );
    canvas.drawCircle(_bodyCenter, 101, _rim(4));
  }

  void _paintFace(Canvas canvas) {
    // Blush and freckles.
    final blush = Paint()
      ..color = BimbiPalette.blush.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(106, 176), width: 30, height: 20),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(216, 176), width: 30, height: 20),
      blush,
    );
    final freckle = Paint()
      ..color = BimbiPalette.freckle.withValues(alpha: 0.75)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in const [
      (Offset(100, 172), Offset(102, 179)),
      (Offset(106, 171), Offset(108, 179)),
      (Offset(112, 172), Offset(114, 179)),
      (Offset(210, 172), Offset(208, 179)),
      (Offset(216, 171), Offset(214, 179)),
      (Offset(222, 172), Offset(220, 179)),
    ]) {
      canvas.drawLine(a, b, freckle);
    }

    _eye(canvas, const Offset(126, 146));
    _eye(canvas, const Offset(196, 146));
    _brow(
      canvas,
      const Offset(126, 117),
      frame.browShiftL,
      frame.browRotL,
      Path()
        ..moveTo(114, 120)
        ..cubicTo(120, 115, 130, 114, 138, 117),
    );
    _brow(
      canvas,
      const Offset(196, 117),
      frame.browShiftR,
      frame.browRotR,
      Path()
        ..moveTo(184, 117)
        ..cubicTo(192, 114, 202, 115, 208, 120),
    );
    _mouth(canvas);
    if (nose) _nose(canvas);
    if (frame.zzz > 0) _zzz(canvas);
  }

  void _eye(Canvas canvas, Offset c) {
    canvas.save();
    canvas.translate(c.dx + frame.eyeShift.dx, c.dy + frame.eyeShift.dy);
    canvas.scale(frame.eyeScale.dx, frame.eyeScale.dy * frame.blink);
    canvas.translate(-c.dx, -c.dy);
    final normal = 1 - frame.starEyes;
    if (normal > 0) {
      final layer = normal < 1;
      if (layer) {
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, normal),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 30, height: 38),
        Paint()..color = BimbiPalette.pupil,
      );
      final white = Paint()..color = BimbiPalette.white;
      canvas.drawCircle(c.translate(-5, 6), 6, white);
      canvas.drawCircle(c.translate(6, -7), 3.5, white);
      if (layer) canvas.restore();
    }
    if (frame.starEyes > 0) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, frame.starEyes),
      );
      canvas.drawCircle(c, 19, Paint()..color = BimbiPalette.pupil);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(frame.starAngle * math.pi / 180);
      final star = Path()
        ..moveTo(0, -12)
        ..lineTo(2.9, -4.1)
        ..lineTo(11.4, -3.7)
        ..lineTo(4.8, 1.6)
        ..lineTo(7.1, 9.7)
        ..lineTo(0, 5)
        ..lineTo(-7.1, 9.7)
        ..lineTo(-4.8, 1.6)
        ..lineTo(-11.4, -3.7)
        ..lineTo(-2.9, -4.1)
        ..close();
      canvas.drawPath(star, Paint()..color = BimbiPalette.white);
      canvas.drawPath(
        star,
        Paint()
          ..color = BimbiPalette.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  void _brow(
    Canvas canvas,
    Offset pivot,
    Offset shift,
    double degrees,
    Path path,
  ) {
    canvas.save();
    canvas.translate(pivot.dx + shift.dx, pivot.dy + shift.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = BimbiPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _mouth(Canvas canvas) {
    final v = frame.mouth.v;
    final path = Path()
      ..moveTo(v[0], v[1])
      ..cubicTo(v[2], v[3], v[4], v[5], v[6], v[7])
      ..cubicTo(v[8], v[9], v[10], v[11], v[0], v[1])
      ..close();
    canvas.save();
    canvas.translate(0, 12);
    canvas.drawPath(path, Paint()..color = BimbiPalette.ink);
    canvas.drawPath(
      path,
      Paint()
        ..color = BimbiPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(161, 198), width: 30, height: 20),
      Paint()..color = BimbiPalette.tongue,
    );
    canvas.restore();
    canvas.restore();
  }

  void _nose(Canvas canvas) {
    canvas.save();
    canvas.translate(161, 168);
    canvas.scale(frame.noseScale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 22, height: 15),
      Paint()..color = BimbiPalette.ink,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, -3), width: 7, height: 3.6),
      Paint()..color = BimbiPalette.white.withValues(alpha: 0.6),
    );
    canvas.restore();
  }

  void _zzz(Canvas canvas) {
    void z(double phase, List<Offset> pts, double width) {
      final t = phase % 1;
      final opacity = (t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75) * frame.zzz;
      final shift = Offset.lerp(const Offset(0, 6), const Offset(8, -14), t)!;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.save();
      canvas.translate(shift.dx, shift.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = zzzColor.withValues(alpha: opacity.clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }

    final secs = frame.zzzSeconds;
    z(secs / 3, const [
      Offset(232, 38),
      Offset(248, 38),
      Offset(232, 56),
      Offset(248, 56),
    ], 3.2);
    z((secs + 1.5) / 3, const [
      Offset(262, 16),
      Offset(273, 16),
      Offset(262, 28),
      Offset(273, 28),
    ], 3.5);
  }

  @override
  bool shouldRepaint(BuddyPainter old) =>
      old.frame != frame ||
      old.palette.base != palette.base ||
      old.nose != nose ||
      old.glow != glow ||
      old.zzzColor != zzzColor;
}
