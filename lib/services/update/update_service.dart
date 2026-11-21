// Signature: dev.tswicolly03
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

enum UpdateTarget { web, windows, android, ios, other }

UpdateTarget get currentUpdateTarget {
  if (kIsWeb) return UpdateTarget.web;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      return UpdateTarget.windows;
    case TargetPlatform.android:
      return UpdateTarget.android;
    case TargetPlatform.iOS:
      return UpdateTarget.ios;
    default:
      return UpdateTarget.other;
  }
}

class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch, this.build);
  final int major, minor, patch, build;
  static final RegExp _valid = RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$');
  static bool isValid(String raw) => _valid.hasMatch(raw);
  static ReleaseVersion parse(String raw) {
    if (!isValid(raw)) throw FormatException('Invalid release version: $raw');
    final List<String> split = raw.split('+');
    final List<int> numbers = split.first.split('.').map(int.parse).toList();
    return ReleaseVersion(numbers[0], numbers[1], numbers[2],
        split.length == 2 ? int.parse(split[1]) : 0);
  }

  @override
  int compareTo(ReleaseVersion other) {
    final List<int> a = <int>[major, minor, patch, build];
    final List<int> b = <int>[
      other.major,
      other.minor,
      other.patch,
      other.build
    ];
    for (int i = 0; i < a.length; i++) {
      final int value = a[i].compareTo(b[i]);
      if (value != 0) return value;
    }
    return 0;
  }
}

class AppRelease {
  const AppRelease(
      {required this.version,
      required this.notes,
      required this.releaseUrl,
      this.installerUrl,
      this.installerSha256,
      this.installerSize});
  final String version;
  final String notes;
  final Uri releaseUrl;
  final Uri? installerUrl;
  final String? installerSha256;
  final int? installerSize;

  bool get hasVerifiedWindowsInstaller =>
      installerUrl != null &&
      installerSha256 != null &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(installerSha256!) &&
      (installerSize ?? 0) > 0;

  factory AppRelease.fromWeb(Map<String, dynamic> json) {
    final String version = (json['version'] ?? '').toString();
    final String build = (json['buildNumber'] ?? '').toString();
    final String full = build.isEmpty ? version : '$version+$build';
    if (!ReleaseVersion.isValid(full)) {
      throw const FormatException('Invalid Web update manifest.');
    }
    return AppRelease(
        version: full,
        notes:
            (json['notes'] ?? 'Novidades e melhorias de leitura.').toString(),
        releaseUrl: Uri.https('github.com', '/TSWill03/Veredra/releases'));
  }

  factory AppRelease.fromGitHub(Map<String, dynamic> json) {
    final String version =
        (json['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), '');
    if (!ReleaseVersion.isValid(version) ||
        json['draft'] == true ||
        json['prerelease'] == true) {
      throw const FormatException('GitHub release is not stable.');
    }
    Uri? installer;
    String? sha;
    int? size;
    final List<dynamic> assets =
        json['assets'] is List ? json['assets'] as List<dynamic> : [];
    final String name = 'Veredra-Setup-v$version.exe';
    for (final dynamic asset in assets) {
      if (asset is! Map || asset['name'] != name) continue;
      final Uri? uri =
          Uri.tryParse((asset['browser_download_url'] ?? '').toString());
      final String digest = (asset['digest'] ?? '').toString();
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'github.com' &&
          uri.path == '/TSWill03/Veredra/releases/download/v$version/$name' &&
          digest.startsWith('sha256:')) {
        installer = uri;
        sha = digest.substring(7);
        size = asset['size'] is int ? asset['size'] as int : null;
      }
    }
    return AppRelease(
        version: version,
        notes: (json['body'] ?? 'Nova versao do Veredra.').toString(),
        releaseUrl:
            Uri.https('github.com', '/TSWill03/Veredra/releases/tag/v$version'),
        installerUrl: installer,
        installerSha256: sha,
        installerSize: size);
  }
}

class UpdateService {
  UpdateService(
      {http.Client? client,
      UpdateTarget? target,
      String? currentVersion,
      Uri? siteUri,
      Uri? githubUri})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        target = target ?? currentUpdateTarget,
        currentVersion = currentVersion ?? AppConfig.clientVersion,
        _siteUri = siteUri ??
            ((target ?? currentUpdateTarget) == UpdateTarget.web &&
                    (Uri.base.scheme == 'https' || Uri.base.scheme == 'http')
                ? Uri.base.resolve('/veredra/updates.json')
                : Uri.https('wicolly.com.br', '/veredra/updates.json')),
        _githubUri = githubUri ??
            Uri.https(
                'api.github.com', '/repos/TSWill03/Veredra/releases/latest');
  final http.Client _client;
  final bool _ownsClient;
  final UpdateTarget target;
  final String currentVersion;
  final Uri _siteUri, _githubUri;

  Future<Map<String, dynamic>> _fetch(Uri uri) async {
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            (uri.host == 'localhost' || uri.host == '127.0.0.1'))) {
      throw const FormatException('Untrusted update origin.');
    }
    final Uri uncached = uri.replace(queryParameters: {
      ...uri.queryParameters,
      '_check': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final http.Response response = await _client.get(uncached, headers: {
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 || response.bodyBytes.length > 131072) {
      throw StateError(
          'Update check unavailable (HTTP ${response.statusCode}).');
    }
    final dynamic payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid update data.');
    }
    return payload;
  }

  Future<AppRelease?> check() async {
    AppRelease latest;
    if (target == UpdateTarget.windows) {
      try {
        latest = AppRelease.fromGitHub(await _fetch(_githubUri));
      } catch (_) {
        // Never run an installer without a trusted GitHub release digest.
        latest = AppRelease.fromWeb(await _fetch(_siteUri));
      }
    } else {
      latest = AppRelease.fromWeb(await _fetch(_siteUri));
    }
    return ReleaseVersion.parse(latest.version)
                .compareTo(ReleaseVersion.parse(currentVersion)) >
            0
        ? latest
        : null;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
