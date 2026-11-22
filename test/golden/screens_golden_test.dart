// Visual baselines (macOS rendering). Regenerate after intended UI changes:
//   flutter test test/golden --update-goldens
@Tags(['golden'])
library;

import 'package:bimbi/app/developer/design_gallery.dart';
import 'package:bimbi/app/shell/adaptive_shell.dart';
import 'package:bimbi/app/theme/bimbi_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

Future<void> _settleImages(WidgetTester tester) async {
  // Bundled images decode asynchronously.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  const widths = [360.0, 412.0, 700.0, 900.0];
  final cases = [
    for (final w in widths) (w, Brightness.light),
    (412.0, Brightness.dark),
    (900.0, Brightness.dark),
  ];
  for (final (width, brightness) in cases) {
    testWidgets('tabs at ${width.toInt()}dp ${brightness.name}', (
      tester,
    ) async {
      await pumpBimbi(tester, width: width, brightness: brightness);
      for (final d in AppDestination.values) {
        await tester.tap(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is NavigationBar || w is NavigationRail,
            ),
            matching: find.text(d.label),
          ),
        );
        await _settleImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/${d.name}_${width.toInt()}_${brightness.name}.png',
          ),
        );
      }
    });
  }

  testWidgets('onboarding first step', (tester) async {
    await pumpBimbi(tester, onboarded: false);
    await _settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_412_light.png'),
    );
  });

  for (final b in Brightness.values) {
    testWidgets('design gallery ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: b == Brightness.light
                ? BimbiTheme.light()
                : BimbiTheme.dark(),
            home: const Scaffold(body: GalleryBody()),
          ),
        ),
      );
      await _settleImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/gallery_${b.name}.png'),
      );
    });
  }
}
