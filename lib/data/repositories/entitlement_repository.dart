import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/config.dart';
import '../../domain/models/plan.dart';
import '../../features/auth/auth_adapter.dart';
import 'collection_sync.dart';

/// Read-only view of what the trusted payment server wrote for an account.
abstract interface class EntitlementSource {
  Stream<Entitlement?> entitlement(String uid);
  Stream<List<TestReceipt>> receipts(String uid);
}

class FirebaseEntitlementSource implements EntitlementSource {
  FirebaseEntitlementSource(this.database);
  final FirebaseDatabase database;

  @override
  Stream<Entitlement?> entitlement(String uid) => database
      .ref('users/$uid/entitlements')
      .onValue
      .map((e) => Entitlement.fromRow(e.snapshot.value));

  @override
  Stream<List<TestReceipt>> receipts(String uid) =>
      database.ref('users/$uid/payments').onValue.map((e) {
        final value = e.snapshot.value;
        if (value is! Map) return const <TestReceipt>[];
        return [
          for (final entry in value.entries)
            ?TestReceipt.fromRow('${entry.key}', entry.value),
        ]..sort((a, b) => b.verifiedAt.compareTo(a.verifiedAt));
      });
}

final entitlementSourceProvider = Provider<EntitlementSource?>((ref) {
  if (!ref.watch(firebaseReadyProvider) ||
      !AppConfig.profileDatabaseConfigured) {
    return null;
  }
  return FirebaseEntitlementSource(FirebaseDatabase.instance);
});

/// The verified account's entitlement as the server wrote it; null for
/// guests, unverified accounts and accounts that never paid.
final entitlementProvider = StreamProvider<Entitlement?>((ref) {
  final source = ref.watch(entitlementSourceProvider);
  final uid = ref.watch(syncAccountProvider);
  if (source == null || uid == null) return Stream.value(null);
  return source.entitlement(uid);
});

final receiptsProvider = StreamProvider<List<TestReceipt>>((ref) {
  final source = ref.watch(entitlementSourceProvider);
  final uid = ref.watch(syncAccountProvider);
  if (source == null || uid == null) return Stream.value(const []);
  return source.receipts(uid);
});

/// The plan in force now. Never set locally: it only follows the server's
/// entitlement and falls back to Free when the pass expires.
final planTierProvider = Provider<PlanTier>((ref) {
  final entitlement = ref.watch(entitlementProvider).value;
  if (entitlement == null) return PlanTier.free;
  return entitlement.effectiveAt(ref.watch(clockProvider)());
});
