// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'package:txt_webnovel_reader/services/storage/app_storage.dart';

class MemoryAppStorage implements AppStorage {
  final Map<String, Object> values = <String, Object>{};

  @override
  Future<void> delete(String key) async {
    values.remove(normalizeStorageKey(key));
  }

  @override
  Future<void> deletePrefix(String keyPrefix) async {
    final String prefix = normalizeStorageKey(keyPrefix);
    values.removeWhere((String key, Object value) => key.startsWith(prefix));
  }

  @override
  Future<bool> exists(String key) async =>
      values.containsKey(normalizeStorageKey(key));

  @override
  Future<Uint8List?> readBytes(String key) async {
    final Object? value = values[normalizeStorageKey(key)];
    return value is Uint8List ? Uint8List.fromList(value) : null;
  }

  @override
  Future<String?> readString(String key) async {
    final Object? value = values[normalizeStorageKey(key)];
    return value is String ? value : null;
  }

  @override
  Future<void> writeBytes(String key, List<int> value) async {
    values[normalizeStorageKey(key)] = Uint8List.fromList(value);
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[normalizeStorageKey(key)] = value;
  }
}
