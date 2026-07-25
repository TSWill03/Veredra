// Signature: dev.tswicolly03

import 'book_service.dart';
import 'library_service.dart';

class TranslationRecoveryResult {
  const TranslationRecoveryResult({
    required this.recoveredCount,
    required this.skippedCount,
  });

  final int recoveredCount;
  final int skippedCount;
}

class TranslationRecoveryService {
  const TranslationRecoveryService({
    required this.bookService,
    required this.libraryService,
  });

  final BookService bookService;
  final LibraryService libraryService;

  Future<TranslationRecoveryResult> recover(String profileId) async {
    return const TranslationRecoveryResult(
      recoveredCount: 0,
      skippedCount: 0,
    );
  }
}
