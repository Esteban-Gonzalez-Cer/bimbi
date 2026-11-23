import 'dart:async';
import 'dart:io';

import 'package:bimbi/core/clock.dart';
import 'package:bimbi/core/platform.dart';
import 'package:bimbi/features/running/application/run_controller.dart';
import 'package:bimbi/features/running/data/run_cloud.dart';
import 'package:bimbi/features/running/data/run_store.dart';
import 'package:bimbi/features/running/domain/run.dart';
import 'package:bimbi/features/running/tracking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_run_location.dart';
import '../helpers/memory_run_disk.dart';

final time = DateTime.utc(2026, 11, 22, 12);
const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

RunPoint point(int second, {double lng = 0, double accuracy = 5}) =>
    RunPoint(0, lng, accuracy, time.add(Duration(seconds: second)));

RunDraft sample() => RunDraft(
  id: id,
  startedAt: time,
  active: const Duration(seconds: 20),
  meters: 11,
  segments: [
    [point(1), point(5, lng: .0001)],
  ],
);

class FakeRunCloud implements RunCloud {
  final online = StreamController<bool>.broadcast(sync: true);
  final remote = StreamController<List<SavedRun>>.broadcast(sync: true);
  final uploaded = <String, RunSummary>{};
  final deleted = <String>[];
  final seenUids = <String>[];

  @override
  Stream<bool> get connection => online.stream;

  @override
  Stream<List<SavedRun>> watch(String uid) {
    seenUids.add(uid);
    return remote.stream;
  }

  @override
  Future<void> save(String uid, RunSummary summary) async =>
      uploaded[summary.id] = summary;

  @override
  Future<void> delete(String uid, String id) async {
    deleted.add(id);
    uploaded.remove(id);
  }
}

void main() {
  test(
    'distance ignores poor fixes, jumps, jitter and gaps between segments',
    () {
      final route = RunRoute();
      FixResult add(RunPoint p, {bool mocked = false, int? at}) {
        return route.add(
          p,
          now: time.add(
            Duration(seconds: at ?? p.timestamp.difference(time).inSeconds),
          ),
          startedSegment: time,
          elapsed: Duration(
            seconds: at ?? p.timestamp.difference(time).inSeconds,
          ),
          mocked: mocked,
        );
      }

      expect(add(point(1)), FixResult.added);
      expect(add(point(2, lng: .000005)), FixResult.steady);
      expect(add(point(3, accuracy: 51)), FixResult.rejected);
      expect(add(point(4, lng: .003)), FixResult.rejected);
      expect(add(point(4), mocked: true), FixResult.rejected);
      expect(add(point(5, lng: .0001)), FixResult.added);
      expect(add(point(4)), FixResult.rejected);
      expect(add(point(6), at: 22), FixResult.rejected);
      expect(route.meters, closeTo(11.12, .02));
      expect(add(point(23, lng: .001)), FixResult.added);
      route.breakSegment();
      expect(add(point(25, lng: .003)), FixResult.added);
      expect(add(point(28, lng: .0031)), FixResult.added);
      expect(route.segments.map((s) => s.length), [2, 1, 2]);
      expect(route.meters, closeTo(22.24, .03));
      expect(route.rejected, 5);
    },
  );

  test(
    'actual disk keeps draft and route private per identity and deletes by id',
    () async {
      final folder = await Directory.systemTemp.createTemp('bimbi-run-test-');
      addTearDown(() => folder.delete(recursive: true));
      RunStore reopen() =>
          RunStore(FileRunDisk('test', location: () async => folder));
      await reopen().checkpoint('user:alice', sample());
      expect((await reopen().load('user:alice')).draft?.summary.distanceM, 11);
      expect((await reopen().load('user:bob')).draft, isNull);
      expect((await reopen().load('guest')).draft, isNull);
      final saved = await reopen().save('user:alice', sample(), sync: true);
      final loaded = await reopen().load('user:alice');
      expect(loaded.draft, isNull);
      expect(loaded.runs[id]?.segments.single.length, 2);
      expect(saved.pending, isTrue);

      await reopen().merge('user:bob', [
        SavedRun(id: id, summary: saved.summary),
      ]);
      expect((await reopen().load('user:bob')).runs[id]?.segments, isEmpty);
      final deletion = await reopen().remove('user:alice', id, sync: true);
      expect(await reopen().confirm('user:alice', saved), isNull);
      await reopen().confirm('user:alice', deletion!);
      await reopen().merge('user:alice', [
        SavedRun(id: id, summary: saved.summary),
      ]);
      final removed = (await reopen().load('user:alice')).runs[id]!;
      expect(removed.deleted, isTrue);
      expect(removed.segments, isEmpty);
      expect(removed.pending, isFalse);
    },
  );

  test(
    'pause, relaunch and resume exclude downtime and save separate segments',
    () async {
      var elapsed = Duration.zero;
      final gps = FakeRunLocation();
      final store = RunStore(MemoryRunDisk());

      ProviderContainer launch() => ProviderContainer(
        overrides: [
          runStoreProvider.overrideWithValue(store),
          runAccountProvider.overrideWithValue((uid: null, verified: false)),
          trackingAdapterProvider.overrideWithValue(gps),
          runElapsedProvider.overrideWithValue(() => elapsed),
          clockProvider.overrideWithValue(() => time.add(elapsed)),
        ],
      );
      final first = launch();
      addTearDown(first.dispose);
      final controller = first.read(runControllerProvider.notifier);
      await first.pump();
      await Future<void>.delayed(Duration.zero);
      await controller.start();
      elapsed = const Duration(seconds: 1);
      gps.emit(point(1));
      elapsed = const Duration(seconds: 5);
      gps.emit(point(5, lng: .0001));
      await first.read(trackingProvider.notifier).stop();
      expect(gps.fixes.hasListener, isFalse);
      expect(first.read(runControllerProvider).phase, RunPhase.paused);

      elapsed = const Duration(minutes: 4);
      final second = launch();
      addTearDown(second.dispose);
      final resumed = second.read(runControllerProvider.notifier);
      await second.pump();
      await Future<void>.delayed(Duration.zero);
      expect(second.read(runControllerProvider).phase, RunPhase.paused);
      expect(second.read(runControllerProvider).active.inSeconds, 5);
      await resumed.start();
      elapsed = const Duration(seconds: 241);
      gps.emit(point(241, lng: .01));
      elapsed = const Duration(seconds: 245);
      gps.emit(point(245, lng: .0101));
      await resumed.finish();
      expect(second.read(runControllerProvider).phase, RunPhase.review);
      await resumed.save();
      final saved = second.read(runControllerProvider).runs.single;
      expect(saved.summary!.durationSec, 10);
      expect(saved.summary!.distanceM, 22);
      expect(saved.segments.length, 2);
      expect(gps.fixes.hasListener, isFalse);
    },
  );

  test(
    'permission denial, approximate access and delayed grant are safe',
    () async {
      final gps = FakeRunLocation();
      final container = ProviderContainer(
        overrides: [
          runAccountProvider.overrideWithValue((uid: null, verified: false)),
          runStoreProvider.overrideWithValue(RunStore(MemoryRunDisk())),
          trackingAdapterProvider.overrideWithValue(gps),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(runControllerProvider.notifier);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      for (final code in ['permission_denied', 'approximate', 'service_off']) {
        gps.permission = () async =>
            throw CapabilityFailure(code, 'Unavailable');
        await controller.start();
        expect(container.read(runControllerProvider).issue?.code, code);
        expect(gps.fixes.hasListener, isFalse);
      }

      final grant = Completer<void>();
      gps.permission = () => grant.future;
      final starting = controller.start();
      await container.read(trackingProvider.notifier).stop();
      grant.complete();
      await starting;
      expect(gps.fixes.hasListener, isFalse);
      expect(container.read(runControllerProvider).phase, RunPhase.idle);
    },
  );

  test('offline totals retry on connection, and switching accounts hides route history', () async {
    final account = StreamController<RunAccount?>();
    final cloud = FakeRunCloud();
    final store = RunStore(MemoryRunDisk());
    await store.save('user:alice', sample(), sync: true);
    final identity = StreamProvider<RunAccount?>((_) => account.stream);
    final container = ProviderContainer(
      overrides: [
        runAccountProvider.overrideWith(
          (ref) => ref.watch(identity).asData?.value,
        ),
        runStoreProvider.overrideWithValue(store),
        runCloudProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(runControllerProvider.notifier);
    final live = container.listen(runControllerProvider, (_, _) {});
    addTearDown(live.close);
    account.add((uid: 'alice', verified: true));
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(runControllerProvider).runs.single.segments,
      isNotEmpty,
    );
    cloud.remote.add([]);
    cloud.online.add(false);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(cloud.uploaded, isEmpty);
    cloud.online.add(true);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(cloud.uploaded[id]?.toJson().keys.toSet(), {
      'startedAt',
      'distanceM',
      'durationSec',
    });
    await controller.delete(id);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(cloud.deleted, [id]);

    account.add((uid: 'bob', verified: false));
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(runControllerProvider).runs, isEmpty);
    expect(cloud.seenUids, ['alice']);
    expect((await store.load('user:alice')).runs[id]?.deleted, isTrue);
  });
}
