// Review renders of the Focus shield screen. Not part of the suite:
// run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/domain/models/focus_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_focus_guard.dart';
import '../helpers/pump.dart';

const _apps = [
  ShieldApp(package: 'video', label: 'VideoTube'),
  ShieldApp(package: 'photo', label: 'Photogram'),
  ShieldApp(package: 'chat', label: 'Chatter'),
  ShieldApp(package: 'news', label: 'Daily News'),
  ShieldApp(package: 'maps', label: 'Maps'),
  ShieldApp(package: 'notes', label: 'Notes'),
];

Future<void> _render(
  WidgetTester tester,
  String name,
  FakeFocusGuard guard, {
  double width = 390,
  double height = 844,
  bool openLimit = false,
}) async {
  await pumpBimbi(
    tester,
    width: width,
    height: height,
    guard: guard,
    now: DateTime(2026, 11, 24, 16),
  );
  await tester.tap(find.text('Focus').last);
  await tester.pumpAndSettle();
  final card = find.textContaining('Focus shield').first;
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  if (openLimit) {
    final button = find.textContaining('Daily limit:').first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
  await settleSnapshotImages(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  testWidgets('shield needs access', (t) {
    return _render(
      t,
      'shield_390_access',
      FakeFocusGuard(usageAccess: true, apps: _apps),
    );
  });
  testWidgets('shield ready with choices', (t) {
    final guard =
        FakeFocusGuard(
            usageAccess: true,
            overlay: true,
            apps: _apps,
            todayMinutes: const {'video': 34, 'photo': 12, 'chat': 51},
          )
          ..focusApps = {'video', 'photo'}
          ..limits = {'chat': 45, 'video': 30};
    return _render(t, 'shield_390_ready', guard);
  });
  testWidgets('shield limit sheet', (t) {
    final guard = FakeFocusGuard(
      usageAccess: true,
      overlay: true,
      apps: _apps,
      todayMinutes: const {'chat': 51},
    )..limits = {'chat': 75};
    return _render(t, 'shield_390_limit', guard, openLimit: true);
  });
  testWidgets('shield tablet landscape', (t) {
    final guard =
        FakeFocusGuard(
            usageAccess: true,
            overlay: true,
            apps: _apps,
            todayMinutes: const {'video': 34, 'photo': 12, 'chat': 51},
          )
          ..focusApps = {'video', 'photo'}
          ..limits = {'chat': 45};
    return _render(t, 'shield_1006', guard, width: 1006, height: 552);
  });
}
