import 'dart:async';

import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/core/clock.dart';
import 'package:bimbi/data/repositories/collection_sync.dart';
import 'package:bimbi/data/repositories/local_collection.dart';
import 'package:bimbi/domain/models/sleep_entry.dart';
import 'package:bimbi/ui/sleep/view_models/sleep_diary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Realtime Database with a connection switch.
class FakeCloud implements CloudCollection {
  final data = <String, Map<String, StoredRow>>{};
  final _online = StreamController<bool>.broadcast();
  final _changes = StreamController<String>.broadcast();
  bool online = false;
  final writes = <String>[];

  void setOnline(bool value) {
    online = value;
    _online.add(value);
  }

  void serverSet(String path, String key, StoredRow? row) {
    final rows = data.putIfAbsent(path, () => {});
    row == null ? rows.remove(key) : rows[key] = row;
    _changes.add(path);
  }

  @override
  Stream<bool> get connection async* {
    yield online;
    yield* _online.stream;
  }

  @override
  Stream<Map<String, StoredRow>> watch(String uid, String name) async* {
    final path = 'users/$uid/$name';
    yield Map.of(data[path] ?? {});
    yield* _changes.stream
        .where((p) => p == path)
        .map((_) => Map.of(data[path] ?? {}));
  }

  @override
  Future<void> write(String uid, String name, String key, StoredRow? row) {
    if (!online) return Completer<void>().future; // waits like RTDB offline
    writes.add('$uid/$name/$key');
    serverSet('users/$uid/$name', key, row);
    return Future.value();
  }
}

class _Account extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? uid) => state = uid;
}

final _account = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  late SharedPreferences prefs;
  late FakeCloud cloud;
  final now = DateTime(2026, 11, 22, 8);

  ProviderContainer app() {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        preferencesProvider.overrideWithValue(prefs),
        cloudCollectionProvider.overrideWithValue(cloud),
        syncAccountProvider.overrideWith((ref) => ref.watch(_account)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(sleepSyncProvider, (_, _) {});
    return c;
  }

  SleepEntry night(int day) => entryFromTimes(
    wakeDay: DateTime(2026, 11, day),
    bedHour: 23,
    bedMinute: 0,
    wakeHour: 7,
    wakeMinute: 0,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = FakeCloud();
  });

  test('guest entries upload once a verified account is online', () async {
    final c = app();
    c.read(sleepRowsProvider.notifier).save(night(21));
    await settle();
    expect(c.read(sleepSyncProvider).phase, SyncPhase.local);

    c.read(_account.notifier).set('alice');
    await settle();
    expect(c.read(sleepSyncProvider).phase, SyncPhase.offline);
    expect(cloud.writes, isEmpty);

    cloud.setOnline(true);
    await settle();
    await settle();
    expect(cloud.data['users/alice/sleep']?.keys, ['2026-11-21']);
    expect(c.read(sleepRowsProvider).pending, isEmpty);
    expect(c.read(sleepSyncProvider).phase, SyncPhase.synced);
  });

  test('edits from another device arrive; offline edits wait', () async {
    cloud.setOnline(true);
    final c = app();
    c.read(_account.notifier).set('alice');
    await settle();
    cloud.serverSet('users/alice/sleep', '2026-11-20', {
      ...night(20).toRow(),
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await settle();
    expect(c.read(sleepDiaryProvider).map((e) => e.dateKey), ['2026-11-20']);

    cloud.setOnline(false);
    c.read(sleepRowsProvider.notifier).save(night(22));
    await settle();
    expect(c.read(sleepSyncProvider).pending, 1);
    expect(cloud.data['users/alice/sleep']!.containsKey('2026-11-22'), false);
  });

  test('deleting while synced removes the row from the cloud', () async {
    cloud.setOnline(true);
    final c = app();
    c.read(_account.notifier).set('alice');
    await settle();
    c.read(sleepRowsProvider.notifier).save(night(21));
    await settle();
    await settle();
    c.read(sleepRowsProvider.notifier).delete(night(21));
    await settle();
    await settle();
    expect(cloud.data['users/alice/sleep'], isEmpty);
    expect(c.read(sleepRowsProvider).rows, isEmpty);
  });

  test('switching accounts never carries entries across', () async {
    cloud.setOnline(true);
    final c = app();
    c.read(_account.notifier).set('alice');
    await settle();
    c.read(sleepRowsProvider.notifier).save(night(21));
    await settle();
    await settle();
    c.read(_account.notifier).set('bob');
    await settle();
    await settle();
    expect(c.read(sleepDiaryProvider), isEmpty);
    expect(cloud.data['users/bob/sleep'] ?? {}, isEmpty);
  });
}
