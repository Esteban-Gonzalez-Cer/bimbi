import 'package:bimbi/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android startup and all five destinations', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    for (final name in ['Sleep', 'Focus', 'Running', 'Profile', 'Alarm']) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      expect(find.text('Bimbi · $name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
