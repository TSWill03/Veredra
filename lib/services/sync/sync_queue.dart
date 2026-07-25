// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../storage/app_storage.dart';
import 'sync_models.dart';

class SyncRetryPolicy {
  const SyncRetryPolicy._();

  static Duration delayForAttempt(int attempt) {
    final int exponent = attempt.clamp(0, 9);
    return Duration(seconds: math.min(1800, 5 * math.pow(2, exponent).toInt()));
  }
}

class SyncQueue {
  SyncQueue({
    required this.profileId,
    AppStorage? storage,
    Uuid? uuid,
  })  : _storage = storage ?? createAppStorage(),
        _uuid = uuid ?? const Uuid();

  final String profileId;
  final AppStorage _storage;
  final Uuid _uuid;
  Future<void> _pendingWrite = Future<void>.value();

  Future<List<SyncOperation>> load() async {
    final String? raw = await _storage.readString(_queueKey);
    if (raw == null || raw.trim().isEmpty) {
      return <SyncOperation>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      return (decoded as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SyncOperation.fromJson)
          .where((SyncOperation operation) => operation.id.isNotEmpty)
          .toList(growable: true);
    } on FormatException {
      await _storage.writeString(
        'profiles/$profileId/sync/queue.corrupt.'
        '${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
        raw,
      );
      await _save(<SyncOperation>[]);
      return <SyncOperation>[];
    }
  }

  Future<SyncOperation> enqueue({
    required String userId,
    required String deviceId,
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    SyncOperationType operationType = SyncOperationType.upsert,
    DateTime? now,
  }) async {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    final List<SyncOperation> operations = await load();
    final int existingIndex = operations.indexWhere(
      (SyncOperation operation) =>
          operation.userId == userId &&
          operation.entityType == entityType &&
          operation.entityId == entityId,
    );
    final SyncOperation operation = SyncOperation(
      id: existingIndex >= 0 ? operations[existingIndex].id : _uuid.v4(),
      userId: userId,
      deviceId: deviceId,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: Map<String, dynamic>.from(payload),
      createdAt:
          existingIndex >= 0 ? operations[existingIndex].createdAt : timestamp,
      updatedAt: timestamp,
      version: existingIndex >= 0 ? operations[existingIndex].version + 1 : 1,
    );
    if (existingIndex >= 0) {
      operations[existingIndex] = operation;
    } else {
      operations.add(operation);
    }
    await _save(operations);
    return operation;
  }

  Future<List<SyncOperation>> due({DateTime? now}) async {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    return (await load())
        .where((SyncOperation operation) => operation.isDue(timestamp))
        .toList(growable: false);
  }

  Future<void> markSucceeded(String operationId) async {
    final List<SyncOperation> operations = await load();
    operations.removeWhere(
      (SyncOperation operation) => operation.id == operationId,
    );
    await _save(operations);
  }

  Future<void> markFailed(String operationId, {DateTime? now}) async {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    final List<SyncOperation> operations = await load();
    final int index = operations.indexWhere(
      (SyncOperation operation) => operation.id == operationId,
    );
    if (index < 0) {
      return;
    }
    final int nextAttempt = operations[index].attemptCount + 1;
    operations[index] = operations[index].copyWith(
      attemptCount: nextAttempt,
      nextAttemptAt: timestamp.add(
        SyncRetryPolicy.delayForAttempt(nextAttempt - 1),
      ),
    );
    await _save(operations);
  }

  Future<void> clearForUser(String userId) async {
    final List<SyncOperation> operations = await load();
    operations.removeWhere(
      (SyncOperation operation) => operation.userId == userId,
    );
    await _save(operations);
  }

  Future<void> _save(List<SyncOperation> operations) {
    _pendingWrite = _pendingWrite.catchError((Object _) {}).then((_) {
      return _storage.writeString(
        _queueKey,
        jsonEncode(
          operations
              .map((SyncOperation operation) => operation.toJson())
              .toList(),
        ),
      );
    });
    return _pendingWrite;
  }

  String get _queueKey => 'profiles/$profileId/sync/queue.json';
}
