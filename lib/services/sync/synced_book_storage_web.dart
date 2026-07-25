// Signature: dev.tswicolly03
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../models/book.dart';
import '../../models/chapter.dart';
import 'book_asset_package.dart';
import '../storage/app_storage.dart';

class SyncedBookStorage {
  SyncedBookStorage({AppStorage? storage})
      : _storage = storage ?? createAppStorage();

  static const String _webStoredPrefix = 'veredra://';

  final AppStorage _storage;
  String _profileId = 'principal';

  void configureProfile(String profileId) {
    _profileId = profileId;
  }

  Future<Book> persist(DecodedBookAssetPackage package) async {
    final String bookHash =
        sha256.convert(utf8.encode(package.entry.id)).toString();
    final String rootKey = normalizeStorageKey(
      'profiles/$_profileId/storage/synced_books/$bookHash',
    );
    final List<String> paths = <String>[];

    try {
      for (int index = 0; index < package.chapters.length; index++) {
        final String fileName = '${(index + 1).toString().padLeft(6, '0')}.txt';
        final String key = normalizeStorageKey('$rootKey/$fileName');
        await _storage.writeString(key, package.chapters[index].content);
        paths.add('$_webStoredPrefix$key');
        if ((index + 1) % 50 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } on Object {
      await _storage.deletePrefix(rootKey);
      rethrow;
    }

    final reference = package.entry.reference.copyWith(
      directoryPath: '',
      sourceLabel: 'Livro sincronizado',
      assetPaths: paths,
    );
    return Book(
      id: package.entry.id,
      title: reference.title,
      reference: reference,
      chapters: <Chapter>[
        for (int index = 0; index < package.chapters.length; index++)
          Chapter(
            index: index,
            sortNumber: index,
            title: package.chapters[index].title,
            fileName: paths[index].split('/').last,
            path: paths[index],
          ),
      ],
    );
  }
}
