// Review renders of the Plans screen. Not part of the suite:
// run with `flutter test test/review --update-goldens`.
@Tags(['review'])
library;

import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/data/repositories/collection_sync.dart';
import 'package:bimbi/data/repositories/entitlement_repository.dart';
import 'package:bimbi/domain/models/plan.dart';
import 'package:bimbi/ui/plans/widgets/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump.dart';

final _now = DateTime(2026, 11, 22, 20);

Future<void> _render(
  WidgetTester tester,
  String name, {
  Entitlement? entitlement,
  List<TestReceipt> receipts = const [],
  bool signedIn = true,
  bool sunrise = false,
  double width = 390,
  double height = 844,
}) async {
  SharedPreferences.setMockInitialValues({
    if (sunrise) 'ui.app_theme': 'sunrise',
  });
  final prefs = await SharedPreferences.getInstance();
  await pumpBimbi(
    tester,
    width: width,
    height: height,
    now: _now,
    overrides: [
      preferencesProvider.overrideWithValue(prefs),
      entitlementProvider.overrideWithValue(AsyncData(entitlement)),
      receiptsProvider.overrideWithValue(AsyncData(receipts)),
      syncAccountProvider.overrideWithValue(signedIn ? 'alice' : null),
    ],
  );
  // ignore: unawaited_futures
  openPlans(tester.element(find.byType(Scaffold).first));
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

Entitlement _pass(PlanTier tier) => Entitlement(
  tier: tier,
  verifiedAt: _now,
  expiresAt: DateTime(2026, 12, 22, 20),
);

final _receipt = TestReceipt(
  id: 'pi_1',
  plan: PlanTier.plus,
  amountMinor: 1000,
  currency: 'MXN',
  verifiedAt: _now,
);

void main() {
  testWidgets(
    'plans guest',
    (t) => _render(t, 'plans_390_free', signedIn: false),
  );
  testWidgets(
    'plans plus',
    (t) => _render(
      t,
      'plans_390_plus',
      entitlement: _pass(PlanTier.plus),
      receipts: [_receipt],
    ),
  );
  testWidgets(
    'plans premium sunrise',
    (t) => _render(
      t,
      'plans_390_premium_sunrise',
      entitlement: _pass(PlanTier.premium),
      receipts: [_receipt],
      sunrise: true,
    ),
  );
  testWidgets(
    'plans tablet landscape',
    (t) => _render(
      t,
      'plans_1006',
      entitlement: _pass(PlanTier.plus),
      receipts: [_receipt],
      width: 1006,
      height: 552,
    ),
  );
}
