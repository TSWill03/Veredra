// Signature: dev.tswicolly03
import 'dart:convert';

import '../storage/app_storage.dart';

class SyncPreferences {
  const SyncPreferences({
    required this.enabled,
    required this.automatic,
    required this.syncBookFiles,
    this.syncIntervalMinutes = 5,
    this.consentAt,
    this.filesConsentAt,
  });

  const SyncPreferences.defaults()
      : enabled = false,
        automatic = true,
        syncBookFiles = false,
        syncIntervalMinutes = 5,
        consentAt = null,
        filesConsentAt = null;

  final bool enabled;
  final bool automatic;
  final bool syncBookFiles;

  /// Applies to background refresh while the app is active. A completed
  /// scroll can also be flushed after five seconds of inactivity.
  final int syncIntervalMinutes;
  final DateTime? consentAt;

  /// Separate, explicit opt-in for uploading copyrighted/private content.
  final DateTime? filesConsentAt;

  SyncPreferences copyWith({
    bool? enabled,
    bool? automatic,
    bool? syncBookFiles,
    int? syncIntervalMinutes,
    DateTime? consentAt,
    DateTime? filesConsentAt,
  }) {
    return SyncPreferences(
      enabled: enabled ?? this.enabled,
      automatic: automatic ?? this.automatic,
      syncBookFiles: syncBookFiles ?? this.syncBookFiles,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      consentAt: consentAt ?? this.consentAt,
      filesConsentAt: filesConsentAt ?? this.filesConsentAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'automatic': automatic,
        'syncBookFiles': syncBookFiles,
        'syncIntervalMinutes': syncIntervalMinutes,
        'consentAt': consentAt?.toUtc().toIso8601String(),
        'filesConsentAt': filesConsentAt?.toUtc().toIso8601String(),
      };

  factory SyncPreferences.fromJson(Map<String, dynamic> json) {
    return SyncPreferences(
      enabled: json['enabled'] as bool? ?? false,
      automatic: json['automatic'] as bool? ?? true,
      syncBookFiles: json['syncBookFiles'] as bool? ?? false,
      syncIntervalMinutes:
          const <int>{1, 5, 10, 15}.contains(json['syncIntervalMinutes'])
              ? json['syncIntervalMinutes'] as int
              : 5,
      consentAt: DateTime.tryParse(json['consentAt'] as String? ?? ''),
      filesConsentAt:
          DateTime.tryParse(json['filesConsentAt'] as String? ?? ''),
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
      syncBookFiles: false,
      consentAt: enabled ? DateTime.now().toUtc() : current.consentAt,
    );
    await save(next);
    return next;
  }

  Future<SyncPreferences> setSyncBookFiles(bool enabled) async {
    final SyncPreferences current = await load();
    if (enabled && !current.enabled) {
      throw StateError('Ative primeiro a sincronizacao dos dados de leitura.');
    }
    final SyncPreferences next = current.copyWith(
      syncBookFiles: enabled,
      filesConsentAt: enabled ? DateTime.now().toUtc() : current.filesConsentAt,
    );
    await save(next);
    return next;
  }

  Future<void> save(SyncPreferences preferences) {
    if (!const <int>{1, 5, 10, 15}.contains(preferences.syncIntervalMinutes)) {
      throw StateError('Intervalo automatico invalido.');
    }
    if (preferences.syncBookFiles &&
        (!preferences.enabled || preferences.filesConsentAt == null)) {
      throw StateError(
          'A sincronizacao de arquivos exige consentimento separado.');
    }
    return _storage.writeString(_key, jsonEncode(preferences.toJson()));
  }

  String get _key => 'profiles/$profileId/sync/preferences.json';
}
