// Signature: dev.tswicolly03
import 'dart:io';

void main() {
  const Set<String> ignoredDirectories = <String>{
    '.git',
    '.dart_tool',
    'build',
    'coverage',
    'node_modules',
    '.idea',
  };
  const Set<String> textExtensions = <String>{
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.md',
    '.sql',
    '.toml',
    '.xml',
    '.kts',
    '.gradle',
    '.properties',
    '.html',
    '.js',
    '.mjs',
    '.ts',
  };
  final List<RegExp> forbidden = <RegExp>[
    RegExp(r'-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    RegExp(r'\bgh[pousr]_[A-Za-z0-9_]{30,}\b'),
    RegExp(r'\bsk-[A-Za-z0-9_-]{24,}\b'),
    RegExp(
        r'\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b'),
    RegExp(r'SUPABASE_SERVICE_ROLE_KEY\s*=\s*[^\s#]+'),
  ];
  final List<String> findings = <String>[];
  for (final FileSystemEntity entity
      in Directory.current.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final List<String> segments = entity.uri.pathSegments;
    if (segments.any(ignoredDirectories.contains)) {
      continue;
    }
    final String name = entity.path.toLowerCase();
    if (name.endsWith('pubspec.lock') || !textExtensions.any(name.endsWith)) {
      continue;
    }
    final String source;
    try {
      source = entity.readAsStringSync();
    } on FileSystemException {
      continue;
    }
    for (final RegExp pattern in forbidden) {
      if (pattern.hasMatch(source)) {
        findings.add('${entity.path}: ${pattern.pattern}');
      }
    }
  }
  if (findings.isNotEmpty) {
    stderr.writeln('Possiveis secrets encontrados:\n${findings.join('\n')}');
    exitCode = 1;
    return;
  }
  stdout.writeln('Nenhum padrao de secret versionado foi encontrado.');
}
