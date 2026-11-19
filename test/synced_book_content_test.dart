// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/models/book_format.dart';
import 'package:txt_webnovel_reader/models/book_reference.dart';
import 'package:txt_webnovel_reader/models/library_entry.dart';

void main() {
  LibraryEntry entry({
    required String sourceLabel,
    List<String> assetPaths = const <String>[],
  }) =>
      LibraryEntry(
        id: 'synced-book',
        reference: BookReference(
          title: 'I have a Super Usb Drive',
          format: BookFormat.text,
          sourceLabel: sourceLabel,
          assetPaths: assetPaths,
        ),
        chapterCount: 645,
        importedAt: DateTime.utc(2026),
        isFavorite: false,
      );

  test('metadata from sync is not mistaken for downloaded chapters', () {
    final LibraryEntry metadata = entry(
      sourceLabel: 'Metadados sincronizados',
    );
    expect(metadata.chapterCount, 645);
    expect(metadata.reference.assetPaths, isEmpty);
    expect(metadata.hasOnlySyncedMetadata, isTrue);
  });

  test('a local text book is not flagged as metadata-only', () {
    final LibraryEntry local = entry(
      sourceLabel: 'Arquivos importados',
      assetPaths: <String>['chapter1.txt'],
    );
    expect(local.hasOnlySyncedMetadata, isFalse);
  });
}
