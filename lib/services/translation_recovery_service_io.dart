// Signature: dev.tswicolly03
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/book_format.dart';
import '../models/library_entry.dart';
import 'book_service.dart';
import 'library_service.dart';

class TranslationRecoveryResult {
  const TranslationRecoveryResult({
    required this.recoveredCount,
    required this.skippedCount,
  });

  final int recoveredCount;
  final int skippedCount;
}

class TranslationRecoveryService {
  const TranslationRecoveryService({
    required this.bookService,
    required this.libraryService,
  });

  final BookService bookService;
  final LibraryService libraryService;

  Future<TranslationRecoveryResult> recover(String profileId) async {
    bookService.configureProfile(profileId);
    libraryService.configureProfile(profileId);

    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory translationsRoot = Directory(
      p.join(
        documentsDirectory.path,
        'profiles',
        profileId,
        'storage',
        'translated_books',
      ),
    );
    if (!await translationsRoot.exists()) {
      return const TranslationRecoveryResult(
        recoveredCount: 0,
        skippedCount: 0,
      );
    }

    final List<LibraryEntry> entries = await libraryService.loadEntries();
    final Set<String> representedDirectories = <String>{
      for (final LibraryEntry entry in entries)
        for (final String path in entry.reference.assetPaths)
          p.normalize(p.dirname(path)),
    };

    int recoveredCount = 0;
    int skippedCount = 0;
    final List<FileSystemEntity> directories =
        await translationsRoot.list(followLinks: false).toList();
    directories.sort(
      (FileSystemEntity a, FileSystemEntity b) =>
          p.basename(a.path).compareTo(p.basename(b.path)),
    );

    for (final FileSystemEntity entity in directories) {
      if (entity is! Directory || entity.path.endsWith('.staging')) {
        continue;
      }
      final String normalizedDirectory = p.normalize(entity.path);
      if (representedDirectories.contains(normalizedDirectory)) {
        skippedCount++;
        continue;
      }

      final List<String> chapterPaths = (await entity
              .list(followLinks: false)
              .where((FileSystemEntity item) => item is File)
              .map((FileSystemEntity item) => item.path)
              .where(_isSupportedTextPath)
              .toList())
        ..sort(_compareChapterPaths);
      if (chapterPaths.isEmpty) {
        skippedCount++;
        continue;
      }

      final String folderName = p.basename(normalizedDirectory).trim();
      final Book loaded = await bookService.loadTextBookFromFiles(
        chapterPaths,
        preferredTitle:
            folderName.isEmpty ? 'Traducao recuperada' : folderName,
        sourceLabel: 'Traducao recuperada do desktop',
        copyToManagedStorage: false,
        format: BookFormat.text,
      );
      final Book recovered = loaded.copyWith(
        reference: loaded.reference.copyWith(
          sourceLabel: 'Traducao recuperada do desktop',
          tags: <String>{
            ...loaded.reference.tags,
            'traducao',
            'recuperada',
          }.toList(growable: false),
        ),
      );
      await libraryService.upsertBook(recovered);
      representedDirectories.add(normalizedDirectory);
      recoveredCount++;
    }

    return TranslationRecoveryResult(
      recoveredCount: recoveredCount,
      skippedCount: skippedCount,
    );
  }

  bool _isSupportedTextPath(String path) {
    return const <String>{'.txt', '.md', '.markdown', '.html', '.htm', '.xhtml'}
        .contains(p.extension(path).toLowerCase());
  }

  int _compareChapterPaths(String a, String b) {
    final int? aNumber = _extractNumber(p.basenameWithoutExtension(a));
    final int? bNumber = _extractNumber(p.basenameWithoutExtension(b));
    if (aNumber != null && bNumber != null) {
      final int comparison = aNumber.compareTo(bNumber);
      if (comparison != 0) {
        return comparison;
      }
    } else if (aNumber != null) {
      return -1;
    } else if (bNumber != null) {
      return 1;
    }
    return p.basename(a).toLowerCase().compareTo(
          p.basename(b).toLowerCase(),
        );
  }

  int? _extractNumber(String value) {
    final Match? match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}
