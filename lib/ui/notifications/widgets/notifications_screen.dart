import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../core/operation.dart';
import '../../../core/platform.dart';
import '../../../data/services/messaging_service.dart';
import '../view_models/notifications.dart';

Future<void> openNotifications(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));

/// Notification topics. Messages come from Bimbi's team through the Firebase
/// Console; alarms never depend on them.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final topics = ref.watch(topicsProvider);
    final online = ref.watch(messagingServiceProvider) != null;
    final allowed =
        ref.watch(capabilitiesProvider).value?['notifications'] == true;
    final busy = ref.watch(operationProvider).busy;
    final controller = ref.read(topicsProvider.notifier);
    void change({bool? tips, bool? updates}) =>
        ref.read(operationProvider.notifier).run(() async {
          final message = await controller.set(tips: tips, updates: updates);
          ref.invalidate(capabilitiesProvider);
          return message;
        });

    Widget topic({
      required String title,
      required String detail,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    detail,
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: online && !busy ? onChanged : null),
          ],
        ),
      ),
    );

    final children = <Widget>[
      BimbiCard(
        color: c.accentTint,
        borderColor: c.accentTint,
        padding: const EdgeInsets.all(BimbiSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gentle notes from Bimbi',
                    style: context.text.titleLarge?.copyWith(
                      color: c.onAccentTint,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose what Bimbi\'s team may send you. Alarms never '
                    'depend on notifications.',
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BimbiSpace.sm),
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BimbiPalette.lightBackground.withValues(alpha: .68),
              ),
              child: const BimbiBuddy(
                size: 84,
                mood: BuddyMood.happy,
                glow: false,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BimbiRadius.cardBorder,
        ),
        child: Row(
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
                    'Android notifications',
                    style: context.text.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    allowed
                        ? 'Allowed for Bimbi.'
                        : 'Off for Bimbi. Turn a topic on to be asked.',
                    style: context.text.bodyMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (allowed)
              const StatusPill('Allowed', tone: PillTone.success)
            else
              OutlinedButton(
                onPressed: () =>
                    ref.read(platformProvider).settings('notification'),
                child: const Text('Open settings'),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Semantics(
          header: true,
          child: Text('Topics', style: context.text.headlineSmall),
        ),
      ),
      topic(
        title: 'Tips',
        detail: 'Short sleep and focus ideas, now and then.',
        value: topics.tips,
        onChanged: (on) => change(tips: on),
      ),
      topic(
        title: 'Updates',
        detail: 'New Bimbi features and important news.',
        value: topics.updates,
        onChanged: (on) => change(updates: on),
      ),
      Text(
        online
            ? 'You can also mute Tips or Updates in Android settings.'
            : 'Notifications need the online build of Bimbi.',
        style: context.text.bodyMedium?.copyWith(color: c.textMuted),
      ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const BimbiIcon(BimbiIcons.chevronLeft),
        ),
        title: Text(
          'Notifications',
          key: PageHeader.titleKey,
          style: context.text.headlineSmall,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ),
      ),
    );
  }
}
