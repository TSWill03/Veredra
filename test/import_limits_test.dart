// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/import_limits.dart';

void main() {
  test('rejects oversized and repeated import payloads', () {
    expect(
      () => ImportLimits.validateFileSize(
        ImportPayloadKind.epub,
        ImportLimits.maxEpubBytes + 1,
        label: 'EPUB',
      ),
      throwsStateError,
    );
    expect(
      () => ImportLimits.validateTextCollection(
        List<int>.filled(ImportLimits.maxTextFileCount + 1, 1),
      ),
      throwsStateError,
    );
  });

  test('accepts a normal text collection', () {
    expect(
      () => ImportLimits.validateTextCollection(<int>[128, 256]),
      returnsNormally,
    );
  });
}
