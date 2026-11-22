import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform.dart';

/// Shared experiment status. Never surfaces raw SDK errors, tokens or URLs.
class OperationState {
  const OperationState({
    this.busy = false,
    this.message = 'Ready for a device experiment.',
  });
  final bool busy;
  final String message;
}

class OperationController extends Notifier<OperationState> {
  @override
  OperationState build() => const OperationState();
  Future<void> run(Future<String> Function() action) async {
    if (state.busy) return;
    state = const OperationState(busy: true, message: 'Working…');
    try {
      state = OperationState(message: await action());
    } on CapabilityFailure catch (e) {
      state = OperationState(message: e.message);
    } on FirebaseException catch (e) {
      state = OperationState(
        message: e.code == 'network-request-failed'
            ? 'No connection. Connect to the internet and try again.'
            : 'Firebase: ${e.code}. Check setup or try again.',
      );
    } catch (_) {
      state = const OperationState(
        message: 'The experiment could not finish. Check configuration and connectivity, then retry.',
      );
    }
  }
}

final operationProvider = NotifierProvider<OperationController, OperationState>(
  OperationController.new,
);
