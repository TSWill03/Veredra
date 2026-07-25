// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/book.dart';
import '../../models/chapter.dart';
import 'book_asset_package.dart';

class SyncedBookStorage {
  String _profileId = 'principal';

  void configureProfile(String profileId) {
    _profileId = profileId;
  }

  Future<Book> persist(DecodedBookAssetPackage package) async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final String bookHash =
        sha256.convert(utf8.encode(package.entry.id)).toString();
    final Directory directory = Directory(
      p.join(
        documents.path,
        'profiles',
        _profileId,
        'storage',
        'synced_books',
        bookHash,
      ),
    );
    final Directory staging = Directory('${directory.path}.staging');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);

    try {
      final List<String> stagingPaths = <String>[];
      for (int index = 0; index < package.chapters.length; index++) {
        final String fileName =
            '${(index + 1).toString().padLeft(6, '0')}.txt';
        final File file = File(p.join(staging.path, fileName));
        await file.writeAsString(package.chapters[index].content, flush: true);
        stagingPaths.add(file.path);
      }

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await staging.rename(directory.path);
    } on Object {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }

    final List<String> paths = <String>[
      for (int index = 0; index < package.chapters.length; index++)
        p.join(
          directory.path,
          '${(index + 1).toString().padLeft(6, '0')}.txt',
        ),
    ];
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
            fileName: p.basename(paths[index]),
            path: paths[index],
          ),
      ],
    );
  }
}
