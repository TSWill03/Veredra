// Signature: dev.tswicolly03
import 'dart:convert';

import 'reader_highlight_color.dart';

class ReaderAnnotation {
  const ReaderAnnotation({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.createdAt,
    required this.color,
    this.note,
    this.isFavorite = false,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final DateTime createdAt;
  final ReaderHighlightColor color;
  final String? note;
  final bool isFavorite;

  ReaderAnnotation copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
    int? startOffset,
    int? endOffset,
    String? selectedText,
    DateTime? createdAt,
    ReaderHighlightColor? color,
    String? note,
    bool? isFavorite,
  }) {
    return ReaderAnnotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      selectedText: selectedText ?? this.selectedText,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      note: note ?? this.note,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'selectedText': selectedText,
      'createdAt': createdAt.toIso8601String(),
      'color': color.name,
      'note': note,
      'isFavorite': isFavorite,
    };
  }

  String encode() => jsonEncode(toJson());

  factory ReaderAnnotation.fromJson(Map<String, dynamic> json) {
    return ReaderAnnotation(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterTitle: json['chapterTitle'] as String? ?? 'Capitulo',
      startOffset: (json['startOffset'] as num?)?.toInt() ?? 0,
      endOffset: (json['endOffset'] as num?)?.toInt() ?? 0,
      selectedText: json['selectedText'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      color: readerHighlightColorFromId(json['color'] as String?),
      note: json['note'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
