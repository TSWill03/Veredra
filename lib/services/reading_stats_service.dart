// Signature: dev.tswicolly03
import 'dart:convert';

import '../models/book_reading_stats.dart';
import 'storage/app_storage.dart';

class ReadingStatsService {
  final AppStorage _storage = createAppStorage();
  String _activeProfileId = 'principal';

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
  }

  Future<Map<String, BookReadingStats>> loadAllStats() async {
    final Map<String, dynamic> json = await _loadJson();
    return <String, BookReadingStats>{
      for (final MapEntry<String, dynamic> entry in json.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: BookReadingStats.fromJson(
            entry.value as Map<String, dynamic>,
          ),
    };
  }

  Future<BookReadingStats?> loadStats(String bookId) async {
    final Map<String, BookReadingStats> stats = await loadAllStats();
    return stats[bookId];
  }

  Future<void> registerBookOpened(String bookId, {int chapterIndex = 0}) async {
    final Map<String, BookReadingStats> stats = await loadAllStats();
    final BookReadingStats current = stats[bookId] ??
        BookReadingStats(
          bookId: bookId,
          totalSeconds: 0,
          sessionCount: 0,
          openedCount: 0,
          lastReadAt: null,
          lastChapterIndex: chapterIndex,
        );
    stats[bookId] = current.copyWith(
      openedCount: current.openedCount + 1,
      lastReadAt: DateTime.now(),
      lastChapterIndex: chapterIndex,
    );
    await _saveJson(stats);
  }

  Future<void> recordReadingSession(
    String bookId,
    Duration duration, {
    int chapterIndex = 0,
  }) async {
    if (duration.inSeconds <= 0) {
      return;
    }

    final Map<String, BookReadingStats> stats = await loadAllStats();
    final DateTime now = DateTime.now();
    final BookReadingStats current = stats[bookId] ??
        BookReadingStats(
          bookId: bookId,
          totalSeconds: 0,
          sessionCount: 0,
          openedCount: 0,
          lastReadAt: null,
          lastChapterIndex: chapterIndex,
        );
    final Map<String, int> dailySeconds =
        Map<String, int>.from(current.dailySeconds);
    final String dateKey = BookReadingStats.dateKey(now);
    dailySeconds[dateKey] = (dailySeconds[dateKey] ?? 0) + duration.inSeconds;
    stats[bookId] = current.copyWith(
      totalSeconds: current.totalSeconds + duration.inSeconds,
      sessionCount: current.sessionCount + 1,
      lastReadAt: now,
      lastChapterIndex: chapterIndex,
      dailySeconds: dailySeconds,
    );
    await _saveJson(stats);
  }

  Future<Map<String, dynamic>> exportJson() async {
    final Map<String, BookReadingStats> stats = await loadAllStats();
    return <String, dynamic>{
      for (final MapEntry<String, BookReadingStats> entry in stats.entries)
        entry.key: entry.value.toJson(),
    };
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    final Map<String, BookReadingStats> stats = <String, BookReadingStats>{
      for (final MapEntry<String, dynamic> entry in json.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: BookReadingStats.fromJson(
            entry.value as Map<String, dynamic>,
          ),
    };
    await _saveJson(stats);
  }

  Future<Map<String, dynamic>> _loadJson() async {
    final String? raw = await _storage.readString(_statsKey);
    if (raw == null) {
      return <String, dynamic>{};
    }
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    return decoded;
  }

  Future<void> _saveJson(Map<String, BookReadingStats> stats) async {
    await _storage.writeString(
      _statsKey,
      jsonEncode(
        <String, dynamic>{
          for (final MapEntry<String, BookReadingStats> entry in stats.entries)
            entry.key: entry.value.toJson(),
        },
      ),
    );
  }

  String get _statsKey =>
      'profiles/$_activeProfileId/reader/reading_stats.json';
}
