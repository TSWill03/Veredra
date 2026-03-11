import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/reader_annotation.dart';

class AnnotationService {
  String _activeProfileId = 'principal';

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
  }

  Future<List<ReaderAnnotation>> loadAnnotations(String bookId) async {
    final Map<String, dynamic> json = await _loadJson();
    final List<dynamic> items =
        json[bookId] as List<dynamic>? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ReaderAnnotation.fromJson)
        .toList(growable: true);
  }

  Future<Map<String, List<ReaderAnnotation>>> loadAllAnnotations() async {
    final Map<String, dynamic> json = await _loadJson();
    final Map<String, List<ReaderAnnotation>> result =
        <String, List<ReaderAnnotation>>{};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      result[entry.key] = (entry.value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ReaderAnnotation.fromJson)
          .toList(growable: true);
    }
    return result;
  }

  Future<void> saveAnnotation(ReaderAnnotation annotation) async {
    final Map<String, dynamic> json = await _loadJson();
    final List<ReaderAnnotation> entries =
        (json[annotation.bookId] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ReaderAnnotation.fromJson)
            .toList(growable: true);

    final int existingIndex = entries
        .indexWhere((ReaderAnnotation entry) => entry.id == annotation.id);
    if (existingIndex >= 0) {
      entries[existingIndex] = annotation;
    } else {
      entries.add(annotation);
    }

    json[annotation.bookId] =
        entries.map((ReaderAnnotation entry) => entry.toJson()).toList();
    await _saveJson(json);
  }

  Future<void> removeAnnotation(String bookId, String annotationId) async {
    final Map<String, dynamic> json = await _loadJson();
    final List<ReaderAnnotation> entries =
        (json[bookId] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ReaderAnnotation.fromJson)
            .toList(growable: true);

    entries.removeWhere((ReaderAnnotation entry) => entry.id == annotationId);
    json[bookId] =
        entries.map((ReaderAnnotation entry) => entry.toJson()).toList();
    await _saveJson(json);
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    await _saveJson(json);
  }

  Future<Map<String, dynamic>> _loadJson() async {
    final File file = await _annotationsFile();
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    final String raw = await file.readAsString();
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
    final File file = await _annotationsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  Future<File> _annotationsFile() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return File(
      p.join(
        documentsDirectory.path,
        'profiles',
        _activeProfileId,
        'reader',
        'annotations.json',
      ),
    );
  }
}
