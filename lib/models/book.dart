import 'book_format.dart';
import 'book_reference.dart';
import 'chapter.dart';

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.reference,
    required this.chapters,
  });

  final String id;
  final String title;
  final BookReference reference;
  final List<Chapter> chapters;

  int get chapterCount => chapters.length;
  BookFormat get format => reference.format;
  bool get usesTextReader => format.usesTextReader;
  String? get coverPath => reference.coverPath;

  Book copyWith({
    String? id,
    String? title,
    BookReference? reference,
    List<Chapter>? chapters,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      reference: reference ?? this.reference,
      chapters: chapters ?? this.chapters,
    );
  }
}
