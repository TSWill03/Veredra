// Signature: dev.tswicolly03
import '../models/library_entry.dart';
import '../models/library_search_result.dart';
import '../models/reader_annotation.dart';
import '../models/reader_bookmark.dart';
import 'annotation_service.dart';
import 'bookmark_service.dart';
import 'book_service.dart';

class LibrarySearchService {
  const LibrarySearchService({
    required this.bookService,
    required this.bookmarkService,
    required this.annotationService,
  });

  final BookService bookService;
  final BookmarkService bookmarkService;
  final AnnotationService annotationService;

  Future<List<LibrarySearchResult>> search(
    List<LibraryEntry> entries,
    String query, {
    int maxResults = 80,
  }) async {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) {
      return const <LibrarySearchResult>[];
    }

    final List<LibrarySearchResult> results = await bookService.searchLibrary(
      entries,
      query,
      maxResults: maxResults,
    );
    if (results.length >= maxResults) {
      return results.take(maxResults).toList(growable: false);
    }

    final Map<String, LibraryEntry> entriesById = <String, LibraryEntry>{
      for (final LibraryEntry entry in entries) entry.id: entry,
    };
    final Map<String, List<ReaderBookmark>> allBookmarks =
        await bookmarkService.loadAllBookmarks();
    final Map<String, List<ReaderAnnotation>> allAnnotations =
        await annotationService.loadAllAnnotations();

    for (final MapEntry<String, List<ReaderBookmark>> entry
        in allBookmarks.entries) {
      final LibraryEntry? libraryEntry = entriesById[entry.key];
      if (libraryEntry == null) {
        continue;
      }

      for (final ReaderBookmark bookmark in entry.value) {
        final String haystack = <String>[
          bookmark.chapterTitle,
          bookmark.note ?? '',
          bookmark.excerpt ?? '',
        ].join(' ').toLowerCase();
        final int matchIndex = haystack.indexOf(normalizedQuery);
        if (matchIndex < 0) {
          continue;
        }

        final String detail = (bookmark.note?.trim().isNotEmpty ?? false)
            ? bookmark.note!.trim()
            : (bookmark.excerpt?.trim().isNotEmpty ?? false)
                ? bookmark.excerpt!.trim()
                : bookmark.chapterTitle;
        results.add(
          LibrarySearchResult(
            reference: libraryEntry.reference,
            bookTitle: libraryEntry.title,
            source: LibrarySearchResultSource.bookmark,
            snippet: _buildSnippet(detail, normalizedQuery),
            matchCount: 1,
            chapterIndex: bookmark.chapterIndex,
            chapterTitle: bookmark.chapterTitle,
            chapterProgress: bookmark.chapterProgress,
          ),
        );
        if (results.length >= maxResults) {
          return results.take(maxResults).toList(growable: false);
        }
      }
    }

    for (final MapEntry<String, List<ReaderAnnotation>> entry
        in allAnnotations.entries) {
      final LibraryEntry? libraryEntry = entriesById[entry.key];
      if (libraryEntry == null) {
        continue;
      }

      for (final ReaderAnnotation annotation in entry.value) {
        final String haystack = <String>[
          annotation.chapterTitle,
          annotation.selectedText,
          annotation.note ?? '',
        ].join(' ').toLowerCase();
        final int matchIndex = haystack.indexOf(normalizedQuery);
        if (matchIndex < 0) {
          continue;
        }

        final String detail = (annotation.note?.trim().isNotEmpty ?? false)
            ? annotation.note!.trim()
            : annotation.selectedText;
        results.add(
          LibrarySearchResult(
            reference: libraryEntry.reference,
            bookTitle: libraryEntry.title,
            source: LibrarySearchResultSource.annotation,
            snippet: _buildSnippet(detail, normalizedQuery),
            matchCount: 1,
            chapterIndex: annotation.chapterIndex,
            chapterTitle: annotation.chapterTitle,
          ),
        );
        if (results.length >= maxResults) {
          return results.take(maxResults).toList(growable: false);
        }
      }
    }

    return results;
  }

  String _buildSnippet(String content, String normalizedQuery) {
    final String normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final int matchIndex = normalized.toLowerCase().indexOf(normalizedQuery);
    if (matchIndex < 0) {
      return normalized;
    }

    final int snippetStart = (matchIndex - 50).clamp(0, normalized.length);
    final int snippetEnd =
        (matchIndex + normalizedQuery.length + 90).clamp(0, normalized.length);
    final String prefix = snippetStart > 0 ? '...' : '';
    final String suffix = snippetEnd < normalized.length ? '...' : '';
    return '$prefix${normalized.substring(snippetStart, snippetEnd).trim()}$suffix';
  }
}
