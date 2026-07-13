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

  Future<List<RemoteSyncRecord>> pullSince({
    required String userId,
    required DateTime? since,
  });
}
