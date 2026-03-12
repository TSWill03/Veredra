// Signature: dev.tswicolly03
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:epubx/epubx.dart';
import 'package:file_selector/file_selector.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;
import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import '../models/book_format.dart';
import '../models/book_reference.dart';
import '../models/book_search_match.dart';
import '../models/chapter.dart';
import '../models/generated_chapter.dart';
import '../models/translation_language.dart';

enum ImportKind { textFolder, textFiles, epub, pdf }

class ImportOption {
  const ImportOption({
    required this.kind,
    required this.label,
    required this.description,
  });

  final ImportKind kind;
  final String label;
  final String description;
}

class BookService {
  static const int _maxCachedChapterContents = 24;

  final LinkedHashMap<String, String> _chapterContentCache =
      LinkedHashMap<String, String>();
  String _activeProfileId = 'principal';

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
    _chapterContentCache.clear();
  }

  bool get supportsDirectoryImport => !Platform.isIOS;

  List<ImportOption> getImportOptions() {
    final List<ImportOption> options = <ImportOption>[
      if (supportsDirectoryImport)
        const ImportOption(
          kind: ImportKind.textFolder,
          label: 'Pasta de texto',
          description: 'Importa capitulos .txt, .md e .html de uma pasta.',
        ),
      const ImportOption(
        kind: ImportKind.textFiles,
        label: 'Arquivos de texto',
        description: 'Importa um ou mais arquivos .txt, .md ou .html.',
      ),
      const ImportOption(
        kind: ImportKind.epub,
        label: 'EPUB',
        description:
            'Extrai capitulos do EPUB e converte para leitura continua.',
      ),
      const ImportOption(
        kind: ImportKind.pdf,
        label: 'PDF',
        description: 'Importa o documento para um viewer dedicado de PDF.',
      ),
    ];

    return List<ImportOption>.unmodifiable(options);
  }

  Future<Book?> importBook(ImportKind kind) async {
    switch (kind) {
      case ImportKind.textFolder:
        return _pickDirectoryAndLoad();
      case ImportKind.textFiles:
        return _pickTextFilesAndLoad();
      case ImportKind.epub:
        return _pickEpubAndLoad();
      case ImportKind.pdf:
        return _pickPdfAndLoad();
    }
  }

  Future<String?> pickAndStoreCustomCover({required String bookId}) async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_imageTypeGroup],
      confirmButtonText: 'Escolher capa',
    );
    if (file == null) {
      return null;
    }

    final Uint8List bytes = await file.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw StateError('Nao foi possivel ler a imagem selecionada.');
    }

    return _writeCoverImage(image, bookId);
  }

  Future<List<BookSearchMatch>> searchBookContent(
    Book book,
    String query, {
    int maxResults = 80,
  }) async {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || !book.usesTextReader) {
      return const <BookSearchMatch>[];
    }

    final List<BookSearchMatch> results = <BookSearchMatch>[];
    for (final Chapter chapter in book.chapters) {
      final String content = await readChapterContent(chapter);
      final String haystack = content.toLowerCase();
      final int firstMatchIndex = haystack.indexOf(normalizedQuery);
      if (firstMatchIndex < 0) {
        continue;
      }

      int matchCount = 0;
      int searchIndex = 0;
      while (true) {
        final int nextIndex = haystack.indexOf(normalizedQuery, searchIndex);
        if (nextIndex < 0) {
          break;
        }
        matchCount++;
        searchIndex = nextIndex + normalizedQuery.length;
      }

      results.add(
        BookSearchMatch(
          chapterIndex: chapter.index,
          chapterTitle: chapter.title,
          matchCount: matchCount,
          snippet:
              _buildSnippet(content, firstMatchIndex, normalizedQuery.length),
        ),
      );

      if (results.length >= maxResults) {
        break;
      }
    }

    return results;
  }

  Future<Book> reopenBook(BookReference reference) {
    if (reference.usesDirectory) {
      return loadBookFromDirectory(
        reference.directoryPath!,
        preferredCoverPath: reference.coverPath,
      ).then((Book book) => _applyPreferredReference(book, reference));
    }

    switch (reference.format) {
      case BookFormat.text:
      case BookFormat.epub:
        return loadTextBookFromFiles(
          reference.assetPaths,
          preferredTitle: reference.title,
          format: reference.format,
          sourceLabel: reference.sourceLabel,
          preferredCoverPath: reference.coverPath,
          copyToManagedStorage: false,
        ).then((Book book) => _applyPreferredReference(book, reference));
      case BookFormat.pdf:
        return loadPdfBook(
          reference.primaryAssetPath!,
          preferredTitle: reference.title,
          preferredCoverPath: reference.coverPath,
          copyToManagedStorage: false,
        ).then((Book book) => _applyPreferredReference(book, reference));
    }
  }

  Future<Book?> _pickDirectoryAndLoad() async {
    if (!supportsDirectoryImport) {
      return null;
    }

    final String? folderPath = await getDirectoryPath(
      confirmButtonText: 'Importar pasta',
    );
    if (folderPath == null) {
      return null;
    }

    return loadBookFromDirectory(folderPath);
  }

  Future<Book?> _pickTextFilesAndLoad() async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[_textTypeGroup],
      confirmButtonText: 'Importar arquivos',
    );
    if (files.isEmpty) {
      return null;
    }

    return loadTextBookFromFiles(
      files.map((XFile file) => file.path).toList(growable: false),
      sourceLabel: 'Arquivos importados',
      copyToManagedStorage: true,
    );
  }

  Future<Book?> _pickEpubAndLoad() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_epubTypeGroup],
      confirmButtonText: 'Importar EPUB',
    );
    if (file == null) {
      return null;
    }

    return loadEpubBook(file.path);
  }

  Future<Book?> _pickPdfAndLoad() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_pdfTypeGroup],
      confirmButtonText: 'Importar PDF',
    );
    if (file == null) {
      return null;
    }

    return loadPdfBook(file.path, copyToManagedStorage: true);
  }

  Book _applyPreferredReference(Book book, BookReference reference) {
    return book.copyWith(
      title: reference.title,
      reference: book.reference.copyWith(
        title: reference.title,
        coverPath: reference.coverPath ?? book.reference.coverPath,
        author: reference.author,
        description: reference.description,
        series: reference.series,
        volume: reference.volume,
        altTitle: reference.altTitle,
        coverZoom: reference.coverZoom,
        coverAlignmentX: reference.coverAlignmentX,
        coverAlignmentY: reference.coverAlignmentY,
        tags: reference.tags,
      ),
    );
  }

  Future<Book> loadBookFromDirectory(
    String folderPath, {
    String? preferredCoverPath,
  }) async {
    final Directory directory = Directory(folderPath);
    if (!await directory.exists()) {
      throw FileSystemException('A pasta selecionada nao existe.', folderPath);
    }

    final List<String> filePaths =
        (await directory.list(followLinks: false).toList())
            .whereType<File>()
            .map((File file) => file.path)
            .where(_isSupportedTextPath)
            .toList(growable: false);

    if (filePaths.isEmpty) {
      throw StateError(
        'Nenhum arquivo de texto suportado foi encontrado na pasta.',
      );
    }

    final String normalizedPath = p.normalize(folderPath);
    final String title = p.basename(normalizedPath);
    final String? coverPath =
        await _resolveExistingCoverPath(preferredCoverPath) ??
            await _findCoverInDirectory(normalizedPath);

    return _buildTextBook(
      title: title,
      format: BookFormat.text,
      reference: BookReference(
        title: title,
        format: BookFormat.text,
        sourceLabel: 'Pasta local',
        directoryPath: normalizedPath,
        coverPath: coverPath,
      ),
      filePaths: filePaths,
      id: normalizedPath,
    );
  }

  Future<Book> loadTextBookFromFiles(
    List<String> filePaths, {
    String? preferredTitle,
    required String sourceLabel,
    required bool copyToManagedStorage,
    String? preferredCoverPath,
    BookFormat format = BookFormat.text,
  }) async {
    final List<String> normalizedPaths =
        await _normalizeExistingPaths(filePaths);
    if (normalizedPaths.isEmpty) {
      throw StateError(
        'Nenhum arquivo de texto valido foi encontrado para importar.',
      );
    }

    final List<String> finalPaths = copyToManagedStorage
        ? await _copyFilesToManagedStorage(
            normalizedPaths,
            folderName: 'imported_text_books',
          )
        : normalizedPaths;
    final String title =
        (preferredTitle != null && preferredTitle.trim().isNotEmpty)
            ? preferredTitle.trim()
            : _inferTitleFromFiles(normalizedPaths);
    final String? coverPath =
        await _resolveExistingCoverPath(preferredCoverPath);

    final BookReference reference = BookReference(
      title: title,
      format: format,
      sourceLabel: sourceLabel,
      coverPath: coverPath,
      assetPaths: finalPaths,
    );

    return _buildTextBook(
      title: title,
      format: format,
      reference: reference,
      filePaths: finalPaths,
      id: _buildFileBookId(format, finalPaths),
    );
  }

  Future<Book> loadEpubBook(String sourcePath) async {
    final String normalizedPath = p.normalize(sourcePath);
    if (!await File(normalizedPath).exists()) {
      throw StateError('O arquivo EPUB selecionado nao existe.');
    }

    final List<int> bytes = await File(normalizedPath).readAsBytes();
    final EpubBookRef epubBookRef = await EpubReader.openBook(bytes);
    final EpubMetadata? metadata = epubBookRef.Schema?.Package?.Metadata;
    final String title = (epubBookRef.Title ?? '').trim().isEmpty
        ? p.basenameWithoutExtension(normalizedPath)
        : epubBookRef.Title!.trim();
    final List<GeneratedChapter> generatedChapters =
        await _readEpubGeneratedChapters(epubBookRef);

    if (generatedChapters.isEmpty) {
      throw StateError('Nao foi possivel extrair capitulos legiveis do EPUB.');
    }

    final String importId = _stableHash(normalizedPath);
    final List<String> chapterPaths = await _writeManagedChapters(
      baseFolderName: 'imported_epub_books',
      bookId: importId,
      chapters: generatedChapters,
    );
    final String? coverPath = await _extractEpubCover(epubBookRef, importId);
    final _EpubMetadataResult metadataResult = _extractEpubMetadata(metadata);
    final Book book = await loadTextBookFromFiles(
      chapterPaths,
      preferredTitle: title,
      sourceLabel: 'EPUB convertido',
      preferredCoverPath: coverPath,
      copyToManagedStorage: false,
      format: BookFormat.epub,
    );
    return _applyPreferredReference(
      book,
      BookReference(
        title: title,
        format: BookFormat.epub,
        sourceLabel: 'EPUB convertido',
        coverPath: coverPath,
        author: metadataResult.author,
        description: metadataResult.description,
        series: metadataResult.series,
        volume: metadataResult.volume,
        tags: metadataResult.tags,
        assetPaths: book.reference.assetPaths,
      ),
    );
  }

  Future<Book> loadPdfBook(
    String sourcePath, {
    String? preferredTitle,
    String? preferredCoverPath,
    required bool copyToManagedStorage,
  }) async {
    final String normalizedPath = p.normalize(sourcePath);
    if (!await File(normalizedPath).exists()) {
      throw StateError('O arquivo PDF selecionado nao existe.');
    }

    final String finalPath = copyToManagedStorage
        ? await _copySingleFileToManagedStorage(
            normalizedPath,
            folderName: 'imported_pdf_books',
          )
        : normalizedPath;

    final String title =
        (preferredTitle != null && preferredTitle.trim().isNotEmpty)
            ? preferredTitle.trim()
            : p.basenameWithoutExtension(normalizedPath);
    final String bookId = _buildFileBookId(BookFormat.pdf, <String>[finalPath]);
    final String? coverPath =
        await _resolveExistingCoverPath(preferredCoverPath) ??
            await _renderPdfCover(finalPath, bookId);

    final BookReference reference = BookReference(
      title: title,
      format: BookFormat.pdf,
      sourceLabel: 'PDF importado',
      coverPath: coverPath,
      assetPaths: <String>[finalPath],
    );

    return Book(
      id: bookId,
      title: title,
      reference: reference,
      chapters: const <Chapter>[],
    );
  }

  Future<List<GeneratedChapter>> exportBookChapters(Book book) async {
    if (!book.usesTextReader) {
      throw StateError('Este livro nao pode ser exportado como texto.');
    }

    final List<GeneratedChapter> chapters = <GeneratedChapter>[];
    for (final Chapter chapter in book.chapters) {
      chapters.add(
        GeneratedChapter(
          title: chapter.title,
          content: await readChapterContent(chapter),
        ),
      );
    }

    return chapters;
  }

  Future<Book> createTranslatedBook({
    required Book sourceBook,
    required String title,
    required List<GeneratedChapter> chapters,
    required TranslationLanguage sourceLanguage,
    required TranslationLanguage targetLanguage,
    String? translatedDescription,
  }) async {
    final String normalizedTitle = title.trim().isEmpty
        ? '${sourceBook.title} [${targetLanguage.label}]'
        : title.trim();
    final String translationId = _stableHash(
      '${sourceBook.id}|${sourceLanguage.code}|${targetLanguage.code}|${DateTime.now().microsecondsSinceEpoch}',
    );
    final List<String> chapterPaths = await _writeManagedChapters(
      baseFolderName: 'translated_books',
      bookId: translationId,
      chapters: chapters,
    );

    final Book book = await loadTextBookFromFiles(
      chapterPaths,
      preferredTitle: normalizedTitle,
      sourceLabel:
          'Traducao local ${sourceLanguage.label} -> ${targetLanguage.label}',
      preferredCoverPath: sourceBook.reference.coverPath,
      copyToManagedStorage: false,
      format: BookFormat.text,
    );

    final String? normalizedDescription =
        _normalizeOptionalText(translatedDescription) ??
            sourceBook.reference.description;
    final List<String> tags = <String>[
      ...sourceBook.reference.tags,
      'traducao',
      targetLanguage.label,
    ]
        .map((String value) => value.trim())
        .where((String value) {
          return value.isNotEmpty;
        })
        .toSet()
        .toList(growable: false);

    return _applyPreferredReference(
      book,
      BookReference(
        title: normalizedTitle,
        format: BookFormat.text,
        sourceLabel:
            'Traducao local ${sourceLanguage.label} -> ${targetLanguage.label}',
        coverPath: sourceBook.reference.coverPath,
        author: sourceBook.reference.author,
        description: normalizedDescription,
        series: sourceBook.reference.series,
        volume: sourceBook.reference.volume,
        altTitle: sourceBook.title,
        tags: tags,
        assetPaths: book.reference.assetPaths,
      ),
    );
  }

  Future<Book> _buildTextBook({
    required String title,
    required BookFormat format,
    required BookReference reference,
    required List<String> filePaths,
    required String id,
  }) async {
    final List<_ChapterCandidate> sortedCandidates = filePaths
        .map(
          (String path) => _ChapterCandidate(
            path: path,
            fileName: p.basename(path),
            title: _deriveChapterTitle(path),
            sortNumber: _extractSortNumber(p.basename(path)),
          ),
        )
        .toList()
      ..sort(_compareCandidates);

    final List<Chapter> chapters = <Chapter>[
      for (int i = 0; i < sortedCandidates.length; i++)
        Chapter(
          index: i,
          sortNumber: sortedCandidates[i].sortNumber ?? 1 << 30,
          title: sortedCandidates[i].title,
          fileName: sortedCandidates[i].fileName,
          path: sortedCandidates[i].path,
        ),
    ];

    return Book(
      id: id,
      title: title,
      reference: reference.copyWith(
        title: title,
        format: format,
        assetPaths: reference.assetPaths,
      ),
      chapters: chapters,
    );
  }

  Future<String> readChapterContent(Chapter chapter) async {
    final String cacheKey = p.normalize(chapter.path);
    final String? cached = _chapterContentCache.remove(cacheKey);
    if (cached != null) {
      _chapterContentCache[cacheKey] = cached;
      return cached;
    }

    final String extension = p.extension(chapter.path).toLowerCase();
    final String rawContent = await File(chapter.path).readAsString();
    late final String normalizedContent;

    switch (extension) {
      case '.md':
      case '.markdown':
        normalizedContent =
            _htmlToPlainText(markdown.markdownToHtml(rawContent));
        break;
      case '.html':
      case '.htm':
      case '.xhtml':
        normalizedContent = _htmlToPlainText(rawContent);
        break;
      default:
        normalizedContent = rawContent.replaceAll('\r\n', '\n').trimRight();
        break;
    }

    _chapterContentCache[cacheKey] = normalizedContent;
    _trimChapterCache();
    return normalizedContent;
  }

  void trimCachedChapters(Iterable<Chapter> keepChapters) {
    final Set<String> keepKeys = keepChapters
        .map((Chapter chapter) => p.normalize(chapter.path))
        .toSet();
    final List<String> removableKeys = _chapterContentCache.keys
        .where((String key) => !keepKeys.contains(key))
        .toList(growable: true);

    while (_chapterContentCache.length > _maxCachedChapterContents ~/ 2 &&
        removableKeys.isNotEmpty) {
      _chapterContentCache.remove(removableKeys.removeAt(0));
    }
  }

  Future<List<GeneratedChapter>> _readEpubGeneratedChapters(
    EpubBookRef epubBookRef,
  ) async {
    final List<GeneratedChapter> chapters = <GeneratedChapter>[];

    try {
      final List<EpubChapterRef> chapterRefs = await epubBookRef.getChapters();
      final List<EpubChapter> parsedChapters =
          await EpubReader.readChapters(chapterRefs);
      _flattenEpubChapters(parsedChapters, chapters);
    } catch (_) {
      // Se o TOC vier quebrado, fazemos fallback pelo spine.
    }

    final List<GeneratedChapter> filtered = _filterGeneratedChapters(chapters);
    if (filtered.length >= 2) {
      return filtered;
    }

    final List<GeneratedChapter> fallback =
        await _fallbackEpubChaptersFromSpine(epubBookRef);
    if (fallback.isNotEmpty) {
      return fallback;
    }

    return filtered;
  }

  Future<List<GeneratedChapter>> _fallbackEpubChaptersFromSpine(
    EpubBookRef epubBookRef,
  ) async {
    final Map<String, dynamic> htmlFiles =
        epubBookRef.Content?.Html ?? const <String, dynamic>{};
    if (htmlFiles.isEmpty) {
      return const <GeneratedChapter>[];
    }

    final Map<String, String> manifestById = <String, String>{
      for (final EpubManifestItem item
          in epubBookRef.Schema?.Package?.Manifest?.Items ??
              const <EpubManifestItem>[])
        if ((item.Id ?? '').isNotEmpty && (item.Href ?? '').isNotEmpty)
          item.Id!.toLowerCase(): item.Href!,
    };

    final List<String> orderedHrefs = <String>[];
    for (final EpubSpineItemRef spineItem
        in epubBookRef.Schema?.Package?.Spine?.Items ??
            const <EpubSpineItemRef>[]) {
      final String? href = manifestById[(spineItem.IdRef ?? '').toLowerCase()];
      if (href != null && href.isNotEmpty && !orderedHrefs.contains(href)) {
        orderedHrefs.add(href);
      }
    }

    for (final String key in htmlFiles.keys) {
      if (!orderedHrefs.contains(key)) {
        orderedHrefs.add(key);
      }
    }

    final List<GeneratedChapter> output = <GeneratedChapter>[];
    for (final String href in orderedHrefs) {
      final dynamic fileRef = _resolveHtmlFileRef(htmlFiles, href);
      if (fileRef == null) {
        continue;
      }

      final String html = await fileRef.readContentAsText();
      final String plainText = _htmlToPlainText(html);
      final String title = _extractTitleFromHtml(html, href);
      if (_shouldSkipEpubHtmlChapter(title, plainText, href)) {
        continue;
      }

      output.add(
        GeneratedChapter(
          title: title,
          content: plainText,
        ),
      );
    }

    return _filterGeneratedChapters(output);
  }

  dynamic _resolveHtmlFileRef(
    Map<String, dynamic> htmlFiles,
    String href,
  ) {
    if (htmlFiles.containsKey(href)) {
      return htmlFiles[href];
    }

    final String normalizedHref =
        p.normalize(href).replaceAll('\\', '/').toLowerCase();
    for (final MapEntry<String, dynamic> entry in htmlFiles.entries) {
      final String normalizedEntry =
          p.normalize(entry.key).replaceAll('\\', '/').toLowerCase();
      if (normalizedEntry == normalizedHref ||
          normalizedEntry.endsWith('/$normalizedHref')) {
        return entry.value;
      }
    }

    return null;
  }

  List<GeneratedChapter> _filterGeneratedChapters(
    List<GeneratedChapter> chapters,
  ) {
    final List<GeneratedChapter> filtered = chapters
        .where(
          (GeneratedChapter chapter) =>
              chapter.content.trim().isNotEmpty &&
              !_looksLikeBoilerplate(chapter.title, chapter.content),
        )
        .toList(growable: false);
    return filtered.isNotEmpty ? filtered : chapters;
  }

  _EpubMetadataResult _extractEpubMetadata(EpubMetadata? metadata) {
    final List<String> tags = (metadata?.Subjects ?? const <String>[])
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    String? series;
    String? volume;

    for (final dynamic metaItem in metadata?.MetaItems ?? const <dynamic>[]) {
      final String name =
          (metaItem.Name ?? metaItem.Property ?? '').trim().toLowerCase();
      final String content = (metaItem.Content ?? '').trim();
      if (content.isEmpty) {
        continue;
      }

      if (series == null &&
          (name.contains('calibre:series') ||
              name.contains('belongs-to-collection') ||
              name == 'series')) {
        series = content;
      }

      if (volume == null &&
          (name.contains('series_index') ||
              name.contains('group-position') ||
              name == 'volume')) {
        volume = content;
      }
    }

    return _EpubMetadataResult(
      author: _normalizeOptionalText(
        metadata?.Creators
            ?.map((dynamic creator) => creator.Creator?.trim() ?? '')
            .where((dynamic value) => (value as String).isNotEmpty)
            .cast<String>()
            .join(', '),
      ),
      description: _normalizeOptionalText(metadata?.Description),
      series: _normalizeOptionalText(series),
      volume: _normalizeOptionalText(volume),
      tags: tags,
    );
  }

  String _buildSnippet(String content, int startIndex, int queryLength) {
    final String normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final int safeStart = startIndex.clamp(0, normalized.length);
    final int snippetStart = (safeStart - 70).clamp(0, normalized.length);
    final int snippetEnd =
        (safeStart + queryLength + 120).clamp(0, normalized.length);
    final String snippet =
        normalized.substring(snippetStart, snippetEnd).trim();
    final String prefix = snippetStart > 0 ? '...' : '';
    final String suffix = snippetEnd < normalized.length ? '...' : '';
    return '$prefix$snippet$suffix';
  }

  String _deriveChapterTitle(String path) {
    final String fileTitle = p.basenameWithoutExtension(path).trim();
    return fileTitle.isEmpty
        ? p.basename(path)
        : _normalizeDisplayTitle(fileTitle);
  }

  Future<List<String>> _normalizeExistingPaths(List<String> paths) async {
    final List<String> normalizedPaths = <String>[];
    for (final String path in paths) {
      final String normalizedPath = p.normalize(path);
      if (await File(normalizedPath).exists() &&
          _isSupportedTextPath(normalizedPath)) {
        normalizedPaths.add(normalizedPath);
      }
    }
    return normalizedPaths;
  }

  Future<List<String>> _copyFilesToManagedStorage(
    List<String> sourcePaths, {
    required String folderName,
  }) async {
    final String importId = _stableHash(
      sourcePaths.map((String path) => p.normalize(path)).join('|'),
    );
    final Directory bookDirectory = Directory(
      p.join((await _profileStorageDirectory(folderName)).path, importId),
    );
    await bookDirectory.create(recursive: true);

    final Map<String, int> seenNames = <String, int>{};
    final List<String> copiedPaths = <String>[];

    for (final String sourcePath in sourcePaths) {
      final String originalName = p.basename(sourcePath);
      final int seenCount = (seenNames[originalName] ?? 0) + 1;
      seenNames[originalName] = seenCount;

      final String targetName = seenCount == 1
          ? originalName
          : '${p.basenameWithoutExtension(originalName)}__$seenCount${p.extension(originalName)}';
      final String targetPath = p.join(bookDirectory.path, targetName);
      final File targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final File copiedFile = await File(sourcePath).copy(targetPath);
      copiedPaths.add(copiedFile.path);
    }

    return copiedPaths;
  }

  Future<String> _copySingleFileToManagedStorage(
    String sourcePath, {
    required String folderName,
  }) async {
    final List<String> copied = await _copyFilesToManagedStorage(
      <String>[sourcePath],
      folderName: folderName,
    );
    return copied.first;
  }

  Future<List<String>> _writeManagedChapters({
    required String baseFolderName,
    required String bookId,
    required List<GeneratedChapter> chapters,
  }) async {
    final Directory bookDirectory = Directory(
      p.join((await _profileStorageDirectory(baseFolderName)).path, bookId),
    );
    await bookDirectory.create(recursive: true);

    final List<String> chapterPaths = <String>[];
    for (int index = 0; index < chapters.length; index++) {
      final String safeTitle = _sanitizeFileName(chapters[index].title);
      final String fileName = '${index + 1} - $safeTitle.txt';
      final File file = File(p.join(bookDirectory.path, fileName));
      await file.writeAsString(
        chapters[index].content.trim(),
        flush: true,
      );
      chapterPaths.add(file.path);
    }

    return chapterPaths;
  }

  Future<String?> _extractEpubCover(
      EpubBookRef epubBookRef, String bookId) async {
    try {
      final img.Image? coverImage = await epubBookRef.readCover();
      if (coverImage == null) {
        return null;
      }

      return _writeCoverImage(coverImage, bookId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _renderPdfCover(String pdfPath, String bookId) async {
    PdfDocument? document;
    PdfImage? pageImage;

    try {
      document = await PdfDocument.openFile(pdfPath);
      if (document.pages.isEmpty) {
        return null;
      }

      final PdfPage firstPage = document.pages.first;
      const double targetWidth = 420;
      final double targetHeight =
          firstPage.height * targetWidth / firstPage.width;
      pageImage = await firstPage.render(
        fullWidth: targetWidth,
        fullHeight: targetHeight,
      );
      if (pageImage == null) {
        return null;
      }

      final img.Format pixelFormat = pageImage.format == ui.PixelFormat.bgra8888
          ? img.Format.bgra
          : img.Format.rgba;
      final img.Image image = img.Image.fromBytes(
        pageImage.width,
        pageImage.height,
        pageImage.pixels,
        format: pixelFormat,
      );
      return _writeCoverImage(image, bookId);
    } catch (_) {
      return null;
    } finally {
      pageImage?.dispose();
      await document?.dispose();
    }
  }

  Future<String> _writeCoverImage(img.Image image, String bookId) async {
    final img.Image normalizedImage =
        image.width > 720 ? img.copyResize(image, width: 720) : image;
    final Directory coverDirectory = Directory(
      p.join(
        (await _profileStorageDirectory('book_covers')).path,
        _stableHash(bookId),
      ),
    );
    await coverDirectory.create(recursive: true);

    final File coverFile = File(p.join(coverDirectory.path, 'cover.png'));
    await coverFile.writeAsBytes(
      img.encodePng(normalizedImage),
      flush: true,
    );
    return coverFile.path;
  }

  Future<Directory> _profileStorageDirectory(String folderName) async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory directory = Directory(
      p.join(
        documentsDirectory.path,
        'profiles',
        _activeProfileId,
        'storage',
        folderName,
      ),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<String?> _resolveExistingCoverPath(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) {
      return null;
    }

    final String normalizedPath = p.normalize(coverPath);
    return await File(normalizedPath).exists() ? normalizedPath : null;
  }

  Future<String?> _findCoverInDirectory(String folderPath) async {
    final Directory directory = Directory(folderPath);
    final List<File> imageFiles =
        (await directory.list(followLinks: false).toList())
            .whereType<File>()
            .where((File file) => _isSupportedImagePath(file.path))
            .toList(growable: false);

    if (imageFiles.isEmpty) {
      return null;
    }

    final List<File> sortedImages = List<File>.from(imageFiles)
      ..sort((File a, File b) {
        final int scoreComparison =
            _coverPriority(a.path).compareTo(_coverPriority(b.path));
        if (scoreComparison != 0) {
          return scoreComparison;
        }
        return p.basename(a.path).toLowerCase().compareTo(
              p.basename(b.path).toLowerCase(),
            );
      });

    return p.normalize(sortedImages.first.path);
  }

  int _coverPriority(String imagePath) {
    final String name = p.basenameWithoutExtension(imagePath).toLowerCase();
    if (name == 'cover' || name == 'capa') {
      return 0;
    }
    if (name.startsWith('cover') ||
        name.startsWith('capa') ||
        name == 'folder' ||
        name == 'front' ||
        name == 'poster') {
      return 1;
    }
    if (name.contains('cover') || name.contains('capa')) {
      return 2;
    }
    return 10;
  }

  void _flattenEpubChapters(
    List<EpubChapter> chapters,
    List<GeneratedChapter> output,
  ) {
    for (final EpubChapter chapter in chapters) {
      final String title = (chapter.Title ?? '').trim().isEmpty
          ? 'Capitulo'
          : _normalizeDisplayTitle(chapter.Title!.trim());
      final String plainText = _htmlToPlainText(chapter.HtmlContent ?? '');
      if (plainText.trim().isNotEmpty) {
        output.add(
          GeneratedChapter(
            title: title,
            content: plainText,
          ),
        );
      }

      final List<EpubChapter> subChapters =
          chapter.SubChapters ?? const <EpubChapter>[];
      if (subChapters.isNotEmpty) {
        _flattenEpubChapters(subChapters, output);
      }
    }
  }

  String _extractTitleFromHtml(String html, String href) {
    final dynamic parsedDocument = html_parser.parse(html);
    final List<String> candidates = <String>[
      parsedDocument.querySelector('h1, h2, h3')?.text?.trim() ?? '',
      parsedDocument.title?.trim() ?? '',
      p.basenameWithoutExtension(href),
    ];

    for (final String candidate in candidates) {
      if (candidate.trim().isNotEmpty) {
        return _normalizeDisplayTitle(candidate.trim());
      }
    }

    return 'Capitulo';
  }

  bool _shouldSkipEpubHtmlChapter(String title, String text, String href) {
    final String normalizedTitle = title.toLowerCase();
    final String normalizedHref = href.toLowerCase();
    final int textLength = text.replaceAll(RegExp(r'\s+'), ' ').trim().length;
    final bool likelyBoilerplate = normalizedTitle.contains('cover') ||
        normalizedTitle.contains('capa') ||
        normalizedTitle.contains('toc') ||
        normalizedTitle.contains('indice') ||
        normalizedTitle.contains('contents') ||
        normalizedTitle.contains('copyright') ||
        normalizedHref.contains('cover') ||
        normalizedHref.contains('toc') ||
        normalizedHref.contains('nav');

    return likelyBoilerplate && textLength < 260;
  }

  bool _looksLikeBoilerplate(String title, String content) {
    final String normalizedTitle = title.toLowerCase();
    final int textLength =
        content.replaceAll(RegExp(r'\s+'), ' ').trim().length;

    if (normalizedTitle.contains('cover') ||
        normalizedTitle.contains('capa') ||
        normalizedTitle.contains('copyright')) {
      return textLength < 320;
    }

    if ((normalizedTitle.contains('toc') ||
            normalizedTitle.contains('indice') ||
            normalizedTitle.contains('contents')) &&
        textLength < 400) {
      return true;
    }

    return false;
  }

  String _htmlToPlainText(String html) {
    final String normalized = html
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n');
    final String parsed = html_parser.parse(normalized).body?.text ?? '';
    return parsed
        .replaceAll('\r\n', '\n')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trimRight();
  }

  String _inferTitleFromFiles(List<String> filePaths) {
    final Set<String> parentNames = filePaths
        .map((String path) => p.basename(p.dirname(path)))
        .where((String name) => name.isNotEmpty)
        .toSet();

    if (parentNames.length == 1) {
      return parentNames.first;
    }

    return 'Livro importado';
  }

  bool _isSupportedTextPath(String path) {
    const Set<String> supportedExtensions = <String>{
      '.txt',
      '.md',
      '.markdown',
      '.html',
      '.htm',
      '.xhtml',
    };
    return supportedExtensions.contains(p.extension(path).toLowerCase());
  }

  bool _isSupportedImagePath(String path) {
    const Set<String> supportedExtensions = <String>{
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.gif',
      '.bmp',
    };
    return supportedExtensions.contains(p.extension(path).toLowerCase());
  }

  String _normalizeDisplayTitle(String value) {
    final String trimmed = value.trim();
    final Match? numberedWithSeparator =
        RegExp(r'^0*(\d+)(\s*[-._]\s*)(.+)$').firstMatch(trimmed);
    if (numberedWithSeparator != null) {
      final int number = int.parse(numberedWithSeparator.group(1)!);
      return '$number${numberedWithSeparator.group(2)!}${numberedWithSeparator.group(3)!}';
    }

    final Match? numberedWithSpace =
        RegExp(r'^0*(\d+)(\s+)(.+)$').firstMatch(trimmed);
    if (numberedWithSpace != null) {
      final int number = int.parse(numberedWithSpace.group(1)!);
      return '$number ${numberedWithSpace.group(3)!}';
    }

    final Match? onlyNumber = RegExp(r'^0*(\d+)$').firstMatch(trimmed);
    if (onlyNumber != null) {
      return int.parse(onlyNumber.group(1)!).toString();
    }

    return trimmed;
  }

  String? _normalizeOptionalText(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  int? _extractSortNumber(String fileName) {
    final String name = p.basenameWithoutExtension(fileName);
    final Match? match = RegExp(r'\d+').firstMatch(name);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(0)!);
  }

  int _compareCandidates(_ChapterCandidate a, _ChapterCandidate b) {
    if (a.sortNumber != null && b.sortNumber != null) {
      final int numberComparison = a.sortNumber!.compareTo(b.sortNumber!);
      if (numberComparison != 0) {
        return numberComparison;
      }
    } else if (a.sortNumber != null) {
      return -1;
    } else if (b.sortNumber != null) {
      return 1;
    }

    return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
  }

  String _buildFileBookId(BookFormat format, List<String> paths) {
    return '${format.name}:${_stableHash(paths.map(p.normalize).join('|'))}';
  }

  String _stableHash(String input) {
    int hash = 2166136261;
    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  String _sanitizeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _trimChapterCache() {
    while (_chapterContentCache.length > _maxCachedChapterContents) {
      _chapterContentCache.remove(_chapterContentCache.keys.first);
    }
  }

  XTypeGroup get _textTypeGroup {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'Text',
        uniformTypeIdentifiers: <String>[
          'public.text',
          'public.plain-text',
          'public.html',
        ],
      );
    }

    return const XTypeGroup(
      label: 'Text',
      extensions: <String>['txt', 'md', 'markdown', 'html', 'htm', 'xhtml'],
      mimeTypes: <String>['text/plain', 'text/html'],
    );
  }

  XTypeGroup get _epubTypeGroup {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'EPUB',
        uniformTypeIdentifiers: <String>['org.idpf.epub-container'],
      );
    }

    return const XTypeGroup(
      label: 'EPUB',
      extensions: <String>['epub'],
      mimeTypes: <String>['application/epub+zip'],
    );
  }

  XTypeGroup get _pdfTypeGroup {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'PDF',
        uniformTypeIdentifiers: <String>['com.adobe.pdf'],
      );
    }

    return const XTypeGroup(
      label: 'PDF',
      extensions: <String>['pdf'],
      mimeTypes: <String>['application/pdf'],
    );
  }

  XTypeGroup get _imageTypeGroup {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'Image',
        uniformTypeIdentifiers: <String>['public.image'],
      );
    }

    return const XTypeGroup(
      label: 'Image',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      mimeTypes: <String>[
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
        'image/bmp',
      ],
    );
  }
}

class _ChapterCandidate {
  const _ChapterCandidate({
    required this.path,
    required this.fileName,
    required this.title,
    required this.sortNumber,
  });

  final String path;
  final String fileName;
  final String title;
  final int? sortNumber;
}

class _EpubMetadataResult {
  const _EpubMetadataResult({
    required this.author,
    required this.description,
    required this.series,
    required this.volume,
    required this.tags,
  });

  final String? author;
  final String? description;
  final String? series;
  final String? volume;
  final List<String> tags;
}
