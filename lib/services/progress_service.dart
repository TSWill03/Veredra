import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_format.dart';
import '../models/book_reference.dart';
import '../models/reader_background_preset.dart';
import '../models/reader_font_preset.dart';
import '../models/reader_preferences.dart';
import '../models/reader_text_align_preset.dart';
import '../models/reading_progress.dart';

/// O app salva configuracoes e progresso em um arquivo por perfil.
/// Isso facilita backup, exportacao e troca de usuario local sem misturar dados.
class ProgressService {
  static const String _legacyThemeKey = 'app.themeMode';
  static const String _legacyFontSizeKey = 'app.fontSize';
  static const String _legacyReaderFontKey = 'app.readerFontPreset';
  static const String _legacyLastBookReferenceKey = 'app.lastBookReference';
  static const String _legacyLastBookPathKey = 'app.lastBookPath';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  String _activeProfileId = 'principal';
  Future<void> _pendingOperation = Future<void>.value();

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
  }

  Future<ThemeMode> loadThemeMode() async {
    return _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      switch (state.themeMode) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        default:
          return ThemeMode.dark;
      }
    });
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    await _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      final _ProgressState nextState = state.copyWith(
        themeMode: themeMode == ThemeMode.light ? 'light' : 'dark',
      );
      await _saveStateUnsafe(nextState);
    });
  }

  Future<ReaderPreferences> loadReaderPreferences() async {
    return _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      return state.readerPreferences;
    });
  }

  Future<void> saveReaderPreferences(ReaderPreferences preferences) async {
    await _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      await _saveStateUnsafe(
        state.copyWith(readerPreferences: preferences),
      );
    });
  }

  Future<double> loadFontSize() async {
    return (await loadReaderPreferences()).fontSize;
  }

  Future<void> saveFontSize(double fontSize) async {
    final ReaderPreferences preferences = await loadReaderPreferences();
    await saveReaderPreferences(preferences.copyWith(fontSize: fontSize));
  }

  Future<ReaderFontPreset> loadReaderFontPreset() async {
    return (await loadReaderPreferences()).fontPreset;
  }

  Future<void> saveReaderFontPreset(ReaderFontPreset preset) async {
    final ReaderPreferences preferences = await loadReaderPreferences();
    await saveReaderPreferences(preferences.copyWith(fontPreset: preset));
  }

  Future<ReaderBackgroundPreset> loadReaderBackgroundPreset() async {
    return (await loadReaderPreferences()).backgroundPreset;
  }

  Future<void> saveReaderBackgroundPreset(ReaderBackgroundPreset preset) async {
    final ReaderPreferences preferences = await loadReaderPreferences();
    await saveReaderPreferences(
      preferences.copyWith(backgroundPreset: preset),
    );
  }

  Future<ReaderTextAlignPreset> loadReaderTextAlignPreset() async {
    return (await loadReaderPreferences()).textAlignPreset;
  }

  Future<void> saveReaderTextAlignPreset(ReaderTextAlignPreset preset) async {
    final ReaderPreferences preferences = await loadReaderPreferences();
    await saveReaderPreferences(preferences.copyWith(textAlignPreset: preset));
  }

  Future<BookReference?> loadLastBookReference() async {
    return _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      return state.lastBookReference;
    });
  }

  Future<void> saveLastBookReference(BookReference reference) async {
    await _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      await _saveStateUnsafe(state.copyWith(lastBookReference: reference));
    });
  }

  Future<ReadingProgress?> loadProgress(String bookId) async {
    return _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      final dynamic raw = state.progresses[_encodeBookId(bookId)];
      if (raw is! Map<String, dynamic>) {
        return null;
      }
      return ReadingProgress.fromJson(raw);
    });
  }

  Future<void> saveProgress(String bookId, ReadingProgress progress) async {
    await _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      final Map<String, Map<String, dynamic>> nextProgresses =
          Map<String, Map<String, dynamic>>.from(state.progresses);
      nextProgresses[_encodeBookId(bookId)] = progress.toJson();
      await _saveStateUnsafe(state.copyWith(progresses: nextProgresses));
    });
  }

  Future<Map<String, dynamic>> exportState() async {
    return _runSerialized(() async {
      final _ProgressState state = await _loadStateUnsafe();
      return state.toJson();
    });
  }

  Future<void> importState(Map<String, dynamic> json) async {
    await _runSerialized(() async {
      await _saveStateUnsafe(_ProgressState.fromJson(json));
    });
  }

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _pendingOperation =
        _pendingOperation.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<_ProgressState> _loadStateUnsafe() async {
    final File file = await _stateFile();
    if (!await file.exists()) {
      final _ProgressState migrated = await _migrateLegacyStateIfAvailable();
      await _saveStateUnsafe(migrated);
      return migrated;
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      final _ProgressState defaults = _ProgressState.defaults();
      await _saveStateUnsafe(defaults);
      return defaults;
    }

    final Map<String, dynamic>? decoded = _tryDecodeStatePayload(raw);
    if (decoded != null) {
      final _ProgressState state = _ProgressState.fromJson(decoded);
      final String normalized = jsonEncode(state.toJson());
      if (normalized != raw) {
        await _saveStateUnsafe(state);
      }
      return state;
    }

    return _recoverStateFromCorruption(file, raw);
  }

  Future<_ProgressState> _recoverStateFromCorruption(
    File file,
    String raw,
  ) async {
    final _ProgressState recovered = await _migrateLegacyStateIfAvailable();
    final String timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final File backupFile = File(
      p.join(
        file.parent.path,
        'progress_state.corrupt.$timestamp.json',
      ),
    );
    await backupFile.writeAsString(raw, flush: true);
    await _saveStateUnsafe(recovered);
    return recovered;
  }

  Map<String, dynamic>? _tryDecodeStatePayload(String raw) {
    final String trimmed = raw.trim();
    final dynamic exact = _tryJsonDecode(trimmed);
    if (exact is Map<String, dynamic>) {
      return exact;
    }

    for (int index = trimmed.length - 1; index >= 0; index--) {
      if (trimmed.codeUnitAt(index) != 0x7D) {
        continue;
      }

      final dynamic candidate = _tryJsonDecode(trimmed.substring(0, index + 1));
      if (candidate is Map<String, dynamic>) {
        return candidate;
      }
    }

    return null;
  }

  dynamic _tryJsonDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _saveStateUnsafe(_ProgressState state) async {
    final File file = await _stateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(state.toJson()),
      flush: true,
    );
  }

  Future<_ProgressState> _migrateLegacyStateIfAvailable() async {
    final ThemeMode themeMode = await _loadLegacyThemeMode();
    final double fontSize = await _preferences.getDouble(_legacyFontSizeKey) ??
        ReaderPreferences.defaults.fontSize;
    final ReaderFontPreset fontPreset = readerFontPresetFromId(
      await _preferences.getString(_legacyReaderFontKey),
    );
    final BookReference? lastBookReference =
        await _loadLegacyLastBookReference();

    return _ProgressState(
      themeMode: themeMode == ThemeMode.light ? 'light' : 'dark',
      lastBookReference: lastBookReference,
      readerPreferences: ReaderPreferences.defaults.copyWith(
        fontSize: fontSize,
        fontPreset: fontPreset,
      ),
      progresses: <String, Map<String, dynamic>>{},
    );
  }

  Future<ThemeMode> _loadLegacyThemeMode() async {
    final String? raw = await _preferences.getString(_legacyThemeKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }

  Future<BookReference?> _loadLegacyLastBookReference() async {
    final String? raw =
        await _preferences.getString(_legacyLastBookReferenceKey);
    final BookReference? reference = BookReference.decode(raw);
    if (reference != null) {
      return reference;
    }

    final String? legacyPath =
        await _preferences.getString(_legacyLastBookPathKey);
    if (legacyPath == null || legacyPath.isEmpty) {
      return null;
    }

    return BookReference(
      title: p.basename(legacyPath),
      format: BookFormat.text,
      sourceLabel: 'Pasta local',
      directoryPath: legacyPath,
    );
  }

  Future<File> _stateFile() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return File(
      p.join(
        documentsDirectory.path,
        'profiles',
        _activeProfileId,
        'state',
        'progress_state.json',
      ),
    );
  }

  String _encodeBookId(String bookId) => Uri.encodeComponent(bookId);
}

class _ProgressState {
  const _ProgressState({
    required this.themeMode,
    required this.lastBookReference,
    required this.readerPreferences,
    required this.progresses,
  });

  final String themeMode;
  final BookReference? lastBookReference;
  final ReaderPreferences readerPreferences;
  final Map<String, Map<String, dynamic>> progresses;

  factory _ProgressState.defaults() {
    return const _ProgressState(
      themeMode: 'dark',
      lastBookReference: null,
      readerPreferences: ReaderPreferences.defaults,
      progresses: <String, Map<String, dynamic>>{},
    );
  }

  _ProgressState copyWith({
    String? themeMode,
    BookReference? lastBookReference,
    ReaderPreferences? readerPreferences,
    Map<String, Map<String, dynamic>>? progresses,
  }) {
    return _ProgressState(
      themeMode: themeMode ?? this.themeMode,
      lastBookReference: lastBookReference ?? this.lastBookReference,
      readerPreferences: readerPreferences ?? this.readerPreferences,
      progresses: progresses ?? this.progresses,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themeMode': themeMode,
      'lastBookReference': lastBookReference?.toJson(),
      'readerPreferences': readerPreferences.toJson(),
      'progresses': progresses,
    };
  }

  factory _ProgressState.fromJson(Map<String, dynamic> json) {
    final dynamic rawProgresses = json['progresses'];
    final Map<String, Map<String, dynamic>> progresses =
        <String, Map<String, dynamic>>{};
    if (rawProgresses is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawProgresses.entries) {
        if (entry.value is Map<String, dynamic>) {
          progresses[entry.key] = Map<String, dynamic>.from(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    return _ProgressState(
      themeMode: json['themeMode'] as String? ?? 'dark',
      lastBookReference: json['lastBookReference'] is Map<String, dynamic>
          ? BookReference.fromJson(
              json['lastBookReference'] as Map<String, dynamic>,
            )
          : null,
      readerPreferences: json['readerPreferences'] is Map<String, dynamic>
          ? ReaderPreferences.fromJson(
              json['readerPreferences'] as Map<String, dynamic>,
            )
          : ReaderPreferences.defaults,
      progresses: progresses,
    );
  }
}
