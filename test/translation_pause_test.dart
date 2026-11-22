import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/models/translation_progress.dart';

void main() {
  test('pause is idempotent and attaches to a late worker', () {
    final pause = TranslationPause();
    pause.request();
    var calls = 0;
    pause.attach(() => calls++);
    pause.request();
    expect(calls, 1);
    expect(pause.check, throwsA(isA<TranslationPausedException>()));
    pause.attach(null);
  });
}
