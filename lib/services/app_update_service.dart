// Signature: dev.tswicolly03
// Verificacao anonima do ultimo GitHub Release publico do Veredra.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

enum AppUpdateStatus { available, upToDate, noPublishedRelease }

/// Versao de tres componentes com numero de build opcional.
/// Tags aceitas: v0.2.0, 0.2.0, v0.2.0+3.
class VeredraVersion implements Comparable<VeredraVersion> {
  const VeredraVersion(this.major, this.minor, this.patch, [this.build]);
  final int major;
  final int minor;
  final int patch;
  final int? build;

  static final RegExp _pattern =
      RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  static VeredraVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return VeredraVersion(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      m.group(4) == null ? null : int.parse(m.group(4)!),
    );
  }

  static VeredraVersion fromPubspec(String text) {
    final m = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+(?:\+\d+)?)\s*$',
      multiLine: true,
    ).firstMatch(text);
    if (m == null) {
      throw const FormatException('Versao nao encontrada no pubspec.');
    }
    return tryParse(m.group(1)!)!;
  }

  String get display =>
      'v$major.$minor.$patch' + (build == null ? '' : '+$build');

  @override
  int compareTo(VeredraVersion other) {
    final a = <int>[major, minor, patch];
    final b = <int>[other.major, other.minor, other.patch];
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    // Uma tag sem numero de build representa a mesma versao semantica.
    if (build == null || other.build == null) return 0;
    return build!.compareTo(other.build!);
  }
}

class VeredraRelease {
  const VeredraRelease({
    required this.tag,
    required this.version,
    required this.url,
    required this.notes,
  });
  final String tag;
  final VeredraVersion version;
  final Uri url;
  final String notes;
}

class AppUpdateResult {
  const AppUpdateResult({
    required this.installed,
    required this.status,
    this.release,
  });
  final VeredraVersion installed;
  final AppUpdateStatus status;
  final VeredraRelease? release;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Uri? endpoint,
    Future<VeredraVersion> Function()? installedVersionLoader,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _endpoint = endpoint ??
            Uri.https('api.github.com', '/repos/TSWill03/Veredra/releases/latest'),
        _installedVersionLoader = installedVersionLoader ?? loadInstalledVersion;

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  final Future<VeredraVersion> Function() _installedVersionLoader;

  static final Uri _releasesPage =
      Uri.https('github.com', '/TSWill03/Veredra/releases');

  /// A versao e lida do proprio pubspec.yaml incorporado no build.
  /// Nao necessita de plugins nativos nem valores manuais duplicados.
  static Future<VeredraVersion> loadInstalledVersion() async =>
      VeredraVersion.fromPubspec(await rootBundle.loadString('pubspec.yaml'));

  Future<AppUpdateResult> check() async {
    final installed = await _installedVersionLoader();
    final http.Response response;
    try {
      response = await _client.get(
        _endpoint,
        headers: const <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Veredra-Update-Checker',
        },
      ).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const AppUpdateException('Tempo limite ao consultar novas versoes.');
    } on http.ClientException {
      throw const AppUpdateException('Nao foi possivel conectar ao GitHub.');
    }

    if (response.statusCode == 404) {
      // Ainda nao ha GitHub Releases publicados.
      return AppUpdateResult(
        installed: installed,
        status: AppUpdateStatus.noPublishedRelease,
      );
    }
    if (response.statusCode != 200) {
      throw AppUpdateException(
        'Erro ao verificar atualizacoes (HTTP ' +
            response.statusCode.toString() + ').',
      );
    }
    if (response.bodyBytes.length > 256 * 1024) {
      throw const AppUpdateException('Resposta muito grande.');
    }

    final Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      throw const AppUpdateException('Resposta de versoes invalida.');
    }
    if (json is! Map<String, dynamic> ||
        json['tag_name'] is! String ||
        json['draft'] == true ||
        json['prerelease'] == true) {
      throw const AppUpdateException('Dados de release invalidos.');
    }
    final tag = json['tag_name'] as String;
    final latest = VeredraVersion.tryParse(tag);
    if (latest == null) {
      throw const AppUpdateException(
        'Use tags como v0.2.0 ou v0.2.0+3 nos Releases.',
      );
    }

    final suppliedUrl = Uri.tryParse(
      json['html_url'] is String ? json['html_url'] as String : '',
    );
    final trusted = suppliedUrl != null &&
        suppliedUrl.scheme == 'https' &&
        suppliedUrl.host == 'github.com' &&
        suppliedUrl.path.toLowerCase().startsWith(
              '/tswill03/veredra/releases/',
            );
    final rawNotes = (json['body'] is String ? json['body'] as String : '').trim();
    final notes = rawNotes.length <= 700
        ? rawNotes
        : rawNotes.substring(0, 700) + '…';

    return AppUpdateResult(
      installed: installed,
      status: latest.compareTo(installed) > 0
          ? AppUpdateStatus.available
          : AppUpdateStatus.upToDate,
      release: VeredraRelease(
        tag: tag,
        version: latest,
        url: trusted ? suppliedUrl : _releasesPage,
        notes: notes,
      ),
    );
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
