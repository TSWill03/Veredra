// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../models/generated_chapter.dart';
import '../../models/library_entry.dart';

class BookAssetPackage {
  const BookAssetPackage({
    required this.bookId,
    required this.checksumSha256,
    required this.bytes,
    required this.chapterCount,
  });

  final String bookId;
  final String checksumSha256;
  final Uint8List bytes;
  final int chapterCount;
}

class DecodedBookAssetPackage {
  const DecodedBookAssetPackage({
    required this.entry,
    required this.chapters,
    required this.checksumSha256,
  });

  final LibraryEntry entry;
  final List<GeneratedChapter> chapters;
  final String checksumSha256;
}

class BookAssetPackageCodec {
  const BookAssetPackageCodec._();

  static const int maxPackageBytes = 100 * 1024 * 1024;
  static const int maxChapterCount = 5000;
  static const int maxChapterBytes = 16 * 1024 * 1024;

  static BookAssetPackage encode({
    required LibraryEntry entry,
    required List<GeneratedChapter> chapters,
  }) {
    if (chapters.isEmpty) {
      throw StateError('O livro nao possui capitulos para sincronizar.');
    }
    if (chapters.length > maxChapterCount) {
      throw StateError(
        'O livro excede o limite de $maxChapterCount capitulos sincronizaveis.',
      );
    }

    final Archive archive = Archive();
    final List<Map<String, dynamic>> manifestChapters = <Map<String, dynamic>>[];
    for (int index = 0; index < chapters.length; index++) {
      final GeneratedChapter chapter = chapters[index];
      final List<int> contentBytes = utf8.encode(chapter.content);
      if (contentBytes.length > maxChapterBytes) {
        throw StateError(
          'O capitulo ${chapter.title} excede o limite seguro de 16 MB.',
        );
      }
      final String fileName =
          'chapters/${(index + 1).toString().padLeft(6, '0')}.txt';
      archive.addFile(
        ArchiveFile(fileName, contentBytes.length, contentBytes),
      );
      manifestChapters.add(<String, dynamic>{
        'index': index,
        'title': chapter.title,
        'path': fileName,
        'sizeBytes': contentBytes.length,
      });
    }

    final Map<String, dynamic> manifest = <String, dynamic>{
      'format': 'veredra-book-package',
      'version': 1,
      'bookId': entry.id,
      'entry': entry.toJson(),
      'chapters': manifestChapters,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    final List<int> manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final List<int>? encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Nao foi possivel gerar o pacote do livro.');
    }
    if (encoded.length > maxPackageBytes) {
      throw StateError('O pacote do livro excede o limite remoto de 100 MB.');
    }
    final Uint8List bytes = Uint8List.fromList(encoded);
    return BookAssetPackage(
      bookId: entry.id,
      checksumSha256: sha256.convert(bytes).toString(),
      bytes: bytes,
      chapterCount: chapters.length,
    );
  }

  static DecodedBookAssetPackage decode(
    Uint8List bytes, {
    String? expectedChecksum,
  }) {
    if (bytes.isEmpty || bytes.length > maxPackageBytes) {
      throw StateError('O pacote remoto possui tamanho invalido.');
    }
    final String checksum = sha256.convert(bytes).toString();
    if (expectedChecksum != null && checksum != expectedChecksum) {
      throw StateError('A verificacao SHA-256 do livro remoto falhou.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw StateError('O pacote remoto do livro esta corrompido.');
    }
    final ArchiveFile? manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null || !manifestFile.isFile) {
      throw StateError('O pacote remoto nao possui manifesto.');
    }
    final dynamic decoded = jsonDecode(
      utf8.decode(_bytesOf(manifestFile), allowMalformed: false),
    );
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'veredra-book-package' ||
        decoded['version'] != 1) {
      throw StateError('O manifesto remoto do livro e invalido.');
    }

    final LibraryEntry entry = LibraryEntry.fromJson(
      decoded['entry'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final List<GeneratedChapter> chapters = <GeneratedChapter>[];
    final List<dynamic> manifestChapters =
        decoded['chapters'] as List<dynamic>? ?? const <dynamic>[];
    if (manifestChapters.isEmpty || manifestChapters.length > maxChapterCount) {
      throw StateError('A quantidade de capitulos do pacote e invalida.');
    }

    for (final Map<String, dynamic> chapterJson
        in manifestChapters.whereType<Map<String, dynamic>>()) {
      final String path = chapterJson['path'] as String? ?? '';
      if (!_isSafeChapterPath(path)) {
        throw StateError('O pacote contem um caminho de capitulo inseguro.');
      }
      final ArchiveFile? chapterFile = archive.findFile(path);
      if (chapterFile == null || !chapterFile.isFile) {
        throw StateError('Um capitulo listado no manifesto esta ausente.');
      }
      if (chapterFile.size > maxChapterBytes) {
        throw StateError('Um capitulo remoto excede o limite seguro.');
      }
      chapters.add(
        GeneratedChapter(
          title: chapterJson['title'] as String? ?? 'Capitulo',
          content: utf8.decode(_bytesOf(chapterFile), allowMalformed: true),
        ),
      );
    }
    if (chapters.length != manifestChapters.length) {
      throw StateError('O manifesto possui capitulos invalidos.');
    }

    return DecodedBookAssetPackage(
      entry: entry,
      chapters: chapters,
      checksumSha256: checksum,
    );
  }

  static bool _isSafeChapterPath(String path) {
    return path.startsWith('chapters/') &&
        !path.startsWith('/') &&
        !path.contains('\\') &&
        !path.contains(':') &&
        !path.split('/').contains('..');
  }

  static Uint8List _bytesOf(ArchiveFile file) {
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
    throw StateError('O pacote contem um arquivo ilegivel.');
  }
}
