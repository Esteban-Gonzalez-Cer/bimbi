import 'package:bimbi/data/repositories/collection_sync.dart';
import 'package:bimbi/data/repositories/entitlement_repository.dart';
import 'package:bimbi/domain/models/plan.dart';
import 'package:bimbi/features/payments/payment_adapter.dart';
import 'package:bimbi/ui/plans/widgets/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump.dart';

class _Payments implements PaymentAdapter {
  final calls = <String>[];
  @override
  Future<String> checkout(String plan) async {
    calls.add('checkout:$plan');
    return 'ok';
  }

  @override
  Future<String> restore() async {
    calls.add('restore');
    return 'Your plan is up to date.';
  }
}

void main() {
  final now = DateTime(2026, 11, 22, 20);

  Future<_Payments> open(
    WidgetTester tester, {
    Entitlement? entitlement,
    List<TestReceipt> receipts = const [],
    double width = 412,
    double textScale = 1,
  }) async {
    final payments = _Payments();
    await pumpBimbi(
      tester,
      width: width,
      height: 1000,
      textScale: textScale,
      now: now,
      overrides: [
        entitlementProvider.overrideWithValue(AsyncData(entitlement)),
        receiptsProvider.overrideWithValue(AsyncData(receipts)),
        syncAccountProvider.overrideWithValue('alice'),
        paymentAdapterProvider.overrideWithValue(payments),
      ],
    );
    final context = tester.element(find.byType(Scaffold).first);
    // ignore: unawaited_futures
    openPlans(context);
    await tester.pumpAndSettle();
    return payments;
  }

  testWidgets('a verified Plus pass shows its expiry, renew and upgrade', (
    tester,
  ) async {
    final payments = await open(
      tester,
      entitlement: Entitlement(
        tier: PlanTier.plus,
        verifiedAt: now,
        expiresAt: DateTime(2026, 12, 22, 20),
      ),
      receipts: [
        TestReceipt(
          id: 'pi_1',
          plan: PlanTier.plus,
          amountMinor: 1000,
          currency: 'MXN',
          verifiedAt: now,
        ),
      ],
    );
    expect(find.text('Active until 22 Dec 2026'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(payments.calls, ['restore']);
    await tester.scrollUntilVisible(
      find.text('Upgrade to Premium'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Renew 30 days'), findsOneWidget);
    expect(find.text(r'MX$10.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expired pass reads as Free and never unlocks anything', (
    tester,
  ) async {
    await open(
      tester,
      entitlement: Entitlement(
        tier: PlanTier.premium,
        verifiedAt: DateTime(2026, 10, 1),
        expiresAt: DateTime(2026, 10, 31),
      ),
    );
    expect(
      find.text('Your Premium pass ended on 31 Oct 2026.'),
      findsOneWidget,
    );
    expect(find.text('Current plan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Get Premium'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plans fits 360 dp at 200 % text and a tablet in landscape', (
    tester,
  ) async {
    await open(tester, width: 360, textScale: 2);
    expect(tester.takeException(), isNull);
    await open(tester, width: 1006);
    expect(tester.takeException(), isNull);
  });
}
