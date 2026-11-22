import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/design_system.dart';
import '../../app/preferences.dart';

class OnboardingStepController extends Notifier<int> {
  @override
  int build() => 0;
  void go(int page) => state = page;
}

final onboardingStepProvider =
    NotifierProvider.autoDispose<OnboardingStepController, int>(
      OnboardingStepController.new,
    );

/// First-run introduction. Never requests permissions: Bimbi asks for each
/// one just in time, from the feature that needs it.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  static const pageCount = 4;
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  late final _name = TextEditingController(text: ref.read(displayNameProvider));

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: BimbiMotion.gentle,
        curve: BimbiMotion.ease,
      );
    }
  }

  void _finish() {
    ref.read(displayNameProvider.notifier).set(_name.text);
    ref.read(onboardingProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(onboardingStepProvider);
    final last = step == OnboardingPage.pageCount - 1;
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.all(BimbiSpace.xs),
                      child: Opacity(
                        opacity: last ? 0 : 1,
                        child: TextButton(
                          onPressed: last ? null : _finish,
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: ref
                          .read(onboardingStepProvider.notifier)
                          .go,
                      children: [
                        const _Hello(),
                        const _Helps(),
                        const _Promise(),
                        _Personalise(name: _name),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BimbiSpace.lg,
                      BimbiSpace.sm,
                      BimbiSpace.lg,
                      BimbiSpace.lg,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          label:
                              'Step ${step + 1} of ${OnboardingPage.pageCount}',
                          excludeSemantics: true,
                          child: Row(
                            children: [
                              for (var i = 0; i < OnboardingPage.pageCount; i++)
                                AnimatedContainer(
                                  duration: BimbiMotion.standard,
                                  margin: const EdgeInsets.only(right: 6),
                                  width: i == step ? 24 : 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: i == step
                                        ? Theme.of(context).colorScheme.primary
                                        : context.bimbi.inputBorder,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (step > 0)
                          TextButton(
                            onPressed: () => _goTo(step - 1),
                            child: const Text('Back'),
                          ),
                        const SizedBox(width: BimbiSpace.xs),
                        FilledButton(
                          onPressed: last ? _finish : () => _goTo(step + 1),
                          child: Text(last ? 'Let’s go' : 'Next'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.buddy,
    required this.title,
    required this.message,
    this.extra,
  });
  final Widget buddy;
  final String title;
  final String message;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: BimbiSpace.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buddy,
            const SizedBox(height: BimbiSpace.lg),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
            ),
            const SizedBox(height: BimbiSpace.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: context.bimbi.textMuted,
              ),
            ),
            if (extra != null) ...[
              const SizedBox(height: BimbiSpace.lg),
              extra!,
            ],
          ],
        ),
      ),
    ),
  );
}

double _buddySize(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.28).clamp(140.0, 240.0);

class _Hello extends StatelessWidget {
  const _Hello();
  @override
  Widget build(BuildContext context) => _Slide(
    buddy: BimbiBuddy(mood: BuddyMood.wakeUp, size: _buddySize(context)),
    title: 'Hi, I’m Bimbi',
    message: 'Your buddy from bedtime to wake-up.',
  );
}

class _Helps extends StatelessWidget {
  const _Helps();
  @override
  Widget build(BuildContext context) {
    Widget item(BimbiIcons icon, String title, String detail) => Padding(
      padding: const EdgeInsets.only(bottom: BimbiSpace.sm),
      child: BimbiCard(
        padding: const EdgeInsets.all(BimbiSpace.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.bimbi.accentTint,
                borderRadius: BimbiRadius.chipBorder,
              ),
              alignment: Alignment.center,
              child: BimbiIcon(icon),
            ),
            const SizedBox(width: BimbiSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  Text(detail, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return _Slide(
      buddy: BimbiBuddy(
        mood: BuddyMood.excited,
        size: _buddySize(context) * 0.7,
      ),
      title: 'Gentle days, start to end',
      message: 'Four simple tools, one calm buddy.',
      extra: Column(
        children: [
          item(BimbiIcons.alarm, 'Alarm', 'Wake gently, dismiss safely'),
          item(BimbiIcons.bedtime, 'Sleep', 'An honest sleep diary'),
          item(BimbiIcons.focus, 'Focus', 'Calm, timed focus blocks'),
          item(BimbiIcons.steps, 'Running', 'Walks on a real map'),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise();
  @override
  Widget build(BuildContext context) => _Slide(
    buddy: BimbiBuddy(mood: BuddyMood.thinking, size: _buddySize(context)),
    title: 'Your data, your call',
    message:
        'I only ask for a permission when you use the feature that needs it. '
        'Your walks and diary stay on this device.',
  );
}

class _Personalise extends ConsumerWidget {
  const _Personalise({required this.name});
  final TextEditingController name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddy = ref.watch(buddyColorProvider);
    return _Slide(
      buddy: BimbiBuddy(mood: BuddyMood.happy, size: _buddySize(context) * 0.8),
      title: 'Make me yours',
      message: 'Pick my colour and tell me what to call you.',
      extra: Column(
        children: [
          BuddyColorPicker(
            value: buddy,
            alignment: WrapAlignment.center,
            onChanged: ref.read(buddyColorProvider.notifier).set,
          ),
          const SizedBox(height: BimbiSpace.lg),
          TextField(
            controller: name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              helperText: 'Optional. Stays on this device.',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}
