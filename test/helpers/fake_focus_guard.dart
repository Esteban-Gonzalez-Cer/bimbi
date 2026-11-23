import 'package:bimbi/data/services/focus_guard_service.dart';
import 'package:bimbi/domain/models/focus_shield.dart';

/// Records shield calls; permissions and apps are set per test.
class FakeFocusGuard implements FocusGuard {
  FakeFocusGuard({
    this.usageAccess = false,
    this.overlay = false,
    this.apps = const [],
    this.todayMinutes = const {},
    this.phoneUse,
  });

  bool usageAccess;
  bool overlay;
  List<ShieldApp> apps;
  Map<String, int> todayMinutes;
  int? phoneUse;
  Set<String> focusApps = {};
  Map<String, int> limits = {};
  final focusCalls = <DateTime?>[];
  final windowCalls = <List<DateTime>>[];
  final settingsOpened = <String>[];

  @override
  Future<ShieldStatus> status() async => ShieldStatus(
    usageAccess: usageAccess,
    overlay: overlay,
    focusApps: focusApps,
    limits: limits,
    focusUntil: focusCalls.lastOrNull,
    todayMinutes: todayMinutes,
  );

  @override
  Future<List<ShieldApp>> installedApps() async => apps;

  @override
  Future<void> setRules({
    required Set<String> focusApps,
    required Map<String, int> limits,
  }) async {
    this.focusApps = focusApps;
    this.limits = limits;
  }

  @override
  Future<void> focusUntil(
    DateTime? until, {
    List<DateTime> windowEnds = const [],
  }) async {
    focusCalls.add(until);
    windowCalls.add(windowEnds);
  }

  @override
  Future<void> usageSettings() async => settingsOpened.add('usage');

  @override
  Future<void> overlaySettings() async => settingsOpened.add('overlay');

  @override
  Future<int?> phoneUseBetween(DateTime from, DateTime to) async =>
      usageAccess ? phoneUse : null;
}
