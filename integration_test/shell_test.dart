import 'package:bimbi/app/design_system/components/surfaces.dart';
import 'package:bimbi/app/shell/adaptive_shell.dart';
import 'package:bimbi/main.dart' as app;
import 'package:bimbi/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android startup, onboarding and all five destinations', (
    tester,
  ) async {
    await app.main();
    // The buddy animates continuously; settle with a bounded pump.
    await tester.pump(const Duration(seconds: 2));
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(seconds: 1));
    }
    for (final destination in [
      ...AppDestination.values.skip(1),
      AppDestination.alarm,
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is NavigationBar || w is NavigationRail,
          ),
          matching: find.text(destination.label),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final title = find.byKey(PageHeader.titleKey);
      expect(title, findsOneWidget);
      if (destination == AppDestination.alarm) {
        expect(find.byType(HomeScreen), findsOneWidget);
      } else if (destination == AppDestination.sleep) {
        expect(tester.widget<Text>(title).data, 'Last night');
      } else {
        expect(tester.widget<Text>(title).data, destination.label);
      }
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(Scaffold), findsWidgets);
  });
}
