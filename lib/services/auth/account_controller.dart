// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_gateway.dart';
import 'auth_models.dart';

class AccountController extends ChangeNotifier {
  AccountController(this._gateway) : user = _gateway.currentUser {
    _subscription = _gateway.sessionChanges.listen(
      _handleSession,
      onError: (Object _) {
        errorMessage =
            'A sessao nao pode ser atualizada. Continue no modo local.';
        notifyListeners();
      },
    );
  }

  final AuthGateway _gateway;
  StreamSubscription<AuthSessionSnapshot>? _subscription;

  AuthUser? user;
  bool busy = false;
  bool passwordRecovery = false;
  bool sessionExpired = false;
  String? errorMessage;
  String? noticeMessage;

  bool get isConfigured => _gateway.isConfigured;
  bool get isSignedIn => user != null;

  Future<void> signUp(String email, String password) {
    return _run(() => _gateway.signUp(email: email, password: password));
  }

  Future<void> signIn(String email, String password) {
    return _run(() => _gateway.signIn(email: email, password: password));
  }

  Future<void> sendPasswordReset(String email) {
    return _run(() => _gateway.sendPasswordReset(email));
  }

  Future<void> updatePassword(String password) async {
    await _run(() => _gateway.updatePassword(password));
    if (errorMessage == null) {
      passwordRecovery = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() {
    return _run(_gateway.signInWithGoogle);
  }

  Future<void> signOut() async {
    await _runVoid(_gateway.signOut);
  }

  Future<void> deleteAccount() async {
    await _runVoid(_gateway.deleteAccount);
  }

  void clearMessages() {
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();
  }

  Future<void> _run(Future<AuthActionResult> Function() action) async {
    if (busy) {
      return;
    }
    busy = true;
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();
    try {
      final AuthActionResult result = await action();
      noticeMessage = result.message;
    } catch (error) {
      errorMessage = _messageFrom(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _runVoid(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    busy = true;
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      errorMessage = _messageFrom(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _handleSession(AuthSessionSnapshot snapshot) {
    final bool hadUser = user != null;
    user = snapshot.user;
    passwordRecovery = snapshot.event == AuthSessionEvent.passwordRecovery;
    sessionExpired = snapshot.event == AuthSessionEvent.signedOut && hadUser;
    notifyListeners();
  }

  String _messageFrom(Object error) {
    if (error is StateError) {
      return error.message;
    }
    return 'Nao foi possivel concluir esta acao.';
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
