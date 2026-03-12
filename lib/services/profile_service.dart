// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_profile.dart';

class ProfileService {
  static const String _defaultProfileId = 'principal';

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
    await profileDirectory(profile.id);
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
    await profileDirectory(profile.id);
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

    final Directory directory = await profileDirectory(profileId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> profilesRootDirectory() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory directory =
        Directory(p.join(documentsDirectory.path, 'profiles'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> profileDirectory(String profileId) async {
    final Directory root = await profilesRootDirectory();
    final Directory directory = Directory(p.join(root.path, profileId));
    await directory.create(recursive: true);
    return directory;
  }

  Future<_ProfileIndex> _loadIndex() async {
    final File file = await _indexFile();
    if (!await file.exists()) {
      final _ProfileIndex index = _ProfileIndex(
        currentProfileId: _defaultProfileId,
        profiles: <AppProfile>[
          AppProfile(
            id: _defaultProfileId,
            name: 'Principal',
            createdAt: DateTime.now(),
          ),
        ],
      );
      await _saveIndex(index);
      return index;
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      final _ProfileIndex index = _ProfileIndex(
        currentProfileId: _defaultProfileId,
        profiles: <AppProfile>[
          AppProfile(
            id: _defaultProfileId,
            name: 'Principal',
            createdAt: DateTime.now(),
          ),
        ],
      );
      await _saveIndex(index);
      return index;
    }

    final dynamic decoded = jsonDecode(raw);
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
    final File file = await _indexFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(
        <String, dynamic>{
          'currentProfileId': index.currentProfileId,
          'profiles': index.profiles
              .map((AppProfile profile) => profile.toJson())
              .toList(),
        },
      ),
      flush: true,
    );
  }

  Future<File> _indexFile() async {
    final Directory root = await profilesRootDirectory();
    return File(p.join(root.path, 'profiles_index.json'));
  }
}

class _ProfileIndex {
  _ProfileIndex({
    required this.currentProfileId,
    required this.profiles,
  });

  String currentProfileId;
  final List<AppProfile> profiles;
}
