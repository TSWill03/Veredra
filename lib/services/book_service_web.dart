// Signature: dev.tswicolly03
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:file_selector/file_selector.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;
import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../models/book_format.dart';
import '../models/book_reference.dart';
import '../models/book_search_match.dart';
import '../models/chapter.dart';
import '../models/generated_chapter.dart';
import '../models/library_entry.dart';
import '../models/library_search_result.dart';
import '../models/translation_language.dart';
import 'import_limits.dart';
import 'storage/app_storage.dart';

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
  static const String _webStoredPrefix = 'veredra://';

  final LinkedHashMap<String, String> _chapterContentCache =
      LinkedHashMap<String, String>();
  final AppStorage _storage = createAppStorage();
  String _activeProfileId = 'principal';

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
    _chapterContentCache.clear();
  }

  bool get supportsDirectoryImport => false;

  List<ImportOption> getImportOptions() {
    return const <ImportOption>[
      ImportOption(
        kind: ImportKind.textFiles,
        label: 'Arquivos de texto',
        description: 'Importa .txt, .md, .markdown, .html, .htm e .xhtml.',
      ),
      ImportOption(
        kind: ImportKind.epub,
        label: 'EPUB',
        description:
            'Extrai capitulos do EPUB e salva a copia local no navegador.',
      ),
      ImportOption(
        kind: ImportKind.pdf,
        label: 'PDF',
        description: 'PDF ainda nao esta disponivel na versao Web.',
      ),
    ];
  }

  Future<bool> isBookReferenceAvailable(BookReference reference) async {
    if (reference.isPdf || reference.assetPaths.isEmpty) {
      return false;
    }

    for (final String path in reference.assetPaths) {
      if (_isWebStoredPath(path) && await _storage.exists(_storageKey(path))) {
        return true;
      }
    }
    return false;
  }

  Future<Book?> importBook(ImportKind kind) async {
    switch (kind) {
      case ImportKind.textFolder:
        throw StateError(
          'Importacao por pasta esta disponivel apenas no desktop.',
        );
      case ImportKind.textFiles:
        return _pickTextFilesAndLoad();
      case ImportKind.epub:
        return _pickEpubAndLoad();
      case ImportKind.pdf:
        throw StateError('PDF ainda nao esta disponivel na versao Web.');
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

    ImportLimits.validateFileSize(
      ImportPayloadKind.image,
      await file.length(),
      label: 'A imagem',
    );
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
          chapterProgress: content.isEmpty
              ? 0
              : firstMatchIndex.clamp(0, content.length) / content.length,
        ),
      );

      if (results.length >= maxResults) {
        break;
      }
    }

    return results;
  }

  Future<List<LibrarySearchResult>> searchLibrary(
    List<LibraryEntry> entries,
    String query, {
    int maxResults = 60,
    int maxContentMatchesPerBook = 3,
  }) async {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) {
      return const <LibrarySearchResult>[];
    }

    final List<LibrarySearchResult> results = <LibrarySearchResult>[];
    for (final LibraryEntry entry in entries) {
      if (entry.reference.searchMetadata.contains(normalizedQuery)) {
        results.add(
          LibrarySearchResult(
            reference: entry.reference,
            bookTitle: entry.title,
            source: LibrarySearchResultSource.metadata,
            snippet: _buildMetadataSnippet(entry.reference, query),
            matchCount: 1,
          ),
        );
      }

      if (results.length >= maxResults || !entry.reference.usesTextReader) {
        if (results.length >= maxResults) {
          break;
        }
        continue;
      }

      try {
        final Book book = await reopenBook(entry.reference);
        final List<BookSearchMatch> matches = await searchBookContent(
          book,
          query,
          maxResults: maxContentMatchesPerBook,
        );
        for (final BookSearchMatch match in matches) {
          results.add(
            LibrarySearchResult(
              reference: entry.reference,
              bookTitle: entry.title,
              source: LibrarySearchResultSource.content,
              snippet: match.snippet,
              matchCount: match.matchCount,
              chapterIndex: match.chapterIndex,
              chapterTitle: match.chapterTitle,
              chapterProgress: match.chapterProgress,
            ),
          );
          if (results.length >= maxResults) {
            break;
          }
        }
      } catch (_) {
        continue;
      }

      if (results.length >= maxResults) {
        break;
      }
    }

    return results;
  }

  Future<Book> reopenBook(BookReference reference) {
    if (reference.isPdf) {
      throw StateError('PDF ainda nao esta disponivel na versao Web.');
    }
    return _loadWebStoredTextBook(reference);
  }

  Future<Book?> _pickTextFilesAndLoad() async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[_textTypeGroup],
      confirmButtonText: 'Importar arquivos',
    );
    if (files.isEmpty) {
      return null;
    }
    return _loadWebTextBookFromXFiles(files);
  }

  Future<Book?> _pickEpubAndLoad() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_epubTypeGroup],
      confirmButtonText: 'Importar EPUB',
    );
    if (file == null) {
      return null;
    }

    return loadEpubBookFromBytes(
      await file.readAsBytes(),
      sourceName: file.name,
    );
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
    throw StateError(
      'Importacao por pasta esta disponivel apenas no desktop.',
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
        'Nenhum capitulo salvo no navegador foi encontrado. Reimporte o livro neste dispositivo.',
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

  Future<Book> _loadWebTextBookFromXFiles(List<XFile> files) async {
    final List<GeneratedChapter> chapters = <GeneratedChapter>[];
    final List<String> displayNames = <String>[];
    final List<String> sourceNames = <String>[];
    ImportLimits.validateTextCollection(
      await Future.wait(files.map((XFile file) => file.length())),
    );

    for (final XFile file in files) {
      final String name = file.name.trim().isEmpty ? 'capitulo.txt' : file.name;
      if (!_isSupportedTextPath(name)) {
        continue;
      }

      final int fileLength = await file.length();
      ImportLimits.validateTextCollection(<int>[fileLength]);
      final Uint8List bytes = await file.readAsBytes();
      final String rawContent = utf8.decode(bytes, allowMalformed: true);
      chapters.add(
        GeneratedChapter(
          title: _deriveChapterTitle(name),
          content: _normalizeImportedText(rawContent, name),
        ),
      );
      displayNames.add(name);
      sourceNames.add('$name:${bytes.length}:${_stableBytesHash(bytes)}');
    }

    if (chapters.isEmpty) {
      throw StateError(
        'Nenhum arquivo de texto valido foi encontrado para importar.',
      );
    }

    final String title = _inferTitleFromFiles(displayNames);
    final String importId = _stableHash(sourceNames.join('|'));
    final List<String> chapterPaths = await _writeManagedChapters(
      baseFolderName: 'imported_text_books',
      bookId: importId,
      chapters: chapters,
    );
    final BookReference reference = BookReference(
      title: title,
      format: BookFormat.text,
      sourceLabel: 'Arquivos importados no navegador',
      assetPaths: chapterPaths,
    );

    return _buildTextBook(
      title: title,
      format: BookFormat.text,
      reference: reference,
      filePaths: chapterPaths,
      id: _buildFileBookId(BookFormat.text, chapterPaths),
    );
  }

  Future<Book> _loadWebStoredTextBook(BookReference reference) async {
    final List<String> existingPaths = <String>[];
    for (final String path in reference.assetPaths) {
      if (_isWebStoredPath(path) && await _storage.exists(_storageKey(path))) {
        existingPaths.add(path);
      }
    }

    if (existingPaths.isEmpty) {
      throw StateError(
        'Os capitulos salvos no navegador nao foram encontrados. Reimporte o livro neste dispositivo.',
      );
    }

    return _buildTextBook(
      title: reference.title,
      format: reference.format,
      reference: reference.copyWith(assetPaths: existingPaths),
      filePaths: existingPaths,
      id: _buildFileBookId(reference.format, existingPaths),
    );
  }

  Future<Book> loadEpubBook(String sourcePath) async {
    throw StateError(
      'EPUB na Web deve ser importado pelo seletor do navegador.',
    );
  }

  Future<Book> loadEpubBookFromBytes(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    ImportLimits.validateFileSize(
      ImportPayloadKind.epub,
      bytes.length,
      label: 'O EPUB',
    );
    final EpubBookRef epubBookRef = await EpubReader.openBook(bytes);
    final EpubMetadata? metadata = epubBookRef.Schema?.Package?.Metadata;
    final String title = (epubBookRef.Title ?? '').trim().isEmpty
        ? p.basenameWithoutExtension(sourceName)
        : epubBookRef.Title!.trim();
    final List<GeneratedChapter> generatedChapters =
        await _readEpubGeneratedChapters(epubBookRef);
    ImportLimits.validateExtractedText(
      generatedChapters.map((GeneratedChapter chapter) => chapter.content),
    );

    if (generatedChapters.isEmpty) {
      throw StateError('Nao foi possivel extrair capitulos legiveis do EPUB.');
    }

    final String importId =
        _stableHash('$sourceName:${bytes.length}:${_stableBytesHash(bytes)}');
    final List<String> chapterPaths = await _writeManagedChapters(
      baseFolderName: 'imported_epub_books',
      bookId: importId,
      chapters: generatedChapters,
    );
    final String? coverPath = await _extractEpubCover(epubBookRef, importId);
    final _EpubMetadataResult metadataResult = _extractEpubMetadata(metadata);
    final BookReference reference = BookReference(
      title: title,
      format: BookFormat.epub,
      sourceLabel: 'EPUB convertido no navegador',
      coverPath: coverPath,
      author: metadataResult.author,
      description: metadataResult.description,
      series: metadataResult.series,
      volume: metadataResult.volume,
      tags: metadataResult.tags,
      assetPaths: chapterPaths,
    );

    return _buildTextBook(
      title: title,
      format: BookFormat.epub,
      reference: reference,
      filePaths: chapterPaths,
      id: _buildFileBookId(BookFormat.epub, chapterPaths),
    );
  }

  Future<Book> loadPdfBook(
    String sourcePath, {
    String? preferredTitle,
    String? preferredCoverPath,
    required bool copyToManagedStorage,
  }) async {
    throw StateError('PDF ainda nao esta disponivel na versao Web.');
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

    if (!_isWebStoredPath(chapter.path)) {
      throw StateError(
        'Este capitulo nao esta salvo no navegador. Reimporte o livro neste dispositivo.',
      );
    }

    final String rawContent = await _readWebStoredChapter(chapter.path);
    final String normalizedContent =
        _normalizeImportedText(rawContent, chapter.path);

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

  String _buildMetadataSnippet(BookReference reference, String query) {
    final List<String> fields = <String>[
      reference.title,
      if (reference.altTitle?.trim().isNotEmpty ?? false)
        'Tambem conhecido como ${reference.altTitle!.trim()}',
      if (reference.author?.trim().isNotEmpty ?? false)
        'Autor: ${reference.author!.trim()}',
      if (reference.series?.trim().isNotEmpty ?? false)
        'Serie: ${reference.series!.trim()}',
      if (reference.description?.trim().isNotEmpty ?? false)
        reference.description!.trim(),
      if (reference.tags.isNotEmpty) 'Tags: ${reference.tags.join(', ')}',
    ];
    final String normalizedQuery = query.trim().toLowerCase();
    for (final String field in fields) {
      final int matchIndex = field.toLowerCase().indexOf(normalizedQuery);
      if (matchIndex >= 0) {
        return _buildSnippet(field, matchIndex, normalizedQuery.length);
      }
    }

    return fields.firstWhere(
      (String value) => value.trim().isNotEmpty,
      orElse: () => reference.subtitle,
    );
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
      if (_isWebStoredPath(path) && await _storage.exists(_storageKey(path))) {
        normalizedPaths.add(path);
      }
    }
    return normalizedPaths;
  }

  Future<List<String>> _copyFilesToManagedStorage(
    List<String> sourcePaths, {
    required String folderName,
  }) async {
    final String importId = _stableHash(sourcePaths.map(p.normalize).join('|'));
    final List<GeneratedChapter> chapters = <GeneratedChapter>[
      for (final String path in sourcePaths)
        GeneratedChapter(
          title: _deriveChapterTitle(path),
          content: await _readWebStoredChapter(path),
        ),
    ];
    return _writeManagedChapters(
      baseFolderName: folderName,
      bookId: importId,
      chapters: chapters,
    );
  }

  Future<List<String>> _writeManagedChapters({
    required String baseFolderName,
    required String bookId,
    required List<GeneratedChapter> chapters,
  }) async {
    final String rootKey =
        'profiles/$_activeProfileId/storage/$baseFolderName/$bookId';
    final List<String> chapterPaths = <String>[];
    for (int index = 0; index < chapters.length; index++) {
      final String safeTitle = _sanitizeFileName(chapters[index].title);
      final String fileName = '${index + 1} - $safeTitle.txt';
      final String key = '$rootKey/$fileName';
      await _storage.writeString(key, chapters[index].content.trim());
      chapterPaths.add(_webPath(key));
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

  Future<String> _writeCoverImage(img.Image image, String bookId) async {
    final img.Image normalizedImage =
        image.width > 720 ? img.copyResize(image, width: 720) : image;
    final List<int> pngBytes = img.encodePng(normalizedImage);
    final String key =
        'profiles/$_activeProfileId/storage/book_covers/${_stableHash(bookId)}/cover.png';
    await _storage.writeBytes(key, pngBytes);
    return _webPath(key);
  }

  Future<String?> _resolveExistingCoverPath(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) {
      return null;
    }

    if (_isWebStoredPath(coverPath) &&
        await _storage.exists(_storageKey(coverPath))) {
      return coverPath;
    }
    return null;
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
      parsedDocument.querySelector('title')?.text?.trim() ?? '',
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
    final dynamic document = html_parser.parse(normalized);
    for (final dynamic unsafe in document.querySelectorAll(
      'script,style,iframe,object,embed,noscript',
    )) {
      unsafe.remove();
    }
    final String parsed = document.body?.text as String? ?? '';
    return parsed
        .replaceAll('\r\n', '\n')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trimRight();
  }

  String _inferTitleFromFiles(List<String> filePaths) {
    final Set<String> parentNames = filePaths
        .map((String path) => p.basename(p.dirname(path)))
        .where((String name) => name.isNotEmpty && name != '.')
        .toSet();

    if (parentNames.length == 1) {
      return parentNames.first;
    }

    if (filePaths.length == 1) {
      final String fileTitle = p.basenameWithoutExtension(filePaths.single);
      if (fileTitle.trim().isNotEmpty) {
        return _normalizeDisplayTitle(fileTitle);
      }
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

  Future<String> _readWebStoredChapter(String path) async {
    final String? raw = await _storage.readString(_storageKey(path));
    if (raw == null) {
      throw StateError(
        'O capitulo salvo no navegador nao foi encontrado. Reimporte o livro neste dispositivo.',
      );
    }
    return raw;
  }

  String _normalizeImportedText(String rawContent, String sourcePath) {
    final String extension = p.extension(sourcePath).toLowerCase();
    switch (extension) {
      case '.md':
      case '.markdown':
        return _htmlToPlainText(markdown.markdownToHtml(rawContent));
      case '.html':
      case '.htm':
      case '.xhtml':
        return _htmlToPlainText(rawContent);
      default:
        return rawContent.replaceAll('\r\n', '\n').trimRight();
    }
  }

  bool _isWebStoredPath(String path) => path.startsWith(_webStoredPrefix);

  String _storageKey(String webPath) {
    return normalizeStorageKey(webPath.replaceFirst(_webStoredPrefix, ''));
  }

  String _webPath(String storageKey) {
    return '$_webStoredPrefix${normalizeStorageKey(storageKey)}';
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

  String _stableBytesHash(List<int> bytes) {
    int hash = 2166136261;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  String _sanitizeFileName(String value) {
    final String sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.isEmpty ? 'Capitulo' : sanitized;
  }

  void _trimChapterCache() {
    while (_chapterContentCache.length > _maxCachedChapterContents) {
      _chapterContentCache.remove(_chapterContentCache.keys.first);
    }
  }

  XTypeGroup get _textTypeGroup {
    return const XTypeGroup(
      label: 'Text',
      extensions: <String>['txt', 'md', 'markdown', 'html', 'htm', 'xhtml'],
      mimeTypes: <String>['text/plain', 'text/html'],
    );
  }

  XTypeGroup get _epubTypeGroup {
    return const XTypeGroup(
      label: 'EPUB',
      extensions: <String>['epub'],
      mimeTypes: <String>['application/epub+zip'],
    );
  }

  XTypeGroup get _imageTypeGroup {
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
