import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/app/theme/bimbi_tokens.dart';
import 'package:bimbi/core/clock.dart';
import 'package:bimbi/core/platform.dart';
import 'package:bimbi/data/repositories/entitlement_repository.dart';
import 'package:bimbi/domain/models/plan.dart';
import 'package:bimbi/ui/plans/view_models/plan_perks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_platform.dart';

void main() {
  final now = DateTime(2026, 11, 22, 20);
  Entitlement pass(PlanTier tier, {int daysLeft = 20}) => Entitlement(
    tier: tier,
    verifiedAt: now.subtract(const Duration(days: 10)),
    expiresAt: now.add(Duration(days: daysLeft)),
  );

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer app(
    AsyncValue<Entitlement?> entitlement, {
    FakePlatform? platform,
  }) {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        preferencesProvider.overrideWithValue(prefs),
        entitlementProvider.overrideWithValue(entitlement),
        if (platform != null) platformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('only an unexpired server pass counts; expired is Free', () {
    expect(pass(PlanTier.plus).effectiveAt(now), PlanTier.plus);
    expect(pass(PlanTier.plus, daysLeft: -1).effectiveAt(now), PlanTier.free);
    expect(app(const AsyncData(null)).read(planTierProvider), PlanTier.free);
    expect(
      app(AsyncData(pass(PlanTier.premium))).read(planTierProvider),
      PlanTier.premium,
    );
    expect(PlanTier.premium.includes(PlanTier.plus), isTrue);
    expect(PlanTier.plus.includes(PlanTier.premium), isFalse);
  });

  test('server rows parse strictly; free or malformed rows are ignored', () {
    final row = {
      'tier': 'plus',
      'verifiedAt': now.millisecondsSinceEpoch,
      'expiresAt': now.add(const Duration(days: 30)).millisecondsSinceEpoch,
      'grants': {'pi_1': 1},
    };
    expect(Entitlement.fromRow(row)?.tier, PlanTier.plus);
    expect(Entitlement.fromRow({...row, 'tier': 'free'}), isNull);
    expect(Entitlement.fromRow({...row, 'expiresAt': 'soon'}), isNull);
    expect(
      TestReceipt.fromRow('pi_1', {
        'plan': 'premium',
        'amount': 2000,
        'currency': 'mxn',
        'verifiedAt': 1,
        'testMode': true,
      })?.amountMinor,
      2000,
    );
    expect(
      TestReceipt.fromRow('pi_2', {
        'plan': 'plus',
        'amount': 1,
        'verifiedAt': 1,
      }),
      isNull,
      reason: 'only test-mode receipts are shown',
    );
  });

  test('Plus colours need a pass and come back when it is renewed', () async {
    await prefs.setString('ui.buddy_color', 'rose');
    expect(
      app(const AsyncData(null)).read(buddyColorProvider),
      BuddyColorPreset.lilac,
    );
    expect(
      app(AsyncData(pass(PlanTier.plus))).read(buddyColorProvider),
      BuddyColorPreset.rose,
    );
    final free = app(const AsyncData(null));
    free.read(buddyColorProvider.notifier).set(BuddyColorPreset.violet);
    expect(
      prefs.getString('ui.buddy_color'),
      'rose',
      reason: 'a locked colour cannot be chosen',
    );
  });

  test('Sunrise needs Premium; Plus is not enough', () {
    final plus = app(AsyncData(pass(PlanTier.plus)));
    plus.read(appThemeProvider.notifier).set(AppTheme.sunrise);
    expect(plus.read(appThemeProvider), AppTheme.lavender);
    final premium = app(AsyncData(pass(PlanTier.premium)));
    premium.read(appThemeProvider.notifier).set(AppTheme.sunrise);
    expect(premium.read(appThemeProvider), AppTheme.sunrise);
    expect(
      app(AsyncData(pass(PlanTier.premium, daysLeft: -1)))
          .read(appThemeProvider),
      AppTheme.lavender,
    );
  });

  group('Plus tone guard', () {
    FakePlatform platform() {
      final fake = FakePlatform(
        capabilities: {
          'alarmTones': [
            {'id': 'dawn_chime', 'title': 'Dawn Chime', 'plus': false},
            {'id': 'sparkle_rise', 'title': 'Sparkle Rise', 'plus': true},
          ],
        },
      );
      fake.alarms['a1'] = {
        'id': 'a1',
        'hour': 7,
        'minute': 0,
        'challenge': 'math',
        'tone': 'sparkle_rise',
        'enabled': true,
        'status': 'armed',
      };
      return fake;
    }

    Future<void> settle(ProviderContainer c) async {
      await c.read(capabilitiesProvider.future);
      c.read(plusToneGuardProvider);
      await Future<void>.delayed(Duration.zero);
    }

    test('a lapsed pass moves alarms to Dawn Chime', () async {
      final fake = platform();
      final c = app(const AsyncData(null), platform: fake);
      await settle(c);
      expect(fake.alarms['a1']!['tone'], fallbackTone);
      expect(fake.alarms['a1']!['enabled'] != false, isTrue);
    });

    test('an active pass or a plan still loading changes nothing', () async {
      final paid = platform();
      await settle(app(AsyncData(pass(PlanTier.plus)), platform: paid));
      expect(paid.alarms['a1']!['tone'], 'sparkle_rise');
      final loading = platform();
      await settle(app(const AsyncLoading(), platform: loading));
      expect(loading.alarms['a1']!['tone'], 'sparkle_rise');
    });
  });
}
