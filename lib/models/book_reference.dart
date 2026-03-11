import 'dart:convert';

import 'book_format.dart';

class BookReference {
  const BookReference({
    required this.title,
    required this.format,
    required this.sourceLabel,
    this.directoryPath,
    this.coverPath,
    this.author,
    this.description,
    this.series,
    this.volume,
    this.altTitle,
    this.coverZoom = 1,
    this.coverAlignmentX = 0,
    this.coverAlignmentY = 0,
    this.tags = const <String>[],
    this.assetPaths = const <String>[],
  });

  final String title;
  final BookFormat format;
  final String sourceLabel;
  final String? directoryPath;
  final String? coverPath;
  final String? author;
  final String? description;
  final String? series;
  final String? volume;
  final String? altTitle;
  final double coverZoom;
  final double coverAlignmentX;
  final double coverAlignmentY;
  final List<String> tags;
  final List<String> assetPaths;

  bool get usesDirectory => directoryPath != null && directoryPath!.isNotEmpty;
  bool get usesTextReader => format.usesTextReader;
  bool get isPdf => format == BookFormat.pdf;
  bool get hasCover => coverPath != null && coverPath!.isNotEmpty;
  bool get hasMetadata =>
      (author?.trim().isNotEmpty ?? false) ||
      (description?.trim().isNotEmpty ?? false) ||
      (series?.trim().isNotEmpty ?? false) ||
      (volume?.trim().isNotEmpty ?? false) ||
      (altTitle?.trim().isNotEmpty ?? false) ||
      tags.isNotEmpty;
  String? get primaryAssetPath => assetPaths.isEmpty ? null : assetPaths.first;

  String get subtitle {
    final List<String> parts = <String>[];
    if (author?.trim().isNotEmpty ?? false) {
      parts.add(author!.trim());
    }

    if (usesDirectory) {
      parts.add(directoryPath ?? '');
    } else if (isPdf) {
      parts.add('Documento PDF importado');
    } else {
      parts.add('$sourceLabel - ${assetPaths.length} capitulos');
    }

    return parts.where((String value) => value.trim().isNotEmpty).join(' - ');
  }

  String get searchMetadata {
    return <String>[
      title,
      altTitle ?? '',
      author ?? '',
      description ?? '',
      series ?? '',
      volume ?? '',
      ...tags,
      sourceLabel,
    ].join(' ').toLowerCase();
  }

  BookReference copyWith({
    String? title,
    BookFormat? format,
    String? sourceLabel,
    String? directoryPath,
    String? coverPath,
    String? author,
    String? description,
    String? series,
    String? volume,
    String? altTitle,
    double? coverZoom,
    double? coverAlignmentX,
    double? coverAlignmentY,
    List<String>? tags,
    List<String>? assetPaths,
  }) {
    return BookReference(
      title: title ?? this.title,
      format: format ?? this.format,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      directoryPath: directoryPath ?? this.directoryPath,
      coverPath: coverPath ?? this.coverPath,
      author: author ?? this.author,
      description: description ?? this.description,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      altTitle: altTitle ?? this.altTitle,
      coverZoom: coverZoom ?? this.coverZoom,
      coverAlignmentX: coverAlignmentX ?? this.coverAlignmentX,
      coverAlignmentY: coverAlignmentY ?? this.coverAlignmentY,
      tags: tags ?? this.tags,
      assetPaths: assetPaths ?? this.assetPaths,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'format': format.name,
      'sourceLabel': sourceLabel,
      'directoryPath': directoryPath,
      'coverPath': coverPath,
      'author': author,
      'description': description,
      'series': series,
      'volume': volume,
      'altTitle': altTitle,
      'coverZoom': coverZoom,
      'coverAlignmentX': coverAlignmentX,
      'coverAlignmentY': coverAlignmentY,
      'tags': tags,
      'assetPaths': assetPaths,
    };
  }

  String encode() => jsonEncode(toJson());

  static BookReference? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return BookReference.fromJson(decoded);
  }

  factory BookReference.fromJson(Map<String, dynamic> json) {
    final String formatName = json['format'] as String? ?? 'text';
    final List<String> assetPaths =
        (json['assetPaths'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);
    final List<String> tags =
        (json['tags'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);

    BookFormat format = BookFormat.text;
    for (final BookFormat value in BookFormat.values) {
      if (value.name == formatName) {
        format = value;
        break;
      }
    }

    return BookReference(
      title: json['title'] as String? ?? 'Livro',
      format: format,
      sourceLabel: json['sourceLabel'] as String? ?? format.storageLabel,
      directoryPath: json['directoryPath'] as String?,
      coverPath: json['coverPath'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
      series: json['series'] as String?,
      volume: json['volume'] as String?,
      altTitle: json['altTitle'] as String?,
      coverZoom: (json['coverZoom'] as num?)?.toDouble() ?? 1,
      coverAlignmentX: (json['coverAlignmentX'] as num?)?.toDouble() ?? 0,
      coverAlignmentY: (json['coverAlignmentY'] as num?)?.toDouble() ?? 0,
      tags: tags,
      assetPaths: assetPaths,
    );
  }
}
