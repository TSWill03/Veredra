// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/sync/sync_preferences_service.dart';

import 'support/memory_app_storage.dart';

void main() {
  test('book files require a second explicit consent', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final SyncPreferencesService service = SyncPreferencesService(
      profileId: 'principal',
      storage: storage,
    );

    expect((await service.load()).enabled, isFalse);
    await expectLater(service.setBookFiles(true), throwsStateError);

    final SyncPreferences enabled = await service.setEnabled(true);
    expect(enabled.enabled, isTrue);
    expect(enabled.syncBookFiles, isFalse);

    final SyncPreferences withFiles = await service.setBookFiles(true);
    expect(withFiles.enabled, isTrue);
    expect(withFiles.syncBookFiles, isTrue);

    final SyncPreferences disabled = await service.setEnabled(false);
    expect(disabled.enabled, isFalse);
    expect(disabled.syncBookFiles, isFalse);
  });
}
