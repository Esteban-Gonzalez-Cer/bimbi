import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/preferences.dart';
import '../../core/clock.dart';

/// One stored row. `updatedAt` (epoch ms) orders concurrent edits; a row with
/// `deleted: true` is a tombstone kept only until the deletion is synced.
typedef StoredRow = Map<String, Object?>;

/// Device-first copy of a user collection (sleep diary, focus history).
///
/// Every local change is saved immediately and listed in [pending] until the
/// cloud confirms it, so edits made offline survive a restart and are sent on
/// reconnection. [owner] is the verified account these rows belong to, or
/// null while they are guest data.
@immutable
class CollectionState {
  const CollectionState({
    this.rows = const {},
    this.pending = const {},
    this.owner,
  });

  final Map<String, StoredRow> rows;
  final Set<String> pending;
  final String? owner;

  /// Rows that are not deletion markers.
  Map<String, StoredRow> get visible => {
    for (final e in rows.entries)
      if (e.value['deleted'] != true) e.key: e.value,
  };

  CollectionState copyWith({
    Map<String, StoredRow>? rows,
    Set<String>? pending,
    String? owner,
    bool clearOwner = false,
  }) => CollectionState(
    rows: rows ?? this.rows,
    pending: pending ?? this.pending,
    owner: clearOwner ? null : owner ?? this.owner,
  );

  Map<String, Object?> toJson() => {
    'rows': rows,
    'pending': pending.toList(),
    'owner': owner,
  };

  static CollectionState fromJson(Object? json) {
    if (json is! Map) return const CollectionState();
    final rows = <String, StoredRow>{};
    final raw = json['rows'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is Map) {
          rows['${e.key}'] = Map<String, Object?>.from(e.value as Map);
        }
      }
    }
    final pending = (json['pending'] is List)
        ? {for (final k in json['pending'] as List) '$k'}
        : <String>{};
    final owner = json['owner'];
    return CollectionState(
      rows: rows,
      pending: pending..retainAll(rows.keys),
      owner: owner is String ? owner : null,
    );
  }
}

/// Persists a [CollectionState] under one SharedPreferences key. Subclasses
/// only name the key; domain mapping lives in the view models.
abstract class CollectionController extends Notifier<CollectionState> {
  String get storageKey;

  SharedPreferences? get _preferences => ref.read(preferencesProvider);
  int _now() => ref.read(clockProvider)().millisecondsSinceEpoch;

  @override
  CollectionState build() {
    final stored = ref.watch(preferencesProvider)?.getString(storageKey);
    if (stored == null) return const CollectionState();
    try {
      return CollectionState.fromJson(jsonDecode(stored));
    } on FormatException {
      return const CollectionState();
    }
  }

  void _save(CollectionState next) {
    state = next;
    _preferences?.setString(storageKey, jsonEncode(next.toJson()));
  }

  /// Saves a row locally and queues it for sync.
  void put(String key, StoredRow row) {
    _save(
      state.copyWith(
        rows: {
          ...state.rows,
          key: {...row, 'updatedAt': _now()},
        },
        pending: {...state.pending, key},
      ),
    );
  }

  /// Deletes locally. Synced accounts keep a tombstone until the cloud
  /// confirms; guest rows disappear at once.
  void remove(String key) {
    if (!state.rows.containsKey(key)) return;
    final rows = {...state.rows};
    final pending = {...state.pending};
    if (state.owner == null) {
      rows.remove(key);
      pending.remove(key);
    } else {
      rows[key] = {'deleted': true, 'updatedAt': _now()};
      pending.add(key);
    }
    _save(state.copyWith(rows: rows, pending: pending));
  }

  /// Binds the collection to a verified account. Guest rows are adopted by
  /// the first account; another account's rows are never carried over.
  void adopt(String uid) {
    if (state.owner == uid) return;
    if (state.owner == null) {
      _save(
        state.copyWith(
          owner: uid,
          pending: {...state.pending, ...state.rows.keys},
        ),
      );
    } else {
      _save(CollectionState(owner: uid));
    }
  }

  /// Merges the cloud snapshot. A newer local edit that has not been sent
  /// yet wins; otherwise the cloud is the truth, including deletions.
  void applyRemote(Map<String, StoredRow> remote) {
    final rows = <String, StoredRow>{};
    for (final e in remote.entries) {
      final local = state.rows[e.key];
      final keepLocal =
          local != null &&
          state.pending.contains(e.key) &&
          _updatedAt(local) >= _updatedAt(e.value);
      rows[e.key] = keepLocal ? local : e.value;
    }
    for (final key in state.pending) {
      if (!remote.containsKey(key) && state.rows[key] != null) {
        rows[key] = state.rows[key]!;
      }
    }
    final pending = {
      for (final key in state.pending)
        if (rows[key] != null && identical(rows[key], state.rows[key])) key,
    };
    rows.removeWhere((k, v) => v['deleted'] == true && !pending.contains(k));
    _save(state.copyWith(rows: rows, pending: pending));
  }

  /// Marks a pending row as confirmed if it has not changed since it was sent.
  void confirm(String key, int sentUpdatedAt) {
    final row = state.rows[key];
    if (row == null || _updatedAt(row) != sentUpdatedAt) return;
    final rows = {...state.rows};
    if (row['deleted'] == true) rows.remove(key);
    _save(state.copyWith(rows: rows, pending: {...state.pending}..remove(key)));
  }

  static int _updatedAt(StoredRow row) {
    final value = row['updatedAt'];
    return value is int ? value : (value is num ? value.toInt() : 0);
  }
}
