// Signature: dev.tswicolly03
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:txt_webnovel_reader/services/update/update_service.dart';

http.Response webResponse(String version, int build) => http.Response(
      jsonEncode(<String, dynamic>{
        'schema': 1,
        'version': version,
        'buildNumber': build,
        'notes': 'Alteracoes desta versao.',
      }),
      200,
    );

void main() {
  test(
    'version comparison includes build number, not lexicographic strings',
    () {
      expect(
        ReleaseVersion.parse(
          '0.1.4+10',
        ).compareTo(ReleaseVersion.parse('0.1.4+9')),
        greaterThan(0),
      );
      expect(
        ReleaseVersion.parse(
          '0.1.4+5',
        ).compareTo(ReleaseVersion.parse('0.1.4+5')),
        0,
      );
      expect(
        ReleaseVersion.parse(
          '1.0.0',
        ).compareTo(ReleaseVersion.parse('0.99.99+800')),
        greaterThan(0),
      );
      expect(() => ReleaseVersion.parse('v1.0.0'), throwsFormatException);
    },
  );

  test('web update is newer, but equal version is not advertised', () async {
    final MockClient client = MockClient((request) async {
      expect(request.url.path, '/veredra/updates.json');
      expect(request.url.queryParameters, contains('_check'));
      return webResponse('0.1.4', 5);
    });
    final UpdateService old = UpdateService(
      client: client,
      target: UpdateTarget.web,
      currentVersion: '0.1.3+4',
    );
    expect((await old.check())!.version, '0.1.4+5');
    final UpdateService same = UpdateService(
      client: client,
      target: UpdateTarget.web,
      currentVersion: '0.1.4+5',
    );
    expect(await same.check(), isNull);
    old.dispose();
    same.dispose();
    client.close();
  });

  test('GitHub release is trusted only with matching asset and digest',
      () async {
    const String hash = 'aabbccddeeff00112233445566778899'
        'aabbccddeeff00112233445566778899';
    final MockClient client = MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'tag_name': 'v0.1.4+5',
          'draft': false,
          'prerelease': false,
          'body': 'Novo leitor.',
          'assets': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Veredra-Setup-v0.1.4+5.exe',
              'browser_download_url':
                  'https://github.com/TSWill03/Veredra/releases/download/v0.1.4+5/Veredra-Setup-v0.1.4+5.exe',
              'size': 501234,
              'digest': 'sha256:$hash',
            },
          ],
        }),
        200,
      );
    });
    final UpdateService service = UpdateService(
      client: client,
      target: UpdateTarget.windows,
      currentVersion: '0.1.3+4',
    );
    final AppRelease release = (await service.check())!;
    expect(release.hasVerifiedWindowsInstaller, isTrue);
    expect(release.installerSha256, hash);
    service.dispose();
    client.close();
  });

  test('GitHub percent-encoded plus sign is valid for official installer', () {
    const String digest =
        'f88590539eb26d9954377d9c2551ab1e4c8d7ad43da654217596cdddda440017';
    final AppRelease release = AppRelease.fromGitHub(<String, dynamic>{
      'tag_name': 'v0.1.4+6',
      'draft': false,
      'prerelease': false,
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Veredra-Setup-v0.1.4+6.exe',
          'browser_download_url':
              'https://github.com/TSWill03/Veredra/releases/download/v0.1.4%2B6/Veredra-Setup-v0.1.4%2B6.exe',
          'digest': 'sha256:$digest',
          'size': 15727998,
        },
      ],
    });
    expect(release.hasVerifiedWindowsInstaller, isTrue);
    expect(
      Uri.decodeComponent(release.installerUrl!.path),
      '/TSWill03/Veredra/releases/download/v0.1.4+6/Veredra-Setup-v0.1.4+6.exe',
    );
    expect(release.installerSha256, digest);
  });

  test('Windows release without digest never offers silent installer', () {
    final AppRelease release = AppRelease.fromGitHub(<String, dynamic>{
      'tag_name': 'v0.1.4+5',
      'draft': false,
      'prerelease': false,
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Veredra-Setup-v0.1.4+5.exe',
          'browser_download_url':
              'https://malicious.example/Veredra-Setup-v0.1.4+5.exe',
          'size': 100,
          'digest': '',
        },
      ],
    });
    expect(release.hasVerifiedWindowsInstaller, isFalse);
  });

  test(
    'Github unavailable falls back to Web notes without installer',
    () async {
      final MockClient client = MockClient(
        (request) async => request.url.host == 'api.github.com'
            ? http.Response('Not Found', 404)
            : webResponse('0.1.4', 5),
      );
      final UpdateService service = UpdateService(
        client: client,
        target: UpdateTarget.windows,
        currentVersion: '0.1.3+4',
      );
      final AppRelease release = (await service.check())!;
      expect(release.hasVerifiedWindowsInstaller, isFalse);
      service.dispose();
      client.close();
    },
  );
}
