import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../features/auth/auth_adapter.dart';
import 'local_collection.dart';

/// Cloud side of a user collection: `users/{uid}/{name}/{key}`.
abstract interface class CloudCollection {
  Stream<bool> get connection;
  Stream<Map<String, StoredRow>> watch(String uid, String name);

  /// Writes a row, or deletes it when [row] is null. Completes when the
  /// server has accepted the change.
  Future<void> write(String uid, String name, String key, StoredRow? row);
}

class FirebaseCloudCollection implements CloudCollection {
  FirebaseCloudCollection(this.database);
  final FirebaseDatabase database;

  @override
  Stream<bool> get connection => database
      .ref('.info/connected')
      .onValue
      .map((e) => e.snapshot.value == true);

  @override
  Stream<Map<String, StoredRow>> watch(String uid, String name) =>
      database.ref('users/$uid/$name').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const {};
        return {
          for (final e in value.entries)
            if (e.value is Map)
              '${e.key}': Map<String, Object?>.from(e.value as Map),
        };
      });

  @override
  Future<void> write(String uid, String name, String key, StoredRow? row) =>
      database.ref('users/$uid/$name/$key').set(row);
}

final cloudCollectionProvider = Provider<CloudCollection?>((ref) {
  if (!ref.watch(firebaseReadyProvider) ||
      !AppConfig.profileDatabaseConfigured) {
    return null;
  }
  return FirebaseCloudCollection(FirebaseDatabase.instance);
});

/// The verified account whose data may sync, or null for guests and
/// unverified sessions (rules deny them anyway).
final syncAccountProvider = Provider<String?>((ref) {
  final user = ref.watch(sessionProvider).asData?.value;
  return user != null && user.emailVerified ? user.uid : null;
});

enum SyncPhase { local, offline, syncing, synced, unavailable }

@immutable
class SyncStatus {
  const SyncStatus({this.phase = SyncPhase.local, this.pending = 0});
  final SyncPhase phase;
  final int pending;
}

/// Keeps one [CollectionController] in step with the cloud for the verified
/// account. Local edits are never blocked by the network.
abstract class CollectionSync extends Notifier<SyncStatus> {
  /// Path segment under `users/{uid}/`.
  String get name;
  NotifierProvider<CollectionController, CollectionState> get rows;

  static const _timeout = Duration(seconds: 15);

  StreamSubscription<Map<String, StoredRow>>? _remote;
  StreamSubscription<bool>? _connection;
  String? _uid;
  bool _online = false;
  bool _pushing = false;
  int _generation = 0;

  CollectionController get _local => ref.read(rows.notifier);

  @override
  SyncStatus build() {
    final cloud = ref.watch(cloudCollectionProvider);
    final uid = ref.watch(syncAccountProvider);
    ref.listen(rows, (_, next) {
      _publish(next);
      if (next.pending.isNotEmpty) unawaited(_push());
    });
    ref.onDispose(() {
      _generation++;
      unawaited(_remote?.cancel());
      unawaited(_connection?.cancel());
    });
    if (cloud == null || uid == null) {
      _uid = null;
      return SyncStatus(pending: ref.read(rows).pending.length);
    }
    final generation = ++_generation;
    _uid = uid;
    _online = false;
    // Adopting may rewrite the local store, so it runs after build.
    scheduleMicrotask(() {
      if (!ref.mounted || generation != _generation) return;
      _local.adopt(uid);
      _remote = cloud
          .watch(uid, name)
          .listen(
            (snapshot) {
              if (generation != _generation) return;
              _local.applyRemote(snapshot);
              unawaited(_push());
            },
            onError: (Object _) {
              if (generation != _generation) return;
              state = SyncStatus(
                phase: SyncPhase.unavailable,
                pending: ref.read(rows).pending.length,
              );
            },
          );
      _connection = cloud.connection.distinct().listen((online) {
        if (generation != _generation) return;
        _online = online;
        _publish(ref.read(rows));
        if (online) unawaited(_push());
      });
    });
    return SyncStatus(
      phase: SyncPhase.offline,
      pending: ref.read(rows).pending.length,
    );
  }

  void _publish(CollectionState rowsState) {
    if (!ref.mounted) return;
    if (_uid == null) {
      state = SyncStatus(pending: rowsState.pending.length);
      return;
    }
    if (state.phase == SyncPhase.unavailable) return;
    state = SyncStatus(
      phase: !_online
          ? SyncPhase.offline
          : rowsState.pending.isEmpty
          ? SyncPhase.synced
          : SyncPhase.syncing,
      pending: rowsState.pending.length,
    );
  }

  Future<void> _push() async {
    final cloud = ref.read(cloudCollectionProvider);
    final uid = _uid;
    if (_pushing || cloud == null || uid == null || !_online) return;
    final generation = _generation;
    _pushing = true;
    try {
      while (ref.mounted && generation == _generation) {
        final snapshot = ref.read(rows);
        if (snapshot.owner != uid || snapshot.pending.isEmpty) break;
        var progress = false;
        for (final key in snapshot.pending.toList()) {
          final row = snapshot.rows[key];
          if (row == null) continue;
          final sent = row['updatedAt'];
          if (sent is! int) continue;
          try {
            await cloud
                .write(uid, name, key, row['deleted'] == true ? null : row)
                .timeout(_timeout);
          } on Object {
            if (ref.mounted) _publish(ref.read(rows));
            return;
          }
          if (!ref.mounted || generation != _generation) return;
          _local.confirm(key, sent);
          progress = true;
        }
        if (!progress) break;
      }
    } finally {
      _pushing = false;
    }
  }
}
