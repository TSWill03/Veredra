// Signature: dev.tswicolly03
class BookSearchMatch {
  const BookSearchMatch({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.matchCount,
    required this.snippet,
    required this.chapterProgress,
  });

  final int chapterIndex;
  final String chapterTitle;
  final int matchCount;
  final String snippet;
  final double chapterProgress;
}
