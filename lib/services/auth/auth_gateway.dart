// Signature: dev.tswicolly03
import 'auth_models.dart';

abstract class AuthGateway {
  bool get isConfigured;

  AuthUser? get currentUser;

  Stream<AuthSessionSnapshot> get sessionChanges;

  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  });

  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  });

  Future<AuthActionResult> sendPasswordReset(String email);

  Future<AuthActionResult> updatePassword(String password);

  Future<AuthActionResult> signInWithGoogle();

  Future<void> signOut();

  Future<void> deleteAccount();
}

class LocalOnlyAuthGateway implements AuthGateway {
  const LocalOnlyAuthGateway();

  static const String _configurationMessage =
      'Conta online indisponivel neste build. Configure o Supabase para '
      'habilitar autenticacao e sincronizacao.';

  @override
  bool get isConfigured => false;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthSessionSnapshot> get sessionChanges =>
      const Stream<AuthSessionSnapshot>.empty();

  @override
  Future<void> deleteAccount() => _unavailable<void>();

  @override
  Future<AuthActionResult> sendPasswordReset(String email) =>
      _unavailable<AuthActionResult>();

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) =>
      _unavailable<AuthActionResult>();

  @override
  Future<AuthActionResult> signInWithGoogle() =>
      _unavailable<AuthActionResult>();

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) =>
      _unavailable<AuthActionResult>();

  @override
  Future<AuthActionResult> updatePassword(String password) =>
      _unavailable<AuthActionResult>();

  Future<T> _unavailable<T>() => Future<T>.error(
        StateError(_configurationMessage),
      );
}
