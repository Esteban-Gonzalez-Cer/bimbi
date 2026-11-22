import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config.dart';
import '../../core/platform.dart';

final firebaseReadyProvider = Provider<bool>((ref) => false);

abstract interface class AuthAdapter {
  Stream<User?> get changes;
  User? get user;
  Future<void> email(String email, String password, {bool register = false});
  Future<void> google();
  Future<void> github();
  Future<void> signOut();
  Future<void> verify();
  Future<void> reload();
  Future<void> reset(String email);
}

class FirebaseAuthAdapter implements AuthAdapter {
  FirebaseAuthAdapter(this.auth);
  final FirebaseAuth auth;
  Future<void>? _googleInit;
  @override
  Stream<User?> get changes => auth.userChanges();
  @override
  User? get user => auth.currentUser;
  @override
  Future<void> email(
    String email,
    String password, {
    bool register = false,
  }) async {
    if (register) {
      await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } else {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  @override
  Future<void> google() async {
    if (AppConfig.googleServerClientId.isEmpty) {
      throw const CapabilityFailure(
        'configuration',
        'Add the Google web client ID to the local configuration.',
      );
    }
    _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
    try {
      await _googleInit;
    } catch (_) {
      _googleInit = null;
      rethrow;
    }
    final account = await GoogleSignIn.instance.authenticate();
    await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
  }

  @override
  Future<void> github() async {
    await auth.signInWithProvider(GithubAuthProvider());
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    if (_googleInit != null) {
      await GoogleSignIn.instance.signOut();
    }
  }

  @override
  Future<void> verify() async {
    await user?.sendEmailVerification();
  }

  @override
  Future<void> reload() async {
    await user?.reload();
    await auth.currentUser?.getIdToken(true);
  }

  @override
  Future<void> reset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
}

final authAdapterProvider = Provider<AuthAdapter?>(
  (ref) => ref.watch(firebaseReadyProvider)
      ? FirebaseAuthAdapter(FirebaseAuth.instance)
      : null,
);
final sessionProvider = StreamProvider<User?>(
  (ref) => ref.watch(authAdapterProvider)?.changes ?? Stream.value(null),
);
