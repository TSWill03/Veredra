// Signature: dev.tswicolly03
enum BookFormat { text, epub, pdf }

extension BookFormatX on BookFormat {
  bool get usesTextReader => this != BookFormat.pdf;

  String get label {
    switch (this) {
      case BookFormat.text:
        return 'Texto';
      case BookFormat.epub:
        return 'EPUB';
      case BookFormat.pdf:
        return 'PDF';
    }
  }

  String get storageLabel {
    switch (this) {
      case BookFormat.text:
        return 'TXT / MD / HTML';
      case BookFormat.epub:
        return 'EPUB';
      case BookFormat.pdf:
        return 'PDF';
    }
  }
}
