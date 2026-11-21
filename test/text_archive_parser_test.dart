// Signature: dev.tswicolly03
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/import/text_archive_parser.dart';

void main() {
  test('orders thousands-style chapter names naturally', () {
    final List<int> zip = _buildZip(<String, String>{
      'SuperGene/10.txt': 'Decimo',
      'SuperGene/2.txt': 'Segundo',
      'SuperGene/1.txt': 'Primeiro',
      'SuperGene/.hidden.txt': 'Ignorado',
      '__MACOSX/metadata.txt': 'Ignorado',
    });

    final TextArchiveImportResult result = TextArchiveParser.parse(
      zip,
      sourceName: 'SuperGene.zip',
    );

    expect(result.title, 'SuperGene');
    expect(result.chapters.map((chapter) => chapter.title), <String>[
      '1',
      '2',
      '10',
    ]);
    expect(result.chapters.map((chapter) => chapter.content), <String>[
      'Primeiro',
      'Segundo',
      'Decimo',
    ]);
    expect(result.ignoredEntries, 2);
  });

  test('normalizes Markdown and HTML chapters', () {
    final List<int> zip = _buildZip(<String, String>{
      '1.md': '# Titulo\n\nTexto em **negrito**.',
      '2.html': '<h1>Outro</h1><p>Conteudo</p>',
    });

    final TextArchiveImportResult result = TextArchiveParser.parse(
      zip,
      sourceName: 'Livro.zip',
    );

    expect(result.chapters[0].content, contains('Texto em negrito.'));
    expect(result.chapters[1].content, contains('Conteudo'));
    expect(result.chapters[1].content, isNot(contains('<p>')));
  });

  test('rejects path traversal entries', () {
    final List<int> zip = _buildZip(<String, String>{
      '../segredo.txt': 'Nao deve ser extraido',
    });

    expect(
      () => TextArchiveParser.parse(zip, sourceName: 'inseguro.zip'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('caminho inseguro'),
        ),
      ),
    );
  });

  test('rejects duplicate chapter paths ignoring case', () {
    final Archive archive = Archive()
      ..addFile(_archiveFile('Capitulo.txt', 'A'))
      ..addFile(_archiveFile('CAPITULO.TXT', 'B'));
    final List<int> zip = ZipEncoder().encode(archive)!;

    expect(
      () => TextArchiveParser.parse(zip, sourceName: 'duplicado.zip'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('duplicados'),
        ),
      ),
    );
  });

  test('rejects archives without supported readable chapters', () {
    final List<int> zip = _buildZip(<String, String>{
      'capa.jpg': 'nao e texto',
      'dados.json': '{}',
    });

    expect(
      () => TextArchiveParser.parse(zip, sourceName: 'vazio.zip'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('Nenhum TXT'),
        ),
      ),
    );
  });
}

List<int> _buildZip(Map<String, String> files) {
  final Archive archive = Archive();
  for (final MapEntry<String, String> entry in files.entries) {
    archive.addFile(_archiveFile(entry.key, entry.value));
  }
  return ZipEncoder().encode(archive)!;
}

ArchiveFile _archiveFile(String name, String content) {
  final List<int> bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}
