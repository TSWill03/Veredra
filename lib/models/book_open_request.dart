// Signature: dev.tswicolly03
import 'book_reference.dart';

class BookOpenRequest {
  const BookOpenRequest({
    required this.reference,
    this.chapterIndex,
    this.chapterProgress,
  });

  final BookReference reference;
  final int? chapterIndex;
  final double? chapterProgress;
}
