// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:io';

void main() {
  final String pubspec = File('pubspec.yaml').readAsStringSync();
  final Match? match =
      RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
          .firstMatch(pubspec);
  if (match == null) throw StateError('pubspec version must be semver+build.');
  final String expected = '${match[1]}+${match[2]}';
  final Map<String, dynamic> web =
      jsonDecode(File('web/updates.json').readAsStringSync())
          as Map<String, dynamic>;
  final String webVersion = '${web['version']}+${web['buildNumber']}';
  if (webVersion != expected) {
    throw StateError('Web manifest mismatch: $webVersion != $expected');
  }
  final String app = File('lib/config/app_config.dart').readAsStringSync();
  if (!app.contains("defaultValue: '$expected'")) {
    throw StateError('Embedded app version must equal $expected.');
  }
  stdout.writeln('Veredra version contract valid: $expected');
}
