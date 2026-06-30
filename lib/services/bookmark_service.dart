// Signature: dev.tswicolly03
import 'dart:convert';

import '../models/reader_bookmark.dart';
import 'storage/app_storage.dart';

class BookmarkService {
  final AppStorage _storage = createAppStorage();
  String _activeProfileId = 'principal';

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
  }

  Future<List<ReaderBookmark>> loadBookmarks(String bookId) async {
    final Map<String, dynamic> json = await _loadJson();
    final List<dynamic> items =
        json[bookId] as List<dynamic>? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ReaderBookmark.fromJson)
        .toList(growable: true);
  }

  Future<Map<String, List<ReaderBookmark>>> loadAllBookmarks() async {
    final Map<String, dynamic> json = await _loadJson();
    final Map<String, List<ReaderBookmark>> result =
        <String, List<ReaderBookmark>>{};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      result[entry.key] = (entry.value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ReaderBookmark.fromJson)
          .toList(growable: true);
    }
    return result;
  }

  Future<void> saveBookmark(ReaderBookmark bookmark) async {
    final Map<String, dynamic> json = await _loadJson();
    final List<ReaderBookmark> entries =
        (json[bookmark.bookId] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ReaderBookmark.fromJson)
            .toList(growable: true);

    final int existingIndex =
        entries.indexWhere((ReaderBookmark entry) => entry.id == bookmark.id);
    if (existingIndex >= 0) {
      entries[existingIndex] = bookmark;
    } else {
      entries.add(bookmark);
    }

    json[bookmark.bookId] =
        entries.map((ReaderBookmark entry) => entry.toJson()).toList();
    await _saveJson(json);
  }

  Future<void> removeBookmark(String bookId, String bookmarkId) async {
    final Map<String, dynamic> json = await _loadJson();
    final List<ReaderBookmark> entries =
        (json[bookId] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ReaderBookmark.fromJson)
            .toList(growable: true);

    entries.removeWhere((ReaderBookmark entry) => entry.id == bookmarkId);
    json[bookId] =
        entries.map((ReaderBookmark entry) => entry.toJson()).toList();
    await _saveJson(json);
  }

  Future<void> replaceAll(Map<String, List<ReaderBookmark>> bookmarks) async {
    final Map<String, dynamic> json = <String, dynamic>{
      for (final MapEntry<String, List<ReaderBookmark>> entry
          in bookmarks.entries)
        entry.key: entry.value
            .map((ReaderBookmark bookmark) => bookmark.toJson())
            .toList(),
    };
    await _saveJson(json);
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    await _saveJson(json);
  }

  Future<Map<String, dynamic>> _loadJson() async {
    final String? raw = await _storage.readString(_bookmarksKey);
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

  Future<void> _saveJson(Map<String, dynamic> json) async {
    await _storage.writeString(_bookmarksKey, jsonEncode(json));
  }

  String get _bookmarksKey =>
      'profiles/$_activeProfileId/reader/bookmarks.json';
}
