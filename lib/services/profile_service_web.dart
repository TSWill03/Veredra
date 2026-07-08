// Signature: dev.tswicolly03
import 'dart:convert';

import '../models/app_profile.dart';
import 'storage/app_storage.dart';

class ProfileService {
  static const String _defaultProfileId = 'principal';

  final AppStorage _storage = createAppStorage();

  Future<List<AppProfile>> loadProfiles() async {
    final _ProfileIndex index = await _loadIndex();
    return List<AppProfile>.from(index.profiles);
  }

  Future<AppProfile> loadCurrentProfile() async {
    final _ProfileIndex index = await _loadIndex();
    final AppProfile? current = index.profiles.cast<AppProfile?>().firstWhere(
          (AppProfile? profile) => profile?.id == index.currentProfileId,
          orElse: () => null,
        );
    return current ?? index.profiles.first;
  }

  Future<AppProfile> createProfile(String name) async {
    final _ProfileIndex index = await _loadIndex();
    final String normalizedName = name.trim().isEmpty ? 'Usuario' : name.trim();
    final AppProfile profile = AppProfile(
      id: 'perfil_${DateTime.now().microsecondsSinceEpoch}',
      name: normalizedName,
      createdAt: DateTime.now(),
    );

    index.profiles.add(profile);
    index.currentProfileId = profile.id;
    await _saveIndex(index);
    return profile;
  }

  Future<AppProfile> renameProfile(String profileId, String nextName) async {
    final _ProfileIndex index = await _loadIndex();
    final int idx = index.profiles
        .indexWhere((AppProfile profile) => profile.id == profileId);
    if (idx < 0) {
      throw StateError('Perfil nao encontrado.');
    }

    final AppProfile updated = index.profiles[idx].copyWith(
      name:
          nextName.trim().isEmpty ? index.profiles[idx].name : nextName.trim(),
    );
    index.profiles[idx] = updated;
    await _saveIndex(index);
    return updated;
  }

  Future<AppProfile> switchProfile(String profileId) async {
    final _ProfileIndex index = await _loadIndex();
    final AppProfile? profile = index.profiles.cast<AppProfile?>().firstWhere(
          (AppProfile? item) => item?.id == profileId,
          orElse: () => null,
        );
    if (profile == null) {
      throw StateError('Perfil nao encontrado.');
    }

    index.currentProfileId = profile.id;
    await _saveIndex(index);
    return profile;
  }

  Future<void> deleteProfile(String profileId) async {
    final _ProfileIndex index = await _loadIndex();
    if (index.profiles.length <= 1) {
      throw StateError('Nao e possivel remover o unico perfil.');
    }

    index.profiles.removeWhere((AppProfile profile) => profile.id == profileId);
    if (index.currentProfileId == profileId) {
      index.currentProfileId = index.profiles.first.id;
    }

    await _saveIndex(index);
    await _storage.deletePrefix('profiles/$profileId');
  }

  Future<Never> profilesRootDirectory() async {
    throw UnsupportedError(
      'Diretorios locais estao disponiveis apenas no desktop.',
    );
  }

  Future<Never> profileDirectory(String profileId) async {
    throw UnsupportedError(
      'Diretorios locais estao disponiveis apenas no desktop.',
    );
  }

  Future<_ProfileIndex> _loadIndex() async {
    final String? raw = await _storage.readString(_indexKey);
    if (raw == null || raw.trim().isEmpty) {
      final _ProfileIndex index = _defaultIndex();
      await _saveIndex(index);
      return index;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      final _ProfileIndex index = _defaultIndex();
      await _storage.writeString(
        'profiles/profiles_index.corrupt.${DateTime.now().microsecondsSinceEpoch}.json',
        raw,
      );
      await _saveIndex(index);
      return index;
    }

    final List<AppProfile> profiles = decoded is Map<String, dynamic>
        ? (decoded['profiles'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AppProfile.fromJson)
            .toList(growable: true)
        : <AppProfile>[];

    if (profiles.isEmpty) {
      profiles.add(
        AppProfile(
          id: _defaultProfileId,
          name: 'Principal',
          createdAt: DateTime.now(),
        ),
      );
    }

    final String currentProfileId = decoded is Map<String, dynamic>
        ? decoded['currentProfileId'] as String? ?? profiles.first.id
        : profiles.first.id;

    final _ProfileIndex index = _ProfileIndex(
      currentProfileId: currentProfileId,
      profiles: profiles,
    );

    if (!profiles.any((AppProfile profile) => profile.id == currentProfileId)) {
      index.currentProfileId = profiles.first.id;
      await _saveIndex(index);
    }

    return index;
  }

  Future<void> _saveIndex(_ProfileIndex index) async {
    await _storage.writeString(
      _indexKey,
      jsonEncode(
        <String, dynamic>{
          'currentProfileId': index.currentProfileId,
          'profiles': index.profiles
              .map((AppProfile profile) => profile.toJson())
              .toList(),
        },
      ),
    );
  }

  _ProfileIndex _defaultIndex() {
    return _ProfileIndex(
      currentProfileId: _defaultProfileId,
      profiles: <AppProfile>[
        AppProfile(
          id: _defaultProfileId,
          name: 'Principal',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  String get _indexKey => 'profiles/profiles_index.json';
}

class _ProfileIndex {
  _ProfileIndex({
    required this.currentProfileId,
    required this.profiles,
  });

  String currentProfileId;
  final List<AppProfile> profiles;
}
