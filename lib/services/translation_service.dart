// Signature: dev.tswicolly03
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/generated_chapter.dart';
import '../models/translation_engine_status.dart';
import '../models/translation_language.dart';
import '../models/translation_pair.dart';
import '../models/translation_progress.dart';
import 'book_service.dart';

class TranslationService {
  String _activeProfileId = 'principal';
  _PythonCommand? _cachedPythonCommand;

  void configureProfile(String profileId) {
    _activeProfileId = profileId;
  }

  bool get supportsLocalTranslation =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<TranslationEngineStatus> inspectLocalEngine() async {
    if (!supportsLocalTranslation) {
      return const TranslationEngineStatus(
        supported: false,
        pythonDetected: false,
        argosInstalled: false,
        onlineIndexAvailable: false,
        pythonCommandLabel: null,
        pythonVersion: null,
        installedPairs: <TranslationPair>[],
        availablePairs: <TranslationPair>[],
        message:
            'A traducao local com Argos esta disponivel apenas no desktop.',
      );
    }

    final _PythonCommand? command = await _resolvePythonCommand();
    if (command == null) {
      return const TranslationEngineStatus(
        supported: true,
        pythonDetected: false,
        argosInstalled: false,
        onlineIndexAvailable: false,
        pythonCommandLabel: null,
        pythonVersion: null,
        installedPairs: <TranslationPair>[],
        availablePairs: <TranslationPair>[],
        message:
            'Python nao foi encontrado. Instale Python 3 com pip para ativar a traducao local.',
      );
    }

    final Map<String, dynamic> payload = await _runJsonCommand(
      command,
      const <String>['status'],
    );
    return TranslationEngineStatus.fromJson(payload);
  }

  Future<void> installArgosPackage() async {
    final _PythonCommand command = await _requirePythonCommand();
    final _ProcessResultData result = await _runCommand(
      command,
      const <String>[
        '-m',
        'pip',
        'install',
        'argostranslate',
      ],
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Nao foi possivel instalar o Argos Translate.\n${_compactOutput(result)}',
      );
    }
  }

  Future<void> installModel(TranslationPair pair) async {
    final _PythonCommand command = await _requirePythonCommand();
    final Map<String, dynamic> payload = await _runJsonCommand(
      command,
      <String>['install-model', pair.source.code, pair.target.code],
    );
    if (payload['installed'] != true) {
      throw StateError(
        payload['message'] as String? ??
            'Nao foi possivel instalar o modelo de traducao selecionado.',
      );
    }
  }

  Future<Book> translateBook({
    required Book sourceBook,
    required TranslationLanguage sourceLanguage,
    required TranslationLanguage targetLanguage,
    required BookService bookService,
    void Function(TranslationProgress value)? onProgress,
  }) async {
    if (!sourceBook.usesTextReader) {
      throw StateError(
        'A traducao local por enquanto funciona apenas em livros textuais.',
      );
    }

    final _PythonCommand command = await _requirePythonCommand();
    final Directory runtimeDirectory = await _runtimeDirectory();
    final File inputFile = File(
      p.join(runtimeDirectory.path,
          'translation_input_${DateTime.now().microsecondsSinceEpoch}.json'),
    );
    final File outputFile = File(
      p.join(runtimeDirectory.path,
          'translation_output_${DateTime.now().microsecondsSinceEpoch}.json'),
    );

    try {
      final List<GeneratedChapter> sourceChapters =
          await bookService.exportBookChapters(sourceBook);
      final Map<String, dynamic> inputPayload = <String, dynamic>{
        'title': sourceBook.title,
        'description': sourceBook.reference.description,
        'chapters': sourceChapters
            .map((GeneratedChapter chapter) => chapter.toJson())
            .toList(growable: false),
      };
      await inputFile.writeAsString(jsonEncode(inputPayload), flush: true);

      onProgress?.call(
        TranslationProgress(
          stage: 'Preparando traducao',
          completedChapters: 0,
          totalChapters: sourceChapters.length,
          detail: 'Carregando capitulos para o motor local.',
        ),
      );

      final List<String> lines = await _runStreamingJsonCommand(
        command,
        <String>[
          'translate-book',
          sourceLanguage.code,
          targetLanguage.code,
          inputFile.path,
          outputFile.path,
        ],
        onJsonLine: (Map<String, dynamic> payload) {
          if (payload['type'] == 'progress') {
            onProgress?.call(
              TranslationProgress(
                stage: 'Traduzindo capitulos',
                completedChapters:
                    (payload['completedChapters'] as num?)?.toInt() ?? 0,
                totalChapters: (payload['totalChapters'] as num?)?.toInt() ??
                    sourceChapters.length,
                currentChapterTitle: payload['chapterTitle'] as String?,
                detail: payload['message'] as String?,
              ),
            );
          }
        },
      );

      if (!await outputFile.exists()) {
        throw StateError(
          'O motor de traducao nao gerou o arquivo de saida esperado.\n${lines.join('\n')}',
        );
      }

      final dynamic decoded = jsonDecode(await outputFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw StateError('A resposta da traducao ficou invalida.');
      }

      final List<GeneratedChapter> translatedChapters =
          (decoded['chapters'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(GeneratedChapter.fromJson)
              .toList(growable: false);
      if (translatedChapters.isEmpty) {
        throw StateError('Nenhum capitulo traduzido foi produzido.');
      }

      onProgress?.call(
        TranslationProgress(
          stage: 'Salvando copia traduzida',
          completedChapters: translatedChapters.length,
          totalChapters: translatedChapters.length,
          detail: 'Gerando uma nova versao do livro na biblioteca.',
        ),
      );

      final String translatedTitle =
          (decoded['title'] as String? ?? '').trim().isEmpty
              ? '${sourceBook.title} [${targetLanguage.label}]'
              : (decoded['title'] as String).trim();
      final String? translatedDescription =
          (decoded['description'] as String?)?.trim();

      return await bookService.createTranslatedBook(
        sourceBook: sourceBook,
        title: translatedTitle,
        chapters: translatedChapters,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        translatedDescription:
            translatedDescription != null && translatedDescription.isNotEmpty
                ? translatedDescription
                : null,
      );
    } finally {
      await _safeDelete(inputFile);
      await _safeDelete(outputFile);
    }
  }

  Future<_PythonCommand> _requirePythonCommand() async {
    final _PythonCommand? command = await _resolvePythonCommand();
    if (command == null) {
      throw StateError(
        'Python nao foi encontrado. Instale Python 3 com pip para usar a traducao local.',
      );
    }
    return command;
  }

  Future<_PythonCommand?> _resolvePythonCommand() async {
    if (_cachedPythonCommand != null) {
      return _cachedPythonCommand;
    }

    final List<_PythonCommand> candidates = <_PythonCommand>[
      const _PythonCommand(executable: 'python', args: <String>[]),
      const _PythonCommand(executable: 'py', args: <String>['-3']),
      const _PythonCommand(executable: 'python3', args: <String>[]),
    ];

    for (final _PythonCommand candidate in candidates) {
      try {
        final _ProcessResultData result = await _runCommand(
          candidate,
          const <String>['--version'],
        );
        if (result.exitCode == 0) {
          _cachedPythonCommand = candidate;
          return candidate;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> _runJsonCommand(
    _PythonCommand command,
    List<String> helperArgs,
  ) async {
    final _ProcessResultData result = await _runCommand(
      command,
      <String>[await _helperScriptPath(), ...helperArgs],
    );
    if (result.exitCode != 0) {
      throw StateError(_compactOutput(result));
    }

    final dynamic decoded = jsonDecode(result.stdout.trim());
    if (decoded is! Map<String, dynamic>) {
      throw StateError('A resposta do motor de traducao ficou invalida.');
    }
    return decoded;
  }

  Future<List<String>> _runStreamingJsonCommand(
    _PythonCommand command,
    List<String> helperArgs, {
    required void Function(Map<String, dynamic> payload) onJsonLine,
  }) async {
    final Process process = await Process.start(
      command.executable,
      <String>[...command.args, await _helperScriptPath(), ...helperArgs],
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.normal,
    );

    final List<String> stdoutLines = <String>[];
    final StreamSubscription<String> stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      if (line.trim().isEmpty) {
        return;
      }
      stdoutLines.add(line);
      final dynamic decoded = _tryDecodeJson(line);
      if (decoded is Map<String, dynamic>) {
        onJsonLine(decoded);
      }
    });

    final String stderr = await process.stderr.transform(utf8.decoder).join();
    final int exitCode = await process.exitCode;
    await stdoutSubscription.cancel();

    if (exitCode != 0) {
      final String output = <String>[
        ...stdoutLines,
        stderr.trim(),
      ].where((String value) => value.isNotEmpty).join('\n');
      throw StateError(
        output.isEmpty
            ? 'A traducao local falhou.'
            : 'A traducao local falhou.\n$output',
      );
    }

    return stdoutLines;
  }

  dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<_ProcessResultData> _runCommand(
    _PythonCommand command,
    List<String> args,
  ) async {
    final ProcessResult result = await Process.run(
      command.executable,
      <String>[...command.args, ...args],
      runInShell: Platform.isWindows,
    );
    return _ProcessResultData(
      exitCode: result.exitCode,
      stdout: '${result.stdout ?? ''}'.trim(),
      stderr: '${result.stderr ?? ''}'.trim(),
    );
  }

  String _compactOutput(_ProcessResultData result) {
    return <String>[
      result.stdout,
      result.stderr,
    ].where((String value) => value.isNotEmpty).join('\n').trim();
  }

  Future<String> _helperScriptPath() async {
    final Directory runtimeDirectory = await _runtimeDirectory();
    final File helperFile =
        File(p.join(runtimeDirectory.path, 'argos_bridge.py'));
    if (!await helperFile.exists() ||
        await helperFile.readAsString() != _helperScriptSource) {
      await helperFile.writeAsString(_helperScriptSource, flush: true);
    }
    return helperFile.path;
  }

  Future<Directory> _runtimeDirectory() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory directory = Directory(
      p.join(
        documentsDirectory.path,
        'profiles',
        _activeProfileId,
        'runtime',
        'translation',
      ),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _PythonCommand {
  const _PythonCommand({
    required this.executable,
    required this.args,
  });

  final String executable;
  final List<String> args;
}

class _ProcessResultData {
  const _ProcessResultData({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

const String _helperScriptSource = r'''
import json
import re
import sys


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def safe_import_argos():
    import argostranslate.package
    import argostranslate.translate
    return argostranslate.package, argostranslate.translate


def language_to_json(code, name):
    return {"code": code or "", "name": name or ""}


def pair_to_json(source_code, source_name, target_code, target_name, installed, available_online):
    return {
        "source": language_to_json(source_code, source_name),
        "target": language_to_json(target_code, target_name),
        "installed": installed,
        "availableOnline": available_online,
    }


def list_status():
    result = {
        "supported": True,
        "pythonDetected": True,
        "argosInstalled": False,
        "onlineIndexAvailable": False,
        "pythonCommandLabel": sys.executable,
        "pythonVersion": sys.version.split()[0],
        "installedPairs": [],
        "availablePairs": [],
        "message": None,
    }

    try:
        package, translate = safe_import_argos()
    except ModuleNotFoundError:
        result["message"] = "Argos Translate nao esta instalado neste Python."
        emit(result)
        return
    except Exception as exc:
        result["message"] = str(exc)
        emit(result)
        return

    result["argosInstalled"] = True
    installed_languages = translate.get_installed_languages()
    installed_pairs = []
    seen_installed = set()

    for source_lang in installed_languages:
        for translation in getattr(source_lang, "translations_from", []):
            target_lang = getattr(translation, "to_lang", None)
            if target_lang is None:
                continue
            key = (source_lang.code, target_lang.code)
            if key in seen_installed:
                continue
            seen_installed.add(key)
            installed_pairs.append(
                pair_to_json(
                    source_lang.code,
                    source_lang.name,
                    target_lang.code,
                    target_lang.name,
                    True,
                    True,
                )
            )

    result["installedPairs"] = installed_pairs

    try:
        package.update_package_index()
        available_packages = package.get_available_packages()
        available_pairs = []
        seen_available = set()
        for pkg in available_packages:
            from_code = getattr(pkg, "from_code", None)
            to_code = getattr(pkg, "to_code", None)
            if not from_code or not to_code:
                continue
            key = (from_code, to_code)
            if key in seen_available:
                continue
            seen_available.add(key)
            available_pairs.append(
                pair_to_json(
                    from_code,
                    getattr(pkg, "from_name", from_code),
                    to_code,
                    getattr(pkg, "to_name", to_code),
                    key in seen_installed,
                    True,
                )
            )
        result["availablePairs"] = available_pairs
        result["onlineIndexAvailable"] = True
    except Exception as exc:
        result["message"] = str(exc)

    emit(result)


def install_model(from_code, to_code):
    package, _ = safe_import_argos()
    package.update_package_index()
    available_packages = package.get_available_packages()

    for pkg in available_packages:
        if getattr(pkg, "from_code", None) == from_code and getattr(pkg, "to_code", None) == to_code:
            download_path = pkg.download()
            package.install_from_path(download_path)
            emit(
                {
                    "installed": True,
                    "message": f"Modelo {from_code}->{to_code} instalado com sucesso.",
                }
            )
            return

    emit(
        {
            "installed": False,
            "message": f"Nao encontrei um modelo disponivel para {from_code}->{to_code}.",
        }
    )


def split_large_piece(text, limit=1400):
    if len(text) <= limit:
        return [text]

    pieces = []
    remaining = text
    while len(remaining) > limit:
        slice_text = remaining[:limit]
        split_index = max(
            slice_text.rfind(". "),
            slice_text.rfind("! "),
            slice_text.rfind("? "),
            slice_text.rfind("; "),
            slice_text.rfind(", "),
            slice_text.rfind(" "),
        )
        if split_index < limit // 3:
            split_index = limit
        else:
            split_index += 1
        pieces.append(remaining[:split_index])
        remaining = remaining[split_index:]
    if remaining:
        pieces.append(remaining)
    return pieces


def translate_document(translation, text):
    normalized = (text or "").replace("\r\n", "\n")
    parts = re.split(r"(\n\s*\n+)", normalized)
    translated_parts = []

    for part in parts:
        if not part:
            continue
        if re.fullmatch(r"\n\s*\n+", part):
            translated_parts.append(part)
            continue
        if not part.strip():
            translated_parts.append(part)
            continue

        chunks = split_large_piece(part)
        translated_parts.append("".join(translation.translate(chunk) for chunk in chunks))

    return "".join(translated_parts).strip()


def translate_book(from_code, to_code, input_path, output_path):
    _, translate = safe_import_argos()
    with open(input_path, "r", encoding="utf-8") as fh:
        payload = json.load(fh)

    installed_languages = translate.get_installed_languages()
    source_lang = next((lang for lang in installed_languages if lang.code == from_code), None)
    target_lang = next((lang for lang in installed_languages if lang.code == to_code), None)
    if source_lang is None or target_lang is None:
        raise RuntimeError("O par de idiomas nao esta instalado neste computador.")

    translation = source_lang.get_translation(target_lang)
    if translation is None:
        raise RuntimeError("O motor local nao encontrou traducao para o par selecionado.")

    source_chapters = payload.get("chapters", [])
    translated_chapters = []
    total_chapters = len(source_chapters)

    for index, chapter in enumerate(source_chapters):
        chapter_title = str(chapter.get("title", "") or f"Capitulo {index + 1}")
        emit(
            {
                "type": "progress",
                "completedChapters": index,
                "totalChapters": total_chapters,
                "chapterTitle": chapter_title,
                "message": f"Traduzindo {chapter_title}",
            }
        )
        translated_chapters.append(
            {
                "title": translate_document(translation, chapter_title),
                "content": translate_document(translation, str(chapter.get("content", "") or "")),
            }
        )

    output = {
        "title": translate_document(translation, str(payload.get("title", "") or "")),
        "description": translate_document(translation, str(payload.get("description", "") or "")),
        "chapters": translated_chapters,
    }

    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump(output, fh, ensure_ascii=False)

    emit(
        {
            "type": "progress",
            "completedChapters": total_chapters,
            "totalChapters": total_chapters,
            "chapterTitle": None,
            "message": "Traducao concluida.",
        }
    )


def main():
    if len(sys.argv) < 2:
        raise SystemExit("missing command")

    command = sys.argv[1]
    if command == "status":
        list_status()
    elif command == "install-model":
        if len(sys.argv) < 4:
            raise SystemExit("missing install-model args")
        install_model(sys.argv[2], sys.argv[3])
    elif command == "translate-book":
        if len(sys.argv) < 6:
            raise SystemExit("missing translate-book args")
        translate_book(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    else:
        raise SystemExit(f"unknown command: {command}")


if __name__ == "__main__":
    main()
''';
