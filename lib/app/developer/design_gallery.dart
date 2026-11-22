import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../shell/layout.dart';

/// Debug-only catalogue of every design-system piece with fixture data.
/// Used for visual review and golden tests; never shows user data.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: context.bimbi.background,
      surfaceTintColor: Colors.transparent,
      title: Text('Design gallery', style: context.text.titleLarge),
    ),
    body: const GalleryBody(),
  );
}

class GalleryBody extends StatelessWidget {
  const GalleryBody({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return PageBody(
      maxWidth: 900,
      children: [
        const SectionLabel('Buddy moods'),
        Wrap(
          spacing: BimbiSpace.md,
          runSpacing: BimbiSpace.md,
          children: [
            for (final mood in BuddyMood.values)
              Column(
                children: [
                  BimbiBuddy(mood: mood, size: 96),
                  Text(mood.name, style: context.text.labelMedium),
                ],
              ),
          ],
        ),
        const SectionLabel('Type'),
        BimbiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('07:00', style: context.text.displayLarge),
              Text('Good morning!', style: context.text.headlineLarge),
              Text('Tonight’s plan', style: context.text.headlineSmall),
              Text(
                'Shake your phone 30 times to stop the alarm.',
                style: context.text.bodyLarge,
              ),
              Text('5 nights logged', style: context.text.labelMedium),
            ],
          ),
        ),
        const SectionLabel('Colour'),
        Wrap(
          spacing: BimbiSpace.xs,
          runSpacing: BimbiSpace.xs,
          children: [
            for (final (name, color) in const [
              ('Plum', BimbiPalette.lightAccent),
              ('Lavender tint', BimbiPalette.lightTint),
              ('Lilac accent', BimbiPalette.darkAccent),
              ('Night', BimbiPalette.night),
              ('Lavender background', BimbiPalette.lightBackground),
              ('Ink', BimbiPalette.ink),
              ('Mint', BimbiPalette.mint),
              ('Coral', BimbiPalette.coral),
            ])
              Container(
                width: 96,
                height: 64,
                padding: const EdgeInsets.all(BimbiSpace.xs),
                alignment: Alignment.bottomLeft,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BimbiRadius.chipBorder,
                  border: Border.all(color: c.cardBorder),
                ),
                child: Text(
                  name,
                  style: context.text.labelSmall?.copyWith(
                    color: color.computeLuminance() > 0.4
                        ? BimbiPalette.ink
                        : BimbiPalette.lightBackground,
                  ),
                ),
              ),
          ],
        ),
        const SectionLabel('Buttons'),
        Wrap(
          spacing: BimbiSpace.sm,
          runSpacing: BimbiSpace.sm,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Start focus')),
            const FilledButton(onPressed: null, child: Text('Start focus')),
            OutlinedButton(onPressed: () {}, child: const Text('Pause')),
            TextButton(onPressed: () {}, child: const Text('See all')),
          ],
        ),
        const SectionLabel('Alarm cards'),
        const AlarmCard(
          time: TimeOfDay(hour: 7, minute: 0),
          label: 'Gym day',
          days: {0, 1, 2, 3, 4},
          enabled: true,
          mission: WakeMission.shake,
        ),
        const AlarmCard(
          time: TimeOfDay(hour: 9, minute: 30),
          label: 'Lazy Sunday',
          days: {6},
          enabled: false,
        ),
        const AlarmCard(
          time: TimeOfDay(hour: 23, minute: 0),
          label: 'Wind down',
          days: {0, 1, 2, 3, 4, 5, 6},
          enabled: true,
          bedtime: true,
        ),
        const SectionLabel('Selection'),
        DayChips(selected: const {0, 2, 4}, onChanged: (_) {}),
        WakeMissionSelector(value: WakeMission.shake, onChanged: (_) {}),
        const MissionProgress(label: 'Shake mission', current: 18, total: 30),
        const SectionLabel('Data'),
        const Row(
          children: [
            Expanded(
              child: StatTile(
                icon: BimbiIcons.bedtime,
                value: '7 h 12 m',
                label: 'Time in bed',
              ),
            ),
            SizedBox(width: BimbiSpace.sm),
            Expanded(
              child: StatTile(
                icon: BimbiIcons.steps,
                value: '1.24 km',
                label: 'Distance',
              ),
            ),
          ],
        ),
        BimbiCard(
          child: WeekBars(
            labels: weekdayLetters,
            values: const [
              Duration(hours: 7, minutes: 10),
              Duration(hours: 6, minutes: 40),
              null,
              Duration(hours: 8),
              Duration(hours: 7, minutes: 30),
              Duration(hours: 9),
              Duration(hours: 7, minutes: 12),
            ],
            highlight: 6,
          ),
        ),
        const SectionLabel('Feedback'),
        const InlineBanner(
          title: 'Bedtime in 30 minutes',
          message: 'Ready to wind down?',
          tone: BannerTone.night,
          icon: BimbiIcons.bedtime,
        ),
        const InlineBanner(
          title: 'Alarm set',
          message: 'Tomorrow at 7:00.',
          tone: BannerTone.success,
          icon: BimbiIcons.check,
        ),
        const InlineBanner(
          title: 'Alarms can’t ring yet',
          message: 'Allow exact alarms.',
          tone: BannerTone.danger,
          icon: BimbiIcons.lock,
        ),
        const SectionLabel('Plans'),
        const PlanCard(
          name: 'Plus',
          price: r'MX$10',
          period: 'test payment',
          featured: true,
          features: ['Everything in Free', 'Wake-up missions'],
          actionLabel: 'Try Plus',
        ),
        const SectionLabel('Icons'),
        Wrap(
          spacing: BimbiSpace.md,
          runSpacing: BimbiSpace.md,
          children: [for (final i in BimbiIcons.values) BimbiIcon(i)],
        ),
        const EmptyState(
          title: 'No alarms yet',
          message: 'Your next wake-up shows here.',
        ),
      ],
    );
  }
}
