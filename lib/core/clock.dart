import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable wall clock. Tests override it; domain code never calls
/// `DateTime.now()` directly.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
