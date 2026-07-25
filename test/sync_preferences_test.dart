// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/sync/sync_preferences_service.dart';

import 'support/memory_app_storage.dart';

void main() {
  test('sync requires explicit consent and never enables files implicitly',
      () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final SyncPreferencesService service = SyncPreferencesService(
      profileId: 'principal',
      storage: storage,
    );

    expect((await service.load()).enabled, isFalse);
    final SyncPreferences enabled = await service.setEnabled(true);
    expect(enabled.enabled, isTrue);
    expect(enabled.syncBookFiles, isFalse);

    expect(
      () => service.save(
        const SyncPreferences(
          enabled: true,
          automatic: true,
          syncBookFiles: true,
        ),
      ),
      throwsStateError,
    );
  });
}
