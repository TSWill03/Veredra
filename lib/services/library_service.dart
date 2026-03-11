import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/book_reference.dart';
import '../models/library_entry.dart';

class LibraryService {
  String _activeProfileId = 'principal';

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
  }

  Future<List<LibraryEntry>> loadEntries() async {
    final File file = await _libraryFile();
    if (!await file.exists()) {
      return <LibraryEntry>[];
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <LibraryEntry>[];
    }

    final dynamic decoded = jsonDecode(raw);
    final List<dynamic> entriesJson = decoded is Map<String, dynamic>
        ? decoded['entries'] as List<dynamic>? ?? const <dynamic>[]
        : const <dynamic>[];

    return entriesJson
        .whereType<Map<String, dynamic>>()
        .map(LibraryEntry.fromJson)
        .toList(growable: true);
  }

  Future<void> replaceEntries(List<LibraryEntry> entries) async {
    await _saveEntries(entries);
  }

  Future<void> upsertBook(Book book, {bool markOpened = false}) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int existingIndex = entries.indexWhere(
      (LibraryEntry entry) => entry.id == book.id,
    );
    final DateTime now = DateTime.now();

    final BookReference mergedReference = existingIndex >= 0
        ? _mergeReference(entries[existingIndex].reference, book.reference)
        : book.reference;

    final LibraryEntry nextEntry = existingIndex >= 0
        ? entries[existingIndex].copyWith(
            reference: mergedReference,
            chapterCount: book.chapterCount,
            lastOpenedAt:
                markOpened ? now : entries[existingIndex].lastOpenedAt,
          )
        : LibraryEntry(
            id: book.id,
            reference: mergedReference,
            chapterCount: book.chapterCount,
            importedAt: now,
            lastOpenedAt: markOpened ? now : null,
            isFavorite: false,
          );

    if (existingIndex >= 0) {
      entries[existingIndex] = nextEntry;
    } else {
      entries.add(nextEntry);
    }

    await _saveEntries(entries);
  }

  Future<void> markOpened(String bookId) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    entries[index] = entries[index].copyWith(lastOpenedAt: DateTime.now());
    await _saveEntries(entries);
  }

  Future<void> toggleFavorite(String bookId) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    entries[index] = entries[index].copyWith(
      isFavorite: !entries[index].isFavorite,
    );
    await _saveEntries(entries);
  }

  Future<void> updateReference(String bookId, BookReference reference) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    entries[index] = entries[index].copyWith(reference: reference);
    await _saveEntries(entries);
  }

  Future<void> updateCover(String bookId, String coverPath) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    entries[index] = entries[index].copyWith(
      reference: entries[index].reference.copyWith(coverPath: coverPath),
    );
    await _saveEntries(entries);
  }

  Future<void> updateCoverFrame(
    String bookId, {
    required double coverZoom,
    required double coverAlignmentX,
    required double coverAlignmentY,
  }) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    entries[index] = entries[index].copyWith(
      reference: entries[index].reference.copyWith(
            coverZoom: coverZoom,
            coverAlignmentX: coverAlignmentX,
            coverAlignmentY: coverAlignmentY,
          ),
    );
    await _saveEntries(entries);
  }

  Future<void> updateTitle(String bookId, String title) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    entries[index] = entries[index].copyWith(
      reference: entries[index].reference.copyWith(title: title),
    );
    await _saveEntries(entries);
  }

  Future<void> updateMetadata(
    String bookId, {
    required String title,
    String? altTitle,
    String? author,
    String? description,
    String? series,
    String? volume,
    List<String>? tags,
  }) async {
    final List<LibraryEntry> entries = await loadEntries();
    final int index =
        entries.indexWhere((LibraryEntry entry) => entry.id == bookId);
    if (index < 0) {
      return;
    }

    final BookReference reference = entries[index].reference;
    final List<String> normalizedTags = tags
            ?.map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false) ??
        reference.tags;

    entries[index] = entries[index].copyWith(
      reference: BookReference(
        title: title,
        format: reference.format,
        sourceLabel: reference.sourceLabel,
        directoryPath: reference.directoryPath,
        coverPath: reference.coverPath,
        author: _normalizeOptionalText(author),
        description: _normalizeOptionalText(description),
        series: _normalizeOptionalText(series),
        volume: _normalizeOptionalText(volume),
        altTitle: _normalizeOptionalText(altTitle),
        coverZoom: reference.coverZoom,
        coverAlignmentX: reference.coverAlignmentX,
        coverAlignmentY: reference.coverAlignmentY,
        tags: normalizedTags,
        assetPaths: reference.assetPaths,
      ),
    );
    await _saveEntries(entries);
  }

  Future<void> remove(String bookId) async {
    final List<LibraryEntry> entries = await loadEntries();
    entries.removeWhere((LibraryEntry entry) => entry.id == bookId);
    await _saveEntries(entries);
  }

  Future<Map<String, dynamic>> exportLibraryJson() async {
    return <String, dynamic>{
      'entries': (await loadEntries())
          .map((LibraryEntry entry) => entry.toJson())
          .toList(),
    };
  }

  Future<void> importLibraryJson(Map<String, dynamic> json) async {
    final List<LibraryEntry> entries =
        (json['entries'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(LibraryEntry.fromJson)
            .toList(growable: true);
    await _saveEntries(entries);
  }

  BookReference _mergeReference(
    BookReference existing,
    BookReference incoming,
  ) {
    return incoming.copyWith(
      title: existing.title,
      altTitle: existing.altTitle ?? incoming.altTitle,
      author: existing.author ?? incoming.author,
      description: existing.description ?? incoming.description,
      series: existing.series ?? incoming.series,
      volume: existing.volume ?? incoming.volume,
      tags: existing.tags.isNotEmpty ? existing.tags : incoming.tags,
      coverPath: incoming.coverPath ?? existing.coverPath,
      coverZoom: existing.coverZoom,
      coverAlignmentX: existing.coverAlignmentX,
      coverAlignmentY: existing.coverAlignmentY,
    );
  }

  String? _normalizeOptionalText(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _saveEntries(List<LibraryEntry> entries) async {
    final File file = await _libraryFile();
    await file.parent.create(recursive: true);
    final String payload = jsonEncode(
      <String, dynamic>{
        'entries': entries.map((LibraryEntry entry) => entry.toJson()).toList(),
      },
    );
    await file.writeAsString(payload, flush: true);
  }

  Future<File> _libraryFile() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return File(
      p.join(
        documentsDirectory.path,
        'profiles',
        _activeProfileId,
        'library',
        'library.json',
      ),
    );
  }
}
