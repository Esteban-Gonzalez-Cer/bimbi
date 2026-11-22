import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../preferences.dart';
import 'buddy_motion.dart';
import 'buddy_painter.dart';
import 'buddy_palette.dart';

export 'buddy_motion.dart' show BuddyMood;

/// Bimbi, the alarm-clock buddy.
///
/// Decorative by default (excluded from TalkBack). Pass [semanticLabel] when
/// the mood carries meaning that is not already in nearby text. Honors the
/// Android "remove animations" setting by showing a static pose.
class BimbiBuddy extends ConsumerStatefulWidget {
  const BimbiBuddy({
    super.key,
    this.mood = BuddyMood.happy,
    this.size = 160,
    this.color,
    this.semanticLabel,
    this.animate = true,
    this.nose = true,
    this.glow = true,
    this.zzzColor,
  });

  final BuddyMood mood;
  final double size;

  /// Overrides the person's chosen buddy colour (e.g. brand Tangerine).
  final Color? color;
  final String? semanticLabel;
  final bool animate;
  final bool nose;
  final bool glow;

  /// Defaults to the ambient text colour so the Zs read on any surface.
  final Color? zzzColor;

  @override
  ConsumerState<BimbiBuddy> createState() => _BimbiBuddyState();
}

class _BimbiBuddyState extends ConsumerState<BimbiBuddy>
    with SingleTickerProviderStateMixin {
  /// Common period of every loop used by the face (1.8, 3, 5, 6, 7, 9 s).
  static const _period = Duration(seconds: 630);
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _period,
  );

  bool get _shouldAnimate =>
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (_shouldAnimate) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BimbiBuddy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _clock.value = 0;
    _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? ref.watch(buddyColorProvider).color;
    final palette = BuddyPalette.from(base);
    final script = MoodScript.of(widget.mood);
    final moodSeconds = script.duration.inMilliseconds / 1000;
    final animated = _shouldAnimate;
    final zzz =
        widget.zzzColor ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final painted = SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final double seconds;
            final double t;
            if (animated) {
              seconds = _clock.value * _period.inSeconds;
              t = (seconds % moodSeconds) / moodSeconds;
            } else {
              t = script.pose;
              seconds = t * moodSeconds;
            }
            return CustomPaint(
              painter: BuddyPainter(
                palette: palette,
                frame: script.frame(t, seconds),
                nose: widget.nose,
                glow: widget.glow,
                zzzColor: zzz,
              ),
            );
          },
        ),
      ),
    );
    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: painted);
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: painted),
    );
  }
}
