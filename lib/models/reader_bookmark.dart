import 'dart:convert';

class ReaderBookmark {
  const ReaderBookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.chapterProgress,
    required this.createdAt,
    this.note,
    this.excerpt,
    this.isFavorite = false,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final double chapterProgress;
  final DateTime createdAt;
  final String? note;
  final String? excerpt;
  final bool isFavorite;

  ReaderBookmark copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
    double? chapterProgress,
    DateTime? createdAt,
    String? note,
    String? excerpt,
    bool? isFavorite,
  }) {
    return ReaderBookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      excerpt: excerpt ?? this.excerpt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'chapterProgress': chapterProgress,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      'excerpt': excerpt,
      'isFavorite': isFavorite,
    };
  }

  String encode() => jsonEncode(toJson());

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    return ReaderBookmark(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterTitle: json['chapterTitle'] as String? ?? 'Capitulo',
      chapterProgress: (json['chapterProgress'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      note: json['note'] as String?,
      excerpt: json['excerpt'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
