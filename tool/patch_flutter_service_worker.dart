// Signature: dev.tswicolly03
import 'dart:io';

void main(List<String> args) {
  final String filePath =
      args.isEmpty ? 'build/web/flutter_service_worker.js' : args.single;
  final File file = File(filePath);
  if (!file.existsSync()) {
    stderr.writeln('Service worker not found: $filePath');
    exitCode = 1;
    return;
  }

  String source = file.readAsStringSync();

  if (!source.contains('function resourceKeyFromUrl(url)')) {
    source = source.replaceFirst(
      'const RESOURCES = ',
      '''
function resourceKeyFromUrl(url) {
  var origin = self.location.origin;
  var key = url.substring(origin.length + 1);
  var scopePath = new URL(self.registration.scope).pathname;
  if (scopePath && scopePath != '/') {
    var scopeKey = scopePath.substring(1);
    if (scopeKey.endsWith('/')) {
      var scopeDirectory = scopeKey.substring(0, scopeKey.length - 1);
      if (key == scopeDirectory) {
        return '/';
      }
      if (key.startsWith(scopeKey)) {
        key = key.substring(scopeKey.length);
      }
    }
  }
  if (key == '') {
    return '/';
  }
  return key;
}

const RESOURCES = ''',
    );

    source = source.replaceAll(
      'var key = request.url.substring(origin.length + 1);',
      'var key = resourceKeyFromUrl(request.url);',
    );

    source = source.replaceFirst(
      'var key = event.request.url.substring(origin.length + 1);',
      'var key = resourceKeyFromUrl(event.request.url);',
    );
  }

  if (!source.contains('function respondWithCachedIndex(event)')) {
    const String messageListener =
        "self.addEventListener('message', (event) => {";
    if (!source.contains(messageListener)) {
      stderr.writeln('Could not find service worker message listener.');
      exitCode = 1;
      return;
    }

    source = source.replaceFirst(
      messageListener,
      '''
function respondWithCachedIndex(event) {
  return event.respondWith(
    fetch(event.request).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          return cache.match('index.html').then((fallbackResponse) => {
            if (fallbackResponse != null) {
              return fallbackResponse;
            }
            throw error;
          });
        });
      });
    })
  );
}

self.addEventListener('message', (event) => {''',
    );
  }

  if (!source.contains("event.request.mode === 'navigate'")) {
    final RegExp getMethodCheck = RegExp(
      "  if \\(event\\.request\\.method !== 'GET'\\) \\{\\r?\\n"
      '    return;\\r?\\n'
      '  \\}\\r?\\n',
    );
    final Match? match = getMethodCheck.firstMatch(source);
    if (match == null) {
      stderr.writeln('Could not find service worker GET method guard.');
      exitCode = 1;
      return;
    }

    source = source.replaceRange(
      match.end,
      match.end,
      "  if (event.request.mode === 'navigate') {\n"
      '    return respondWithCachedIndex(event);\n'
      '  }\n',
    );
  }

  source = source.replaceFirst(
    'return cache.match(event.request).then((response) => {\n'
        '          if (response != null) {\n'
        '            return response;\n'
        '          }\n'
        '          throw error;\n'
        '        });',
    'return cache.match(event.request).then((response) => {\n'
        '          if (response != null) {\n'
        '            return response;\n'
        '          }\n'
        "          return cache.match('index.html').then((fallbackResponse) => {\n"
        '            if (fallbackResponse != null) {\n'
        '              return fallbackResponse;\n'
        '            }\n'
        '            throw error;\n'
        '          });\n'
        '        });',
  );

  file.writeAsStringSync(source);
  stdout.writeln('Patched service worker for subpath hosting: $filePath');
}
