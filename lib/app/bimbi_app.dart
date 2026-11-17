import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/config.dart';
import '../core/operation.dart';
import '../core/platform.dart';
import '../features/auth/auth_adapter.dart';
import '../features/cloud/cloud_probe.dart';
import '../features/notifications/messaging.dart';
import '../features/payments/payment_adapter.dart';
import '../features/running/tracking.dart';

class BimbiApp extends StatelessWidget {
  const BimbiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Bimbi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff79658f),
        surface: const Color(0xfffff9f2),
      ),
      scaffoldBackgroundColor: const Color(0xfffff9f2),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffbda7d3),
        brightness: Brightness.dark,
      ),
    ),
    home: const BimbiShell(),
  );
}

const tabNames = ['Alarm', 'Sleep', 'Focus', 'Running', 'Profile'];
const tabIcons = [
  Icons.alarm_rounded,
  Icons.bedtime_outlined,
  Icons.timelapse_rounded,
  Icons.directions_run_rounded,
  Icons.person_outline_rounded,
];

class BimbiShell extends ConsumerStatefulWidget {
  const BimbiShell({super.key});
  @override
  ConsumerState<BimbiShell> createState() => _BimbiShellState();
}

class _BimbiShellState extends ConsumerState<BimbiShell> {
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () {
        unawaited(ref.read(trackingProvider.notifier).stop());
      },
      onHide: () {
        unawaited(ref.read(trackingProvider.notifier).stop());
      },
      onResume: () {
        ref.invalidate(capabilitiesProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index != 3) unawaited(ref.read(trackingProvider.notifier).stop());
    ref.read(destinationProvider.notifier).select(index);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(destinationProvider);
    final messageStatus = AppConfig.harness ? ref.watch(messagingProvider) : '';
    final busy = ref.watch(operationProvider).busy;
    return PopScope(
      canPop: selected == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Scaffold(
            appBar: AppBar(
              title: Text('Bimbi · ${tabNames[selected]}'),
              actions: [
                if (AppConfig.harness)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Chip(label: Text('Phase 1')),
                  ),
              ],
            ),
            bottomNavigationBar: compact
                ? NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: _select,
                    destinations: [
                      for (var i = 0; i < 5; i++)
                        NavigationDestination(
                          icon: Icon(tabIcons[i]),
                          label: tabNames[i],
                        ),
                    ],
                  )
                : null,
            body: SafeArea(
              child: Row(
                children: [
                  if (!compact)
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 120
                              ? constraints.maxHeight - 120
                              : 0,
                        ),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: selected,
                            onDestinationSelected: _select,
                            labelType: NavigationRailLabelType.all,
                            destinations: [
                              for (var i = 0; i < 5; i++)
                                NavigationRailDestination(
                                  icon: Icon(tabIcons[i]),
                                  label: Text(tabNames[i]),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: SingleChildScrollView(
                          key: ValueKey(selected),
                          padding: EdgeInsets.all(compact ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (AppConfig.harness) ...[
                                if (messageStatus.startsWith('Foreground'))
                                  Semantics(
                                    liveRegion: true,
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(messageStatus),
                                      ),
                                    ),
                                  ),
                                Semantics(
                                  liveRegion: true,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(
                                            busy
                                                ? Icons.hourglass_top
                                                : Icons.science_outlined,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              ref
                                                  .watch(operationProvider)
                                                  .message,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!AppConfig.harness)
                                const EmptyPanel(
                                  title: 'A gentler day starts here',
                                  message: 'Bimbi’s core features are being prepared.',
                                )
                              else
                                switch (selected) {
                                  0 => const AlarmPanel(),
                                  1 => const EmptyPanel(
                                    title: 'Your sleep diary',
                                    message: 'Sleep entries and honest routine summaries arrive in Phase 5.',
                                  ),
                                  2 => const FocusPanel(),
                                  3 => const RunningPanel(),
                                  _ => const ProfilePanel(),
                                },
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) =>
      Section(title: title, children: [Text(message)]);
}

class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          for (final child in children) ...[child, const SizedBox(height: 12)],
        ],
      ),
    ),
  );
}

class ActionButton extends ConsumerWidget {
  const ActionButton(this.label, this.action, {super.key, this.enabled = true});
  final String label;
  final Future<String> Function() action;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.tonal(
    onPressed: enabled && !ref.watch(operationProvider).busy
        ? () => ref.read(operationProvider.notifier).run(action)
        : null,
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class AlarmPanel extends ConsumerWidget {
  const AlarmPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(capabilitiesProvider);
    final platform = ref.read(platformProvider);
    Future<String> schedule(Duration delay, Duration repeat) async {
      await platform.schedule(
        id: 'phase1-alarm',
        at: DateTime.now().add(delay),
        repeat: repeat,
      );
      ref.invalidate(capabilitiesProvider);
      return 'Exact alarm scheduled. Test audio lasts at most two minutes.';
    }

    return Section(
      title: 'Wake gently. Dismiss safely.',
      children: [
        const Text(
          'Native Android experiment · one pending alarm. Scheduling replaces the previous test alarm.',
        ),
        capability.when(
          data: (c) => Text(
            'Exact alarms: ${c['exactAlarm'] == true ? 'allowed' : 'not allowed'}\nNotifications: ${c['notifications'] == true ? 'allowed' : 'not allowed'}\nFull-screen access: ${c['fullScreen'] == true ? 'allowed' : 'not allowed'}\nPending: ${c['pending'] == null ? 'none' : DateTime.fromMillisecondsSinceEpoch((c['pending'] as Map)['atMillis'] as int).toLocal()}\nLast event: ${c['lastEvent']}',
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Android capabilities unavailable.'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final setting in [
              ('exact', 'Allow exact alarms'),
              ('notification', 'Notification settings'),
              ('fullScreen', 'Lock-screen access'),
            ])
              ActionButton(setting.$2, () async {
                await platform.settings(setting.$1);
                return 'Return to Bimbi after reviewing Android settings.';
              }),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionButton(
              'Alarm in 30 seconds',
              () => schedule(const Duration(seconds: 30), Duration.zero),
            ),
            ActionButton(
              'Alarm in 3 minutes',
              () => schedule(const Duration(minutes: 3), Duration.zero),
            ),
            ActionButton(
              'Repeat every minute',
              () => schedule(
                const Duration(minutes: 1),
                const Duration(minutes: 1),
              ),
            ),
            ActionButton('Cancel pending alarm', () async {
              await platform.cancel();
              ref.invalidate(capabilitiesProvider);
              return 'Pending alarm cancelled.';
            }),
            // Emergency dismissal deliberately remains available while other operations run.
            OutlinedButton(
              onPressed: () async {
                await platform.dismiss();
                ref.invalidate(capabilitiesProvider);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Dismiss ringing alarm'),
            ),
            ActionButton('Refresh alarm status', () async {
              ref.invalidate(capabilitiesProvider);
              return 'Alarm status refreshed.';
            }),
          ],
        ),
      ],
    );
  }
}

class FocusPanel extends ConsumerWidget {
  const FocusPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Section(
    title: 'Space to focus',
    children: [
      const Text(
        'The resilient Focus timer arrives in Phase 5. Usage Access is an optional, separate experiment.',
      ),
      ActionButton('Review Usage Access', () async {
        await ref.read(platformProvider).settings('usage');
        return 'Usage Access is optional. Denying it will not disable Focus.';
      }),
      ActionButton('Check usage permission', () async {
        final values = await ref.read(platformProvider).usageSummary();
        return 'Usage Access granted. ${values['observedApps']} apps observed; ${values['totalForegroundSeconds']} foreground seconds in the daily query. Nothing uploaded.';
      }),
    ],
  );
}

class RunningPanel extends ConsumerWidget {
  const RunningPanel({super.key});
  // Bosque de Chapultepec, Mexico City. Fixed public facility, never a user's route.
  static const park = LatLng(19.4204, -99.1819);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final capabilities = ref.watch(capabilitiesProvider).asData?.value;
    return Section(
      title: 'A little movement',
      children: [
        if (capabilities?['mapsConfigured'] == true)
          SizedBox(
            height: 320,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: park,
                zoom: 14,
              ),
              markers: {
                const Marker(
                  markerId: MarkerId('chapultepec'),
                  position: park,
                  infoWindow: InfoWindow(title: 'Bosque de Chapultepec'),
                ),
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('foreground-trace'),
                  points: tracking.points
                      .map((p) => LatLng(p.latitude, p.longitude))
                      .toList(),
                  color: Colors.deepPurple,
                  width: 5,
                ),
              },
              myLocationEnabled: tracking.running,
              myLocationButtonEnabled: tracking.running,
              mapToolbarEnabled: false,
            ),
          )
        else
          const Text(
            'Map configuration required. GPS and motion can be tested independently.',
          ),
        Text(
          '${tracking.status}\nAccepted GPS samples: ${tracking.points.length}\nMovement: ${tracking.movement.toStringAsFixed(1)} m/s²',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionButton('Start GPS', () async {
              await ref.read(trackingProvider.notifier).startGps();
              return 'GPS experiment started. Keep Bimbi in the foreground.';
            }, enabled: !tracking.running),
            ActionButton('Start motion sensor', () async {
              await ref.read(trackingProvider.notifier).startMotion();
              return 'Accelerometer experiment started.';
            }, enabled: !tracking.motionActive),
            ActionButton('Stop tracking', () async {
              await ref.read(trackingProvider.notifier).stop();
              return 'GPS and motion subscriptions stopped.';
            }),
            ActionButton('Delete local trace', () async {
              await ref.read(trackingProvider.notifier).clear();
              return 'In-memory trace deleted.';
            }),
          ],
        ),
        const Text(
          'The short experiment trace stays in memory and is discarded when the app process closes.',
        ),
      ],
    );
  }
}

class ProfilePanel extends ConsumerStatefulWidget {
  const ProfilePanel({super.key});
  @override
  ConsumerState<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends ConsumerState<ProfilePanel> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authAdapterProvider);
    final user = ref.watch(sessionProvider).asData?.value;
    final ready = ref.watch(firebaseReadyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          title: 'Your account',
          children: [
            if (!ready)
              const Text(
                'Firebase configuration required. Add your development project settings using the setup guide.',
              ),
            if (user == null) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionButton('Sign in', () async {
                    await auth!.email(_email.text, _password.text);
                    _password.clear();
                    return 'Signed in.';
                  }, enabled: ready),
                  ActionButton('Create account', () async {
                    await auth!.email(
                      _email.text,
                      _password.text,
                      register: true,
                    );
                    _password.clear();
                    await auth.verify();
                    return 'Account created. Check your verification email.';
                  }, enabled: ready),
                  ActionButton('Google', () async {
                    await auth!.google();
                    return 'Google sign-in completed.';
                  }, enabled: ready),
                  ActionButton('GitHub', () async {
                    await auth!.github();
                    return 'GitHub sign-in completed.';
                  }, enabled: ready),
                  ActionButton('Reset password', () async {
                    await auth!.reset(_email.text);
                    return 'Password reset requested. Check your email.';
                  }, enabled: ready),
                ],
              ),
            ] else ...[
              Text(
                '${user.email ?? 'Signed-in account'}\nEmail ${user.emailVerified ? 'verified' : 'not verified'}\nProvider: ${user.providerData.map((p) => p.providerId).join(', ')}',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionButton('Resend verification', () async {
                    await auth!.verify();
                    return 'Verification requested.';
                  }, enabled: !user.emailVerified),
                  ActionButton('Refresh verification', () async {
                    await auth!.reload();
                    return 'Session refreshed.';
                  }),
                  ActionButton('Sign out', () async {
                    await auth!.signOut();
                    return 'Signed out.';
                  }),
                  ActionButton('Test private data and image', () async {
                    await ref.read(cloudProbeProvider).run();
                    return 'Private record and image matched after readback; probe data deleted.';
                  }, enabled: user.emailVerified),
                ],
              ),
            ],
          ],
        ),
        Section(
          title: 'Notification experiment',
          children: [
            Text(ref.watch(messagingProvider)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionButton('Enable test topic', () async {
                  await ref.read(messagingProvider.notifier).subscribe();
                  return 'Notification experiment updated.';
                }, enabled: ready),
                ActionButton('Disable test topic', () async {
                  await ref.read(messagingProvider.notifier).unsubscribe();
                  return 'Test topic disabled.';
                }, enabled: ready),
              ],
            ),
          ],
        ),
        Section(
          title: 'Plans · test mode only',
          children: [
            const Text(
              'These are payment experiments, not recurring subscriptions. No real charges or production access.',
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Free'),
              subtitle: Text('No payment required'),
            ),
            for (final plan in [
              ('plus', 'Plus · MX\$10 test payment'),
              ('premium', 'Premium · MX\$20 test payment'),
            ])
              ActionButton(
                plan.$2,
                () => ref.read(paymentAdapterProvider).checkout(plan.$1),
                enabled: ready && user?.emailVerified == true,
              ),
          ],
        ),
      ],
    );
  }
}
