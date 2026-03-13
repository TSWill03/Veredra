// Signature: dev.tswicolly03
import 'book_open_request.dart';
import 'book_reference.dart';

enum LibrarySearchResultSource { metadata, content, bookmark, annotation }

class LibrarySearchResult {
  const LibrarySearchResult({
    required this.reference,
    required this.bookTitle,
    required this.source,
    required this.snippet,
    required this.matchCount,
    this.chapterIndex,
    this.chapterTitle,
    this.chapterProgress,
  });

  final BookReference reference;
  final String bookTitle;
  final LibrarySearchResultSource source;
  final String snippet;
  final int matchCount;
  final int? chapterIndex;
  final String? chapterTitle;
  final double? chapterProgress;

  String get sourceLabel {
    switch (source) {
      case LibrarySearchResultSource.metadata:
        return 'Metadados';
      case LibrarySearchResultSource.content:
        return chapterTitle ?? 'Conteudo';
      case LibrarySearchResultSource.bookmark:
        return 'Marcador';
      case LibrarySearchResultSource.annotation:
        return 'Destaque';
    }
  }

  BookOpenRequest toOpenRequest() {
    return BookOpenRequest(
      reference: reference,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
    );
  }
}
