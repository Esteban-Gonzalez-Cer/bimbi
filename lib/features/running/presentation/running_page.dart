import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/capabilities.dart';
import '../../../core/clock.dart';
import '../../../core/platform.dart';
import '../../../ui/core/widgets/metric_tile.dart';
import '../application/run_controller.dart';
import '../domain/run.dart';

/// A fixed public facility. Workout coordinates come from the tracking adapter.
const parkLocation = LatLng(19.4204, -99.1819);
const parkName = 'Bosque de Chapultepec';

final mapStyleProvider = FutureProvider.family<String?, Brightness>((
  ref,
  brightness,
) async {
  try {
    return await rootBundle.loadString(
      brightness == Brightness.dark
          ? 'assets/map/dark.json'
          : 'assets/map/light.json',
    );
  } catch (_) {
    return null;
  }
});

class RunningPage extends ConsumerWidget {
  const RunningPage({super.key});

  static const _pad = EdgeInsets.fromLTRB(20, 28, 20, 32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runControllerProvider);
    final controller = ref.read(runControllerProvider.notifier);
    final window = WindowScope.of(context);
    final expanded = window.isExpanded;
    final recording = state.phase == RunPhase.recording;
    final mapHeight = expanded
        ? (MediaQuery.sizeOf(context).height - 330).clamp(220.0, 520.0)
        : window.isCompact
        ? 240.0
        : 340.0;
    final hero = _SessionCard(
      state: state,
      map: RunMap(
        height: mapHeight,
        segments: controller.visibleSegments,
        recording: recording,
      ),
    );
    final metrics = _RunMetrics(
      meters: controller.distanceMeters,
      active: state.active,
    );
    final history = _HistoryCard(state: state);

    if (expanded) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _Column(
                  padding: _pad,
                  children: [const _Header(), hero],
                ),
              ),
              Expanded(
                flex: 2,
                child: _Column(
                  padding: _pad.copyWith(top: 32 + 58),
                  children: [metrics, history],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _Column(
          padding: _pad,
          children: [const _Header(), hero, metrics, history],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.padding, required this.children});
  final EdgeInsets padding;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding,
    itemCount: children.length,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, i) => children[i],
  );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final now = ref.watch(clockProvider)();
    final recording =
        ref.watch(runControllerProvider.select((s) => s.phase)) ==
        RunPhase.recording;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}',
                  style: context.text.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                ),
                Text(
                  'Running',
                  key: PageHeader.titleKey,
                  style: context.text.headlineLarge?.copyWith(
                    fontSize: 36,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accentTint,
          ),
          child: BimbiBuddy(
            size: 50,
            mood: recording ? BuddyMood.excited : BuddyMood.happy,
            glow: false,
          ),
        ),
      ],
    );
  }
}

/// Tinted hero: what the run is doing, the map, and the actions.
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.state, required this.map});
  final RunningState state;
  final Widget map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final controller = ref.read(runControllerProvider.notifier);
    final night = Theme.of(context).brightness == Brightness.dark;
    final fg = night ? c.onNight : c.onAccentTint;
    final muted = night ? c.onNightMuted : c.textMuted;
    final phase = state.phase;
    final recording = phase == RunPhase.recording;
    final reviewing = phase == RunPhase.review;
    final title = switch (phase) {
      RunPhase.idle => 'Ready to move',
      RunPhase.starting => 'Checking location',
      RunPhase.recording => 'Recording',
      RunPhase.paused => 'Run paused',
      RunPhase.review => 'Review your run',
    };
    final accuracy = state.accuracy;
    final (gpsLabel, gpsTone) = switch ((recording, state.lostFix, accuracy)) {
      (false, _, _) => ('GPS off', PillTone.neutral),
      (true, true, _) => ('GPS signal lost', PillTone.danger),
      (true, false, null) => ('Finding GPS…', PillTone.accent),
      (true, false, final double m) when m <= 15 => (
        'GPS good · ±${m.round()} m',
        PillTone.success,
      ),
      (true, false, final double m) => (
        'GPS weak · ±${m.round()} m',
        PillTone.danger,
      ),
    };
    final failure = state.issue;
    final badStore = failure?.code == 'run_storage' && state.draft == null;

    Widget pair(Widget first, Widget? second) => second == null
        ? first
        : Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: BimbiSpace.sm),
              Expanded(child: second),
            ],
          );

    final Widget actions;
    if (badStore) {
      actions = OutlinedButton(
        onPressed: controller.retryStorage,
        child: const Text('Retry'),
      );
    } else if (reviewing) {
      actions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pair(
            FilledButton(
              onPressed: state.busy || state.draft?.canSave != true
                  ? null
                  : controller.save,
              child: const Text('Save run'),
            ),
            OutlinedButton(
              onPressed: state.busy ? null : controller.returnToPause,
              child: const Text('Back to run'),
            ),
          ),
          TextButton(
            onPressed: state.busy
                ? null
                : () async {
                    if (await _confirm(
                      context,
                      'Discard this run?',
                      'Discard',
                    )) {
                      await controller.discard();
                    }
                  },
            child: const Text('Discard'),
          ),
        ],
      );
    } else {
      actions = pair(
        FilledButton.icon(
          onPressed: phase == RunPhase.starting
              ? null
              : recording
              ? controller.pause
              : controller.start,
          icon: BimbiIcon(
            recording ? BimbiIcons.pause : BimbiIcons.play,
            onAccent: true,
          ),
          label: Text(
            recording
                ? 'Pause'
                : phase == RunPhase.paused
                ? 'Resume'
                : 'Start',
          ),
        ),
        recording || phase == RunPhase.paused
            ? OutlinedButton.icon(
                onPressed: controller.finish,
                icon: const BimbiIcon(BimbiIcons.stop),
                label: const Text('Finish'),
              )
            : null,
      );
    }

    return BimbiCard(
      color: night ? c.night : c.accentTint,
      borderColor: night ? c.cardBorder : c.accentTint,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: BimbiSpace.sm,
            runSpacing: 6,
            children: [
              Text(
                title,
                style: context.text.titleLarge?.copyWith(
                  fontSize: 22,
                  color: fg,
                ),
              ),
              Semantics(
                liveRegion: true,
                child: StatusPill(
                  gpsLabel,
                  tone: gpsTone,
                  icon: BimbiIcons.gps,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          map,
          if (state.loading) ...[
            const SizedBox(height: BimbiSpace.md),
            const LinearProgressIndicator(semanticsLabel: 'Loading saved runs'),
          ] else ...[
            if (failure != null) ...[
              const SizedBox(height: BimbiSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  failure.message,
                  style: context.text.bodyMedium?.copyWith(color: fg),
                ),
              ),
              if ([
                'permission_denied',
                'approximate',
                'service_off',
                'gps_stopped',
              ].contains(failure.code))
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: controller.openSettings,
                    child: const Text('Location settings'),
                  ),
                ),
            ],
            if (reviewing) ...[
              const SizedBox(height: BimbiSpace.sm),
              Text(
                state.draft?.canSave != true
                    ? 'Walk a little farther with a usable GPS signal to save a route.'
                    : state.verified
                    ? 'Your route stays here. Date, distance and active time sync to your account.'
                    : 'This run stays on this device.',
                style: context.text.bodyMedium?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: BimbiSpace.md),
            actions,
          ],
        ],
      ),
    );
  }
}

String _distance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(2)} km';

String _duration(Duration duration) {
  final m = duration.inMinutes;
  final s = duration.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _RunMetrics extends StatelessWidget {
  const _RunMetrics({required this.meters, required this.active});
  final double meters;
  final Duration active;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tiles = [
        MetricTile(
          icon: BimbiIcons.steps,
          value: _distance(meters),
          label: 'Distance',
        ),
        MetricTile(
          icon: BimbiIcons.focus,
          value: _duration(active),
          label: 'Active time',
        ),
      ];
      return constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(16) > 24
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tiles.first, const SizedBox(height: 10), tiles.last],
            )
          : Row(
              children: [
                Expanded(child: tiles.first),
                const SizedBox(width: 10),
                Expanded(child: tiles.last),
              ],
            );
    },
  );
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.state});
  final RunningState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final label = switch (state.sync) {
      RunSync.local => 'Saved on this device',
      RunSync.offline => 'Offline · syncs when connected',
      RunSync.syncing => 'Syncing…',
      RunSync.synced => 'Synced',
      RunSync.unavailable => 'Sync needs attention',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: BimbiSpace.sm,
            children: [
              Semantics(
                header: true,
                child: Text('Run history', style: context.text.headlineSmall),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state.sync == RunSync.unavailable)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: ref.read(runControllerProvider.notifier).retrySync,
              child: const Text('Retry sync'),
            ),
          ),
        if (state.loading)
          Text(
            'Loading saved runs…',
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          )
        else if (state.runs.isEmpty)
          Text(
            'Your saved runs will appear here.',
            style: context.text.bodyMedium?.copyWith(color: c.textMuted),
          )
        else
          for (final run in state.runs) ...[
            BimbiCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              onTap: () async {
                await ref.read(runControllerProvider.notifier).pause();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _RunDetail(id: run.id),
                  ),
                );
              },
              semanticLabel:
                  '${_runDate(context, run.summary!.startedAt)}, '
                  '${_distance(run.summary!.distanceM.toDouble())}, '
                  '${_duration(Duration(seconds: run.summary!.durationSec))}. Open',
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentTint,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    child: const BimbiIcon(BimbiIcons.steps, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _runDate(context, run.summary!.startedAt),
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_distance(run.summary!.distanceM.toDouble())} · '
                          '${_duration(Duration(seconds: run.summary!.durationSec))}',
                          style: context.text.bodyMedium?.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const BimbiIcon(BimbiIcons.chevronRight, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

String _runDate(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final format = MaterialLocalizations.of(context);
  return '${format.formatMediumDate(local)} · '
      '${format.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class _RunDetail extends ConsumerWidget {
  const _RunDetail({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runControllerProvider);
    final run = state.runs.where((entry) => entry.id == id).firstOrNull;
    final summary = run?.summary;
    final c = context.bimbi;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to Running',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const BimbiIcon(BimbiIcons.chevronLeft),
        ),
        title: Text('Saved run', style: context.text.headlineSmall),
      ),
      body: summary == null
          ? const Center(child: Text('This run is unavailable.'))
          : SafeArea(
              child: PageBody(
                maxWidth: 640,
                children: [
                  BimbiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _runDate(context, summary.startedAt),
                          style: context.text.titleLarge,
                        ),
                        const SizedBox(height: BimbiSpace.sm),
                        _RunMetrics(
                          meters: summary.distanceM.toDouble(),
                          active: Duration(seconds: summary.durationSec),
                        ),
                      ],
                    ),
                  ),
                  if (run!.segments.isEmpty)
                    const Text(
                      'The route is available on the recording device.',
                    )
                  else
                    RunMap(
                      height: 300,
                      segments: run.segments,
                      showPark: false,
                    ),
                  if (state.issue case final CapabilityFailure issue)
                    Text(issue.message),
                  OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            if (!await _confirm(
                              context,
                              'Delete this saved run?',
                              'Delete',
                            )) {
                              return;
                            }
                            if (!context.mounted) return;
                            await ref
                                .read(runControllerProvider.notifier)
                                .delete(id);
                            if (context.mounted &&
                                ref.read(runControllerProvider).issue == null) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Delete run'),
                  ),
                ],
              ),
            ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep run'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class RunMap extends ConsumerStatefulWidget {
  const RunMap({
    super.key,
    required this.height,
    required this.segments,
    this.recording = false,
    this.showPark = true,
  });

  final double height;
  final List<List<RunPoint>> segments;
  final bool recording;
  final bool showPark;

  @override
  ConsumerState<RunMap> createState() => _RunMapState();
}

class _RunMapState extends ConsumerState<RunMap> {
  GoogleMapController? _map;

  LatLng get _target => switch (widget.segments.lastOrNull?.lastOrNull) {
    final RunPoint point => LatLng(point.latitude, point.longitude),
    null => parkLocation,
  };

  @override
  void didUpdateWidget(covariant RunMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.isEmpty && widget.segments.isNotEmpty) {
      unawaited(_recenter());
    }
  }

  Future<void> _recenter() async {
    try {
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(_target, 16));
    } on PlatformException {
      // The platform view may be closing during a navigation transition.
    } on StateError {
      // The platform view may be closing during a navigation transition.
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(capabilitiesProvider).asData?.value;
    final native =
        widget.showPark &&
        configured != null &&
        DeviceCapabilities(configured).mapsConfigured;
    final style = native
        ? ref
              .watch(mapStyleProvider(Theme.of(context).brightness))
              .asData
              ?.value
        : null;
    final c = context.bimbi;
    final routeColor = Theme.of(context).colorScheme.primary;
    final hasRoute = widget.segments.any((segment) => segment.length >= 2);
    return Semantics(
      label: widget.showPark ? 'Running map, $parkName' : 'Recorded route',
      container: true,
      child: Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.accentTint,
          borderRadius: BimbiRadius.cardBorder,
          border: Border.all(color: c.cardBorder, width: 1.5),
        ),
        child: native
            ? Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) => _map = controller,
                    initialCameraPosition: CameraPosition(
                      target: _target,
                      zoom: widget.segments.isEmpty ? 14 : 16,
                    ),
                    style: style,
                    markers: {
                      if (widget.showPark)
                        Marker(
                          markerId: const MarkerId('chapultepec'),
                          position: parkLocation,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueViolet,
                          ),
                          infoWindow: const InfoWindow(title: parkName),
                        ),
                    },
                    polylines: {
                      for (final (index, segment) in widget.segments.indexed)
                        if (segment.length > 1)
                          Polyline(
                            polylineId: PolylineId('run-$index'),
                            points: _mapPoints(segment),
                            color: routeColor,
                            width: 5,
                            jointType: JointType.round,
                            startCap: Cap.roundCap,
                            endCap: Cap.roundCap,
                          ),
                    },
                    myLocationEnabled: widget.recording,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  PositionedDirectional(
                    top: BimbiSpace.sm,
                    end: BimbiSpace.sm,
                    child: IconButton.filledTonal(
                      onPressed: _recenter,
                      tooltip: 'Center map',
                      icon: const BimbiIcon(BimbiIcons.gps),
                    ),
                  ),
                ],
              )
            : hasRoute
            ? CustomPaint(
                painter: _RoutePainter(widget.segments, routeColor),
                child: const SizedBox.expand(),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(BimbiSpace.lg),
                  child: Text(
                    'Map unavailable. You can still record a run.',
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium,
                  ),
                ),
              ),
      ),
    );
  }
}

List<LatLng> _mapPoints(List<RunPoint> segment) {
  final step = (segment.length / 1200).ceil();
  return [
    for (var i = 0; i < segment.length - 1; i += step)
      LatLng(segment[i].latitude, segment[i].longitude),
    LatLng(segment.last.latitude, segment.last.longitude),
  ];
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.segments, this.color);
  final List<List<RunPoint>> segments;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final routes = segments
        .where((segment) => segment.length > 1)
        .map(_mapPoints)
        .toList();
    final points = routes.expand((segment) => segment).toList();
    if (points.isEmpty || size.shortestSide <= 36) return;
    final minX = points.map((point) => point.longitude).reduce(math.min);
    final maxX = points.map((point) => point.longitude).reduce(math.max);
    final minY = points.map((point) => point.latitude).reduce(math.min);
    final maxY = points.map((point) => point.latitude).reduce(math.max);
    final scale = math.min(
      (size.width - 36) / math.max(maxX - minX, 0.000001),
      (size.height - 36) / math.max(maxY - minY, 0.000001),
    );
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = size.center(Offset.zero);
    for (final route in routes) {
      final path = Path();
      for (final (i, point) in route.indexed) {
        final x = center.dx + (point.longitude - (minX + maxX) / 2) * scale;
        final y = center.dy - (point.latitude - (minY + maxY) / 2) * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.color != color;
}
