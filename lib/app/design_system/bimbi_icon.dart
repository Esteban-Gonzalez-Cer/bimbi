import 'package:flutter/material.dart';

import '../theme/bimbi_tokens.dart';

/// Claude Hand Drawn by Icons8. Assets are bundled at their original size.
enum BimbiIcons {
  alarm('alarm-clock'),
  bedtime('sleep'),
  wakeUp('sunrise'),
  phoneFree('do-not-disturb'),
  shake('lightning-bolt'),
  math('math'),
  light('light-on'),
  steps('running'),
  sleepStats('line-chart'),
  place('marker'),
  focus('timer'),
  profile('user'),
  plus('add'),
  play('play'),
  pause('pause'),
  stop('stop'),
  check('checkmark'),
  close('delete-sign'),
  chevronRight('forward'),
  chevronLeft('back'),
  edit('edit-pencil'),
  trash('delete'),
  settings('settings'),
  palette('paint-palette'),
  shield('shield'),
  bell('push-notifications'),
  card('bank-cards'),
  signOut('exit'),
  lock('lock'),
  mail('mail'),
  gps('navigation'),
  motion('walking'),
  diary('journal'),
  info('info'),
  sun('sun'),
  google('google-logo'),
  github('github'),
  developer('command-line');

  const BimbiIcons(this.slug);

  final String slug;
  String get asset => 'assets/icons/claude/$slug.png';
}

/// Shows the original artwork on a light backing where contrast needs it.
/// Decorative unless [semanticLabel] is given.
class BimbiIcon extends StatelessWidget {
  const BimbiIcon(
    this.icon, {
    super.key,
    this.size,
    this.onAccent = false,
    this.semanticLabel,
  });

  final BimbiIcons icon;
  final double? size;
  final bool onAccent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? IconTheme.of(context).size ?? 24;
    final needsBacking =
        onAccent || Theme.of(context).brightness == Brightness.dark;
    final picture = DecoratedBox(
      decoration: BoxDecoration(
        color: needsBacking ? BimbiPalette.lightTint : Colors.transparent,
        borderRadius: BorderRadius.circular(dimension / 4),
      ),
      child: Image.asset(
        icon.asset,
        width: dimension,
        height: dimension,
        excludeFromSemantics: true,
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: picture);
    return Semantics(label: semanticLabel, image: true, child: picture);
  }
}
