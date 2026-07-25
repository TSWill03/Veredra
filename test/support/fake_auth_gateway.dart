// Signature: dev.tswicolly03
import 'dart:async';

import 'package:txt_webnovel_reader/services/auth/auth_gateway.dart';
import 'package:txt_webnovel_reader/services/auth/auth_models.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({
    this.user,
    this.delay = Duration.zero,
    this.googleAuthEnabled = false,
  });

  AuthUser? user;
  Duration delay;
  final bool googleAuthEnabled;
  int signInCalls = 0;
  int signUpCalls = 0;
  int resetCalls = 0;
  int googleCalls = 0;
  bool fail = false;
  final StreamController<AuthSessionSnapshot> controller =
      StreamController<AuthSessionSnapshot>.broadcast();

  @override
  AuthUser? get currentUser => user;

  @override
  bool get isConfigured => true;

  @override
  bool get isGoogleAuthEnabled => googleAuthEnabled;

  @override
  Stream<AuthSessionSnapshot> get sessionChanges => controller.stream;

  @override
  Future<void> deleteAccount() async {
    user = null;
    controller.add(
      const AuthSessionSnapshot(event: AuthSessionEvent.signedOut, user: null),
    );
  }

  @override
  Future<AuthActionResult> sendPasswordReset(String email) async {
    resetCalls++;
    await Future<void>.delayed(delay);
    return const AuthActionResult(message: 'Recuperacao enviada.');
  }

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    await Future<void>.delayed(delay);
    if (fail) {
      throw StateError('Falha simulada.');
    }
    user = AuthUser(id: 'user-a', email: email, emailVerified: true);
    controller.add(
      AuthSessionSnapshot(event: AuthSessionEvent.signedIn, user: user),
    );
    return const AuthActionResult(message: 'Login concluido.');
  }

  @override
  Future<AuthActionResult> signInWithGoogle() async {
    googleCalls++;
    return const AuthActionResult(message: 'Google aberto.');
  }

  @override
  Future<void> signOut() async {
    user = null;
    controller.add(
      const AuthSessionSnapshot(event: AuthSessionEvent.signedOut, user: null),
    );
  }

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    await Future<void>.delayed(delay);
    return const AuthActionResult(
      message: 'Confirme o e-mail.',
      requiresEmailVerification: true,
    );
  }

  @override
  Future<AuthActionResult> updatePassword(String password) async {
    return const AuthActionResult(message: 'Senha atualizada.');
  }

  Future<void> close() => controller.close();
}
