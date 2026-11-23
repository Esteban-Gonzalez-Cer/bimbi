import 'package:bimbi/app/bimbi_app.dart';
import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/core/clock.dart';
import 'package:bimbi/core/platform.dart';
import 'package:bimbi/features/running/data/run_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bimbi/data/services/focus_guard_service.dart';

import 'fake_focus_guard.dart';
import 'fake_platform.dart';
import 'memory_run_disk.dart';

/// Fixed morning so greetings, moods and the sleep week are deterministic.
final testNow = DateTime(2026, 11, 21, 8, 30);

class _Onboarded extends OnboardingController {
  _Onboarded(this.value);
  final bool value;
  @override
  bool build() => value;
}

/// Pumps the whole app at a logical size, text scale and brightness.
/// Animations are disabled (Android "Remove animations") so the buddy holds
/// a static pose and `pumpAndSettle` terminates.
Future<FakePlatform> pumpBimbi(
  WidgetTester tester, {
  double width = 412,
  double height = 900,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool onboarded = true,
  DateTime? now,
  FakePlatform? platform,
  FakeFocusGuard? guard,
  List overrides = const [],
}) async {
  final fake = platform ?? FakePlatform();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformProvider.overrideWithValue(fake),
        focusGuardProvider.overrideWithValue(guard ?? FakeFocusGuard()),
        clockProvider.overrideWithValue(() => now ?? testNow),
        onboardingProvider.overrideWith(() => _Onboarded(onboarded)),
        runStoreProvider.overrideWithValue(RunStore(MemoryRunDisk())),
        ...overrides.cast(),
      ],
      child: const BimbiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Wait for visible bundled artwork before comparing a screenshot.
Future<void> settleSnapshotImages(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final images = find.byType(Image).evaluate().toList();
    await Future.wait(
      images.map((element) {
        final image = element.widget as Image;
        return precacheImage(image.image, element);
      }),
    );
  });
  await tester.pumpAndSettle();
}
