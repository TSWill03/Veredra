// Signature: dev.tswicolly03
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/sync/sync_models.dart';
import 'package:txt_webnovel_reader/services/sync/sync_queue.dart';

import 'support/memory_app_storage.dart';

void main() {
  late MemoryAppStorage storage;
  late SyncQueue queue;

  setUp(() {
    storage = MemoryAppStorage();
    queue = SyncQueue(profileId: 'principal', storage: storage);
  });

  test('deduplicates repeated operations for the same entity', () async {
    await queue.enqueue(
      userId: 'user-a',
      deviceId: 'device-a',
      entityType: SyncEntityType.progress,
      entityId: 'book-a',
      payload: <String, dynamic>{'chapter': 1},
    );
    await queue.enqueue(
      userId: 'user-a',
      deviceId: 'device-a',
      entityType: SyncEntityType.progress,
      entityId: 'book-a',
      payload: <String, dynamic>{'chapter': 2},
    );

    final List<SyncOperation> operations = await queue.load();
    expect(operations, hasLength(1));
    expect(operations.single.payload['chapter'], 2);
    expect(operations.single.version, 2);
  });

  test('schedules deterministic exponential retry and later succeeds',
      () async {
    final DateTime now = DateTime.utc(2026, 7, 13, 12);
    final SyncOperation operation = await queue.enqueue(
      userId: 'user-a',
      deviceId: 'device-a',
      entityType: SyncEntityType.annotation,
      entityId: 'annotation-a',
      payload: <String, dynamic>{'text': 'nota'},
      now: now,
    );

    await queue.markFailed(operation.id, now: now);
    expect(await queue.due(now: now.add(const Duration(seconds: 4))), isEmpty);
    expect(
      await queue.due(now: now.add(const Duration(seconds: 5))),
      hasLength(1),
    );

    await queue.markSucceeded(operation.id);
    expect(await queue.load(), isEmpty);
  });

  test('quarantines a corrupt persisted queue', () async {
    storage.values['profiles/principal/sync/queue.json'] = '{broken';

    expect(await queue.load(), isEmpty);
    expect(
      storage.values.keys.any((String key) => key.contains('queue.corrupt.')),
      isTrue,
    );
    expect(
      jsonDecode(
        storage.values['profiles/principal/sync/queue.json']! as String,
      ),
      isEmpty,
    );
  });
}
