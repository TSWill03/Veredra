// Signature: dev.tswicolly03
import 'book_reference.dart';

class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.reference,
    required this.chapterCount,
    required this.importedAt,
    required this.isFavorite,
    this.lastOpenedAt,
  });

  final String id;
  final BookReference reference;
  final int chapterCount;
  final DateTime importedAt;
  final DateTime? lastOpenedAt;
  final bool isFavorite;

  String get title => reference.title;

  LibraryEntry copyWith({
    BookReference? reference,
    int? chapterCount,
    DateTime? importedAt,
    DateTime? lastOpenedAt,
    bool? isFavorite,
  }) {
    return LibraryEntry(
      id: id,
      reference: reference ?? this.reference,
      chapterCount: chapterCount ?? this.chapterCount,
      importedAt: importedAt ?? this.importedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'reference': reference.toJson(),
      'chapterCount': chapterCount,
      'importedAt': importedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory LibraryEntry.fromJson(Map<String, dynamic> json) {
    return LibraryEntry(
      id: json['id'] as String? ?? '',
      reference: BookReference.fromJson(
        json['reference'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      chapterCount: (json['chapterCount'] as num?)?.toInt() ?? 0,
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.now(),
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? ''),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
