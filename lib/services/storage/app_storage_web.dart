// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_base.dart';

AppStorage createAppStorage() => WebAppStorage();

class WebAppStorage implements AppStorage {
  static const String _prefix = 'veredra.storage.';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> readString(String key) {
    return _preferences.getString(_preferenceKey(key));
  }

  @override
  Future<void> writeString(String key, String value) {
    return _preferences.setString(_preferenceKey(key), value);
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final String? raw = await readString(key);
    if (raw == null) {
      return null;
    }
    return Uint8List.fromList(base64Decode(raw));
  }

  @override
  Future<void> writeBytes(String key, List<int> value) {
    return writeString(key, base64Encode(value));
  }

  @override
  Future<bool> exists(String key) async {
    return await readString(key) != null;
  }

  @override
  Future<void> delete(String key) {
    return _preferences.remove(_preferenceKey(key));
  }

  @override
  Future<void> deletePrefix(String keyPrefix) async {
    final String normalizedPrefix = _preferenceKey(keyPrefix);
    final Set<String> keys = await _preferences.getKeys();
    for (final String key in keys) {
      if (key.startsWith(normalizedPrefix)) {
        await _preferences.remove(key);
      }
    }
  }

  String _preferenceKey(String key) => '$_prefix${normalizeStorageKey(key)}';
}
