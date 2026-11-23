import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../auth/auth_adapter.dart';
import '../domain/run.dart';
import 'run_store.dart';

typedef RunAccount = ({String? uid, bool verified});

final runAccountProvider = Provider<RunAccount?>((ref) {
  if (ref.watch(authAdapterProvider) == null) {
    return (uid: null, verified: false);
  }
  // Hold local history while Firebase is restoring the identity.
  final session = ref.watch(sessionProvider).asData;
  if (session == null) return null;
  return (
    uid: session.value?.uid,
    verified: session.value?.emailVerified == true,
  );
});

abstract interface class RunCloud {
  Stream<bool> get connection;
  Stream<List<SavedRun>> watch(String uid);
  Future<void> save(String uid, RunSummary summary);
  Future<void> delete(String uid, String id);
}

class FirebaseRunCloud implements RunCloud {
  FirebaseRunCloud(this.database);

  final FirebaseDatabase database;

  DatabaseReference _runs(String uid) => database.ref('users/$uid/runs');

  @override
  Stream<bool> get connection => database
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true)
      .distinct();

  @override
  Stream<List<SavedRun>> watch(String uid) => _runs(uid).onValue.map((event) {
    final entries = <SavedRun>[];
    for (final snapshot in event.snapshot.children) {
      final id = snapshot.key;
      final value = snapshot.value;
      if (id == null || !runIdPattern.hasMatch(id)) continue;
      if (value is Map && value.length == 1 && value['deleted'] == true) {
        entries.add(SavedRun(id: id, summary: null));
      } else if (RunSummary.parse(id, value) case final RunSummary summary) {
        entries.add(SavedRun(id: id, summary: summary));
      }
    }
    return entries;
  });

  @override
  Future<void> save(String uid, RunSummary summary) =>
      _runs(uid).child(summary.id).set(summary.toJson());

  @override
  Future<void> delete(String uid, String id) =>
      _runs(uid).child(id).set({'deleted': true});
}

final runCloudProvider = Provider<RunCloud?>((ref) {
  if (!ref.watch(firebaseReadyProvider) ||
      !AppConfig.profileDatabaseConfigured) {
    return null;
  }
  return FirebaseRunCloud(FirebaseDatabase.instance);
});
