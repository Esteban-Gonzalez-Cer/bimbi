import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../core/clock.dart';
import '../../../data/repositories/collection_sync.dart';
import '../../../data/repositories/local_collection.dart';
import '../../../domain/models/focus_record.dart';

enum FocusPhase { idle, running, paused }

/// Focus session derived from absolute timestamps, never from an in-memory
/// countdown. It is saved on every change, so a new process rebuilds the
/// same remaining time (spec FOCUS-01).
@immutable
class FocusSession {
  const FocusSession({
    this.target = const Duration(minutes: 25),
    this.phase = FocusPhase.idle,
    this.startedAt,
    this.banked = Duration.zero,
    this.firstStartedAt,
    this.taskLabel,
    this.windows = const [],
  });

  static const minTarget = Duration(minutes: 1);

  /// Four turns of the dial; one turn is [turn].
  static const maxTarget = Duration(minutes: 480);
  static const turn = Duration(minutes: 120);
  static const maxLabel = 40;
  static const maxWindows = 6;

  final Duration target;
  final FocusPhase phase;

  /// Start of the current running stretch.
  final DateTime? startedAt;

  /// Focus time completed before the current stretch (across pauses).
  final Duration banked;

  /// First start of this session; identifies its history record.
  final DateTime? firstStartedAt;

  /// Optional "what are you focusing on".
  final String? taskLabel;

  /// Optional split into consecutive windows, in minutes. Empty, or summing
  /// to [target]. A chime marks the end of each window.
  final List<int> windows;

  /// Window index (0-based) and the time left in it, or null without a split.
  (int, Duration)? windowAt(DateTime now) {
    if (windows.length < 2) return null;
    final done = elapsed(now);
    var end = Duration.zero;
    for (final (i, minutes) in windows.indexed) {
      end += Duration(minutes: minutes);
      if (done < end || i == windows.length - 1) {
        final left = end - done;
        return (i, left.isNegative ? Duration.zero : left);
      }
    }
    return null;
  }

  /// When each window still ahead ends (not the session end), while running.
  List<DateTime> windowEnds(DateTime now) {
    if (phase != FocusPhase.running || windows.length < 2) return const [];
    final done = elapsed(now);
    var end = Duration.zero;
    return [
      for (final minutes in windows.take(windows.length - 1))
        if ((end += Duration(minutes: minutes)) > done) now.add(end - done),
    ];
  }

  Duration elapsed(DateTime now) {
    final live = phase == FocusPhase.running && startedAt != null
        ? now.difference(startedAt!)
        : Duration.zero;
    final total = banked + (live.isNegative ? Duration.zero : live);
    return total > target ? target : total;
  }

  Duration remaining(DateTime now) => target - elapsed(now);
  bool isComplete(DateTime now) =>
      phase != FocusPhase.idle && remaining(now) == Duration.zero;
  double progress(DateTime now) => target.inMilliseconds == 0
      ? 0
      : elapsed(now).inMilliseconds / target.inMilliseconds;

  /// When a running session reaches its target; null unless running.
  DateTime? endsAt(DateTime now) =>
      phase == FocusPhase.running ? now.add(remaining(now)) : null;

  Map<String, Object?> toJson() => {
    'targetMin': target.inMinutes,
    'phase': phase.name,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'bankedMs': banked.inMilliseconds,
    'firstStartedAt': firstStartedAt?.millisecondsSinceEpoch,
    'taskLabel': taskLabel,
    'windows': windows,
  };

  static FocusSession fromJson(Object? json) {
    if (json is! Map) return const FocusSession();
    DateTime? time(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    final minutes = json['targetMin'];
    final phase = FocusPhase.values
        .where((p) => p.name == json['phase'])
        .firstOrNull;
    final banked = json['bankedMs'];
    final label = json['taskLabel'];
    final rawWindows = json['windows'];
    final windows = [
      if (rawWindows is List)
        for (final w in rawWindows)
          if (w is int && w > 0) w,
    ];
    final session = FocusSession(
      target: Duration(
        minutes: (minutes is int ? minutes : 25).clamp(
          minTarget.inMinutes,
          maxTarget.inMinutes,
        ),
      ),
      phase: phase ?? FocusPhase.idle,
      startedAt: time(json['startedAt']),
      banked: Duration(milliseconds: banked is int ? banked : 0),
      firstStartedAt: time(json['firstStartedAt']),
      taskLabel: label is String ? label : null,
      windows:
          windows.length > 1 &&
              windows.fold<int>(0, (a, b) => a + b) ==
                  (minutes is int ? minutes : -1)
          ? windows
          : const [],
    );
    // A running session must know when it started; anything else is idle.
    if (session.phase == FocusPhase.running && session.startedAt == null) {
      return FocusSession(target: session.target);
    }
    return session;
  }
}

const _sessionKey = 'bimbi.focus.session';

class FocusController extends Notifier<FocusSession> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  FocusSession build() {
    final stored = ref.watch(preferencesProvider)?.getString(_sessionKey);
    if (stored == null) return const FocusSession();
    try {
      return FocusSession.fromJson(jsonDecode(stored));
    } on FormatException {
      return const FocusSession();
    }
  }

  void _save(FocusSession next) {
    state = next;
    ref
        .read(preferencesProvider)
        ?.setString(_sessionKey, jsonEncode(next.toJson()));
  }

  /// Sets the length while idle: the dial snaps to 5-minute steps, typed
  /// values are [exact]. 1 minute to 8 hours. A new length clears any split.
  void setTarget(Duration value, {bool exact = false}) {
    if (state.phase != FocusPhase.idle) return;
    final minutes = exact
        ? value.inMinutes
        : math.max(5, (value.inMinutes / 5).round() * 5);
    final clamped = minutes.clamp(
      FocusSession.minTarget.inMinutes,
      FocusSession.maxTarget.inMinutes,
    );
    if (clamped == state.target.inMinutes) return;
    _save(
      FocusSession(
        target: Duration(minutes: clamped),
        taskLabel: state.taskLabel,
      ),
    );
  }

  /// Splits the session into consecutive windows (minutes each, at least 1).
  /// Fewer than two windows removes the split. Idle only.
  void setWindows(List<int> windows) {
    if (state.phase != FocusPhase.idle) return;
    final clean = [
      for (final w in windows.take(FocusSession.maxWindows))
        if (w > 0) w,
    ];
    final total = clean.fold<int>(0, (a, b) => a + b);
    if (clean.length < 2 || total > FocusSession.maxTarget.inMinutes) {
      _save(FocusSession(target: state.target, taskLabel: state.taskLabel));
      return;
    }
    _save(
      FocusSession(
        target: Duration(minutes: total),
        taskLabel: state.taskLabel,
        windows: clean,
      ),
    );
  }

  void setTaskLabel(String value) {
    final trimmed = value.trim();
    final label = trimmed.length > FocusSession.maxLabel
        ? trimmed.substring(0, FocusSession.maxLabel)
        : trimmed;
    _save(
      FocusSession(
        target: state.target,
        phase: state.phase,
        startedAt: state.startedAt,
        banked: state.banked,
        firstStartedAt: state.firstStartedAt,
        taskLabel: label.isEmpty ? null : label,
        windows: state.windows,
      ),
    );
  }

  void start() {
    if (state.phase == FocusPhase.running) return;
    final now = _now();
    final resuming = state.phase == FocusPhase.paused;
    _save(
      FocusSession(
        target: state.target,
        phase: FocusPhase.running,
        startedAt: now,
        banked: resuming ? state.banked : Duration.zero,
        firstStartedAt: resuming ? state.firstStartedAt ?? now : now,
        taskLabel: state.taskLabel,
        windows: state.windows,
      ),
    );
  }

  void pause() {
    if (state.phase != FocusPhase.running) return;
    _save(
      FocusSession(
        target: state.target,
        phase: FocusPhase.paused,
        banked: state.elapsed(_now()),
        firstStartedAt: state.firstStartedAt,
        taskLabel: state.taskLabel,
        windows: state.windows,
      ),
    );
  }

  /// Finishes the session. Sessions of at least one minute go to history as
  /// completed (target reached) or ended early.
  void end() {
    final now = _now();
    final focused = state.elapsed(now);
    final first = state.firstStartedAt ?? state.startedAt;
    if (state.phase != FocusPhase.idle &&
        first != null &&
        focused >= const Duration(minutes: 1)) {
      final record = FocusRecord(
        id: '${first.millisecondsSinceEpoch}',
        startedAt: first,
        duration: focused,
        outcome: state.isComplete(now)
            ? FocusOutcome.completed
            : FocusOutcome.ended,
        taskLabel: state.taskLabel,
      );
      ref.read(focusHistoryProvider.notifier).put(record.id, record.toRow());
    }
    _save(
      FocusSession(
        target: state.target,
        taskLabel: state.taskLabel,
        windows: state.windows,
      ),
    );
  }
}

final focusProvider = NotifierProvider<FocusController, FocusSession>(
  FocusController.new,
);

/// One-second UI tick while a session runs. Display only; time is always
/// recomputed from timestamps.
final focusTickProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
);

class FocusHistoryController extends CollectionController {
  @override
  String get storageKey => 'bimbi.focus.history';
}

/// Finished sessions, saved on the device and synced for verified accounts.
final focusHistoryProvider =
    NotifierProvider<FocusHistoryController, CollectionState>(
      FocusHistoryController.new,
    );

/// History as domain records, newest first.
final focusRecordsProvider = Provider<List<FocusRecord>>((ref) {
  final rows = ref.watch(focusHistoryProvider).visible;
  return [for (final e in rows.entries) ?FocusRecord.fromRow(e.key, e.value)]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
});

/// Focused minutes since local midnight.
final focusTodayProvider = Provider<Duration>((ref) {
  final now = ref.watch(clockProvider)();
  final midnight = DateTime(now.year, now.month, now.day);
  return ref
      .watch(focusRecordsProvider)
      .where((r) => !r.startedAt.isBefore(midnight))
      .fold(Duration.zero, (sum, r) => sum + r.duration);
});

class FocusSync extends CollectionSync {
  @override
  String get name => 'focus';
  @override
  NotifierProvider<CollectionController, CollectionState> get rows =>
      focusHistoryProvider;
}

/// Sync state of the Focus history for the verified account.
final focusSyncProvider = NotifierProvider<FocusSync, SyncStatus>(
  FocusSync.new,
);
