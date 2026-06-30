// Signature: dev.tswicolly03
import 'dart:typed_data';

abstract class AppStorage {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);

  Future<Uint8List?> readBytes(String key);

  Future<void> writeBytes(String key, List<int> value);

  Future<bool> exists(String key);

  Future<void> delete(String key);

  Future<void> deletePrefix(String keyPrefix);
}

String normalizeStorageKey(String key) {
  return key
      .replaceAll('\\', '/')
      .split('/')
      .map((String segment) => segment.trim())
      .where((String segment) =>
          segment.isNotEmpty && segment != '.' && segment != '..')
      .join('/');
}
