import 'dart:ui' show Offset, lerpDouble;

import '../../theme/bimbi_tokens.dart';

/// The buddy's moods. Only the face acts; the body never changes shape.
///
/// Spec mascot states map onto these: sleepy → [sleepy], waking → [wakeUp]
/// or [surprised], focused → [thinking], active → [excited], celebrating →
/// [excited] / [happy].
enum BuddyMood { happy, excited, thinking, sleepy, grumpy, surprised, wakeUp }

/// Mouth outline: M a C c1 c2 b C c3 c4 a Z, in the 320×320 buddy space.
class MouthShape {
  const MouthShape(this.v);

  /// a.x a.y c1.x c1.y c2.x c2.y b.x b.y c3.x c3.y c4.x c4.y
  final List<double> v;

  static MouthShape lerp(MouthShape a, MouthShape b, double t) =>
      MouthShape([for (var i = 0; i < 12; i++) lerpDouble(a.v[i], b.v[i], t)!]);

  static const smile = MouthShape([
    149, 178, 155, 184, 167, 184, 173, 178, 167, 185, 155, 185, //
  ]);
  static const small = MouthShape([
    153, 179, 157, 183, 165, 183, 169, 179, 165, 184, 157, 184, //
  ]);
  static const oh = MouthShape([
    153, 177, 153, 169, 169, 169, 169, 177, 169, 190, 153, 190, //
  ]);
  static const yawn = MouthShape([
    148, 174, 148, 158, 174, 158, 174, 174, 174, 202, 148, 202, //
  ]);
  static const grin = MouthShape([
    144, 174, 152, 177, 170, 177, 178, 174, 175, 195, 147, 195, //
  ]);
  static const bigGrin = MouthShape([
    139, 171, 150, 174, 172, 174, 183, 171, 181, 203, 141, 203, //
  ]);
  static const smirk = MouthShape([
    151, 182, 158, 184, 167, 183, 174, 177, 168, 185, 157, 185, //
  ]);
  static const frown = MouthShape([
    150, 185, 155, 179, 167, 179, 172, 185, 167, 180, 155, 180, //
  ]);
  static const flat = MouthShape([
    151, 182, 157, 183, 165, 183, 171, 182, 165, 184, 157, 184, //
  ]);
}

/// One sampled pose of the face.
class FaceFrame {
  const FaceFrame({
    this.eyeShift = Offset.zero,
    this.eyeScale = const Offset(1, 1),
    this.blink = 1,
    this.starEyes = 0,
    this.starAngle = 0,
    this.browShiftL = Offset.zero,
    this.browShiftR = Offset.zero,
    this.browRotL = 0,
    this.browRotR = 0,
    this.mouth = MouthShape.smile,
    this.noseScale = 1,
    this.zzz = 0,
    this.zzzSeconds = 0,
    this.earWiggle = 0,
  });

  final Offset eyeShift;
  final Offset eyeScale;

  /// Vertical eye scale from blinking (1 open, 0.08 shut).
  final double blink;

  /// 0 normal eyes, 1 star eyes.
  final double starEyes;
  final double starAngle;
  final Offset browShiftL;
  final Offset browShiftR;

  /// Degrees.
  final double browRotL;
  final double browRotR;
  final MouthShape mouth;
  final double noseScale;

  /// 0 hides the floating Zs, 1 shows them.
  final double zzz;
  final double zzzSeconds;

  /// Degrees; bells wobble when the alarm rings.
  final double earWiggle;
}

/// Eased keyframe track (SVG `calcMode="spline"` with keySplines
/// 0.45 0 0.55 1 on every segment).
class Track<T> {
  const Track(this.times, this.values, this.lerp)
    : assert(times.length == values.length);

  final List<double> times;
  final List<T> values;
  final T Function(T a, T b, double t) lerp;

  T at(double t) {
    if (t <= times.first) return values.first;
    for (var i = 1; i < times.length; i++) {
      if (t <= times[i]) {
        final span = times[i] - times[i - 1];
        final local = span <= 0 ? 1.0 : (t - times[i - 1]) / span;
        return lerp(
          values[i - 1],
          values[i],
          BimbiMotion.ease.transform(local.clamp(0.0, 1.0)),
        );
      }
    }
    return values.last;
  }
}

List<double> _n(String s) => [for (final p in s.split(';')) double.parse(p)];

Track<double> _d(String times, String values) =>
    Track<double>(_n(times), _n(values), (a, b, t) => lerpDouble(a, b, t)!);

Track<Offset> _p(String times, String values) => Track<Offset>(_n(times), [
  for (final pair in values.split(';'))
    Offset(
      double.parse(pair.trim().split(' ')[0]),
      double.parse(pair.trim().split(' ')[1]),
    ),
], (a, b, t) => Offset.lerp(a, b, t)!);

Track<MouthShape> _m(String times, List<MouthShape> shapes) =>
    Track<MouthShape>(_n(times), shapes, MouthShape.lerp);

Offset _mul(Offset a, Offset b) => Offset(a.dx * b.dx, a.dy * b.dy);

/// Nose "boop" shared by every mood (9 s loop).
final _nose = _d(
  '0.0;0.2889;0.3;0.3111;0.3222;0.3333;0.8444;0.8556;0.8667;0.8778;0.8889;1',
  '1;1;1.1;0.95;1.08;1;1;1.1;0.95;1.08;1;1',
);

const _shut = '1;1;0.08;0.08;0.6;1;1';

/// A looping expression script.
abstract class MoodScript {
  const MoodScript();
  Duration get duration;

  /// Normalised time used for the static pose when animations are off.
  double get pose;
  FaceFrame frame(double t, double seconds);

  static MoodScript of(BuddyMood mood) => switch (mood) {
    BuddyMood.happy => _happy,
    BuddyMood.excited => _excited,
    BuddyMood.thinking => _thinking,
    BuddyMood.sleepy => _sleepy,
    BuddyMood.grumpy => _grumpy,
    BuddyMood.surprised => _surprised,
    BuddyMood.wakeUp => _wakeUp,
  };
}

double _nosAt(double seconds) => _nose.at((seconds % 9) / 9);

class _Happy extends MoodScript {
  _Happy();
  @override
  Duration get duration => const Duration(seconds: 6);
  @override
  double get pose => 0.6;
  final eye = _p(
    '0.0;0.1633;0.18;0.3667;0.3833;1',
    '0 0;0 0;-5 -2;-5 -2;0 0;0 0',
  );
  final squint = _p(
    '0.0;0.4917;0.5083;0.7167;0.75;1',
    '1 1;1 1;1 0.7;1 0.7;1 1;1 1',
  );
  final blink = _d(
    '0.0;0.1583;0.17;0.18;0.1933;0.2083;0.3633;0.375;0.385;0.3983;0.4133;0.85;0.8617;0.8717;0.885;0.9;1',
    '1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1',
  );
  final brow = _p(
    '0.0;0.4583;0.4833;0.5;0.7;0.7333;0.75;1',
    '0 0;0 0;0 -6;0 -4;0 -4;0 0.8;0 0;0 0',
  );
  final mouth = _m(
    '0.0;0.4917;0.5083;0.5417;0.575;0.6083;0.65;0.725;0.7583;1',
    [
      MouthShape.smile,
      MouthShape.smile,
      MouthShape.grin,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.grin,
      MouthShape.smile,
      MouthShape.smile,
    ],
  );
  @override
  FaceFrame frame(double t, double seconds) => FaceFrame(
    eyeShift: eye.at(t),
    eyeScale: squint.at(t),
    blink: blink.at(t),
    browShiftL: brow.at(t),
    browShiftR: brow.at(t),
    mouth: mouth.at(t),
    noseScale: _nosAt(seconds),
  );
}

class _Excited extends MoodScript {
  _Excited();
  @override
  Duration get duration => const Duration(seconds: 5);
  @override
  double get pose => 0.4;
  final pop = _p(
    '0.0;0.124;0.144;0.18;0.204;0.224;0.58;0.6;0.624;0.8;0.86;1',
    '1 1;1 1;0.92 0.92;1.28 1.28;1.08 1.08;1.12 1.12;1.1 1.1;1.22 1.22;1.08 1.08;1.08 1.08;1 1;1 1',
  );
  final squash = _p(
    '0.0;0.2;0.22;0.46;0.5;0.8;0.86;1',
    '1 1;1 1;1 0.82;1 0.82;1 0.92;1 0.92;1 1;1 1',
  );
  final blink = _d(
    '0.0;0.124;0.144;0.168;0.186;0.204;0.81;0.824;0.844;0.864;0.884;1',
    '1;1;0.1;0.1;1.12;1;1;0.08;0.08;0.6;1;1',
  );
  final stars = _d('0.0;0.16;0.162;0.834;0.836;1', '0;0;1;1;0;0');
  final spin = _d('0.0;0.5;1', '-12;12;-12');
  final brow = _p(
    '0.0;0.12;0.144;0.176;0.2;0.22;0.24;0.264;0.29;0.316;0.35;0.38;0.42;0.47;0.8;0.87;1',
    '0 0;0 0;0 2.5;0 -13;0 -9;0 -9.5;0 -10.5;0 -7.5;0 -10;0 -8;0 -9.5;0 -8;0 -9;0 -7.5;0 -7.5;0 0;0 0',
  );
  final mouth = _m(
    '0.0;0.12;0.144;0.172;0.21;0.23;0.26;0.28;0.316;0.34;0.38;0.41;0.47;0.8;0.86;1',
    [
      MouthShape.smile,
      MouthShape.smile,
      MouthShape.small,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.bigGrin,
      MouthShape.grin,
      MouthShape.grin,
      MouthShape.smile,
      MouthShape.smile,
    ],
  );
  @override
  FaceFrame frame(double t, double seconds) => FaceFrame(
    eyeScale: _mul(pop.at(t), squash.at(t)),
    blink: blink.at(t),
    starEyes: stars.at(t),
    starAngle: spin.at((seconds % 1.8) / 1.8),
    browShiftL: brow.at(t),
    browShiftR: brow.at(t),
    mouth: mouth.at(t),
    noseScale: _nosAt(seconds),
  );
}

class _Thinking extends MoodScript {
  _Thinking();
  @override
  Duration get duration => const Duration(seconds: 7);
  @override
  double get pose => 0.5;
  final eye = _p(
    '0.0;0.1257;0.14;0.3643;0.3786;0.5714;0.58;0.6429;0.6514;0.6929;0.7071;1',
    '0 0;0 0;-7 -6;-7 -6;7 -6;7 -6;5 -7;5 -7;7 -5;7 -5;0 0;0 0',
  );
  final pop = _p(
    '0.0;0.6857;0.7029;0.7214;0.8714;0.9071;1',
    '1 1;1 1;1.12 1.12;1.06 1.06;1.06 1.06;1 1;1 1',
  );
  final blink = _d(
    '0.0;0.1214;0.1314;0.14;0.1514;0.1643;0.36;0.37;0.3786;0.39;0.4029;0.7029;0.7129;0.7214;0.7329;0.7457;0.9143;0.9243;0.9329;0.9443;0.9571;1',
    '1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1',
  );
  final browL = _p(
    '0.0;0.1;0.1214;0.6786;0.6929;0.7071;0.8714;0.9071;1',
    '0 0;0 0;0 1.5;0 1.5;0 -9;0 -7;0 -7;0 0;0 0',
  );
  final rotL = _d('0.0;0.1;0.1214;0.6786;0.6929;1', '0;0;6;6;0;0');
  final browR = _p(
    '0.0;0.1;0.1214;0.1357;0.6786;0.6929;0.7071;0.8714;0.9071;1',
    '0 0;0 0;0 -7;0 -5.5;0 -5.5;0 -9;0 -7;0 -7;0 0;0 0',
  );
  final rotR = _d('0.0;0.1;0.1214;0.6786;0.6929;1', '0;0;-4;-4;0;0');
  final mouth = _m('0.0;0.1357;0.1571;0.6929;0.7143;0.8714;0.9071;1', [
    MouthShape.smile,
    MouthShape.smile,
    MouthShape.smirk,
    MouthShape.smirk,
    MouthShape.grin,
    MouthShape.grin,
    MouthShape.smile,
    MouthShape.smile,
  ]);
  @override
  FaceFrame frame(double t, double seconds) => FaceFrame(
    eyeShift: eye.at(t),
    eyeScale: pop.at(t),
    blink: blink.at(t),
    browShiftL: browL.at(t),
    browShiftR: browR.at(t),
    browRotL: rotL.at(t),
    browRotR: rotR.at(t),
    mouth: mouth.at(t),
    noseScale: _nosAt(seconds),
  );
}

class _Sleepy extends MoodScript {
  _Sleepy();
  @override
  Duration get duration => const Duration(seconds: 7);
  @override
  double get pose => 0.1;
  final lids = _d(
    '0.0;0.2143;0.3143;0.4286;0.44;0.4643;0.5571;0.6143;0.6357;0.8;0.85;1',
    '0.42;0.42;0.08;0.08;0.55;0.5;0.42;0.42;0.08;0.08;0.42;0.42',
  );
  final brow = _p(
    '0.0;0.4214;0.4357;0.4857;0.5571;0.5929;0.6143;0.8;0.85;1',
    '0 2;0 2;0 -3;0 1;0 2;0 2;0 -4;0 -4;0 2;0 2',
  );
  final mouth = _m('0.0;0.6;0.6214;0.6571;0.7714;0.8214;0.85;1', [
    MouthShape.small,
    MouthShape.small,
    MouthShape.oh,
    MouthShape.yawn,
    MouthShape.yawn,
    MouthShape.oh,
    MouthShape.small,
    MouthShape.small,
  ]);
  @override
  FaceFrame frame(double t, double seconds) => FaceFrame(
    eyeShift: const Offset(0, 3),
    eyeScale: Offset(1, lids.at(t)),
    browShiftL: brow.at(t),
    browShiftR: brow.at(t),
    browRotL: -6,
    browRotR: 6,
    mouth: mouth.at(t),
    noseScale: _nosAt(seconds),
    zzz: 1,
    zzzSeconds: seconds,
  );
}

class _Grumpy extends MoodScript {
  _Grumpy();
  @override
  Duration get duration => const Duration(seconds: 6);
  @override
  double get pose => 0.3;
  final eye = _p('0.0;0.1667;0.1833;0.4;0.4167;1', '0 0;0 0;-7 0;-7 0;0 0;0 0');
  final lids = _d(
    '0.0;0.5333;0.55;0.6583;0.6833;1',
    '0.78;0.78;0.55;0.55;0.78;0.78',
  );
  final blink = _d('0.0;0.8333;0.8583;0.9;0.9333;0.9583;1', _shut);
  final brow = _p(
    '0.0;0.5167;0.5417;0.65;0.675;0.7;1',
    '0 3;0 3;0 7;0 7;0 1.5;0 3;0 3',
  );
  final rot = _d('0.0;0.5167;0.5417;0.65;0.675;0.7;1', '14;14;20;20;12;14;14');
  final mouth = _m('0.0;0.55;0.57;0.6417;0.675;1', [
    MouthShape.frown,
    MouthShape.frown,
    MouthShape.flat,
    MouthShape.flat,
    MouthShape.frown,
    MouthShape.frown,
  ]);
  @override
  FaceFrame frame(double t, double seconds) {
    final r = rot.at(t);
    return FaceFrame(
      eyeShift: eye.at(t),
      eyeScale: Offset(1, lids.at(t)),
      blink: blink.at(t),
      browShiftL: brow.at(t),
      browShiftR: brow.at(t),
      browRotL: r,
      browRotR: -r,
      mouth: mouth.at(t),
      noseScale: _nosAt(seconds),
    );
  }
}

class _Surprised extends MoodScript {
  _Surprised();
  @override
  Duration get duration => const Duration(seconds: 5);
  @override
  double get pose => 0.4;
  final pop = _p(
    '0.0;0.16;0.184;0.208;0.232;0.26;0.64;0.69;1',
    '1 1;1 1;0.92 0.92;1.22 1.22;1.14 1.14;1.16 1.16;1.16 1.16;1 1;1 1',
  );
  final squash = _p('0.0;0.16;0.184;0.208;1', '1 1;1 1;1 0.85;1 1;1 1');
  final blink = _d(
    '0.0;0.49;0.504;0.516;0.532;0.55;0.556;0.57;0.582;0.598;0.616;1',
    '1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1',
  );
  final brow = _p(
    '0.0;0.16;0.184;0.208;0.232;0.26;0.64;0.69;0.86;0.91;1',
    '0 0;0 0;0 2.5;0 -12;0 -9.5;0 -10;0 -10;0 -3;0 -3;0 0;0 0',
  );
  final mouth = _m('0.0;0.196;0.22;0.65;0.69;0.87;0.92;1', [
    MouthShape.smile,
    MouthShape.smile,
    MouthShape.oh,
    MouthShape.oh,
    MouthShape.grin,
    MouthShape.grin,
    MouthShape.smile,
    MouthShape.smile,
  ]);
  @override
  FaceFrame frame(double t, double seconds) => FaceFrame(
    eyeScale: _mul(pop.at(t), squash.at(t)),
    blink: blink.at(t),
    browShiftL: brow.at(t),
    browShiftR: brow.at(t),
    mouth: mouth.at(t),
    noseScale: _nosAt(seconds),
  );
}

/// Asleep → startled awake (bells ring) → double blink → big yawn → smile.
class _WakeUp extends MoodScript {
  _WakeUp();
  @override
  Duration get duration => const Duration(seconds: 9);
  @override
  double get pose => 0.75;
  final pop = _p(
    '0.0;0.2833;0.2911;0.3022;0.4333;0.4556;1',
    '1 1;1 1;1.2 1.2;1.14 1.14;1.14 1.14;1 1;1 1',
  );
  final lids = _d(
    '0.0;0.2833;0.2911;0.4911;0.5056;0.6222;0.6556;0.8889;0.9556;1',
    '0.08;0.08;1;1;0.08;0.08;0.78;0.78;0.08;0.08',
  );
  final blink = _d(
    '0.0;0.3778;0.3856;0.3922;0.4011;0.4111;0.4133;0.4211;0.4278;0.4367;0.4467;0.7778;0.7856;0.7922;0.8011;0.8111;1',
    '1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1;0.08;0.08;0.6;1;1',
  );
  final brow = _p(
    '0.0;0.2722;0.2833;0.2978;0.4333;0.4556;0.4778;0.4911;0.6222;0.6556;0.8889;0.9556;1',
    '0 3;0 3;0 -10;0 -7.5;0 -7.5;0 -2;0 -2;0 -5;0 -5;0 0;0 0;0 3;0 3',
  );
  final mouth = _m(
    '0.0;0.2889;0.3;0.4944;0.5167;0.6111;0.6444;0.6611;0.8778;0.9222;0.9556;1',
    [
      MouthShape.small,
      MouthShape.small,
      MouthShape.oh,
      MouthShape.oh,
      MouthShape.yawn,
      MouthShape.yawn,
      MouthShape.oh,
      MouthShape.grin,
      MouthShape.grin,
      MouthShape.smile,
      MouthShape.small,
      MouthShape.small,
    ],
  );
  final zzz = _d('0.0;0.2722;0.2833;0.9556;0.9889;1', '1;1;0;0;1;1');
  final ring = _d(
    '0.0;0.2667;0.2756;0.2844;0.2933;0.3022;0.3111;0.32;0.3289;0.3378;0.3467;1',
    '0;0;14;-14;12;-12;10;-10;6;-6;0;0',
  );
  @override
  FaceFrame frame(double t, double seconds) => FaceFrame(
    eyeScale: _mul(pop.at(t), Offset(1, lids.at(t))),
    blink: blink.at(t),
    browShiftL: brow.at(t),
    browShiftR: brow.at(t),
    mouth: mouth.at(t),
    noseScale: _nosAt(seconds),
    zzz: zzz.at(t),
    zzzSeconds: seconds,
    earWiggle: ring.at(t) * 0.6,
  );
}

final _happy = _Happy();
final _excited = _Excited();
final _thinking = _Thinking();
final _sleepy = _Sleepy();
final _grumpy = _Grumpy();
final _surprised = _Surprised();
final _wakeUp = _WakeUp();
