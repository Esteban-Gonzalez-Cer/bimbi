import 'package:flutter/material.dart';

import '../../../app/design_system/design_system.dart';

/// White metric chip from the artboard: 38px tinted icon box, value, label.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  final BimbiIcons icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              alignment: Alignment.center,
              child: BimbiIcon(icon, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: context.text.titleLarge?.copyWith(
                      fontSize: 18,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
