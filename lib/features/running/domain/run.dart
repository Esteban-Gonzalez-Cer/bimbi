import 'dart:math' as math;

const fixGap = Duration(seconds: 15);
final runIdPattern = RegExp(r'^[a-f0-9]{32}$');

class RunPoint {
  const RunPoint(this.latitude, this.longitude, this.accuracy, this.timestamp);

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  bool get valid =>
      latitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.isFinite &&
      longitude.abs() <= 180 &&
      accuracy.isFinite &&
      accuracy > 0 &&
      accuracy <= 50;

  List<num> toJson() => [
    latitude,
    longitude,
    accuracy,
    timestamp.millisecondsSinceEpoch,
  ];

  factory RunPoint.fromJson(List<dynamic> value) => RunPoint(
    (value[0] as num).toDouble(),
    (value[1] as num).toDouble(),
    (value[2] as num).toDouble(),
    DateTime.fromMillisecondsSinceEpoch(value[3] as int, isUtc: true),
  );

  double distanceTo(RunPoint other) {
    const radians = math.pi / 180;
    final dLat = (other.latitude - latitude) * radians;
    final dLng = (other.longitude - longitude) * radians;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(other.latitude * radians) *
            math.pow(math.sin(dLng / 2), 2);
    return 12742000 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }
}

enum FixResult { rejected, steady, added }

/// Keeps separate segments so distance never crosses a pause or loss of fix.
class RunRoute {
  RunRoute({Iterable<List<RunPoint>> segments = const [], double meters = 0})
    : _segments = segments.map((s) => s.toList()).toList(),
      _meters = math.max(0, meters);

  final List<List<RunPoint>> _segments;
  double _meters;
  RunPoint? _anchor;
  DateTime? _lastFix;
  Duration? _lastReceipt;
  double? accuracy;
  int rejected = 0;

  double get meters => _meters;
  bool get hasRoute => _segments.any((s) => s.length >= 2);
  int get pointCount => _segments.fold(0, (total, s) => total + s.length);
  List<List<RunPoint>> get segments => List.unmodifiable(
    _segments.map((segment) => List<RunPoint>.unmodifiable(segment)),
  );

  void breakSegment() {
    _anchor = null;
    _lastFix = null;
    _lastReceipt = null;
    accuracy = null;
  }

  bool stale(Duration elapsed) =>
      _lastReceipt == null || elapsed - _lastReceipt! >= fixGap;

  FixResult add(
    RunPoint fix, {
    required DateTime now,
    required DateTime startedSegment,
    required Duration elapsed,
    required bool mocked,
  }) {
    final age = now.difference(fix.timestamp);
    final previous = _lastFix;
    if (mocked ||
        !fix.valid ||
        age >= fixGap ||
        age < const Duration(seconds: -5) ||
        fix.timestamp.isBefore(startedSegment) ||
        (previous != null && !fix.timestamp.isAfter(previous))) {
      rejected++;
      return FixResult.rejected;
    }

    if (stale(elapsed)) _anchor = null;
    final anchor = _anchor;
    if (anchor == null) {
      _segments.add([fix]);
      _anchor = fix;
      _use(fix, elapsed);
      return FixResult.added;
    }

    final distance = anchor.distanceTo(fix);
    final seconds =
        fix.timestamp.difference(anchor.timestamp).inMicroseconds / 1000000;
    if (seconds <= 0 || distance > 15 * seconds) {
      rejected++;
      return FixResult.rejected;
    }
    _use(fix, elapsed);
    final jitter = math.max(3.0, math.max(anchor.accuracy, fix.accuracy) / 2);
    if (distance < jitter) return FixResult.steady;

    _segments.last.add(fix);
    _anchor = fix;
    _meters += distance;
    return FixResult.added;
  }

  void _use(RunPoint fix, Duration elapsed) {
    _lastFix = fix.timestamp;
    _lastReceipt = elapsed;
    accuracy = fix.accuracy;
  }
}

/// Only these fields may go to Firebase. Coordinates belong to RunDraft and
/// the local copy of a saved run.
class RunSummary {
  const RunSummary(this.id, this.startedAt, this.distanceM, this.durationSec);

  final String id;
  final DateTime startedAt;
  final int distanceM;
  final int durationSec;

  Map<String, int> toJson() => {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'distanceM': distanceM,
    'durationSec': durationSec,
  };

  static RunSummary? parse(String id, Object? json) {
    if (!runIdPattern.hasMatch(id) || json is! Map || json.length != 3) {
      return null;
    }
    final startedAt = json['startedAt'];
    final distance = json['distanceM'];
    final seconds = json['durationSec'];
    if (startedAt is! int ||
        startedAt < 1577836800000 ||
        startedAt > 8640000000000000 ||
        distance is! int ||
        distance < 0 ||
        seconds is! int ||
        seconds <= 0) {
      return null;
    }
    return RunSummary(
      id,
      DateTime.fromMillisecondsSinceEpoch(startedAt, isUtc: true),
      distance,
      seconds,
    );
  }
}

class RunDraft {
  const RunDraft({
    required this.id,
    required this.startedAt,
    this.active = Duration.zero,
    this.meters = 0,
    this.segments = const [],
  });

  final String id;
  final DateTime startedAt;
  final Duration active;
  final double meters;
  final List<List<RunPoint>> segments;

  bool get canSave => segments.any((s) => s.length >= 2);

  RunSummary get summary => RunSummary(
    id,
    startedAt,
    meters.round(),
    math.max(1, (active.inMilliseconds / 1000).round()),
  );

  RunDraft checkpoint(Duration active, RunRoute route) => RunDraft(
    id: id,
    startedAt: startedAt,
    active: active,
    meters: route.meters,
    segments: route.segments,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'activeMs': active.inMilliseconds,
    'meters': meters,
    'segments': encodeSegments(segments),
  };

  factory RunDraft.fromJson(Map<String, dynamic> value) => RunDraft(
    id: value['id'] as String,
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      value['startedAt'] as int,
      isUtc: true,
    ),
    active: Duration(milliseconds: value['activeMs'] as int),
    meters: (value['meters'] as num).toDouble(),
    segments: decodeSegments(value['segments'] as List),
  );
}

List<List<List<num>>> encodeSegments(List<List<RunPoint>> segments) => [
  for (final segment in segments) [for (final point in segment) point.toJson()],
];

List<List<RunPoint>> decodeSegments(List<dynamic> value) => [
  for (final segment in value)
    [for (final point in segment as List) RunPoint.fromJson(point as List)],
];
