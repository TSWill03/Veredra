import 'dart:convert';

class ReadingProgress {
  const ReadingProgress({
    required this.chapterIndex,
    required this.chapterOffset,
    required this.chapterProgress,
    required this.savedAt,
  });

  final int chapterIndex;
  final double chapterOffset;
  final double chapterProgress;
  final DateTime savedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'chapterIndex': chapterIndex,
      'chapterOffset': chapterOffset,
      'chapterProgress': chapterProgress,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  String encode() => jsonEncode(toJson());

  static ReadingProgress? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return ReadingProgress.fromJson(decoded);
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    final double rawProgress =
        (json['chapterProgress'] as num?)?.toDouble() ?? 0;

    return ReadingProgress(
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterOffset: (json['chapterOffset'] as num?)?.toDouble() ?? 0,
      chapterProgress: rawProgress < 0
          ? 0
          : rawProgress > 1
              ? 1
              : rawProgress,
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
