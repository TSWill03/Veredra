// Signature: dev.tswicolly03
class BookReadingStats {
  const BookReadingStats({
    required this.bookId,
    required this.totalSeconds,
    required this.sessionCount,
    required this.openedCount,
    required this.lastReadAt,
    required this.lastChapterIndex,
  });

  final String bookId;
  final int totalSeconds;
  final int sessionCount;
  final int openedCount;
  final DateTime? lastReadAt;
  final int lastChapterIndex;

  Duration get totalDuration => Duration(seconds: totalSeconds);

  BookReadingStats copyWith({
    String? bookId,
    int? totalSeconds,
    int? sessionCount,
    int? openedCount,
    DateTime? lastReadAt,
    int? lastChapterIndex,
  }) {
    return BookReadingStats(
      bookId: bookId ?? this.bookId,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      sessionCount: sessionCount ?? this.sessionCount,
      openedCount: openedCount ?? this.openedCount,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bookId': bookId,
      'totalSeconds': totalSeconds,
      'sessionCount': sessionCount,
      'openedCount': openedCount,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastChapterIndex': lastChapterIndex,
    };
  }

  factory BookReadingStats.fromJson(Map<String, dynamic> json) {
    return BookReadingStats(
      bookId: json['bookId'] as String? ?? '',
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      openedCount: (json['openedCount'] as num?)?.toInt() ?? 0,
      lastReadAt: DateTime.tryParse(json['lastReadAt'] as String? ?? ''),
      lastChapterIndex: (json['lastChapterIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
