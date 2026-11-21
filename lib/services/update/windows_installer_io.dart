// Signature: dev.tswicolly03
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'update_service.dart';

bool _allowedRedirect(Uri uri, {required bool first}) {
  if (uri.scheme != 'https') return false;
  if (first) {
    return uri.host == 'github.com' &&
        uri.path.startsWith('/TSWill03/Veredra/releases/download/');
  }
  return uri.host == 'github.com' ||
      uri.host.endsWith('.githubusercontent.com');
}

Future<void> installWindowsRelease(
  AppRelease release,
  void Function(double value) onProgress,
) async {
  if (!Platform.isWindows || !release.hasVerifiedWindowsInstaller) {
    throw StateError('Este build nao possui instalador Windows verificado.');
  }
  final Uri source = release.installerUrl!;
  if (!_allowedRedirect(source, first: true) ||
      !source.path.endsWith('/Veredra-Setup-v${release.version}.exe')) {
    throw const FormatException('URL do instalador nao autorizado.');
  }
  final int expectedSize = release.installerSize!;
  if (expectedSize > 350 * 1024 * 1024) {
    throw const FormatException('O instalador excede o limite permitido.');
  }

  final Directory tmp = Directory(p.join(
    (await getTemporaryDirectory()).path,
    'veredra-verified-updates',
  ));
  await tmp.create(recursive: true);
  final File installer =
      File(p.join(tmp.path, 'Veredra-Setup-v${release.version}.exe'));
  final File partial = File('${installer.path}.part');

  Future<bool> verified(File file) async {
    if (!await file.exists()) return false;
    if (await file.length() != expectedSize) return false;
    final Digest checksum = await sha256.bind(file.openRead()).first;
    return checksum.toString().toLowerCase() ==
        release.installerSha256!.toLowerCase();
  }

  if (!await verified(installer)) {
    if (await partial.exists()) await partial.delete();
    final http.Client client = http.Client();
    IOSink? output;
    try {
      Uri next = source;
      http.StreamedResponse? response;
      for (int redirects = 0; redirects < 6; redirects++) {
        if (!_allowedRedirect(next, first: redirects == 0)) {
          throw const FormatException(
              'Redirecionamento externo nao autorizado.');
        }
        final http.Request request = http.Request('GET', next)
          ..followRedirects = false;
        response =
            await client.send(request).timeout(const Duration(seconds: 30));
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final String? location = response.headers['location'];
          if (location == null) {
            throw const FormatException('Redirect sem destino.');
          }
          next = next.resolve(location);
          continue;
        }
        break;
      }
      if (response == null || response.statusCode != 200) {
        throw StateError(
            'Download indisponivel (HTTP ${response?.statusCode}).');
      }
      output = partial.openWrite();
      int downloaded = 0;
      await for (final List<int> chunk in response.stream.timeout(
        const Duration(minutes: 2),
      )) {
        downloaded += chunk.length;
        if (downloaded > expectedSize) {
          throw const FormatException('Download excedeu o tamanho esperado.');
        }
        output.add(chunk);
        onProgress(downloaded / expectedSize);
      }
      await output.flush();
      await output.close();
      output = null;
      if (!await verified(partial)) {
        throw const FormatException(
            'SHA-256 ou tamanho do instalador incorreto.');
      }
      if (await installer.exists()) await installer.delete();
      await partial.rename(installer.path);
    } finally {
      if (output != null) await output.close();
      if (await partial.exists()) await partial.delete();
      client.close();
    }
  }
  // The user explicitly confirmed the update from the library. Inno Setup
  // is per-user and restarts the app after replacing program files; it never
  // touches Application Support / profile data.
  await Process.start(
      installer.path,
      <String>[
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ],
      mode: ProcessStartMode.detached);
  exit(0);
}
