// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/diagnostics_service.dart';

import 'support/memory_app_storage.dart';

void main() {
  test('diagnostics redact credentials and email addresses', () async {
    final DiagnosticsService diagnostics = DiagnosticsService(
      storage: MemoryAppStorage(),
    );
    await diagnostics.record(
      DiagnosticCategory.authentication,
      StateError(
        'token=abc123 password=hunter2 user=reader@example.com',
      ),
      StackTrace.fromString('authorization: Bearer top.secret.value'),
    );

    final List<Map<String, dynamic>> events = await diagnostics.readEvents();
    final String encoded = events.single.toString();
    expect(encoded, isNot(contains('abc123')));
    expect(encoded, isNot(contains('hunter2')));
    expect(encoded, isNot(contains('reader@example.com')));
    expect(encoded, isNot(contains('top.secret.value')));
    expect(encoded, contains('[redacted]'));
  });
}
