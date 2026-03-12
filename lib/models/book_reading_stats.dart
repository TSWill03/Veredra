// Signature: dev.tswicolly03
class BookReadingStats {
  const BookReadingStats({
    required this.bookId,
    required this.totalSeconds,
    required this.sessionCount,
    required this.openedCount,
    required this.lastReadAt,
    required this.lastChapterIndex,
    this.dailySeconds = const <String, int>{},
  });

  final String bookId;
  final int totalSeconds;
  final int sessionCount;
  final int openedCount;
  final DateTime? lastReadAt;
  final int lastChapterIndex;
  final Map<String, int> dailySeconds;

  Duration get totalDuration => Duration(seconds: totalSeconds);

  int secondsForDate(DateTime date) {
    return dailySeconds[_dateKey(date)] ?? 0;
  }

  int totalSecondsLastDays(int days, {DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    int total = 0;
    for (int offset = 0; offset < days; offset++) {
      final DateTime day = anchor.subtract(Duration(days: offset));
      total += secondsForDate(day);
    }
    return total;
  }

  int currentStreakDays({DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    int streak = 0;
    for (int offset = 0;; offset++) {
      final DateTime day = anchor.subtract(Duration(days: offset));
      if (secondsForDate(day) <= 0) {
        break;
      }
      streak++;
    }
    return streak;
  }

  BookReadingStats copyWith({
    String? bookId,
    int? totalSeconds,
    int? sessionCount,
    int? openedCount,
    DateTime? lastReadAt,
    int? lastChapterIndex,
    Map<String, int>? dailySeconds,
  }) {
    return BookReadingStats(
      bookId: bookId ?? this.bookId,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      sessionCount: sessionCount ?? this.sessionCount,
      openedCount: openedCount ?? this.openedCount,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      dailySeconds: dailySeconds ?? this.dailySeconds,
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
      'dailySeconds': dailySeconds,
    };
  }

  factory BookReadingStats.fromJson(Map<String, dynamic> json) {
    final Map<String, int> dailySeconds = <String, int>{};
    final dynamic rawDailySeconds = json['dailySeconds'];
    if (rawDailySeconds is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawDailySeconds.entries) {
        dailySeconds[entry.key] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    return BookReadingStats(
      bookId: json['bookId'] as String? ?? '',
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      openedCount: (json['openedCount'] as num?)?.toInt() ?? 0,
      lastReadAt: DateTime.tryParse(json['lastReadAt'] as String? ?? ''),
      lastChapterIndex: (json['lastChapterIndex'] as num?)?.toInt() ?? 0,
      dailySeconds: dailySeconds,
    );
  }

  static String dateKey(DateTime date) => _dateKey(date);

  static String _dateKey(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
