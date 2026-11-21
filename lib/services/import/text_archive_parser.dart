// Signature: dev.tswicolly03
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as p;

import '../../models/generated_chapter.dart';
import '../import_limits.dart';

class TextArchiveImportResult {
  const TextArchiveImportResult({
    required this.title,
    required this.chapters,
    required this.ignoredEntries,
    required this.totalUncompressedBytes,
  });

  final String title;
  final List<GeneratedChapter> chapters;
  final int ignoredEntries;
  final int totalUncompressedBytes;
}

class TextArchiveParser {
  const TextArchiveParser._();

  static const int maxArchiveEntries = 10000;

  static TextArchiveImportResult parse(
    List<int> bytes, {
    required String sourceName,
  }) {
    if (bytes.isEmpty) {
      throw StateError('O arquivo ZIP esta vazio.');
    }
    if (bytes.length > ImportLimits.maxTextTotalBytes) {
      throw StateError(
        'O ZIP excede o limite seguro de '
        '${ImportLimits.maxTextTotalBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw StateError('Nao foi possivel abrir o ZIP selecionado.');
    }

    if (archive.files.length > maxArchiveEntries) {
      throw StateError(
        'O ZIP excede o limite seguro de $maxArchiveEntries entradas.',
      );
    }

    final List<_ArchiveChapter> candidates = <_ArchiveChapter>[];
    final Set<String> seenPaths = <String>{};
    int ignoredEntries = 0;
    int totalBytes = 0;

    for (final ArchiveFile entry in archive.files) {
      if (!entry.isFile) {
        ignoredEntries++;
        continue;
      }

      final String? safePath = _safeArchivePath(entry.name);
      if (safePath == null) {
        throw StateError(
          'O ZIP contem um caminho inseguro e foi recusado: ${entry.name}',
        );
      }
      if (_shouldIgnorePath(safePath) || !_isSupportedTextPath(safePath)) {
        ignoredEntries++;
        continue;
      }
      if (!seenPaths.add(safePath.toLowerCase())) {
        throw StateError('O ZIP contem capitulos duplicados: $safePath');
      }

      final int declaredSize = entry.size;
      ImportLimits.validateFileSize(
        ImportPayloadKind.text,
        declaredSize,
        label: 'O capitulo ${p.posix.basename(safePath)}',
      );
      totalBytes += declaredSize;
      if (totalBytes > ImportLimits.maxTextTotalBytes) {
        throw StateError(
          'Os capitulos extraidos excedem o limite total de '
          '${ImportLimits.maxTextTotalBytes ~/ (1024 * 1024)} MB.',
        );
      }

      final Object? rawContent = entry.content;
      if (rawContent is! List<int>) {
        throw StateError('Nao foi possivel ler o capitulo $safePath.');
      }
      final String decoded = utf8.decode(rawContent, allowMalformed: true);
      final String content = _normalizeImportedText(decoded, safePath);
      if (content.trim().isEmpty) {
        ignoredEntries++;
        continue;
      }

      candidates.add(
        _ArchiveChapter(
          path: safePath,
          title: _deriveChapterTitle(safePath),
          content: content,
          sortNumber: _extractSortNumber(safePath),
        ),
      );
    }

    if (candidates.isEmpty) {
      throw StateError(
        'Nenhum TXT, Markdown ou HTML valido foi encontrado no ZIP.',
      );
    }

    ImportLimits.validateTextCollection(
      candidates.map((_ArchiveChapter chapter) => chapter.content.length),
    );
    ImportLimits.validateExtractedText(
      candidates.map((_ArchiveChapter chapter) => chapter.content),
    );

    candidates.sort(_compareChapters);
    final List<GeneratedChapter> chapters = candidates
        .map(
          (_ArchiveChapter chapter) =>
              GeneratedChapter(title: chapter.title, content: chapter.content),
        )
        .toList(growable: false);

    final String sourceTitle = p.basenameWithoutExtension(sourceName).trim();
    return TextArchiveImportResult(
      title: sourceTitle.isEmpty ? 'Livro importado' : sourceTitle,
      chapters: chapters,
      ignoredEntries: ignoredEntries,
      totalUncompressedBytes: totalBytes,
    );
  }

  static String? _safeArchivePath(String rawPath) {
    if (rawPath.contains('\u0000')) {
      return null;
    }
    final String slashed = rawPath.replaceAll('\\', '/').trim();
    if (slashed.isEmpty || slashed.startsWith('/') || slashed.contains(':')) {
      return null;
    }
    final String normalized = p.posix.normalize(slashed);
    if (normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized.contains('/../')) {
      return null;
    }
    return normalized;
  }

  static bool _shouldIgnorePath(String path) {
    final List<String> segments = p.posix.split(path);
    return segments.any(
      (String segment) =>
          segment.isEmpty || segment == '__MACOSX' || segment.startsWith('.'),
    );
  }

  static bool _isSupportedTextPath(String path) {
    return const <String>{
      '.txt',
      '.md',
      '.markdown',
      '.html',
      '.htm',
      '.xhtml',
    }.contains(p.posix.extension(path).toLowerCase());
  }

  static String _normalizeImportedText(String rawContent, String sourcePath) {
    final String extension = p.posix.extension(sourcePath).toLowerCase();
    switch (extension) {
      case '.md':
      case '.markdown':
        return _htmlToPlainText(markdown.markdownToHtml(rawContent));
      case '.html':
      case '.htm':
      case '.xhtml':
        return _htmlToPlainText(rawContent);
      default:
        return rawContent.replaceAll('\r\n', '\n').trimRight();
    }
  }

  static String _htmlToPlainText(String html) {
    final String text = html_parser.parse(html).body?.text ?? '';
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _deriveChapterTitle(String path) {
    final String fileTitle = p.posix.basenameWithoutExtension(path).trim();
    if (fileTitle.isEmpty) {
      return p.posix.basename(path);
    }
    final Match? numberedWithSeparator = RegExp(
      r'^0*(\d+)(\s*[-._]\s*)(.+)$',
    ).firstMatch(fileTitle);
    if (numberedWithSeparator != null) {
      final int number = int.parse(numberedWithSeparator.group(1)!);
      return '$number${numberedWithSeparator.group(2)!}${numberedWithSeparator.group(3)!}';
    }
    final Match? onlyNumber = RegExp(r'^0*(\d+)$').firstMatch(fileTitle);
    if (onlyNumber != null) {
      return int.parse(onlyNumber.group(1)!).toString();
    }
    return fileTitle;
  }

  static int? _extractSortNumber(String path) {
    final String name = p.posix.basenameWithoutExtension(path);
    final Match? match = RegExp(r'\d+').firstMatch(name);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static int _compareChapters(_ArchiveChapter a, _ArchiveChapter b) {
    if (a.sortNumber != null && b.sortNumber != null) {
      final int comparison = a.sortNumber!.compareTo(b.sortNumber!);
      if (comparison != 0) {
        return comparison;
      }
    } else if (a.sortNumber != null) {
      return -1;
    } else if (b.sortNumber != null) {
      return 1;
    }
    return a.path.toLowerCase().compareTo(b.path.toLowerCase());
  }
}

class _ArchiveChapter {
  const _ArchiveChapter({
    required this.path,
    required this.title,
    required this.content,
    required this.sortNumber,
  });

  final String path;
  final String title;
  final String content;
  final int? sortNumber;
}
