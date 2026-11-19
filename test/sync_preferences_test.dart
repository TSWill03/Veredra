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

  test('file consent persists separately and is opt-in', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final SyncPreferencesService service = SyncPreferencesService(
      profileId: 'principal',
      storage: storage,
    );

    expect(
      service.setSyncBookFiles(true),
      throwsStateError,
    );

    final SyncPreferences metadataOnly = await service.setEnabled(true);
    expect(metadataOnly.syncBookFiles, isFalse);
    expect(metadataOnly.filesConsentAt, isNull);

    final SyncPreferences filesEnabled = await service.setSyncBookFiles(true);
    expect(filesEnabled.syncBookFiles, isTrue);
    expect(filesEnabled.filesConsentAt, isNotNull);

    final SyncPreferences reloaded = await service.load();
    expect(reloaded.syncBookFiles, isTrue);
    expect(reloaded.filesConsentAt, isNotNull);

    final SyncPreferences disabled = await service.setSyncBookFiles(false);
    expect(disabled.syncBookFiles, isFalse);
    expect(disabled.enabled, isTrue);

    final SyncPreferences metadataDisabled = await service.setEnabled(false);
    expect(metadataDisabled.syncBookFiles, isFalse);
    expect(metadataDisabled.enabled, isFalse);
  });

  test('file consent cannot be restored from an unconsented preference',
      () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final SyncPreferencesService service = SyncPreferencesService(
      profileId: 'principal',
      storage: storage,
    );
    expect(
      () => service.save(const SyncPreferences(
        enabled: false,
        automatic: true,
        syncBookFiles: true,
      )),
      throwsStateError,
    );
  });
}
