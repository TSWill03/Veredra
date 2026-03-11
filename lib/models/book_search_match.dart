class BookSearchMatch {
  const BookSearchMatch({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.matchCount,
    required this.snippet,
  });

  final int chapterIndex;
  final String chapterTitle;
  final int matchCount;
  final String snippet;
}
