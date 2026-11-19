// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/models/book_format.dart';
import 'package:txt_webnovel_reader/models/book_reference.dart';
import 'package:txt_webnovel_reader/models/library_entry.dart';
import 'package:txt_webnovel_reader/services/book_service.dart';
import 'package:txt_webnovel_reader/services/library_service.dart';
import 'package:txt_webnovel_reader/services/sync/book_file_remote_gateway.dart';
import 'package:txt_webnovel_reader/services/sync/book_file_sync_service.dart';

import 'support/memory_app_storage.dart';

class FakeBookFileGateway implements BookFileRemoteGateway {
  final Map<String, RemoteBookAsset> records = <String, RemoteBookAsset>{};
  final Map<String, Uint8List> blobs = <String, Uint8List>{};
  int uploaded = 0;
  bool corrupt = false;

  @override
  Future<List<RemoteBookAsset>> listAssets({required String userId}) async =>
      records.values
          .where((asset) => asset.storagePath.startsWith('$userId/'))
          .toList();

  @override
  Future<void> upload({
    required String userId,
    required String deviceId,
    required String bookId,
    required Uint8List bytes,
    required String checksum,
  }) async {
    final String path = '$userId/$bookId/$checksum.zip';
    blobs[path] = Uint8List.fromList(bytes);
    records[bookId] = RemoteBookAsset(
      bookId: bookId,
      storagePath: path,
      checksum: checksum,
      sizeBytes: bytes.length,
    );
    uploaded++;
  }

  @override
  Future<Uint8List> download(RemoteBookAsset asset) async {
    final Uint8List bytes = blobs[asset.storagePath]!;
    if (corrupt) {
      final Uint8List damaged = Uint8List.fromList(bytes);
      damaged[0] ^= 0xff;
      return damaged;
    }
    return Uint8List.fromList(bytes);
  }
}

LibraryEntry _entry({
  required String id,
  required BookReference reference,
  required int count,
}) =>
    LibraryEntry(
      id: id,
      reference: reference,
      chapterCount: count,
      importedAt: DateTime.utc(2026, 11, 19),
      isFavorite: false,
    );

void main() {
  test('uploads actual chapters and downloads them for offline reading',
      () async {
    final MemoryAppStorage first = MemoryAppStorage();
    final MemoryAppStorage second = MemoryAppStorage();
    final BookService firstBooks = BookService(storage: first);
    final BookService secondBooks = BookService(storage: second);
    final LibraryService firstLibrary = LibraryService(storage: first);
    final LibraryService secondLibrary = LibraryService(storage: second);
    final FakeBookFileGateway cloud = FakeBookFileGateway();
    const String chapterKey =
        'profiles/principal/storage/books/example/ch1.txt';
    await first.writeString(chapterKey, 'O capitulo foi sincronizado.');
    await firstLibrary.replaceEntries(<LibraryEntry>[
      _entry(
        id: 'book-1',
        count: 1,
        reference: const BookReference(
          title: 'Livro de teste',
          format: BookFormat.text,
          sourceLabel: 'Importado',
          assetPaths: <String>['veredra://$chapterKey'],
        ),
      ),
    ]);
    await secondLibrary.replaceEntries(<LibraryEntry>[
      _entry(
        id: 'book-1',
        count: 1,
        reference: const BookReference(
          title: 'Livro de teste',
          format: BookFormat.text,
          sourceLabel: 'Metadados sincronizados',
        ),
      ),
    ]);

    final BookFileSyncService from = BookFileSyncService(
      profileId: 'principal',
      libraryService: firstLibrary,
      bookService: firstBooks,
      remote: cloud,
      storage: first,
    );
    final BookFileSyncService to = BookFileSyncService(
      profileId: 'principal',
      libraryService: secondLibrary,
      bookService: secondBooks,
      remote: cloud,
      storage: second,
    );

    final BookFileSyncReport sent =
        await from.synchronize(userId: 'user-1', deviceId: 'first-device');
    expect(sent.errors, isEmpty);
    expect(sent.uploaded, 1);
    expect(cloud.uploaded, 1);

    final RemoteBookAsset asset = cloud.records['book-1']!;
    expect(sha256.convert(cloud.blobs[asset.storagePath]!).toString(),
        asset.checksum);

    final BookFileSyncReport received =
        await to.synchronize(userId: 'user-1', deviceId: 'second-device');
    expect(received.errors, isEmpty);
    expect(received.downloaded, 1);
    final LibraryEntry restored = (await secondLibrary.loadEntries()).single;
    expect(restored.reference.assetPaths, hasLength(1));
    expect(restored.reference.syncedBookId, restored.id);
    final book = await secondBooks.reopenBook(restored.reference);
    expect(book.id, 'book-1');
    expect(book.chapters, hasLength(1));
    expect(await secondBooks.readChapterContent(book.chapters.single),
        'O capitulo foi sincronizado.');

    // The portable bundle must be byte-for-byte reproducible on restore:
    // no spurious re-uploads and no conflict after syncing the same book.
    final BookFileSyncReport again =
        await to.synchronize(userId: 'user-1', deviceId: 'second-device');
    expect(again.errors, isEmpty);
    expect(again.uploaded, 0);
    expect(cloud.uploaded, 1);
  });

  test('a corrupted download cannot replace a metadata-only entry', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final LibraryService library = LibraryService(storage: storage);
    final BookService books = BookService(storage: storage);
    final FakeBookFileGateway cloud = FakeBookFileGateway();
    cloud.records['book-2'] = const RemoteBookAsset(
      bookId: 'book-2',
      storagePath: 'user-1/book-2/zip.zip',
      checksum: 'invalid',
      sizeBytes: 3,
    );
    cloud.blobs['user-1/book-2/zip.zip'] = Uint8List.fromList(<int>[1, 2, 3]);
    await library.replaceEntries(<LibraryEntry>[
      _entry(
        id: 'book-2',
        count: 10,
        reference: const BookReference(
          title: 'Sem download',
          format: BookFormat.text,
          sourceLabel: 'Metadados sincronizados',
        ),
      ),
    ]);
    final BookFileSyncService sync = BookFileSyncService(
      profileId: 'principal',
      libraryService: library,
      bookService: books,
      remote: cloud,
      storage: storage,
    );
    final BookFileSyncReport report =
        await sync.synchronize(userId: 'user-1', deviceId: 'second-device');
    expect(report.hasErrors, isTrue);
    expect(report.downloaded, 0);
    expect((await library.loadEntries()).single.hasOnlySyncedMetadata, isTrue);
  });
}
