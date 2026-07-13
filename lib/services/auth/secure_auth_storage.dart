// Signature: dev.tswicolly03
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureAuthLocalStorage extends LocalStorage {
  SecureAuthLocalStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _sessionKey = 'veredra.supabase.auth.session';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _prefix = 'veredra.supabase.pkce.';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) {
    return _storage.read(key: '$_prefix$key');
  }

  @override
  Future<void> removeItem({required String key}) {
    return _storage.delete(key: '$_prefix$key');
  }

  @override
  Future<void> setItem({required String key, required String value}) {
    return _storage.write(key: '$_prefix$key', value: value);
  }
}
