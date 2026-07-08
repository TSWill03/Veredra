// Signature: dev.tswicolly03
import '../models/book.dart';
import '../models/translation_engine_status.dart';
import '../models/translation_language.dart';
import '../models/translation_pair.dart';
import '../models/translation_progress.dart';
import 'book_service.dart';

class TranslationService {
  void configureProfile(String profileId) {}

  bool get supportsLocalTranslation => false;

  Future<TranslationEngineStatus> inspectLocalEngine() async {
    return const TranslationEngineStatus(
      supported: false,
      pythonDetected: false,
      argosInstalled: false,
      onlineIndexAvailable: false,
      pythonCommandLabel: null,
      pythonVersion: null,
      installedPairs: <TranslationPair>[],
      availablePairs: <TranslationPair>[],
      message: 'A traducao local com Argos esta disponivel apenas no desktop.',
    );
  }

  Future<void> installArgosPackage() async {
    _throwUnsupported();
  }

  Future<void> installModel(TranslationPair pair) async {
    _throwUnsupported();
  }

  Future<Book> translateBook({
    required Book sourceBook,
    required TranslationLanguage sourceLanguage,
    required TranslationLanguage targetLanguage,
    required BookService bookService,
    void Function(TranslationProgress value)? onProgress,
  }) async {
    _throwUnsupported();
  }

  Never _throwUnsupported() {
    throw StateError(
      'A traducao local com Argos esta disponivel apenas no desktop.',
    );
  }
}
