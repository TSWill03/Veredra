// Signature: dev.tswicolly03
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS registers the native Supabase OAuth redirect scheme', () {
    final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(plist, contains('<string>veredra</string>'));
  });

  test('Android registers the native Supabase OAuth redirect scheme', () {
    final String manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:scheme="veredra"'));
    expect(manifest, contains('android:host="auth-callback"'));
  });
}
