// Signature: dev.tswicolly03
import 'sync_models.dart';

class SyncRemoteException implements Exception {
  const SyncRemoteException(this.message, {this.sessionExpired = false});

  final String message;
  final bool sessionExpired;

  @override
  String toString() => message;
}

abstract class RemoteSyncGateway {
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String name,
    required String platform,
  });

  Future<void> push(SyncOperation operation);

  /// Always fetch the current position for each book before pushing any
  /// queued checkpoint. The other tables continue using delta sync.
  Future<List<RemoteSyncRecord>> pullProgress({required String userId}) async {
    final List<RemoteSyncRecord> records =
        await pullSince(userId: userId, since: null);
    return records
        .where(
            (RemoteSyncRecord row) => row.entityType == SyncEntityType.progress)
        .toList(growable: false);
  }

  Future<List<RemoteSyncRecord>> pullSince({
    required String userId,
    required DateTime? since,
  });
}
