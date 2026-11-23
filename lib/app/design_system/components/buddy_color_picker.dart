import 'package:flutter/material.dart';

import '../../theme/bimbi_colors.dart';
import '../../theme/bimbi_tokens.dart';

/// Round 48dp swatches for the buddy colour. Plus colours show a small
/// badge and call [onLocked] instead of [onChanged] until [plusUnlocked].
class BuddyColorPicker extends StatelessWidget {
  const BuddyColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.alignment = WrapAlignment.start,
    this.plusUnlocked = false,
    this.onLocked,
  });

  final BuddyColorPreset value;
  final ValueChanged<BuddyColorPreset> onChanged;
  final WrapAlignment alignment;
  final bool plusUnlocked;
  final VoidCallback? onLocked;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return Wrap(
      alignment: alignment,
      spacing: BimbiSpace.xs,
      runSpacing: BimbiSpace.xs,
      children: [
        for (final p in BuddyColorPreset.values)
          if (!p.plus || plusUnlocked || onLocked != null)
            Semantics(
              button: true,
              selected: p == value,
              label: p.plus && !plusUnlocked
                  ? '${p.label} buddy, needs Plus'
                  : '${p.label} buddy',
              excludeSemantics: true,
              child: InkResponse(
                radius: 26,
                onTap: () =>
                    p.plus && !plusUnlocked ? onLocked?.call() : onChanged(p),
                child: Container(
                  width: kBimbiMinTarget,
                  height: kBimbiMinTarget,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: p == value ? c.focusRing : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.plus && !plusUnlocked
                                ? p.color.withValues(alpha: .45)
                                : p.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.text, width: 2),
                          ),
                        ),
                      ),
                      if (p.plus && !plusUnlocked)
                        Positioned(
                          right: -6,
                          bottom: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: c.cardBorder),
                            ),
                            child: Text(
                              'Plus',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: c.link,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
