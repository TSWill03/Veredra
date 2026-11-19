// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:txt_webnovel_reader/models/reading_progress.dart';
import 'package:txt_webnovel_reader/services/progress_service.dart';

import 'support/memory_app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('newer remote checkpoint can move backwards in the book', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    await storage.writeString(
      'profiles/principal/state/progress_state.json',
      '{"themeMode":"dark","lastBookReference":null,'
          '"readerPreferences":{},"progresses":{}}',
    );
    final ProgressService service = ProgressService(storage: storage);
    final DateTime earlier = DateTime.utc(2026, 11, 19, 14, 0);
    final DateTime later = earlier.add(const Duration(minutes: 2));
    await service.saveProgress(
      'book-x',
      ReadingProgress(
        chapterIndex: 20,
        chapterOffset: 10,
        chapterProgress: 0.7,
        savedAt: earlier,
      ),
    );
    await service.mergeRemoteProgress(
      'book-x',
      ReadingProgress(
        chapterIndex: 2,
        chapterOffset: 4,
        chapterProgress: 0.2,
        savedAt: later,
      ),
    );
    final ReadingProgress? restored = await service.loadProgress('book-x');
    expect(restored?.chapterIndex, 2);
    expect(restored?.chapterProgress, 0.2);
    expect(restored?.savedAt.toUtc(), later);
  });

  test('an older cloud checkpoint never overwrites more recent local scroll',
      () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    await storage.writeString(
      'profiles/principal/state/progress_state.json',
      '{"themeMode":"dark","lastBookReference":null,'
          '"readerPreferences":{},"progresses":{}}',
    );
    final ProgressService service = ProgressService(storage: storage);
    final DateTime now = DateTime.utc(2026, 11, 19, 14, 30);
    await service.saveProgress(
      'book-x',
      ReadingProgress(
        chapterIndex: 4,
        chapterOffset: 55,
        chapterProgress: 0.6,
        savedAt: now,
      ),
    );
    await service.mergeRemoteProgress(
      'book-x',
      ReadingProgress(
        chapterIndex: 18,
        chapterOffset: 8,
        chapterProgress: 0.1,
        savedAt: now.subtract(const Duration(hours: 1)),
      ),
    );
    expect((await service.loadProgress('book-x'))?.chapterIndex, 4);
  });
}
