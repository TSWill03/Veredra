// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/app_profile.dart';
import '../models/book_reference.dart';
import '../models/library_entry.dart';
import 'annotation_service.dart';
import 'bookmark_service.dart';
import 'library_service.dart';
import 'profile_service.dart';
import 'progress_service.dart';
import 'reading_stats_service.dart';

class BackupService {
  static const int _maxBackupBytes = 256 * 1024 * 1024;
  static const int _maxArchiveFiles = 20000;
  static const int _maxArchiveFileBytes = 100 * 1024 * 1024;
  static const int _maxTotalUncompressedBytes = 512 * 1024 * 1024;

  BackupService({
    required this.profileService,
    required this.libraryService,
    required this.progressService,
    required this.bookmarkService,
    required this.annotationService,
    required this.readingStatsService,
  });

  final ProfileService profileService;
  final LibraryService libraryService;
  final ProgressService progressService;
  final BookmarkService bookmarkService;
  final AnnotationService annotationService;
  final ReadingStatsService readingStatsService;

  Future<String?> exportCurrentProfile(AppProfile profile) async {
    if (kIsWeb) {
      throw StateError(
        'Backup e restauracao ainda estao disponiveis apenas no desktop.',
      );
    }

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: '${_sanitizeFileName(profile.name)}.twrbackup',
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'Backup',
          extensions: <String>['twrbackup', 'zip'],
        ),
      ],
    );
    if (location == null || location.path.isEmpty) {
      return null;
    }

    final List<LibraryEntry> entries = await libraryService.loadEntries();
    final Map<String, dynamic> progressState =
        await progressService.exportState();
    final Map<String, List<dynamic>> bookmarks =
        (await bookmarkService.loadAllBookmarks()).map(
      (String key, List<dynamic> value) => MapEntry<String, List<dynamic>>(
        key,
        value.map((dynamic item) => item.toJson()).toList(growable: false),
      ),
    );
    final Map<String, List<dynamic>> annotations =
        (await annotationService.loadAllAnnotations()).map(
      (String key, List<dynamic> value) => MapEntry<String, List<dynamic>>(
        key,
        value.map((dynamic item) => item.toJson()).toList(growable: false),
      ),
    );
    final Map<String, dynamic> readingStats =
        await readingStatsService.exportJson();

    final Archive archive = Archive();
    final List<Map<String, dynamic>> snapshotBooks = <Map<String, dynamic>>[];

    for (final LibraryEntry entry in entries) {
      final _ArchivedBookRecord record = await _archiveBook(entry, archive);
      snapshotBooks.add(record.toJson());
    }

    final Map<String, dynamic> snapshot = <String, dynamic>{
      'profile': profile.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
      'books': snapshotBooks,
      'progressState': progressState,
      'bookmarks': bookmarks,
      'annotations': annotations,
      'readingStats': readingStats,
    };

    final List<int> snapshotBytes = utf8.encode(jsonEncode(snapshot));
    archive.addFile(
      ArchiveFile('snapshot.json', snapshotBytes.length, snapshotBytes),
    );

    final List<int>? encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Nao foi possivel gerar o backup.');
    }

    final File file = File(location.path);
    await file.writeAsBytes(encoded, flush: true);
    return file.path;
  }

  Future<AppProfile?> importProfileBackup() async {
    if (kIsWeb) {
      throw StateError(
        'Backup e restauracao ainda estao disponiveis apenas no desktop.',
      );
    }

    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'Backup',
          extensions: <String>['twrbackup', 'zip'],
        ),
      ],
      confirmButtonText: 'Importar backup',
    );
    if (file == null) {
      return null;
    }

    final List<int> bytes = await file.readAsBytes();
    if (bytes.length > _maxBackupBytes) {
      throw StateError('O backup selecionado excede o tamanho maximo seguro.');
    }

    final Archive archive = ZipDecoder().decodeBytes(bytes);
    _validateArchive(archive);
    final ArchiveFile? snapshotFile = archive.findFile('snapshot.json');
    if (snapshotFile == null) {
      throw StateError('O arquivo nao parece ser um backup valido.');
    }

    final dynamic decoded = jsonDecode(
      utf8.decode(snapshotFile.content as List<int>),
    );
    if (decoded is! Map<String, dynamic>) {
      throw StateError('O snapshot do backup esta invalido.');
    }

    final AppProfile sourceProfile = AppProfile.fromJson(
      decoded['profile'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final AppProfile importedProfile = await profileService.createProfile(
      '${sourceProfile.name} Importado',
    );

    libraryService.configureProfile(importedProfile.id);
    progressService.configureProfile(importedProfile.id);
    bookmarkService.configureProfile(importedProfile.id);
    annotationService.configureProfile(importedProfile.id);
    readingStatsService.configureProfile(importedProfile.id);

    final List<LibraryEntry> importedEntries = <LibraryEntry>[];
    for (final Map<String, dynamic> bookJson
        in (decoded['books'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()) {
      importedEntries
          .add(await _restoreBook(bookJson, archive, importedProfile));
    }

    await libraryService.replaceEntries(importedEntries);

    final Map<String, dynamic> progressState =
        decoded['progressState'] as Map<String, dynamic>? ??
            <String, dynamic>{};
    final BookReference? previousLastBook =
        progressState['lastBookReference'] is Map<String, dynamic>
            ? BookReference.fromJson(
                progressState['lastBookReference'] as Map<String, dynamic>,
              )
            : null;
    if (previousLastBook != null) {
      final LibraryEntry? match =
          importedEntries.cast<LibraryEntry?>().firstWhere(
                (LibraryEntry? entry) => _sameBookReference(
                  entry?.reference,
                  previousLastBook,
                ),
                orElse: () => null,
              );
      if (match != null) {
        progressState['lastBookReference'] = match.reference.toJson();
      }
    }
    await progressService.importState(progressState);

    await bookmarkService.importJson(
      decoded['bookmarks'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    await annotationService.importJson(
      decoded['annotations'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    await readingStatsService.importJson(
      decoded['readingStats'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );

    return importedProfile;
  }

  Future<_ArchivedBookRecord> _archiveBook(
    LibraryEntry entry,
    Archive archive,
  ) async {
    final List<String> archivedAssets = <String>[];
    final String bookRoot = 'books/${entry.id}';

    if (entry.reference.usesDirectory) {
      final Directory directory = Directory(entry.reference.directoryPath!);
      if (await directory.exists()) {
        await for (final FileSystemEntity entity
            in directory.list(recursive: false, followLinks: false)) {
          if (entity is! File) {
            continue;
          }

          final String targetPath =
              '$bookRoot/directory/${p.basename(entity.path)}';
          await _addArchiveFileFromDisk(archive, targetPath, entity.path);
        }
      }
    } else {
      for (int index = 0; index < entry.reference.assetPaths.length; index++) {
        final String assetPath = entry.reference.assetPaths[index];
        final String targetPath =
            '$bookRoot/assets/$index-${p.basename(assetPath)}';
        if (await File(assetPath).exists()) {
          await _addArchiveFileFromDisk(archive, targetPath, assetPath);
          archivedAssets.add(targetPath);
        }
      }
    }

    String? archivedCoverPath;
    if (entry.reference.coverPath != null &&
        await File(entry.reference.coverPath!).exists()) {
      archivedCoverPath =
          '$bookRoot/cover${p.extension(entry.reference.coverPath!)}';
      await _addArchiveFileFromDisk(
        archive,
        archivedCoverPath,
        entry.reference.coverPath!,
      );
    }

    return _ArchivedBookRecord(
      entry: entry,
      archivedAssetPaths: archivedAssets,
      archivedCoverPath: archivedCoverPath,
    );
  }

  Future<LibraryEntry> _restoreBook(
    Map<String, dynamic> json,
    Archive archive,
    AppProfile profile,
  ) async {
    final LibraryEntry entry = LibraryEntry.fromJson(
      json['entry'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final List<String> archivedAssetPaths =
        (json['archivedAssetPaths'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);
    final String? archivedCoverPath = json['archivedCoverPath'] as String?;

    final Directory profileDirectory =
        await profileService.profileDirectory(profile.id);
    final Directory storageDirectory =
        Directory(p.join(profileDirectory.path, 'storage', 'restored'));
    await storageDirectory.create(recursive: true);

    BookReference reference = entry.reference;
    if (reference.usesDirectory) {
      final Directory restoredDirectory = Directory(
        p.join(storageDirectory.path, 'directory_books', entry.id),
      );
      await restoredDirectory.create(recursive: true);
      for (final ArchiveFile file in archive.files) {
        if (!file.isFile ||
            !file.name.startsWith('books/${entry.id}/directory/')) {
          continue;
        }

        final String relativeName = _safeArchiveFileName(
          file.name.replaceFirst('books/${entry.id}/directory/', ''),
        );
        final File targetFile =
            File(p.join(restoredDirectory.path, relativeName));
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes((file.content as List).cast<int>());
      }
      reference = reference.copyWith(directoryPath: restoredDirectory.path);
    } else {
      final Directory restoredAssetsDirectory = Directory(
        p.join(storageDirectory.path, 'assets', entry.id),
      );
      await restoredAssetsDirectory.create(recursive: true);
      final List<String> restoredAssetPaths = <String>[];
      for (final String archivePath in archivedAssetPaths) {
        final ArchiveFile? file = archive.findFile(archivePath);
        if (file == null || !file.isFile) {
          continue;
        }

        final String filename = _safeArchiveFileName(archivePath);
        final File targetFile =
            File(p.join(restoredAssetsDirectory.path, filename));
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes((file.content as List).cast<int>());
        restoredAssetPaths.add(targetFile.path);
      }
      reference = reference.copyWith(assetPaths: restoredAssetPaths);
    }

    if (archivedCoverPath != null) {
      final ArchiveFile? coverFile = archive.findFile(archivedCoverPath);
      if (coverFile != null && coverFile.isFile) {
        final Directory restoredCoverDirectory = Directory(
          p.join(storageDirectory.path, 'covers', entry.id),
        );
        await restoredCoverDirectory.create(recursive: true);
        final File targetFile = File(
          p.join(
            restoredCoverDirectory.path,
            _safeArchiveFileName(archivedCoverPath),
          ),
        );
        await targetFile.writeAsBytes((coverFile.content as List).cast<int>());
        reference = reference.copyWith(coverPath: targetFile.path);
      }
    }

    return entry.copyWith(reference: reference);
  }

  bool _sameBookReference(BookReference? a, BookReference? b) {
    if (a == null || b == null) {
      return false;
    }

    if (a.format != b.format || a.directoryPath != b.directoryPath) {
      return false;
    }

    if (a.assetPaths.length != b.assetPaths.length) {
      return false;
    }

    for (int index = 0; index < a.assetPaths.length; index++) {
      if (p.basename(a.assetPaths[index]) != p.basename(b.assetPaths[index])) {
        return false;
      }
    }

    return true;
  }

  Future<void> _addArchiveFileFromDisk(
    Archive archive,
    String archivePath,
    String sourcePath,
  ) async {
    final File file = File(sourcePath);
    final int fileLength = await file.length();
    if (fileLength > _maxArchiveFileBytes) {
      throw StateError('Um arquivo do backup excede o tamanho maximo seguro.');
    }
    final List<int> bytes = await file.readAsBytes();
    archive.addFile(
      ArchiveFile(archivePath, bytes.length, Uint8List.fromList(bytes)),
    );
  }

  String _sanitizeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _validateArchive(Archive archive) {
    int fileCount = 0;
    int totalUncompressedBytes = 0;

    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }

      fileCount++;
      if (fileCount > _maxArchiveFiles) {
        throw StateError('O backup possui arquivos demais para restaurar.');
      }

      if (!_isSafeArchivePath(file.name)) {
        throw StateError('O backup contem caminhos internos invalidos.');
      }

      final int size = file.size;
      if (size > _maxArchiveFileBytes) {
        throw StateError('O backup contem um arquivo grande demais.');
      }

      totalUncompressedBytes += size;
      if (totalUncompressedBytes > _maxTotalUncompressedBytes) {
        throw StateError('O backup descompactado excede o limite seguro.');
      }
    }
  }

  bool _isSafeArchivePath(String archivePath) {
    final String normalized = archivePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains(':')) {
      return false;
    }

    return !normalized
        .split('/')
        .any((String segment) => segment.isEmpty || segment == '..');
  }

  String _safeArchiveFileName(String archivePath) {
    final String fileName = p.basename(archivePath.replaceAll('\\', '/'));
    final String sanitized = _sanitizeFileName(fileName);
    if (sanitized.isEmpty) {
      throw StateError('O backup contem um nome de arquivo invalido.');
    }
    return sanitized;
  }
}

class _ArchivedBookRecord {
  const _ArchivedBookRecord({
    required this.entry,
    required this.archivedAssetPaths,
    required this.archivedCoverPath,
  });

  final LibraryEntry entry;
  final List<String> archivedAssetPaths;
  final String? archivedCoverPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entry': entry.toJson(),
      'archivedAssetPaths': archivedAssetPaths,
      'archivedCoverPath': archivedCoverPath,
    };
  }
}
