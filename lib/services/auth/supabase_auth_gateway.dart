// Signature: dev.tswicolly03
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../config/app_config.dart';
import 'auth_gateway.dart';
import 'auth_models.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(
    this._client, {
    bool? googleAuthEnabled,
  }) : _googleAuthEnabled = googleAuthEnabled ?? AppConfig.googleAuthEnabled;

  final SupabaseClient _client;
  final bool _googleAuthEnabled;

  @override
  bool get isConfigured => true;

  @override
  bool get isGoogleAuthEnabled => _googleAuthEnabled;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthSessionSnapshot> get sessionChanges {
    return _client.auth.onAuthStateChange.map((AuthState state) {
      return AuthSessionSnapshot(
        event: _mapEvent(state.event),
        user: _mapUser(state.session?.user),
      );
    });
  }

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: AppConfig.webAuthRedirectUrl,
      );
      final bool requiresVerification = response.session == null;
      return AuthActionResult(
        message: requiresVerification
            ? 'Conta criada. Confirme o e-mail antes de entrar.'
            : 'Conta criada e autenticada.',
        requiresEmailVerification: requiresVerification,
      );
    } on AuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthActionResult(message: 'Login concluido.');
    } on AuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  @override
  Future<AuthActionResult> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb
            ? AppConfig.webAuthRedirectUrl
            : AppConfig.nativeAuthRedirectUrl,
      );
      return const AuthActionResult(
        message: 'Se o e-mail existir, enviaremos o link de recuperacao.',
      );
    } on AuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  @override
  Future<AuthActionResult> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      return const AuthActionResult(message: 'Senha atualizada com seguranca.');
    } on AuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  @override
  Future<AuthActionResult> signInWithGoogle() async {
    if (!_googleAuthEnabled) {
      throw StateError(
        'A entrada com Google esta desativada nesta entrega.',
      );
    }
    try {
      final bool launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? AppConfig.webAuthRedirectUrl
            : AppConfig.nativeAuthRedirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Nao foi possivel abrir o login do Google.');
      }
      return const AuthActionResult(
        message: 'Conclua a entrada com Google no navegador.',
      );
    } on AuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc<void>('delete_own_account');
      await _client.auth.signOut(scope: SignOutScope.local);
    } on PostgrestException catch (error) {
      throw StateError(
        error.message.isEmpty
            ? 'Nao foi possivel excluir a conta agora.'
            : 'Nao foi possivel excluir a conta agora.',
      );
    }
  }

  AuthSessionEvent _mapEvent(AuthChangeEvent event) {
    switch (event) {
      case AuthChangeEvent.signedIn:
        return AuthSessionEvent.signedIn;
      case AuthChangeEvent.signedOut:
        return AuthSessionEvent.signedOut;
      case AuthChangeEvent.tokenRefreshed:
        return AuthSessionEvent.tokenRefreshed;
      case AuthChangeEvent.passwordRecovery:
        return AuthSessionEvent.passwordRecovery;
      case AuthChangeEvent.userUpdated:
        return AuthSessionEvent.userUpdated;
      default:
        return AuthSessionEvent.initial;
    }
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      emailVerified: user.emailConfirmedAt != null,
    );
  }

  String _friendlyAuthError(AuthException error) {
    final String normalized = error.message.toLowerCase();
    if (normalized.contains('invalid login') ||
        normalized.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (normalized.contains('already registered') ||
        normalized.contains('already exists')) {
      return 'Ja existe uma conta com este e-mail.';
    }
    if (normalized.contains('rate limit') || normalized.contains('too many')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    }
    if (normalized.contains('network') || normalized.contains('socket')) {
      return 'Sem conexao com o servico de contas.';
    }
    return 'Nao foi possivel concluir a autenticacao.';
  }
}
