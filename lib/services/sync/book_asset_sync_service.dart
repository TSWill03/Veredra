// Signature: dev.tswicolly03
import '../book_service.dart';
import '../library_service.dart';
import '../storage/app_storage.dart';
import '../translation_recovery_service.dart';
import 'book_asset_gateway.dart';
import 'book_asset_package.dart';
import 'synced_book_storage.dart';

abstract class BookAssetSynchronizer {
  Future<void> syncAll({required String userId});
}

class BookAssetSyncService implements BookAssetSynchronizer {
  BookAssetSyncService({
    required this.profileId,
    required this.libraryService,
    required this.bookService,
    required this.remoteGateway,
    AppStorage? storage,
    SyncedBookStorage? syncedBookStorage,
    TranslationRecoveryService? translationRecoveryService,
  })  : _storage = storage ?? createAppStorage(),
        _syncedBookStorage = syncedBookStorage ?? SyncedBookStorage(),
        _translationRecoveryService = translationRecoveryService ??
            TranslationRecoveryService(
              bookService: bookService,
              libraryService: libraryService,
            ) {
    _syncedBookStorage.configureProfile(profileId);
  }

  final String profileId;
  final LibraryService libraryService;
  final BookService bookService;
  final BookAssetRemoteGateway remoteGateway;
  final AppStorage _storage;
  final SyncedBookStorage _syncedBookStorage;
  final TranslationRecoveryService _translationRecoveryService;

  @override
  Future<void> syncAll({required String userId}) async {
    await _translationRecoveryService.recover(profileId);
    final entries = await libraryService.loadEntries();

    for (final entry in entries) {
      if (!entry.reference.usesTextReader ||
          entry.reference.assetPaths.isEmpty) {
        continue;
      }
      final book = await bookService.reopenBook(entry.reference);
      final chapters = await bookService.exportBookChapters(book);
      final package = BookAssetPackageCodec.encode(
        entry: entry,
        chapters: chapters,
      );
      final String? uploadedChecksum = await _storage.readString(
        _uploadedChecksumKey(entry.id),
      );
      if (uploadedChecksum == package.checksumSha256) {
        continue;
      }
      await remoteGateway.upload(userId: userId, package: package);
      await _storage.writeString(
        _uploadedChecksumKey(entry.id),
        package.checksumSha256,
      );
    }

    final remoteAssets = await remoteGateway.list(userId: userId);
    final refreshedEntries = await libraryService.loadEntries();
    for (final asset in remoteAssets) {
      final int localIndex = refreshedEntries.indexWhere(
        (entry) => entry.id == asset.bookId,
      );
      final bool localAvailable = localIndex >= 0 &&
          await bookService.isBookReferenceAvailable(
            refreshedEntries[localIndex].reference,
          );
      final String? downloadedChecksum = await _storage.readString(
        _downloadedChecksumKey(asset.bookId),
      );
      if (localAvailable && downloadedChecksum == asset.checksumSha256) {
        continue;
      }

      final bytes = await remoteGateway.download(
        userId: userId,
        asset: asset,
      );
      final decoded = BookAssetPackageCodec.decode(
        bytes,
        expectedChecksum: asset.checksumSha256,
      );
      if (decoded.entry.id != asset.bookId) {
        throw StateError(
          'O pacote remoto nao corresponde ao livro solicitado.',
        );
      }
      final restoredBook = await _syncedBookStorage.persist(decoded);
      await libraryService.upsertBook(restoredBook);
      await _storage.writeString(
        _downloadedChecksumKey(asset.bookId),
        asset.checksumSha256,
      );
    }
  }

  String _uploadedChecksumKey(String bookId) {
    return 'profiles/$profileId/sync/book-assets/uploaded/${Uri.encodeComponent(bookId)}.sha256';
  }

  String _downloadedChecksumKey(String bookId) {
    return 'profiles/$profileId/sync/book-assets/downloaded/${Uri.encodeComponent(bookId)}.sha256';
  }
}
