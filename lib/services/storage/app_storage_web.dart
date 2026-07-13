// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_base.dart';

AppStorage createAppStorage() => WebAppStorage();

/// Stores Veredra data in IndexedDB and migrates the former
/// `shared_preferences_web` values lazily, without dropping existing books.
class WebAppStorage implements AppStorage {
  static const String _databaseName = 'veredra_local_storage';
  static const String _objectStoreName = 'entries';
  static const String _legacyPrefix = 'veredra.storage.';

  final SharedPreferencesAsync _legacyPreferences = SharedPreferencesAsync();
  Future<Database>? _databaseFuture;

  @override
  Future<String?> readString(String key) async {
    final String normalizedKey = normalizeStorageKey(key);
    final Object? record = await _readRecord(normalizedKey);
    final String? value = _stringFromRecord(record);
    if (value != null) {
      return value;
    }

    final String? legacyValue =
        await _legacyPreferences.getString(_legacyKey(normalizedKey));
    if (legacyValue == null) {
      return null;
    }
    await writeString(normalizedKey, legacyValue);
    await _legacyPreferences.remove(_legacyKey(normalizedKey));
    return legacyValue;
  }

  @override
  Future<void> writeString(String key, String value) {
    return _writeRecord(
      normalizeStorageKey(key),
      <String, Object>{'kind': 'string', 'value': value},
    );
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final String normalizedKey = normalizeStorageKey(key);
    final Object? record = await _readRecord(normalizedKey);
    final Uint8List? value = _bytesFromRecord(record);
    if (value != null) {
      return value;
    }

    final String? legacyValue =
        await _legacyPreferences.getString(_legacyKey(normalizedKey));
    if (legacyValue == null) {
      return null;
    }
    try {
      final Uint8List migrated = Uint8List.fromList(base64Decode(legacyValue));
      await writeBytes(normalizedKey, migrated);
      await _legacyPreferences.remove(_legacyKey(normalizedKey));
      return migrated;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> writeBytes(String key, List<int> value) {
    return _writeRecord(
      normalizeStorageKey(key),
      <String, Object>{
        'kind': 'bytes',
        'value': Uint8List.fromList(value),
      },
    );
  }

  @override
  Future<bool> exists(String key) async {
    final String normalizedKey = normalizeStorageKey(key);
    if (await _readRecord(normalizedKey) != null) {
      return true;
    }
    return await _legacyPreferences.getString(_legacyKey(normalizedKey)) !=
        null;
  }

  @override
  Future<void> delete(String key) async {
    final String normalizedKey = normalizeStorageKey(key);
    final Database database = await _database;
    final Transaction transaction =
        database.transaction(_objectStoreName, idbModeReadWrite);
    await transaction.objectStore(_objectStoreName).delete(normalizedKey);
    await transaction.completed;
    await _legacyPreferences.remove(_legacyKey(normalizedKey));
  }

  @override
  Future<void> deletePrefix(String keyPrefix) async {
    final String normalizedPrefix = normalizeStorageKey(keyPrefix);
    final Database database = await _database;
    final Transaction transaction =
        database.transaction(_objectStoreName, idbModeReadWrite);
    final ObjectStore store = transaction.objectStore(_objectStoreName);
    final List<Object> keys = await store.getAllKeys();
    for (final Object key in keys) {
      if (key is String && key.startsWith(normalizedPrefix)) {
        await store.delete(key);
      }
    }
    await transaction.completed;

    final String legacyPrefix = _legacyKey(normalizedPrefix);
    final Set<String> legacyKeys = await _legacyPreferences.getKeys();
    for (final String key in legacyKeys) {
      if (key.startsWith(legacyPrefix)) {
        await _legacyPreferences.remove(key);
      }
    }
  }

  Future<Object?> _readRecord(String key) async {
    final Database database = await _database;
    final Transaction transaction =
        database.transaction(_objectStoreName, idbModeReadOnly);
    final Object? value =
        await transaction.objectStore(_objectStoreName).getObject(key);
    await transaction.completed;
    return value;
  }

  Future<void> _writeRecord(String key, Object value) async {
    final Database database = await _database;
    final Transaction transaction =
        database.transaction(_objectStoreName, idbModeReadWrite);
    await transaction.objectStore(_objectStoreName).put(value, key);
    await transaction.completed;
  }

  Future<Database> get _database {
    return _databaseFuture ??= idbFactoryBrowser.open(
      _databaseName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final Database database = event.database;
        if (!database.objectStoreNames.contains(_objectStoreName)) {
          database.createObjectStore(_objectStoreName);
        }
      },
    );
  }

  String? _stringFromRecord(Object? record) {
    if (record is Map) {
      final Object? kind = record['kind'];
      final Object? value = record['value'];
      if (kind == 'string' && value is String) {
        return value;
      }
    }
    return null;
  }

  Uint8List? _bytesFromRecord(Object? record) {
    if (record is Map && record['kind'] == 'bytes') {
      final Object? value = record['value'];
      if (value is Uint8List) {
        return value;
      }
      if (value is List<int>) {
        return Uint8List.fromList(value);
      }
      if (value is List) {
        return Uint8List.fromList(value.whereType<int>().toList());
      }
    }
    return null;
  }

  String _legacyKey(String key) => '$_legacyPrefix$key';
}
