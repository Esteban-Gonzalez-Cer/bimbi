import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../data/services/messaging_service.dart';
import '../view_models/notifications.dart';

/// A console message received while Bimbi is open. Android shows nothing in
/// the foreground, so Bimbi shows it here with Open and Dismiss.
class MessageBanner extends ConsumerWidget {
  const MessageBanner({super.key, required this.message});
  final InboxMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final inbox = ref.read(inboxProvider.notifier);
    final title = message.title?.trim().isNotEmpty == true
        ? message.title!.trim()
        : 'Bimbi';
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: c.cardBorder),
          boxShadow: c.shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentTint,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: const BimbiIcon(BimbiIcons.bell, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (message.body?.trim().isNotEmpty == true)
                        Text(
                          message.body!.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: inbox.dismiss,
                  child: const Text('Dismiss'),
                ),
                TextButton(
                  onPressed: () => inbox.open(message),
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
