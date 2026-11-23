import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/clock.dart';
import '../../../core/platform.dart';
import '../data/run_cloud.dart';
import '../data/run_store.dart';
import '../domain/run.dart';
import '../tracking_adapter.dart';

enum RunPhase { idle, starting, recording, paused, review }

enum RunSync { local, offline, syncing, synced, unavailable }

class RunningState {
  const RunningState({
    this.loading = true,
    this.busy = false,
    this.phase = RunPhase.idle,
    this.draft,
    this.active = Duration.zero,
    this.runs = const [],
    this.issue,
    this.accuracy,
    this.lostFix = false,
    this.sync = RunSync.local,
    this.verified = false,
  });

  final bool loading;
  final bool busy;
  final RunPhase phase;
  final RunDraft? draft;
  final Duration active;
  final List<SavedRun> runs;
  final CapabilityFailure? issue;
  final double? accuracy;
  final bool lostFix;
  final RunSync sync;
  final bool verified;

  RunningState copy({
    bool? loading,
    bool? busy,
    RunPhase? phase,
    RunDraft? draft,
    bool clearDraft = false,
    Duration? active,
    List<SavedRun>? runs,
    CapabilityFailure? issue,
    bool clearIssue = false,
    double? accuracy,
    bool clearAccuracy = false,
    bool? lostFix,
    RunSync? sync,
    bool? verified,
  }) => RunningState(
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    phase: phase ?? this.phase,
    draft: clearDraft ? null : draft ?? this.draft,
    active: active ?? this.active,
    runs: runs ?? this.runs,
    issue: clearIssue ? null : issue ?? this.issue,
    accuracy: clearAccuracy ? null : accuracy ?? this.accuracy,
    lostFix: lostFix ?? this.lostFix,
    sync: sync ?? this.sync,
    verified: verified ?? this.verified,
  );
}

final runElapsedProvider = Provider<Duration Function()>((ref) {
  final clock = Stopwatch()..start();
  return () => clock.elapsed;
});

final runControllerProvider = NotifierProvider<RunController, RunningState>(
  RunController.new,
);

class RunController extends Notifier<RunningState> {
  late RunStore _store;
  late Duration Function() _elapsed;
  late DateTime Function() _now;
  final Map<String, SavedRun> _runs = {};
  RunAccount? _account;
  String? _owner;
  int _accountEpoch = 0;
  int _recordingEpoch = 0;
  RunRoute? _route;
  Duration? _recordingAt;
  Duration _lastCheckpoint = Duration.zero;
  DateTime? _segmentStart;
  Timer? _timer;
  StreamSubscription<Position>? _gps;
  StreamSubscription<bool>? _connection;
  StreamSubscription<List<SavedRun>>? _remote;
  bool _online = false;
  bool _remoteReady = false;
  bool _syncing = false;
  bool _syncFailed = false;
  bool _storeReady = false;

  @override
  RunningState build() {
    _store = ref.read(runStoreProvider);
    _elapsed = ref.read(runElapsedProvider);
    _now = ref.read(clockProvider);
    ref.listen(runAccountProvider, (_, account) => unawaited(_open(account)));
    final initial = ref.read(runAccountProvider);
    final epoch = _accountEpoch;
    scheduleMicrotask(() {
      if (ref.mounted && _accountEpoch == epoch) unawaited(_open(initial));
    });
    ref.onDispose(() {
      _accountEpoch++;
      _stopLocation();
      _stopSync();
    });
    return const RunningState();
  }

  bool _current(int epoch) => ref.mounted && _accountEpoch == epoch;

  Future<void> _open(RunAccount? account) async {
    if (_owner != null && _account == account && _storeReady) return;
    final previousOwner = _owner;
    final previousDraft = _snapshot();
    final wasRecording = _recordingAt != null;
    _stopLocation();
    _stopSync();
    final epoch = ++_accountEpoch;
    _account = account;
    _owner = account == null
        ? null
        : account.uid == null
        ? 'guest'
        : 'user:${account.uid}';
    _storeReady = false;
    _runs.clear();
    _route = null;
    state = RunningState(verified: account?.verified == true);
    if (wasRecording && previousOwner != null && previousDraft != null) {
      // Queued before reading the replacement account, even on a quick switch
      // back to the same account.
      final previousWrite = _store.checkpoint(previousOwner, previousDraft);
      unawaited(previousWrite.catchError((Object _) {}));
    }
    final owner = _owner;
    if (owner == null) return;
    try {
      final saved = await _store.load(owner);
      if (!_current(epoch)) return;
      _storeReady = true;
      _runs.addAll(saved.runs);
      final draft = saved.draft;
      _route = draft == null
          ? null
          : RunRoute(segments: draft.segments, meters: draft.meters);
      state = state.copy(
        loading: false,
        phase: draft == null ? RunPhase.idle : RunPhase.paused,
        draft: draft,
        active: draft?.active ?? Duration.zero,
        runs: _visibleRuns,
      );
      _startSync(epoch, owner);
    } catch (_) {
      if (_current(epoch)) {
        state = state.copy(loading: false, issue: _storageIssue);
      }
    }
  }

  Future<void> retryStorage() => _open(_account);

  Future<void> start() async {
    final owner = _owner;
    if (owner == null ||
        !_storeReady ||
        state.busy ||
        (state.phase != RunPhase.idle && state.phase != RunPhase.paused)) {
      return;
    }
    final epoch = ++_recordingEpoch;
    final previousDraft = state.draft;
    state = state.copy(phase: RunPhase.starting, clearIssue: true);
    try {
      final adapter = ref.read(trackingAdapterProvider);
      await adapter.requestLocation();
      if (!ref.mounted || _recordingEpoch != epoch) return;
      final now = _now().toUtc();
      final draft = previousDraft ?? RunDraft(id: _newId(), startedAt: now);
      await _store.checkpoint(owner, draft);
      if (!ref.mounted || _recordingEpoch != epoch) return;
      _route ??= RunRoute(segments: draft.segments, meters: draft.meters);
      _route!.breakSegment();
      _segmentStart = now;
      _recordingAt = _elapsed();
      _lastCheckpoint = draft.active;
      state = state.copy(
        draft: draft,
        active: draft.active,
        phase: RunPhase.recording,
        clearAccuracy: true,
        lostFix: false,
      );
      _gps = adapter.positions().listen(
        (fix) => _onFix(epoch, fix),
        onError: (Object _) => unawaited(_locationEnded(epoch)),
        onDone: () => unawaited(_locationEnded(epoch)),
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } on CapabilityFailure catch (failure) {
      _startFailed(epoch, previousDraft, failure);
    } catch (_) {
      _startFailed(epoch, state.draft ?? previousDraft, _storageIssue);
    }
  }

  void _startFailed(int epoch, RunDraft? draft, CapabilityFailure failure) {
    if (!ref.mounted || _recordingEpoch != epoch) return;
    _stopLocation();
    state = state.copy(
      phase: draft == null ? RunPhase.idle : RunPhase.paused,
      issue: failure,
    );
  }

  Duration get _active {
    final base = state.draft?.active ?? Duration.zero;
    final start = _recordingAt;
    return start == null ? base : base + (_elapsed() - start);
  }

  RunDraft? _snapshot() {
    final draft = state.draft;
    final route = _route;
    return route == null ? draft : draft?.checkpoint(_active, route);
  }

  void _onFix(int epoch, Position fix) {
    final route = _route;
    if (epoch != _recordingEpoch || route == null || _segmentStart == null) {
      return;
    }
    final result = route.add(
      RunPoint(fix.latitude, fix.longitude, fix.accuracy, fix.timestamp),
      now: _now(),
      startedSegment: _segmentStart!,
      elapsed: _elapsed(),
      mocked: fix.isMocked,
    );
    if (result == FixResult.rejected) return;
    state = state.copy(accuracy: route.accuracy, lostFix: false);
  }

  List<List<RunPoint>> get visibleSegments => _route?.segments ?? const [];
  double get distanceMeters => _route?.meters ?? 0;

  void _tick() {
    final active = _active;
    final route = _route;
    if (route == null || _recordingAt == null) return;
    final stale = route.stale(_elapsed());
    state = state.copy(
      active: active,
      lostFix: stale && _elapsed() - _recordingAt! >= fixGap,
      clearAccuracy: stale,
    );
    if (active - _lastCheckpoint >= const Duration(seconds: 5)) {
      _lastCheckpoint = active;
      unawaited(_checkpoint(_snapshot()));
    }
  }

  Future<void> _locationEnded(int epoch) async {
    if (epoch != _recordingEpoch || !ref.mounted) return;
    await pause(
      issue: const CapabilityFailure(
        'gps_stopped',
        'Location stopped. Check your settings and resume.',
      ),
    );
  }

  void _stopLocation() {
    _recordingEpoch++;
    unawaited(_gps?.cancel());
    _gps = null;
    _timer?.cancel();
    _timer = null;
    _recordingAt = null;
    _segmentStart = null;
  }

  Future<void> pause({CapabilityFailure? issue}) async {
    final phase = state.phase;
    if (phase != RunPhase.recording && phase != RunPhase.starting) return;
    final draft = _snapshot();
    _stopLocation();
    state = state.copy(
      phase: draft == null ? RunPhase.idle : RunPhase.paused,
      draft: draft,
      active: draft?.active ?? Duration.zero,
      clearAccuracy: true,
      lostFix: false,
      issue: issue,
    );
    if (draft != null) await _checkpoint(draft);
  }

  Future<void> finish() async {
    if (state.phase != RunPhase.recording && state.phase != RunPhase.paused) {
      return;
    }
    final draft = _snapshot();
    _stopLocation();
    state = state.copy(
      phase: RunPhase.review,
      draft: draft,
      active: draft?.active,
      clearAccuracy: true,
      lostFix: false,
      clearIssue: true,
    );
    if (draft != null) await _checkpoint(draft);
  }

  void returnToPause() => state = state.copy(phase: RunPhase.paused);

  Future<void> _checkpoint(RunDraft? draft) async {
    final owner = _owner;
    if (owner == null) return;
    final epoch = _accountEpoch;
    try {
      await _store.checkpoint(owner, draft);
    } catch (_) {
      if (_current(epoch)) state = state.copy(issue: _storageIssue);
    }
  }

  Future<void> save() async {
    final draft = state.draft;
    final owner = _owner;
    if (owner == null ||
        state.busy ||
        state.phase != RunPhase.review ||
        draft == null ||
        !draft.canSave) {
      return;
    }
    final epoch = _accountEpoch;
    state = state.copy(busy: true, clearIssue: true);
    try {
      final saved = await _store.save(
        owner,
        draft,
        sync: _account?.uid != null,
      );
      if (!_current(epoch)) return;
      _runs[saved.id] = saved;
      _clearDraft();
      _publish();
      unawaited(_push());
    } catch (_) {
      if (_current(epoch)) {
        state = state.copy(busy: false, issue: _storageIssue);
      }
    }
  }

  Future<void> discard() async {
    final owner = _owner;
    if (owner == null || state.busy || state.phase != RunPhase.review) return;
    final epoch = _accountEpoch;
    state = state.copy(busy: true, clearIssue: true);
    try {
      await _store.checkpoint(owner, null);
      if (_current(epoch)) _clearDraft();
    } catch (_) {
      if (_current(epoch)) {
        state = state.copy(busy: false, issue: _storageIssue);
      }
    }
  }

  void _clearDraft() {
    _route = null;
    state = state.copy(
      busy: false,
      phase: RunPhase.idle,
      clearDraft: true,
      active: Duration.zero,
    );
  }

  Future<void> delete(String id) async {
    final owner = _owner;
    if (owner == null || state.busy || _runs[id]?.summary == null) return;
    final epoch = _accountEpoch;
    state = state.copy(busy: true, clearIssue: true);
    try {
      final deleted = await _store.remove(
        owner,
        id,
        sync: _account?.uid != null,
      );
      if (!_current(epoch)) return;
      if (deleted == null) {
        _runs.remove(id);
      } else {
        _runs[id] = deleted;
      }
      state = state.copy(busy: false);
      _publish();
      unawaited(_push());
    } catch (_) {
      if (_current(epoch)) {
        state = state.copy(busy: false, issue: _storageIssue);
      }
    }
  }

  Future<void> openSettings() async {
    try {
      await ref
          .read(trackingAdapterProvider)
          .openLocationSettings(app: state.issue?.code != 'service_off');
    } catch (_) {
      if (ref.mounted) {
        state = state.copy(
          issue: const CapabilityFailure(
            'settings',
            'Open Android Settings to check location access.',
          ),
        );
      }
    }
  }

  List<SavedRun> get _visibleRuns =>
      _runs.values.where((run) => !run.deleted).toList()
        ..sort((a, b) => b.summary!.startedAt.compareTo(a.summary!.startedAt));

  void _publish() {
    final pending = _runs.values.any((run) => run.pending);
    state = state.copy(
      runs: _visibleRuns,
      sync: !state.verified || ref.read(runCloudProvider) == null
          ? RunSync.local
          : _syncFailed
          ? RunSync.unavailable
          : !_online || !_remoteReady
          ? RunSync.offline
          : pending
          ? RunSync.syncing
          : RunSync.synced,
    );
  }

  void _startSync(int epoch, String owner) {
    final uid = _account?.uid;
    final cloud = ref.read(runCloudProvider);
    if (uid == null || _account?.verified != true || cloud == null) return;
    _publish();
    _connection = cloud.connection.listen((online) {
      if (!_current(epoch)) return;
      _online = online;
      if (online) _syncFailed = false;
      _publish();
      if (online) unawaited(_push());
    }, onError: (Object _) => _syncError(epoch));
    _remote = cloud.watch(uid).listen((entries) async {
      if (!_current(epoch)) return;
      try {
        final changed = await _store.merge(owner, entries);
        if (!_current(epoch)) return;
        for (final entry in changed) {
          if (_runs[entry.id]?.deleted != true) _runs[entry.id] = entry;
        }
        _remoteReady = true;
        _publish();
        unawaited(_push());
      } catch (_) {
        _syncError(epoch);
      }
    }, onError: (Object _) => _syncError(epoch));
  }

  void _syncError(int epoch) {
    if (!_current(epoch)) return;
    _syncFailed = true;
    _publish();
  }

  Future<void> retrySync() async {
    final owner = _owner;
    if (owner == null || _syncing) return;
    final epoch = _accountEpoch;
    await _connection?.cancel();
    await _remote?.cancel();
    if (!_current(epoch)) return;
    _stopSync();
    _startSync(epoch, owner);
  }

  void _stopSync() {
    unawaited(_connection?.cancel());
    unawaited(_remote?.cancel());
    _connection = null;
    _remote = null;
    _syncing = false;
    _online = false;
    _remoteReady = false;
    _syncFailed = false;
  }

  Future<void> _push() async {
    final epoch = _accountEpoch;
    final owner = _owner;
    final uid = _account?.uid;
    final cloud = ref.read(runCloudProvider);
    if (!_online ||
        !_remoteReady ||
        _syncing ||
        _syncFailed ||
        owner == null ||
        uid == null ||
        cloud == null) {
      return;
    }
    _syncing = true;
    try {
      while (_current(epoch) && _online) {
        final next = _runs.values.where((run) => run.pending).firstOrNull;
        if (next == null) break;
        final summary = next.summary;
        await (summary != null
                ? cloud.save(uid, summary)
                : cloud.delete(uid, next.id))
            .timeout(const Duration(seconds: 12));
        if (!_current(epoch)) return;
        final confirmed = await _store.confirm(owner, next);
        if (!_current(epoch)) return;
        if (confirmed != null &&
            (_runs[next.id]?.deleted == confirmed.deleted)) {
          _runs[next.id] = confirmed;
        }
        _publish();
      }
    } catch (_) {
      _syncError(epoch);
    } finally {
      if (_current(epoch)) _syncing = false;
    }
  }

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static const _storageIssue = CapabilityFailure(
    'run_storage',
    'Could not access saved runs. Try again.',
  );
}
