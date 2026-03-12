// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';

import 'package:txt_webnovel_reader/models/book_format.dart';
import 'package:txt_webnovel_reader/models/book_reference.dart';
import 'package:txt_webnovel_reader/models/reader_font_preset.dart';
import 'package:txt_webnovel_reader/models/reading_progress.dart';

void main() {
  test('BookReference serializes imported EPUB metadata', () {
    const BookReference reference = BookReference(
      title: 'Meu Livro',
      format: BookFormat.epub,
      sourceLabel: 'EPUB convertido',
      coverPath: '/books/meu_livro/cover.png',
      assetPaths: <String>[
        '/books/meu_livro/0001 - Prologo.txt',
        '/books/meu_livro/0002 - Capitulo 1.txt',
      ],
    );

    final BookReference? decoded = BookReference.decode(reference.encode());

    expect(decoded, isNotNull);
    expect(decoded!.title, 'Meu Livro');
    expect(decoded.format, BookFormat.epub);
    expect(decoded.coverPath, '/books/meu_livro/cover.png');
    expect(decoded.assetPaths.length, 2);
    expect(decoded.subtitle, 'EPUB convertido - 2 capitulos');
  });

  test('ReadingProgress clamps progress to a valid range', () {
    final ReadingProgress progress = ReadingProgress.fromJson(
      <String, dynamic>{
        'chapterIndex': 7,
        'chapterOffset': 320.0,
        'chapterProgress': 2.4,
        'savedAt': '2026-03-10T18:00:00.000',
      },
    );

    expect(progress.chapterIndex, 7);
    expect(progress.chapterOffset, 320.0);
    expect(progress.chapterProgress, 1.0);
    expect(progress.savedAt.year, 2026);
  });

  test('ReaderFontPreset falls back safely for unknown values', () {
    expect(readerFontPresetFromId('serif'), ReaderFontPreset.serif);
    expect(readerFontPresetFromId('desconhecido'), ReaderFontPreset.system);
  });
}
