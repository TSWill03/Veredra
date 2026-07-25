// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/models/book_format.dart';
import 'package:txt_webnovel_reader/models/book_reference.dart';
import 'package:txt_webnovel_reader/models/generated_chapter.dart';
import 'package:txt_webnovel_reader/models/library_entry.dart';
import 'package:txt_webnovel_reader/services/sync/book_asset_package.dart';

void main() {
  final LibraryEntry entry = LibraryEntry(
    id: 'book-super-gene',
    reference: const BookReference(
      title: 'Super Gene',
      format: BookFormat.text,
      sourceLabel: 'Teste',
      tags: <String>['traducao'],
      assetPaths: <String>['local-1.txt', 'local-2.txt'],
    ),
    chapterCount: 2,
    importedAt: DateTime.utc(2026, 7, 25),
    isFavorite: true,
  );

  test('encodes and decodes a verified package', () {
    final BookAssetPackage package = BookAssetPackageCodec.encode(
      entry: entry,
      chapters: const <GeneratedChapter>[
        GeneratedChapter(title: 'Capitulo 1', content: 'Conteudo um'),
        GeneratedChapter(title: 'Capitulo 2', content: 'Conteudo dois'),
      ],
    );

    expect(package.checksumSha256, hasLength(64));
    final DecodedBookAssetPackage decoded = BookAssetPackageCodec.decode(
      package.bytes,
      expectedChecksum: package.checksumSha256,
    );

    expect(decoded.entry.id, entry.id);
    expect(decoded.entry.reference.title, 'Super Gene');
    expect(decoded.chapters, hasLength(2));
    expect(decoded.chapters.last.content, 'Conteudo dois');
  });

  test('rejects a package changed after checksum generation', () {
    final BookAssetPackage package = BookAssetPackageCodec.encode(
      entry: entry,
      chapters: const <GeneratedChapter>[
        GeneratedChapter(title: 'Capitulo 1', content: 'Original'),
      ],
    );
    final Uint8List changed = Uint8List.fromList(package.bytes);
    changed[changed.length - 1] ^= 0xff;

    expect(
      () => BookAssetPackageCodec.decode(
        changed,
        expectedChecksum: package.checksumSha256,
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('SHA-256'),
        ),
      ),
    );
  });
}
