import 'package:bimbi/core/config.dart';
import 'package:bimbi/features/profile/presentation/profile_picture.dart';
import 'package:bimbi/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The fixture is seeded in demo-bimbi with the Firebase Auth and Storage
/// emulators before running this test. It never signs in to a live project.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android loads and updates a verified emulator profile', (
    tester,
  ) async {
    expect(AppConfig.firebaseEmulators, isTrue);
    await app.main();
    await tester.pump(const Duration(seconds: 2));
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(seconds: 1));
    }
    final profileTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Profile'),
    );
    await tester.tap(profileTab);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Account'));
    await tester.pump(const Duration(seconds: 1));
    if (find.text('Sign out').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sign out'));
    }
    await _waitFor(tester, find.text('Create account'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'phase3-avatar@example.test');
    await tester.enterText(fields.at(1), 'SyntheticBimbiProfile2026');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await _waitFor(tester, find.text('Email verified'));
    await _waitFor(tester, find.text('Choose photo'));
    await tester.pageBack();
    final fixtureName = find.textContaining(
      RegExp(r'^Bimbi (Profile|Android) Demo$'),
    );
    await _waitFor(tester, fixtureName);
    final name =
        tester.widget<Text>(fixtureName.first).data == 'Bimbi Profile Demo'
        ? 'Bimbi Android Demo'
        : 'Bimbi Profile Demo';
    await _waitFor(
      tester,
      find.descendant(
        of: find.byType(ProfilePicture),
        matching: find.byType(Image),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Save name'));
    await _waitFor(tester, find.text('Name synced.'));
    await tester.pageBack();
    await _waitFor(tester, find.text(name));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 32; attempt++) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
