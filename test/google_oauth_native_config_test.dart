// Signature: dev.tswicolly03
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:txt_webnovel_reader/services/auth/supabase_auth_gateway.dart';

void main() {
  test('iOS registers the native Supabase OAuth redirect scheme', () {
    final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(plist, contains('<string>veredra</string>'));
  });

  test('Windows Google OAuth button respects the configured feature flag', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final SupabaseClient client =
        SupabaseClient('https://example.supabase.co', 'test-publishable-key');
    addTearDown(client.dispose);
    expect(
      SupabaseAuthGateway(client, googleAuthEnabled: true).isGoogleAuthEnabled,
      isTrue,
    );
    expect(
      SupabaseAuthGateway(client, googleAuthEnabled: false).isGoogleAuthEnabled,
      isFalse,
    );
  });

  test('Windows offers Google OAuth and forwards callbacks safely', () {
    final String gateway =
        File('lib/services/auth/supabase_auth_gateway.dart').readAsStringSync();
    final String runner = File('windows/runner/main.cpp').readAsStringSync();
    final String installer =
        File('tool/install_windows_oauth_protocol.ps1').readAsStringSync();
    expect(gateway, contains('TargetPlatform.windows'));
    expect(runner, contains('veredra://auth-callback/'));
    expect(runner, contains('WM_COPYDATA'));
    expect(runner, contains('QueryFullProcessImageNameW'));
    expect(installer, contains('HKCU:'));
    expect(installer, contains('veredra.exe'));
    expect(installer, contains('URL Protocol'));
  });

  test('Android registers the native Supabase OAuth redirect scheme', () {
    final String manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:scheme="veredra"'));
    expect(manifest, contains('android:host="auth-callback"'));
  });
}
