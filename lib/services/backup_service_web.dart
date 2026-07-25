// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
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
import 'storage/app_storage.dart';
import 'web_download.dart';

class BackupService {
  static const int _maxBackupBytes = 256 * 1024 * 1024;
  static const int _maxArchiveFiles = 20000;
  static const int _maxArchiveFileBytes = 100 * 1024 * 1024;
  static const int _maxTotalUncompressedBytes = 512 * 1024 * 1024;
  static const String _webStoredPrefix = 'veredra://';

  BackupService({
    required this.profileService,
    required this.libraryService,
    required this.progressService,
    required this.bookmarkService,
    required this.annotationService,
    required this.readingStatsService,
    AppStorage? storage,
  }) : _storage = storage ?? createAppStorage();

  final ProfileService profileService;
  final LibraryService libraryService;
  final ProgressService progressService;
  final BookmarkService bookmarkService;
  final AnnotationService annotationService;
  final ReadingStatsService readingStatsService;
  final AppStorage _storage;

  Future<String?> exportCurrentProfile(AppProfile profile) async {
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
      snapshotBooks.add((await _archiveBook(entry, archive)).toJson());
    }

    final Map<String, dynamic> snapshot = <String, dynamic>{
      'formatVersion': 2,
      'platform': 'web',
      'profile': profile.toJson(),
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
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
    if (encoded.length > _maxBackupBytes) {
      throw StateError('O backup excede o tamanho maximo seguro de 256 MB.');
    }

    final String fileName = '${_sanitizeFileName(profile.name)}.twrbackup';
    downloadBytesInBrowser(
      bytes: Uint8List.fromList(encoded),
      fileName: fileName,
      mimeType: 'application/zip',
    );
    return fileName;
  }

  Future<AppProfile?> importProfileBackup() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'Backup do Veredra',
          extensions: <String>['twrbackup', 'zip'],
          mimeTypes: <String>['application/zip'],
        ),
      ],
      confirmButtonText: 'Importar backup',
    );
    if (file == null) {
      return null;
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length > _maxBackupBytes) {
      throw StateError('O backup selecionado excede o tamanho maximo seguro.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw StateError('O arquivo nao parece ser um backup ZIP valido.');
    }
    _validateArchive(archive);

    final ArchiveFile? snapshotFile = archive.findFile('snapshot.json');
    if (snapshotFile == null || !snapshotFile.isFile) {
      throw StateError('O arquivo nao parece ser um backup do Veredra.');
    }
    final dynamic decoded = jsonDecode(
      utf8.decode(_archiveBytes(snapshotFile), allowMalformed: false),
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
    final String stagingPrefix = normalizeStorageKey(
      'profiles/${importedProfile.id}/storage/restored',
    );

    libraryService.configureProfile(importedProfile.id);
    progressService.configureProfile(importedProfile.id);
    bookmarkService.configureProfile(importedProfile.id);
    annotationService.configureProfile(importedProfile.id);
    readingStatsService.configureProfile(importedProfile.id);

    try {
      final List<LibraryEntry> importedEntries = <LibraryEntry>[];
      for (final Map<String, dynamic> bookJson
          in (decoded['books'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()) {
        importedEntries.add(
          await _restoreBook(bookJson, archive, importedProfile),
        );
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
        final LibraryEntry? match = importedEntries.cast<LibraryEntry?>().firstWhere(
              (LibraryEntry? entry) =>
                  _sameBookReference(entry?.reference, previousLastBook),
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
    } on Object {
      await _storage.deletePrefix(stagingPrefix);
      rethrow;
    }
  }

  Future<_ArchivedBookRecord> _archiveBook(
    LibraryEntry entry,
    Archive archive,
  ) async {
    final List<String> archivedAssets = <String>[];
    final String bookRoot = 'books/${entry.id}';

    for (int index = 0; index < entry.reference.assetPaths.length; index++) {
      final String assetPath = entry.reference.assetPaths[index];
      final Uint8List? bytes = await _readStoredAsset(assetPath);
      if (bytes == null) {
        continue;
      }
      if (bytes.length > _maxArchiveFileBytes) {
        throw StateError('Um arquivo do backup excede o limite seguro.');
      }
      final String targetPath =
          '$bookRoot/assets/$index-${_safeArchiveFileName(assetPath)}';
      archive.addFile(ArchiveFile(targetPath, bytes.length, bytes));
      archivedAssets.add(targetPath);
    }

    String? archivedCoverPath;
    final String? coverPath = entry.reference.coverPath;
    if (coverPath != null) {
      final Uint8List? coverBytes = await _readStoredAsset(coverPath);
      if (coverBytes != null) {
        archivedCoverPath =
            '$bookRoot/cover${p.extension(_safeArchiveFileName(coverPath))}';
        archive.addFile(
          ArchiveFile(archivedCoverPath, coverBytes.length, coverBytes),
        );
      }
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
    final String bookRoot = normalizeStorageKey(
      'profiles/${profile.id}/storage/restored/assets/${entry.id}',
    );

    final List<String> restoredAssetPaths = <String>[];
    if (entry.reference.usesDirectory) {
      for (final ArchiveFile archiveFile in archive.files) {
        if (!archiveFile.isFile ||
            !archiveFile.name.startsWith('books/${entry.id}/directory/')) {
          continue;
        }
        final String fileName = _safeArchiveFileName(archiveFile.name);
        final String key = normalizeStorageKey('$bookRoot/$fileName');
        await _writeRestoredAsset(key, archiveFile);
        restoredAssetPaths.add('$_webStoredPrefix$key');
      }
    } else {
      for (final String archivePath in archivedAssetPaths) {
        final ArchiveFile? archiveFile = archive.findFile(archivePath);
        if (archiveFile == null || !archiveFile.isFile) {
          continue;
        }
        final String fileName = _safeArchiveFileName(archivePath);
        final String key = normalizeStorageKey('$bookRoot/$fileName');
        await _writeRestoredAsset(key, archiveFile);
        restoredAssetPaths.add('$_webStoredPrefix$key');
      }
    }

    BookReference reference = entry.reference.copyWith(
      directoryPath: '',
      assetPaths: restoredAssetPaths,
    );
    if (archivedCoverPath != null) {
      final ArchiveFile? coverFile = archive.findFile(archivedCoverPath);
      if (coverFile != null && coverFile.isFile) {
        final String coverName = _safeArchiveFileName(archivedCoverPath);
        final String coverKey = normalizeStorageKey(
          'profiles/${profile.id}/storage/restored/covers/${entry.id}/$coverName',
        );
        await _storage.writeBytes(coverKey, _archiveBytes(coverFile));
        reference = reference.copyWith(coverPath: '$_webStoredPrefix$coverKey');
      }
    }
    return entry.copyWith(reference: reference);
  }

  Future<void> _writeRestoredAsset(String key, ArchiveFile file) async {
    final Uint8List bytes = _archiveBytes(file);
    final String extension = p.extension(file.name).toLowerCase();
    if (const <String>{'.txt', '.md', '.markdown', '.html', '.htm', '.xhtml'}
        .contains(extension)) {
      await _storage.writeString(key, utf8.decode(bytes, allowMalformed: true));
    } else {
      await _storage.writeBytes(key, bytes);
    }
  }

  Future<Uint8List?> _readStoredAsset(String path) async {
    if (!path.startsWith(_webStoredPrefix)) {
      return null;
    }
    final String key = normalizeStorageKey(
      path.replaceFirst(_webStoredPrefix, ''),
    );
    final Uint8List? bytes = await _storage.readBytes(key);
    if (bytes != null) {
      return bytes;
    }
    final String? text = await _storage.readString(key);
    return text == null ? null : Uint8List.fromList(utf8.encode(text));
  }

  Uint8List _archiveBytes(ArchiveFile file) {
    final Object? content = file.content;
    if (content is Uint8List) {
      return content;
    }
    if (content is List<int>) {
      return Uint8List.fromList(content);
    }
    if (content is List) {
      return Uint8List.fromList(content.whereType<int>().toList());
    }
    throw StateError('O backup contem um arquivo que nao pode ser lido.');
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
      if (file.size > _maxArchiveFileBytes) {
        throw StateError('O backup contem um arquivo grande demais.');
      }
      totalUncompressedBytes += file.size;
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

  String _sanitizeFileName(String value) {
    final String normalized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'Veredra' : normalized;
  }

  bool _sameBookReference(BookReference? a, BookReference? b) {
    if (a == null || b == null || a.format != b.format) {
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
