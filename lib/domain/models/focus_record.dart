import 'package:flutter/foundation.dart';

/// How a Focus session finished.
enum FocusOutcome {
  completed,
  ended;

  static FocusOutcome parse(Object? value) =>
      value == 'completed' ? FocusOutcome.completed : FocusOutcome.ended;
}

/// One finished Focus session (spec 5.3 `users/{uid}/focus/{id}`).
@immutable
class FocusRecord {
  const FocusRecord({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.outcome,
    this.taskLabel,
  });

  final String id;
  final DateTime startedAt;

  /// Focused time, excluding pauses.
  final Duration duration;
  final FocusOutcome outcome;
  final String? taskLabel;

  Map<String, Object?> toRow() => {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'durationSec': duration.inSeconds,
    'status': outcome.name,
    if (taskLabel != null && taskLabel!.isNotEmpty) 'taskLabel': taskLabel,
  };

  static FocusRecord? fromRow(String id, Map<String, Object?> row) {
    final started = row['startedAt'];
    final seconds = row['durationSec'];
    if (started is! num || seconds is! num) return null;
    final label = row['taskLabel'];
    return FocusRecord(
      id: id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(started.toInt()),
      duration: Duration(seconds: seconds.toInt()),
      outcome: FocusOutcome.parse(row['status']),
      taskLabel: label is String ? label : null,
    );
  }
}
