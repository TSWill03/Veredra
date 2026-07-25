// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/sync/device_identity_service.dart';
import 'package:txt_webnovel_reader/services/sync/local_sync_repository.dart';
import 'package:txt_webnovel_reader/services/sync/network_monitor.dart';
import 'package:txt_webnovel_reader/services/sync/remote_sync_gateway.dart';
import 'package:txt_webnovel_reader/services/sync/sync_coordinator.dart';
import 'package:txt_webnovel_reader/services/sync/sync_models.dart';
import 'package:txt_webnovel_reader/services/sync/sync_preferences_service.dart';
import 'package:txt_webnovel_reader/services/sync/sync_queue.dart';

import 'support/memory_app_storage.dart';

void main() {
  test('offline changes stay queued and are sent when network returns',
      () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final FakeNetworkMonitor network = FakeNetworkMonitor(false);
    final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
    final FakeLocalSyncDataSource local = FakeLocalSyncDataSource(
      snapshots: <LocalSyncSnapshot>[
        const LocalSyncSnapshot(
          entityType: SyncEntityType.progress,
          entityId: 'book-a',
          data: <String, dynamic>{
            'bookId': 'book-a',
            'chapterIndex': 2,
            'chapterProgress': 0.4,
          },
        ),
      ],
    );
    final SyncCoordinator coordinator = await _coordinator(
      storage: storage,
      network: network,
      remote: remote,
      local: local,
    );
    addTearDown(coordinator.dispose);

    await coordinator.syncNow();
    expect(coordinator.phase, SyncPhase.offline);
    expect(coordinator.pendingCount, 1);
    expect(remote.records, isEmpty);

    network.online = true;
    await coordinator.syncNow();
    expect(coordinator.phase, SyncPhase.synchronized);
    expect(coordinator.pendingCount, 0);
    expect(remote.records.values.single.payload['chapterIndex'], 2);
  });

  test('another session pulls progress and annotations for the same user',
      () async {
    final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
    final FakeNetworkMonitor network = FakeNetworkMonitor(true);
    final FakeLocalSyncDataSource firstLocal = FakeLocalSyncDataSource(
      snapshots: <LocalSyncSnapshot>[
        const LocalSyncSnapshot(
          entityType: SyncEntityType.progress,
          entityId: 'book-a',
          data: <String, dynamic>{
            'bookId': 'book-a',
            'chapterIndex': 5,
            'chapterProgress': 0.8,
          },
        ),
        const LocalSyncSnapshot(
          entityType: SyncEntityType.annotation,
          entityId: 'note-a',
          data: <String, dynamic>{
            'id': 'note-a',
            'bookId': 'book-a',
            'note': 'Importante',
          },
        ),
      ],
    );
    final SyncCoordinator first = await _coordinator(
      storage: MemoryAppStorage(),
      network: network,
      remote: remote,
      local: firstLocal,
    );
    addTearDown(first.dispose);
    await first.syncNow();

    final FakeLocalSyncDataSource secondLocal = FakeLocalSyncDataSource();
    final SyncCoordinator second = await _coordinator(
      storage: MemoryAppStorage(),
      network: network,
      remote: remote,
      local: secondLocal,
    );
    addTearDown(second.dispose);
    await second.syncNow();

    expect(
      secondLocal.applied.map((RemoteSyncRecord record) => record.entityType),
      containsAll(<SyncEntityType>[
        SyncEntityType.progress,
        SyncEntityType.annotation,
      ]),
    );
  });

  test('expired token changes state without deleting local queue', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway()..expire = true;
    final SyncCoordinator coordinator = await _coordinator(
      storage: storage,
      network: FakeNetworkMonitor(true),
      remote: remote,
      local: FakeLocalSyncDataSource(
        snapshots: const <LocalSyncSnapshot>[
          LocalSyncSnapshot(
            entityType: SyncEntityType.bookmark,
            entityId: 'bookmark-a',
            data: <String, dynamic>{'bookId': 'book-a'},
          ),
        ],
      ),
    );
    addTearDown(coordinator.dispose);

    await coordinator.syncNow();
    expect(coordinator.phase, SyncPhase.sessionExpired);
    expect(coordinator.pendingCount, 1);
  });
}

Future<SyncCoordinator> _coordinator({
  required MemoryAppStorage storage,
  required FakeNetworkMonitor network,
  required FakeRemoteSyncGateway remote,
  required FakeLocalSyncDataSource local,
}) async {
  final SyncPreferencesService preferences = SyncPreferencesService(
    profileId: 'principal',
    storage: storage,
  );
  await preferences.setEnabled(true);
  final SyncCoordinator coordinator = SyncCoordinator(
    profileId: 'principal',
    currentUserId: () => '11111111-1111-4111-8111-111111111111',
    localRepository: local,
    queue: SyncQueue(profileId: 'principal', storage: storage),
    preferencesService: preferences,
    deviceIdentityService: DeviceIdentityService(storage: storage),
    networkMonitor: network,
    remoteGateway: remote,
    storage: storage,
  );
  await coordinator.initialize();
  return coordinator;
}

class FakeNetworkMonitor implements NetworkMonitor {
  FakeNetworkMonitor(this.online);

  bool online;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => controller.stream;

  @override
  Future<bool> isOnline() async => online;
}

class FakeLocalSyncDataSource implements LocalSyncDataSource {
  FakeLocalSyncDataSource({this.snapshots = const <LocalSyncSnapshot>[]});

  final List<LocalSyncSnapshot> snapshots;
  final List<RemoteSyncRecord> applied = <RemoteSyncRecord>[];

  @override
  Future<void> applyRemoteRecords(List<RemoteSyncRecord> records) async {
    applied.addAll(records);
  }

  @override
  Future<List<LocalSyncSnapshot>> createSnapshot() async => snapshots;
}

class FakeRemoteSyncGateway implements RemoteSyncGateway {
  final Map<String, RemoteSyncRecord> records = <String, RemoteSyncRecord>{};
  bool expire = false;

  @override
  Future<List<RemoteSyncRecord>> pullSince({
    required String userId,
    required DateTime? since,
  }) async {
    if (expire) {
      throw const SyncRemoteException('Sessao expirada.', sessionExpired: true);
    }
    return records.values
        .where(
          (RemoteSyncRecord record) =>
              since == null || record.updatedAt.isAfter(since),
        )
        .toList(growable: false);
  }

  @override
  Future<void> push(SyncOperation operation) async {
    if (expire) {
      throw const SyncRemoteException('Sessao expirada.', sessionExpired: true);
    }
    records['${operation.entityType.name}:${operation.entityId}'] =
        RemoteSyncRecord(
      entityType: operation.entityType,
      entityId: operation.entityId,
      payload: Map<String, dynamic>.from(
        operation.payload['data'] as Map<String, dynamic>,
      ),
      updatedAt: operation.updatedAt,
      version: operation.version,
      deletedAt: operation.operationType == SyncOperationType.delete
          ? operation.updatedAt
          : null,
    );
  }

  @override
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String name,
    required String platform,
  }) async {
    if (expire) {
      throw const SyncRemoteException('Sessao expirada.', sessionExpired: true);
    }
  }
}
