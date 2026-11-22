import 'package:flutter/material.dart';

import '../../theme/bimbi_colors.dart';
import '../../theme/bimbi_tokens.dart';

/// Six round 48dp swatches for the buddy colour.
class BuddyColorPicker extends StatelessWidget {
  const BuddyColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.alignment = WrapAlignment.start,
  });

  final BuddyColorPreset value;
  final ValueChanged<BuddyColorPreset> onChanged;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return Wrap(
      alignment: alignment,
      spacing: BimbiSpace.xs,
      runSpacing: BimbiSpace.xs,
      children: [
        for (final p in BuddyColorPreset.values)
          Semantics(
            button: true,
            selected: p == value,
            label: '${p.label} buddy',
            excludeSemantics: true,
            child: InkResponse(
              radius: 26,
              onTap: () => onChanged(p),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.text, width: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
