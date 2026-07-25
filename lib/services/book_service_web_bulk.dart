// Signature: dev.tswicolly03
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../models/book_format.dart';
import '../models/book_reference.dart';
import '../models/chapter.dart';
import '../models/generated_chapter.dart';
import 'book_service_web.dart' as legacy;
import 'import/text_archive_parser.dart';
import 'storage/app_storage.dart';

export 'book_service_web.dart' show ImportKind, ImportOption;

/// Web-specific extension of the existing service.
///
/// `ImportKind.textFolder` continues to mean a real directory on desktop. In
/// the browser it is presented as a ZIP of chapter files, which works on
/// desktop browsers, installed PWA and iPhone without selecting thousands of
/// files one by one.
class BookService extends legacy.BookService {
  static const String _webStoredPrefix = 'veredra://';

  final AppStorage _bulkStorage = createAppStorage();
  String _bulkProfileId = 'principal';

  @override
  void configureProfile(String profileId) {
    super.configureProfile(profileId);
    _bulkProfileId = profileId;
  }

  @override
  bool get supportsDirectoryImport => true;

  @override
  List<legacy.ImportOption> getImportOptions() {
    return <legacy.ImportOption>[
      const legacy.ImportOption(
        kind: legacy.ImportKind.textFolder,
        label: 'ZIP de capitulos',
        description:
            'Importa milhares de TXT, Markdown ou HTML como um unico livro.',
      ),
      ...super.getImportOptions(),
    ];
  }

  @override
  Future<Book?> importBook(legacy.ImportKind kind) {
    if (kind == legacy.ImportKind.textFolder) {
      return _pickTextArchiveAndLoad();
    }
    return super.importBook(kind);
  }

  Future<Book?> _pickTextArchiveAndLoad() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_zipTypeGroup],
      confirmButtonText: 'Importar ZIP',
    );
    if (file == null) {
      return null;
    }

    final TextArchiveImportResult parsed = TextArchiveParser.parse(
      await file.readAsBytes(),
      sourceName: file.name,
    );
    return _persistParsedArchive(parsed, sourceName: file.name);
  }

  Future<Book> _persistParsedArchive(
    TextArchiveImportResult parsed, {
    required String sourceName,
  }) async {
    final String importId = _stableHash(
      '$sourceName|${parsed.chapters.length}|${parsed.totalUncompressedBytes}|'
      '${parsed.chapters.first.title}|${parsed.chapters.last.title}',
    );
    final String rootKey = normalizeStorageKey(
      'profiles/$_bulkProfileId/storage/imported_text_archives/$importId',
    );
    final List<String> chapterPaths = <String>[];

    try {
      for (int index = 0; index < parsed.chapters.length; index++) {
        final GeneratedChapter chapter = parsed.chapters[index];
        final String safeTitle = _sanitizeFileName(chapter.title);
        final String fileName = '${index + 1} - $safeTitle.txt';
        final String key = normalizeStorageKey('$rootKey/$fileName');
        await _bulkStorage.writeString(key, chapter.content.trim());
        chapterPaths.add('$_webStoredPrefix$key');

        if ((index + 1) % 50 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } on Object {
      await _bulkStorage.deletePrefix(rootKey);
      rethrow;
    }

    final BookReference reference = BookReference(
      title: parsed.title,
      format: BookFormat.text,
      sourceLabel:
          'ZIP importado no navegador - ${parsed.chapters.length} capitulos',
      tags: const <String>['zip', 'importacao em lote'],
      assetPaths: chapterPaths,
    );
    final List<Chapter> chapters = <Chapter>[
      for (int index = 0; index < parsed.chapters.length; index++)
        Chapter(
          index: index,
          sortNumber: _extractSortNumber(parsed.chapters[index].title) ?? index,
          title: parsed.chapters[index].title,
          fileName: p.basename(chapterPaths[index]),
          path: chapterPaths[index],
        ),
    ];

    return Book(
      id: 'text:$importId',
      title: parsed.title,
      reference: reference,
      chapters: chapters,
    );
  }

  int? _extractSortNumber(String value) {
    final Match? match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  String _sanitizeFileName(String value) {
    final String sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.isEmpty ? 'Capitulo' : sanitized;
  }

  String _stableHash(String input) {
    int hash = 2166136261;
    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  XTypeGroup get _zipTypeGroup {
    return const XTypeGroup(
      label: 'ZIP de capitulos',
      extensions: <String>['zip'],
      mimeTypes: <String>[
        'application/zip',
        'application/x-zip-compressed',
      ],
    );
  }
}
