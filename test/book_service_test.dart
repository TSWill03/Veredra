// Signature: dev.tswicolly03
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:txt_webnovel_reader/models/book_format.dart';
import 'package:txt_webnovel_reader/models/book_reference.dart';
import 'package:txt_webnovel_reader/services/book_service.dart';

void main() {
  test('BookService reports local file references as available', () async {
    final Directory tempDirectory =
        await Directory.systemTemp.createTemp('veredra_book_service_test_');
    addTearDown(() => tempDirectory.delete(recursive: true));

    final File chapter = File('${tempDirectory.path}/001.txt');
    await chapter.writeAsString('Capitulo local');

    final BookService service = BookService();
    final bool available = await service.isBookReferenceAvailable(
      BookReference(
        title: 'Livro local',
        format: BookFormat.text,
        sourceLabel: 'Teste',
        assetPaths: <String>[chapter.path],
      ),
    );

    expect(available, isTrue);
  });

  test('BookService normalizes markdown chapter content', () async {
    final Directory tempDirectory =
        await Directory.systemTemp.createTemp('veredra_markdown_test_');
    addTearDown(() => tempDirectory.delete(recursive: true));

    final File chapter = File('${tempDirectory.path}/001.md');
    await chapter.writeAsString('# Titulo\n\nTexto **forte**.');

    final BookService service = BookService();
    final book = await service.loadTextBookFromFiles(
      <String>[chapter.path],
      sourceLabel: 'Teste',
      copyToManagedStorage: false,
    );

    final String content =
        await service.readChapterContent(book.chapters.first);

    expect(content, contains('Titulo'));
    expect(content, contains('Texto forte.'));
    expect(content, isNot(contains('**')));
  });

  test('BookReference keeps browser-persisted chapter paths', () {
    const BookReference reference = BookReference(
      title: 'Web',
      format: BookFormat.text,
      sourceLabel: 'Navegador',
      assetPaths: <String>[
        'veredra://profiles/principal/storage/imported_text_books/a/1.txt',
      ],
    );

    final BookReference decoded = BookReference.fromJson(reference.toJson());

    expect(decoded.assetPaths.single, startsWith('veredra://'));
  });
}
