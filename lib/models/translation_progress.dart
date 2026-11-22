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

/// Job-scoped pause signal. Completed checkpoints remain on disk.
class TranslationPause {
  bool _requested = false;
  void Function()? _onPause;
  bool get requested => _requested;

  void request() {
    if (_requested) return;
    _requested = true;
    _onPause?.call();
  }

  void attach(void Function()? callback) {
    _onPause = callback;
    if (_requested) callback?.call();
  }

  void check() {
    if (_requested) throw const TranslationPausedException();
  }
}

class TranslationPausedException implements Exception {
  const TranslationPausedException();

  @override
  String toString() =>
      'Traducao pausada. Inicie novamente com o mesmo livro e idiomas para retomar.';
}
