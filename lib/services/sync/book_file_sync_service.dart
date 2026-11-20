// Signature: dev.tswicolly03
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../models/book.dart';
import '../../models/book_reference.dart';
import '../../models/generated_chapter.dart';
import '../../models/library_entry.dart';
import '../book_service.dart';
import '../library_service.dart';
import '../storage/app_storage.dart';
import 'book_file_platform.dart';
import 'book_file_remote_gateway.dart';

class BookFileSyncReport {
  const BookFileSyncReport({
    required this.uploaded,
    required this.downloaded,
    required this.checked,
    required this.errors,
  });

  final int uploaded;
  final int downloaded;
  final int checked;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

class _BookBundle {
  const _BookBundle(this.bytes, this.checksum);
  final Uint8List bytes;
  final String checksum;
}

/// Transfers private, integrity-checked book archives. Metadata sync runs first.
///
/// EPUB/TXT uploads contain readable chapters and an optional cover; they do
/// not claim to preserve the original EPUB. PDF uploads preserve the PDF bytes.
/// Never overwrite a locally readable book when versions diverge.
class BookFileSyncService {
  BookFileSyncService({
    required this.profileId,
    required this.libraryService,
    required this.bookService,
    required this.remote,
    AppStorage? storage,
  }) : _storage = storage ?? createAppStorage();

  static const int maxBundleBytes = 95 * 1024 * 1024;
  static const int maxUncompressedBytes = 128 * 1024 * 1024;
  static const int maxChapterBytes = 16 * 1024 * 1024;
  static const int maxChapters = 5000;
  static const String _virtualPrefix = 'veredra://';

  final String profileId;
  final LibraryService libraryService;
  final BookService bookService;
  final BookFileRemoteGateway remote;
  final AppStorage _storage;

  Future<BookFileSyncReport> synchronize({
    required String userId,
    required String deviceId,
    void Function(String stage, int done, int total)? onProgress,
  }) async {
    final List<RemoteBookAsset> assets =
        await remote.listAssets(userId: userId);
    final Map<String, RemoteBookAsset> byBookId = <String, RemoteBookAsset>{
      for (final RemoteBookAsset asset in assets) asset.bookId: asset,
    };
    final List<LibraryEntry> entries = await libraryService.loadEntries();
    final Map<String, dynamic> state = await _loadState(userId);
    final List<String> errors = <String>[];
    int uploaded = 0;
    int downloaded = 0;
    int checked = 0;

    for (final LibraryEntry entry in entries) {
      checked++;
      onProgress?.call('Sincronizando livros', checked, entries.length);
      try {
        final RemoteBookAsset? asset = byBookId[entry.id];
        final bool localAvailable =
            await bookService.isBookReferenceAvailable(entry.reference);

        // A PDF can be backed up from native apps; Web has no PDF reader.
        if (kIsWeb && entry.reference.isPdf) {
          continue;
        }

        if (asset == null) {
          if (!localAvailable) continue; // Remote metadata-only placeholder.
          final _BookBundle bundle = await _buildBundle(entry);
          await remote.upload(
            userId: userId,
            deviceId: deviceId,
            bookId: entry.id,
            bytes: bundle.bytes,
            checksum: bundle.checksum,
          );
          state[entry.id] = bundle.checksum;
          uploaded++;
          await _saveState(userId, state);
          continue;
        }

        if (asset.sizeBytes > maxBundleBytes || asset.sizeBytes < 1) {
          throw StateError('O arquivo remoto ultrapassa o limite seguro.');
        }

        if (!localAvailable) {
          final Uint8List bytes = await remote.download(asset);
          _checkDownload(bytes, asset);
          await _restoreBundle(entry, bytes);
          state[entry.id] = asset.checksum;
          downloaded++;
          await _saveState(userId, state);
          continue;
        }

        // Detect changes on both ends, but never silently replace a book.
        final _BookBundle localBundle = await _buildBundle(entry);
        if (localBundle.checksum == asset.checksum) {
          if (state[entry.id] != asset.checksum) {
            state[entry.id] = asset.checksum;
            await _saveState(userId, state);
          }
        } else if (state[entry.id] == asset.checksum) {
          // Remote version is the last known version; only local changed.
          await remote.upload(
            userId: userId,
            deviceId: deviceId,
            bookId: entry.id,
            bytes: localBundle.bytes,
            checksum: localBundle.checksum,
          );
          state[entry.id] = localBundle.checksum;
          uploaded++;
          await _saveState(userId, state);
        } else {
          errors.add(
            'Conteudo divergente em "${entry.title}". '
            'Nenhuma versao foi sobrescrita.',
          );
        }
      } on StateError catch (error) {
        // Only known safe messages are displayed; no paths, chapters or
        // raw server responses are surfaced to the user.
        const Set<String> safeReasons = <String>{
          'Livro excede o limite de sincronizacao.',
          'O pacote excede 95 MB apos compactacao.',
          'Um capitulo excede o limite seguro.',
          'Numero de capitulos invalido.',
          'PDF sem arquivo local.',
          'PDF indisponivel no dispositivo.',
          'O arquivo remoto ultrapassa o limite seguro.',
          'Checksum ou tamanho incorreto no download.',
        };
        final String detail = error.message.toString();
        final String reason = safeReasons.contains(detail)
            ? detail
            : 'O pacote ou os arquivos locais precisam de verificacao.';
        errors.add(
          'Nao foi possivel transferir "${entry.title}": $reason '
          'O arquivo local foi preservado.',
        );
      } catch (_) {
        // Keep local data and continue with the next book. Diagnostics must
        // never contain chapters or raw cloud storage responses.
        errors.add(
          'Nao foi possivel transferir "${entry.title}". '
          'O arquivo local foi preservado.',
        );
      }
    }
    return BookFileSyncReport(
      uploaded: uploaded,
      downloaded: downloaded,
      checked: checked,
      errors: errors,
    );
  }

  Future<_BookBundle> _buildBundle(LibraryEntry entry) async {
    final Archive archive = Archive();
    final Map<String, dynamic> manifest = <String, dynamic>{
      'schema': 1,
      'bookId': entry.id,
      'format': entry.reference.format.name,
    };
    int sourceSize = 0;

    void addFile(String name, Uint8List bytes) {
      sourceSize += bytes.length;
      if (sourceSize > maxUncompressedBytes) {
        throw StateError('Livro excede o limite de sincronizacao.');
      }
      final ArchiveFile file = ArchiveFile(name, bytes.length, bytes);
      file.lastModTime = 0;
      archive.addFile(file);
    }

    if (entry.reference.isPdf) {
      final String? pdfPath = entry.reference.primaryAssetPath;
      if (pdfPath == null) {
        throw StateError('PDF sem arquivo local.');
      }
      final Uint8List? pdf = await _readAssetBytes(pdfPath);
      if (pdf == null || pdf.isEmpty) {
        throw StateError('PDF indisponivel no dispositivo.');
      }
      addFile('book.pdf', pdf);
      manifest['pdf'] = 'book.pdf';
    } else {
      final Book book = await bookService.reopenBook(entry.reference);
      final List<GeneratedChapter> chapters =
          await bookService.exportBookChapters(book);
      if (chapters.isEmpty || chapters.length > maxChapters) {
        throw StateError('Numero de capitulos invalido.');
      }
      final List<Map<String, String>> chapterIndex = <Map<String, String>>[];
      final Map<String, String> storedContentByHash = <String, String>{};
      bool hasRepeatedContent = false;
      final List<String>? originalTitles = await _syncedChapterTitles(entry.id);
      for (int i = 0; i < chapters.length; i++) {
        final String name = 'chapters/${i.toString().padLeft(5, '0')}.txt';
        final Uint8List bytes =
            Uint8List.fromList(utf8.encode(chapters[i].content));
        if (bytes.length > maxChapterBytes) {
          throw StateError('Um capitulo excede o limite seguro.');
        }
        // Repeated content is referenced, not stored hundreds of times.
        // Chapter titles and order remain independently represented.
        final String checksum = sha256.convert(bytes).toString();
        final String? earlierPath = storedContentByHash[checksum];
        if (earlierPath == null) {
          addFile(name, bytes);
          storedContentByHash[checksum] = name;
        } else {
          hasRepeatedContent = true;
        }
        chapterIndex.add(<String, String>{
          'path': earlierPath ?? name,
          'title':
              originalTitles != null && originalTitles.length == chapters.length
                  ? originalTitles[i]
                  : chapters[i].title,
        });
      }
      manifest['chapters'] = chapterIndex;
      if (hasRepeatedContent) {
        // Schema 2 permits multiple chapters to refer to one earlier file.
        // Schema 1 stays byte-compatible with already uploaded books.
        manifest['schema'] = 2;
      }
    }

    final String? coverPath = entry.reference.coverPath;
    if (coverPath != null && coverPath.isNotEmpty) {
      final Uint8List? cover = await _readAssetBytes(coverPath);
      if (cover != null &&
          cover.isNotEmpty &&
          cover.length <= 20 * 1024 * 1024) {
        // Cover files are normalized to .png on download; non-PNG source
        // bytes are kept in their native format with an explicit extension.
        final String? suffix = _imageSuffix(cover);
        if (suffix != null) {
          final String name = 'cover.$suffix';
          addFile(name, cover);
          manifest['cover'] = name;
        }
      }
    }
    addFile(
      'manifest.json',
      Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
    );
    final List<int>? encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty || encoded.length > maxBundleBytes) {
      throw StateError('O pacote excede 95 MB apos compactacao.');
    }
    final Uint8List bytes = Uint8List.fromList(encoded);
    return _BookBundle(bytes, sha256.convert(bytes).toString());
  }

  Future<void> _restoreBundle(LibraryEntry entry, Uint8List bytes) async {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final Map<String, ArchiveFile> files = <String, ArchiveFile>{};
    int extractedSize = 0;
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile || files.containsKey(file.name)) {
        throw StateError('Pacote de livro invalido.');
      }
      extractedSize += file.size;
      if (extractedSize > maxUncompressedBytes) {
        throw StateError('Pacote expandido ultrapassa o limite seguro.');
      }
      files[file.name] = file;
    }
    final ArchiveFile? manifestFile = files['manifest.json'];
    if (manifestFile == null || manifestFile.size > 2 * 1024 * 1024) {
      throw StateError('Manifesto ausente ou invalido.');
    }
    final dynamic decoded = jsonDecode(utf8.decode(_contents(manifestFile)));
    if (decoded is! Map<String, dynamic> ||
        (decoded['schema'] != 1 && decoded['schema'] != 2) ||
        decoded['bookId'] != entry.id ||
        decoded['format'] != entry.reference.format.name) {
      throw StateError('Manifesto incompatível com o livro.');
    }
    final String folder = sha256.convert(utf8.encode(entry.id)).toString();
    final String root = 'profiles/$profileId/storage/synced_books/$folder';
    final List<String> paths = <String>[];
    final List<String> originalChapterTitles = <String>[];
    final String? pdf = decoded['pdf'] as String?;
    if (entry.reference.isPdf) {
      if (pdf != 'book.pdf' || files[pdf] == null) {
        throw StateError('PDF ausente do pacote.');
      }
      paths.add(await storeSyncedBinary(
          '$root/book.pdf', Uint8List.fromList(_contents(files[pdf]!))));
    } else {
      final dynamic rawChapters = decoded['chapters'];
      if (rawChapters is! List<dynamic> ||
          rawChapters.isEmpty ||
          rawChapters.length > maxChapters) {
        throw StateError('Indice de capitulos invalido.');
      }
      final Set<String> restoredFiles = <String>{};
      for (int i = 0; i < rawChapters.length; i++) {
        final dynamic raw = rawChapters[i];
        if (raw is! Map<String, dynamic>) {
          throw StateError('Pacote com capitulos incompletos.');
        }
        final String? fileName = raw['path'] as String?;
        final String expectedName =
            'chapters/${i.toString().padLeft(5, '0')}.txt';
        final int? sourceIndex = fileName != null &&
                RegExp(r'^chapters/[0-9]{5}\.txt$').hasMatch(fileName)
            ? int.tryParse(fileName.substring(9, 14))
            : null;
        if (fileName == null ||
            (decoded['schema'] == 1 && fileName != expectedName) ||
            (decoded['schema'] == 2 &&
                (sourceIndex == null || sourceIndex > i)) ||
            files[fileName] == null ||
            files[fileName]!.size > maxChapterBytes) {
          throw StateError('Pacote com capitulos incompletos.');
        }
        final String title = (raw['title'] as String? ?? '').trim();
        if (title.isEmpty || title.length > 400) {
          throw StateError('Titulo de capitulo invalido.');
        }
        originalChapterTitles.add(title);
        // Store each unique payload once; preserve repeated chapter references.
        final String key = '$root/$fileName';
        if (restoredFiles.add(fileName)) {
          await _storage.writeString(
            key,
            utf8.decode(_contents(files[fileName]!)),
          );
        }
        paths.add('$_virtualPrefix$key');
      }
    }

    String? coverPath;
    final String? coverName = decoded['cover'] as String?;
    if (coverName != null) {
      if (!const <String>['cover.png', 'cover.jpg', 'cover.webp']
              .contains(coverName) ||
          files[coverName] == null ||
          files[coverName]!.size > 20 * 1024 * 1024) {
        throw StateError('Capa do pacote invalida.');
      }
      coverPath = await storeSyncedBinary(
        '$root/$coverName',
        Uint8List.fromList(_contents(files[coverName]!)),
      );
    }

    if (originalChapterTitles.isNotEmpty) {
      await _storage.writeString(
        '$root/chapter_titles.json',
        jsonEncode(originalChapterTitles),
      );
    }
    // Commit library references only after all assets are safely persisted.
    final List<LibraryEntry> all = await libraryService.loadEntries();
    final int index = all.indexWhere((item) => item.id == entry.id);
    if (index < 0) return;
    final Map<String, dynamic> reference = all[index].reference.toJson()
      ..['directoryPath'] = null
      ..['sourceLabel'] = 'Conteudo sincronizado'
      ..['assetPaths'] = paths
      ..['coverPath'] = coverPath
      ..['syncedBookId'] = entry.id;
    all[index] = all[index].copyWith(
      reference: BookReference.fromJson(reference),
      chapterCount: entry.reference.isPdf ? 0 : paths.length,
    );
    await libraryService.replaceEntries(all);
  }

  Future<List<String>?> _syncedChapterTitles(String bookId) async {
    final String folder = sha256.convert(utf8.encode(bookId)).toString();
    final String key =
        'profiles/$profileId/storage/synced_books/$folder/chapter_titles.json';
    final String? raw = await _storage.readString(key);
    if (raw == null) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List<dynamic> &&
          decoded.every((value) => value is String)) {
        return decoded.cast<String>();
      }
    } catch (_) {
      // Invalid sidecar: reconstruct from local chapter names.
    }
    return null;
  }

  Future<Uint8List?> _readAssetBytes(String path) async {
    if (path.startsWith(_virtualPrefix)) {
      final String key = normalizeStorageKey(
        path.substring(_virtualPrefix.length),
      );
      return _storage.readBytes(key);
    }
    return readPhysicalBookAsset(path);
  }

  void _checkDownload(Uint8List bytes, RemoteBookAsset asset) {
    if (bytes.isEmpty ||
        bytes.length != asset.sizeBytes ||
        bytes.length > maxBundleBytes ||
        sha256.convert(bytes).toString() != asset.checksum) {
      throw StateError('Checksum ou tamanho incorreto no download.');
    }
  }

  List<int> _contents(ArchiveFile file) {
    final dynamic content = file.content;
    if (content is List<int>) return content;
    throw StateError('Conteudo do pacote invalido.');
  }

  String? _imageSuffix(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    return null;
  }

  String _stateKey(String userId) =>
      'profiles/$profileId/sync/book_checksums/$userId.json';

  Future<Map<String, dynamic>> _loadState(String userId) async {
    final String? raw = await _storage.readString(_stateKey(userId));
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final dynamic data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveState(String userId, Map<String, dynamic> state) =>
      _storage.writeString(_stateKey(userId), jsonEncode(state));
}
