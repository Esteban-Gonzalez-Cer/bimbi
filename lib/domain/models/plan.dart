import 'package:flutter/foundation.dart';

/// Bimbi's three plans. Paid plans are 30-day passes bought with a Stripe
/// test payment; only the trusted server writes them (ADR-005).
enum PlanTier {
  free('Free'),
  plus('Plus'),
  premium('Premium');

  const PlanTier(this.label);
  final String label;

  bool includes(PlanTier other) => index >= other.index;

  static PlanTier parse(Object? value) =>
      PlanTier.values.where((t) => t.name == value).firstOrNull ??
      PlanTier.free;
}

/// Server-written plan state at `users/{uid}/entitlements`. Read-only here.
@immutable
class Entitlement {
  const Entitlement({
    required this.tier,
    required this.verifiedAt,
    required this.expiresAt,
  });

  final PlanTier tier;
  final DateTime verifiedAt;
  final DateTime expiresAt;

  bool activeAt(DateTime now) =>
      tier != PlanTier.free && expiresAt.isAfter(now);

  /// The plan in force at [now]: Free once the pass has expired.
  PlanTier effectiveAt(DateTime now) => activeAt(now) ? tier : PlanTier.free;

  static Entitlement? fromRow(Object? value) {
    if (value is! Map) return null;
    final tier = PlanTier.parse(value['tier']);
    final verified = value['verifiedAt'];
    final expires = value['expiresAt'];
    if (tier == PlanTier.free || verified is! num || expires is! num) {
      return null;
    }
    return Entitlement(
      tier: tier,
      verifiedAt: DateTime.fromMillisecondsSinceEpoch(verified.toInt()),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires.toInt()),
    );
  }
}

/// A server-written test receipt at `users/{uid}/payments/{paymentIntentId}`.
@immutable
class TestReceipt {
  const TestReceipt({
    required this.id,
    required this.plan,
    required this.amountMinor,
    required this.currency,
    required this.verifiedAt,
  });

  final String id;
  final PlanTier plan;

  /// Minor units (centavos).
  final int amountMinor;
  final String currency;
  final DateTime verifiedAt;

  static TestReceipt? fromRow(String id, Object? value) {
    if (value is! Map || value['testMode'] != true) return null;
    final amount = value['amount'];
    final verified = value['verifiedAt'];
    final plan = PlanTier.parse(value['plan']);
    if (amount is! num || verified is! num || plan == PlanTier.free) {
      return null;
    }
    return TestReceipt(
      id: id,
      plan: plan,
      amountMinor: amount.toInt(),
      currency: '${value['currency'] ?? 'mxn'}'.toUpperCase(),
      verifiedAt: DateTime.fromMillisecondsSinceEpoch(verified.toInt()),
    );
  }
}
