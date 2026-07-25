// Signature: dev.tswicolly03
enum ImportPayloadKind { text, epub, pdf, image }

class ImportLimits {
  const ImportLimits._();

  static const int maxTextFileBytes = 16 * 1024 * 1024;
  static const int maxTextTotalBytes = 128 * 1024 * 1024;
  static const int maxTextFileCount = 5000;
  static const int maxEpubBytes = 100 * 1024 * 1024;
  static const int maxPdfBytes = 256 * 1024 * 1024;
  static const int maxImageBytes = 20 * 1024 * 1024;
  static const int maxExtractedCharacters = 64 * 1024 * 1024;

  static void validateFileSize(
    ImportPayloadKind kind,
    int bytes, {
    required String label,
  }) {
    final int limit = switch (kind) {
      ImportPayloadKind.text => maxTextFileBytes,
      ImportPayloadKind.epub => maxEpubBytes,
      ImportPayloadKind.pdf => maxPdfBytes,
      ImportPayloadKind.image => maxImageBytes,
    };
    if (bytes < 0 || bytes > limit) {
      throw StateError(
        '$label excede o limite seguro de ${_megabytes(limit)} MB.',
      );
    }
  }

  static void validateTextCollection(Iterable<int> sizes) {
    final List<int> values = sizes.toList(growable: false);
    if (values.length > maxTextFileCount) {
      throw StateError(
        'A importacao excede o limite seguro de $maxTextFileCount arquivos.',
      );
    }
    int total = 0;
    for (final int size in values) {
      validateFileSize(ImportPayloadKind.text, size, label: 'Um capitulo');
      total += size;
      if (total > maxTextTotalBytes) {
        throw StateError(
          'Os capitulos excedem o limite total de '
          '${_megabytes(maxTextTotalBytes)} MB.',
        );
      }
    }
  }

  static void validateExtractedText(Iterable<String> chapters) {
    int characters = 0;
    for (final String chapter in chapters) {
      characters += chapter.length;
      if (characters > maxExtractedCharacters) {
        throw StateError(
          'O conteudo extraido excede o limite seguro. O arquivo pode estar '
          'corrompido ou compactado de forma maliciosa.',
        );
      }
    }
  }

  static int _megabytes(int bytes) => bytes ~/ (1024 * 1024);
}
