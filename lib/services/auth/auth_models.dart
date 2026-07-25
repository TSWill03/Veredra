// Signature: dev.tswicolly03
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final bool emailVerified;
}

enum AuthSessionEvent {
  initial,
  signedIn,
  signedOut,
  tokenRefreshed,
  passwordRecovery,
  userUpdated,
}

class AuthSessionSnapshot {
  const AuthSessionSnapshot({required this.event, required this.user});

  final AuthSessionEvent event;
  final AuthUser? user;
}

class AuthActionResult {
  const AuthActionResult({
    required this.message,
    this.requiresEmailVerification = false,
  });

  final String message;
  final bool requiresEmailVerification;
}

class AuthInputValidator {
  const AuthInputValidator._();

  static String? email(String value) {
    final String normalized = value.trim();
    final RegExp pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (normalized.isEmpty) {
      return 'Informe seu e-mail.';
    }
    if (normalized.length > 254 || !pattern.hasMatch(normalized)) {
      return 'Informe um e-mail valido.';
    }
    return null;
  }

  static String? password(String value) {
    if (value.length < 10) {
      return 'Use pelo menos 10 caracteres.';
    }
    if (!RegExp('[a-z]').hasMatch(value) ||
        !RegExp('[A-Z]').hasMatch(value) ||
        !RegExp('[0-9]').hasMatch(value)) {
      return 'Inclua letra maiuscula, minuscula e numero.';
    }
    return null;
  }
}
