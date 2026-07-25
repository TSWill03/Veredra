// Signature: dev.tswicolly03
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  static const String legacySupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String webAuthRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'https://wicolly.com.br/veredra/',
  );
  static const String nativeAuthRedirectUrl = String.fromEnvironment(
    'NATIVE_AUTH_REDIRECT_URL',
    defaultValue: 'veredra://auth-callback/',
  );
  static const bool diagnosticsUploadEnabled = bool.fromEnvironment(
    'ENABLE_DIAGNOSTICS_UPLOAD',
    defaultValue: false,
  );
  static const bool googleAuthEnabled = bool.fromEnvironment(
    'ENABLE_GOOGLE_AUTH',
    defaultValue: false,
  );

  /// When enabled, production must not silently fall back to an anonymous
  /// local-only library when authentication is unavailable.
  static const bool privateAccessRequired = bool.fromEnvironment(
    'PRIVATE_ACCESS_REQUIRED',
    defaultValue: false,
  );

  /// Public self-service registration is disabled by default. Accounts for a
  /// private deployment must be provisioned explicitly by the administrator.
  static const bool publicSignupEnabled = bool.fromEnvironment(
    'PUBLIC_SIGNUP_ENABLED',
    defaultValue: false,
  );

  static String get effectiveSupabaseKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : legacySupabaseAnonKey;

  static bool get isSupabaseConfigured {
    final Uri? uri = Uri.tryParse(supabaseUrl);
    final bool allowedScheme = uri?.scheme == 'https' ||
        (uri?.scheme == 'http' &&
            (uri?.host == 'localhost' || uri?.host == '127.0.0.1'));
    return allowedScheme &&
        uri!.host.isNotEmpty &&
        effectiveSupabaseKey.trim().isNotEmpty &&
        !effectiveSupabaseKey.contains('your-');
  }
}
