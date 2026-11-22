import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/capabilities.dart';
import '../../../core/operation.dart';
import '../../../core/platform.dart';
import '../tracking.dart';

/// Bosque de Chapultepec, Mexico City. A fixed public facility, never a
/// person's route.
const parkLocation = LatLng(19.4204, -99.1819);
const parkName = 'Bosque de Chapultepec';

/// Derived, display-only route summary from accepted foreground samples.
class RouteSummary {
  RouteSummary(List<Position> points)
    : samples = points.length,
      distanceMeters = _distance(points),
      duration = points.length < 2
          ? Duration.zero
          : points.last.timestamp.difference(points.first.timestamp),
      lastAccuracy = points.isEmpty ? null : points.last.accuracy;

  final int samples;
  final double distanceMeters;
  final Duration duration;
  final double? lastAccuracy;

  static double _distance(List<Position> p) {
    var total = 0.0;
    for (var i = 1; i < p.length; i++) {
      total += Geolocator.distanceBetween(
        p[i - 1].latitude,
        p[i - 1].longitude,
        p[i].latitude,
        p[i].longitude,
      );
    }
    return total;
  }

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(2)} km';

  String get durationLabel {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = WindowScope.of(context);
    const header = PageHeader(title: 'Running', subtitle: 'A little movement');
    if (window.isExpanded) {
      // Map fills the visible height so its gestures never fight scrolling.
      final mapHeight = (MediaQuery.sizeOf(context).height - 210)
          .clamp(320.0, 640.0)
          .toDouble();
      return TwoPane(
        primaryFlex: 3,
        secondaryFlex: 2,
        primary: [
          header,
          _MapCard(height: mapHeight),
        ],
        secondary: const [_ControlsCard(), _PlaceCard(), _PrivacyNote()],
      );
    }
    return PageBody(
      children: [
        header,
        _MapCard(height: window.isCompact ? 280 : 360),
        const _ControlsCard(),
        const _PlaceCard(),
        const _PrivacyNote(),
      ],
    );
  }
}

class _MapCard extends ConsumerWidget {
  const _MapCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref
        .watch(capabilitiesProvider)
        .whenData(DeviceCapabilities.new)
        .asData
        ?.value;
    final tracking = ref.watch(trackingProvider);
    final style = ref
        .watch(mapStyleProvider(Theme.of(context).brightness))
        .asData
        ?.value;
    final c = context.bimbi;
    final Widget content;
    if (caps?.mapsConfigured == true) {
      content = GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: parkLocation,
          zoom: 14,
        ),
        style: style,
        markers: {
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
          Polyline(
            polylineId: const PolylineId('foreground-trace'),
            points: [
              for (final p in tracking.points) LatLng(p.latitude, p.longitude),
            ],
            color: Theme.of(context).colorScheme.primary,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        },
        myLocationEnabled: tracking.running,
        myLocationButtonEnabled: tracking.running,
        mapToolbarEnabled: false,
      );
    } else {
      content = Container(
        color: c.accentTint,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BimbiSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BimbiIcon(BimbiIcons.place, size: 40),
              const SizedBox(height: BimbiSpace.xs),
              Text(
                'Map unavailable in this build',
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
              Text(
                'GPS tracking still works.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: 'Map showing $parkName and your current walk',
      container: true,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BimbiRadius.cardBorder,
          border: Border.all(color: c.cardBorder, width: 1.5),
          boxShadow: c.shadows,
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

class _ControlsCard extends ConsumerWidget {
  const _ControlsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final summary = RouteSummary(tracking.points);
    final controller = ref.read(trackingProvider.notifier);
    final op = ref.read(operationProvider.notifier);
    final hasTrace = tracking.points.isNotEmpty;
    final accuracy = summary.lastAccuracy;
    final (gpsLabel, gpsTone) = !tracking.running
        ? ('GPS off', PillTone.neutral)
        : accuracy == null
        ? ('Finding GPS…', PillTone.accent)
        : accuracy <= 15
        ? ('GPS good · ±${accuracy.round()} m', PillTone.success)
        : ('GPS weak · ±${accuracy.round()} m', PillTone.danger);

    void start() => op.run(() async {
      await controller.startGps();
      return 'Walk started. Keep Bimbi open while you move.';
    });

    return BimbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BimbiBuddy(
                mood: tracking.running ? BuddyMood.excited : BuddyMood.happy,
                size: 64,
              ),
              const SizedBox(width: BimbiSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracking.running
                          ? 'Walking'
                          : hasTrace
                          ? 'Paused'
                          : 'Ready to move',
                      style: context.text.headlineSmall,
                    ),
                    const SizedBox(height: 4),
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
              ),
            ],
          ),
          const SizedBox(height: BimbiSpace.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: BimbiIcons.steps,
                  value: summary.distanceLabel,
                  label: 'Distance',
                ),
              ),
              const SizedBox(width: BimbiSpace.sm),
              Expanded(
                child: StatTile(
                  icon: BimbiIcons.focus,
                  value: summary.durationLabel,
                  label: 'Time',
                ),
              ),
            ],
          ),
          const SizedBox(height: BimbiSpace.xs),
          Text(
            '${summary.samples} accepted GPS samples',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: BimbiSpace.md),
          Wrap(
            spacing: BimbiSpace.sm,
            runSpacing: BimbiSpace.sm,
            children: [
              if (tracking.running)
                FilledButton.icon(
                  onPressed: () => op.run(() async {
                    await controller.stop();
                    return 'Walk paused. GPS is off.';
                  }),
                  icon: const BimbiIcon(BimbiIcons.pause, onAccent: true),
                  label: const Text('Pause'),
                )
              else
                FilledButton.icon(
                  onPressed: start,
                  icon: const BimbiIcon(BimbiIcons.play, onAccent: true),
                  label: Text(hasTrace ? 'Resume' : 'Start'),
                ),
              if (tracking.running || hasTrace)
                OutlinedButton.icon(
                  onPressed: () => op.run(() async {
                    await controller.stop();
                    return 'Walk finished: ${summary.distanceLabel} in '
                        '${summary.durationLabel}.';
                  }),
                  icon: const BimbiIcon(BimbiIcons.stop),
                  label: const Text('Finish'),
                ),
              if (hasTrace && !tracking.running)
                TextButton(
                  onPressed: () => op.run(() async {
                    await controller.clear();
                    return 'Walk removed from this device.';
                  }),
                  child: const Text('Discard walk'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard();
  @override
  Widget build(BuildContext context) => BimbiCard(
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.bimbi.successTint,
            borderRadius: BimbiRadius.chipBorder,
          ),
          alignment: Alignment.center,
          child: BimbiIcon(BimbiIcons.place),
        ),
        const SizedBox(width: BimbiSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(parkName, style: context.text.titleMedium),
              Text('Public park · Mexico City', style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => const InlineBanner(
    icon: BimbiIcons.shield,
    title: 'Your route stays on this device',
    message: 'GPS runs only while Bimbi is open on this screen.',
  );
}
