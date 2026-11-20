// Signature: dev.tswicolly03
import 'dart:async';
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
  SyncQueue({required this.profileId, AppStorage? storage, Uuid? uuid})
    : _storage = storage ?? createAppStorage(),
      _uuid = uuid ?? const Uuid();

  final String profileId;
  final AppStorage _storage;
  final Uuid _uuid;

  // Serializes the *entire* read-modify-write transaction, not merely writes.
  // Without this lock two concurrent checkpoints can each read the old queue
  // and the last writer silently loses the other operation.
  Future<void> _pendingWrite = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final Completer<T> result = Completer<T>();
    _pendingWrite = _pendingWrite.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<List<SyncOperation>> _readUnsafe() async {
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
      await _writeUnsafe(<SyncOperation>[]);
      return <SyncOperation>[];
    }
  }

  Future<void> _writeUnsafe(List<SyncOperation> operations) =>
      _storage.writeString(
        _queueKey,
        jsonEncode(operations.map((SyncOperation op) => op.toJson()).toList()),
      );

  Future<T> _mutate<T>(T Function(List<SyncOperation>) update) =>
      _exclusive(() async {
        final List<SyncOperation> operations = await _readUnsafe();
        final T result = update(operations);
        await _writeUnsafe(operations);
        return result;
      });

  Future<List<SyncOperation>> load() => _exclusive(() async => _readUnsafe());

  Future<SyncOperation> enqueue({
    required String userId,
    required String deviceId,
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    SyncOperationType operationType = SyncOperationType.upsert,
    DateTime? now,
  }) => _mutate((List<SyncOperation> operations) {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    final int existingIndex = operations.indexWhere(
      (SyncOperation op) =>
          op.userId == userId &&
          op.entityType == entityType &&
          op.entityId == entityId,
    );
    final SyncOperation? previous = existingIndex >= 0
        ? operations[existingIndex]
        : null;
    // Do not bump revisions or reset backoff for unchanged snapshots.
    if (previous != null &&
        previous.operationType == operationType &&
        jsonEncode(previous.payload) == jsonEncode(payload)) {
      return previous;
    }
    final SyncOperation operation = SyncOperation(
      // Keep the same ID for idempotent remote upserts; the exact version
      // is checked before acknowledging a concurrent replacement.
      id: previous?.id ?? _uuid.v4(),
      userId: userId,
      deviceId: deviceId,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: Map<String, dynamic>.from(payload),
      createdAt: previous?.createdAt ?? timestamp,
      updatedAt: timestamp,
      version: (previous?.version ?? 0) + 1,
    );
    if (existingIndex >= 0) {
      operations[existingIndex] = operation;
    } else {
      operations.add(operation);
    }
    return operation;
  });

  Future<List<SyncOperation>> due({DateTime? now}) => _exclusive(() async {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    return (await _readUnsafe())
        .where((SyncOperation operation) => operation.isDue(timestamp))
        .toList(growable: false);
  });

  /// An ACK for revision A must never discard revision B, even when the
  /// remote upsert reused the operation UUID while A was in flight.
  Future<void> markSucceeded(String operationId, {int? expectedVersion}) =>
      _mutate((List<SyncOperation> operations) {
        operations.removeWhere(
          (SyncOperation op) =>
              op.id == operationId &&
              (expectedVersion == null || op.version == expectedVersion),
        );
      });

  Future<void> markFailed(
    String operationId, {
    int? expectedVersion,
    DateTime? now,
  }) => _mutate((List<SyncOperation> operations) {
    final int index = operations.indexWhere(
      (SyncOperation op) =>
          op.id == operationId &&
          (expectedVersion == null || op.version == expectedVersion),
    );
    if (index < 0) return;
    final int nextAttempt = operations[index].attemptCount + 1;
    operations[index] = operations[index].copyWith(
      attemptCount: nextAttempt,
      nextAttemptAt: (now ?? DateTime.now()).toUtc().add(
        SyncRetryPolicy.delayForAttempt(nextAttempt - 1),
      ),
    );
  });

  /// Only discard progress operations proven older than the server value.
  /// Re-read and compare under the lock: a newer local scroll can have been
  /// enqueued after the cloud snapshot was fetched.
  Future<void> discardEntity({
    required String userId,
    required SyncEntityType entityType,
    required String entityId,
    DateTime? maxProgressSavedAt,
  }) => _mutate((List<SyncOperation> operations) {
    operations.removeWhere((SyncOperation op) {
      if (op.userId != userId ||
          op.entityType != entityType ||
          op.entityId != entityId) {
        return false;
      }
      if (entityType != SyncEntityType.progress) return true;
      if (maxProgressSavedAt == null) return false;
      final dynamic raw = op.payload['data'];
      final Map<String, dynamic> data = raw is Map<String, dynamic>
          ? raw
          : <String, dynamic>{};
      final DateTime? localTime = DateTime.tryParse(
        data['savedAt'] as String? ?? '',
      );
      return localTime == null ||
          !localTime.toUtc().isAfter(maxProgressSavedAt.toUtc());
    });
  });

  Future<void> clearForUser(String userId) =>
      _mutate((List<SyncOperation> operations) {
        operations.removeWhere((SyncOperation op) => op.userId == userId);
      });

  String get _queueKey => 'profiles/$profileId/sync/queue.json';
}
