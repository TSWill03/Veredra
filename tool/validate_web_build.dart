// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final Directory root = Directory(args.isEmpty ? 'build/web' : args.single);
  final List<String> errors = <String>[];
  final File index = File('${root.path}/index.html');
  final File manifest = File('${root.path}/manifest.json');
  final File worker = File('${root.path}/flutter_service_worker.js');
  for (final File file in <File>[index, manifest, worker]) {
    if (!file.existsSync()) {
      errors.add('Arquivo ausente: ${file.path}');
    }
  }
  if (errors.isEmpty) {
    final String indexSource = index.readAsStringSync();
    if (!indexSource.contains('<base href="/veredra/">')) {
      errors.add('index.html nao usa base href /veredra/.');
    }
    final Map<String, dynamic> manifestJson =
        jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    if (manifestJson['id'] != '/veredra/' ||
        manifestJson['start_url'] != '/veredra/' ||
        manifestJson['scope'] != '/veredra/') {
      errors.add('manifest.json nao fixa id/start_url/scope em /veredra/.');
    }
    for (final dynamic icon
        in manifestJson['icons'] as List<dynamic>? ?? const <dynamic>[]) {
      if (icon is Map<String, dynamic>) {
        final String? source = icon['src'] as String?;
        if (source == null || !File('${root.path}/$source').existsSync()) {
          errors.add('Icone do manifest ausente: $source');
        }
      }
    }
    final String workerSource = worker.readAsStringSync();
    for (final String marker in <String>[
      'function resourceKeyFromUrl(url)',
      'function respondWithCachedIndex(event)',
      "event.request.mode === 'navigate'",
      "cache.match('index.html')",
    ]) {
      if (!workerSource.contains(marker)) {
        errors.add('Service worker sem marcador obrigatorio: $marker');
      }
    }
    final RegExp navigationFallback = RegExp(
      r"if \(event\.request\.method !== 'GET'\) \{\s*"
      r"return;\s*\}\s*"
      r"if \(event\.request\.mode === 'navigate'\) \{\s*"
      r"return respondWithCachedIndex\(event\);\s*\}",
    );
    if (!navigationFallback.hasMatch(workerSource)) {
      errors.add(
        'Fallback de navegacao nao aparece imediatamente apos o guard GET.',
      );
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Web/PWA build validado para /veredra/.');
}
