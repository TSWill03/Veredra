// Signature: dev.tswicolly03
import 'dart:convert';

import '../storage/app_storage.dart';

class SyncPreferences {
  const SyncPreferences({
    required this.enabled,
    required this.automatic,
    required this.syncBookFiles,
    this.consentAt,
  });

  const SyncPreferences.defaults()
      : enabled = false,
        automatic = true,
        syncBookFiles = false,
        consentAt = null;

  final bool enabled;
  final bool automatic;
  final bool syncBookFiles;
  final DateTime? consentAt;

  SyncPreferences copyWith({
    bool? enabled,
    bool? automatic,
    bool? syncBookFiles,
    DateTime? consentAt,
  }) {
    return SyncPreferences(
      enabled: enabled ?? this.enabled,
      automatic: automatic ?? this.automatic,
      syncBookFiles: syncBookFiles ?? this.syncBookFiles,
      consentAt: consentAt ?? this.consentAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'automatic': automatic,
        'syncBookFiles': syncBookFiles,
        'consentAt': consentAt?.toUtc().toIso8601String(),
      };

  factory SyncPreferences.fromJson(Map<String, dynamic> json) {
    return SyncPreferences(
      enabled: json['enabled'] as bool? ?? false,
      automatic: json['automatic'] as bool? ?? true,
      syncBookFiles: json['syncBookFiles'] as bool? ?? false,
      consentAt: DateTime.tryParse(json['consentAt'] as String? ?? ''),
    );
  }
}

class SyncPreferencesService {
  SyncPreferencesService({required this.profileId, AppStorage? storage})
      : _storage = storage ?? createAppStorage();

  final String profileId;
  final AppStorage _storage;

  Future<SyncPreferences> load() async {
    final String? raw = await _storage.readString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const SyncPreferences.defaults();
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? SyncPreferences.fromJson(decoded)
          : const SyncPreferences.defaults();
    } on FormatException {
      return const SyncPreferences.defaults();
    }
  }

  Future<SyncPreferences> setEnabled(bool enabled) async {
    final SyncPreferences current = await load();
    final SyncPreferences next = current.copyWith(
      enabled: enabled,
      syncBookFiles: enabled ? current.syncBookFiles : false,
      consentAt: enabled ? DateTime.now().toUtc() : current.consentAt,
    );
    await save(next);
    return next;
  }

  Future<SyncPreferences> setBookFiles(bool enabled) async {
    final SyncPreferences current = await load();
    if (enabled && !current.enabled) {
      throw StateError(
        'Ative primeiro a sincronizacao dos dados de leitura.',
      );
    }
    final SyncPreferences next = current.copyWith(
      syncBookFiles: enabled,
      consentAt: enabled ? DateTime.now().toUtc() : current.consentAt,
    );
    await save(next);
    return next;
  }

  Future<void> save(SyncPreferences preferences) {
    return _storage.writeString(_key, jsonEncode(preferences.toJson()));
  }

  String get _key => 'profiles/$profileId/sync/preferences.json';
}
