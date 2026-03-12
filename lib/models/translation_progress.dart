// Signature: dev.tswicolly03
class TranslationProgress {
  const TranslationProgress({
    required this.stage,
    required this.completedChapters,
    required this.totalChapters,
    this.currentChapterTitle,
    this.detail,
  });

  final String stage;
  final int completedChapters;
  final int totalChapters;
  final String? currentChapterTitle;
  final String? detail;

  double get fraction {
    if (totalChapters <= 0) {
      return 0;
    }
    return completedChapters.clamp(0, totalChapters) / totalChapters;
  }

  TranslationProgress copyWith({
    String? stage,
    int? completedChapters,
    int? totalChapters,
    String? currentChapterTitle,
    String? detail,
  }) {
    return TranslationProgress(
      stage: stage ?? this.stage,
      completedChapters: completedChapters ?? this.completedChapters,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      detail: detail ?? this.detail,
    );
  }
}
