import 'package:bimbi/app/design_system/components/surfaces.dart';
import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/app/theme/bimbi_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump.dart';

void main() {
  testWidgets('onboarding: four steps, name and colour, then the shell', (
    tester,
  ) async {
    await pumpBimbi(tester, onboarded: false);
    expect(find.text('Hi, I’m Bimbi'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Make me yours'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Mint buddy'));
    await tester.enterText(find.byType(TextField), 'Sofía');
    await tester.tap(find.text('Let’s go'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(PageHeader.titleKey)),
    );
    expect(container.read(displayNameProvider), 'Sofía');
    expect(container.read(buddyColorProvider), BuddyColorPreset.mint);
    expect(container.read(onboardingProvider), isTrue);
    expect(find.text('Good morning,'), findsOneWidget);
    expect(find.text('Sofía'), findsOneWidget);
  });

  testWidgets('Back steps through onboarding before leaving', (tester) async {
    await pumpBimbi(tester, onboarded: false);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 2 of 4'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
  });

  testWidgets('Skip finishes onboarding without requesting permissions', (
    tester,
  ) async {
    await pumpBimbi(tester, onboarded: false, textScale: 2, width: 360);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(PageHeader.titleKey)),
    );
    expect(container.read(buddyColorProvider), BuddyColorPreset.lilac);
    expect(find.byKey(PageHeader.titleKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
