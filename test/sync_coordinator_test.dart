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
  test(
    'offline changes stay queued and are sent when network returns',
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
    },
  );

  test(
    'another session pulls progress and annotations for the same user',
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
    },
  );

  test(
    'exposes real metadata sync progress without a chapter download percent',
    () async {
      final SyncCoordinator coordinator = await _coordinator(
        storage: MemoryAppStorage(),
        network: FakeNetworkMonitor(true),
        remote: FakeRemoteSyncGateway(),
        local: FakeLocalSyncDataSource(
          snapshots: const <LocalSyncSnapshot>[
            LocalSyncSnapshot(
              entityType: SyncEntityType.book,
              entityId: 'book-a',
              data: <String, dynamic>{'title': 'Example'},
            ),
            LocalSyncSnapshot(
              entityType: SyncEntityType.progress,
              entityId: 'book-a',
              data: <String, dynamic>{'chapterIndex': 8},
            ),
          ],
        ),
      );
      addTearDown(coordinator.dispose);
      final List<String> stages = <String>[];
      final List<double> progressValues = <double>[];
      coordinator.addListener(() {
        if (coordinator.phase == SyncPhase.synchronizing) {
          stages.add(coordinator.activeStep ?? '');
          if (coordinator.operationProgress != null) {
            progressValues.add(coordinator.operationProgress!);
          }
        }
      });

      await coordinator.syncNow();
      expect(stages, contains('Preparando dados de leitura'));
      expect(stages, contains('Enviando dados de leitura'));
      expect(stages, contains('Buscando dados de leitura'));
      expect(stages, contains('Aplicando dados de leitura'));
      expect(progressValues, contains(0.0));
      expect(progressValues, contains(0.5));
      expect(progressValues, contains(1.0));
      expect(coordinator.activeStep, isNull);
      expect(coordinator.operationProgress, isNull);
      expect(coordinator.phase, SyncPhase.synchronized);
    },
  );

  test(
    'a stale Web checkpoint cannot overwrite a newer desktop position',
    () async {
      final DateTime recent = DateTime.utc(2026, 11, 19, 18, 0);
      final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
      remote.records['progress:book-a'] = RemoteSyncRecord(
        entityType: SyncEntityType.progress,
        entityId: 'book-a',
        payload: <String, dynamic>{
          'bookId': 'book-a',
          'chapterIndex': 10,
          'chapterProgress': 0.75,
          'savedAt': recent.toIso8601String(),
        },
        updatedAt: recent,
        version: 3,
      );
      final FakeLocalSyncDataSource oldWeb = FakeLocalSyncDataSource(
        snapshots: <LocalSyncSnapshot>[
          LocalSyncSnapshot(
            entityType: SyncEntityType.progress,
            entityId: 'book-a',
            data: <String, dynamic>{
              'bookId': 'book-a',
              'chapterIndex': 1,
              'chapterProgress': 0.25,
              'savedAt': recent
                  .subtract(const Duration(hours: 2))
                  .toIso8601String(),
            },
          ),
        ],
      );
      final SyncCoordinator session = await _coordinator(
        storage: MemoryAppStorage(),
        network: FakeNetworkMonitor(true),
        remote: remote,
        local: oldWeb,
      );
      addTearDown(session.dispose);
      await session.syncNow();
      expect(remote.records['progress:book-a']!.payload['chapterIndex'], 10);
      expect(oldWeb.applied, isNotEmpty);
      expect(session.pendingCount, 0);
    },
  );

  test(
    'new session saved while re-reading an earlier chapter is uploaded',
    () async {
      final DateTime recent = DateTime.utc(2026, 11, 19, 18, 0);
      final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
      remote.records['progress:book-a'] = RemoteSyncRecord(
        entityType: SyncEntityType.progress,
        entityId: 'book-a',
        payload: <String, dynamic>{
          'bookId': 'book-a',
          'chapterIndex': 15,
          'chapterProgress': 0.9,
          'savedAt': recent
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
        },
        updatedAt: recent.subtract(const Duration(minutes: 5)),
        version: 1,
      );
      final FakeLocalSyncDataSource reader = FakeLocalSyncDataSource(
        snapshots: <LocalSyncSnapshot>[
          LocalSyncSnapshot(
            entityType: SyncEntityType.progress,
            entityId: 'book-a',
            data: <String, dynamic>{
              'bookId': 'book-a',
              'chapterIndex': 2,
              'chapterProgress': 0.2,
              'savedAt': recent.toIso8601String(),
            },
          ),
        ],
      );
      final SyncCoordinator session = await _coordinator(
        storage: MemoryAppStorage(),
        network: FakeNetworkMonitor(true),
        remote: remote,
        local: reader,
      );
      addTearDown(session.dispose);
      await session.syncNow();
      expect(remote.records['progress:book-a']!.payload['chapterIndex'], 2);
      expect(session.pendingCount, 0);
    },
  );

  test(
    'queued offline checkpoint is discarded when cloud became newer',
    () async {
      final DateTime recent = DateTime.utc(2026, 11, 19, 18, 0);
      final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
      final FakeNetworkMonitor network = FakeNetworkMonitor(false);
      final FakeLocalSyncDataSource oldReader = FakeLocalSyncDataSource(
        snapshots: <LocalSyncSnapshot>[
          LocalSyncSnapshot(
            entityType: SyncEntityType.progress,
            entityId: 'book-a',
            data: <String, dynamic>{
              'bookId': 'book-a',
              'chapterIndex': 2,
              'savedAt': recent
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            },
          ),
        ],
      );
      final SyncCoordinator session = await _coordinator(
        storage: MemoryAppStorage(),
        network: network,
        remote: remote,
        local: oldReader,
      );
      addTearDown(session.dispose);
      await session.syncNow();
      expect(session.pendingCount, 1);
      remote.records['progress:book-a'] = RemoteSyncRecord(
        entityType: SyncEntityType.progress,
        entityId: 'book-a',
        payload: <String, dynamic>{
          'bookId': 'book-a',
          'chapterIndex': 7,
          'savedAt': recent.toIso8601String(),
        },
        updatedAt: recent,
        version: 2,
      );
      network.online = true;
      await session.syncNow();
      expect(remote.records['progress:book-a']!.payload['chapterIndex'], 7);
      expect(session.pendingCount, 0);
    },
  );

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

  test(
    'per-book sync skips full library and does not push book content',
    () async {
      final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
      final CountingLocalSyncDataSource local = CountingLocalSyncDataSource(
        snapshots: <LocalSyncSnapshot>[
          LocalSyncSnapshot(
            entityType: SyncEntityType.progress,
            entityId: 'book-a',
            data: <String, dynamic>{
              'bookId': 'book-a',
              'chapterIndex': 257,
              'savedAt': DateTime.utc(2026, 11, 19, 20).toIso8601String(),
            },
          ),
          const LocalSyncSnapshot(
            entityType: SyncEntityType.book,
            entityId: 'book-a',
            data: <String, dynamic>{'title': 'Book content must stay local'},
          ),
          const LocalSyncSnapshot(
            entityType: SyncEntityType.progress,
            entityId: 'book-b',
            data: <String, dynamic>{'bookId': 'book-b', 'chapterIndex': 1},
          ),
        ],
      );
      final SyncCoordinator coordinator = await _coordinator(
        storage: MemoryAppStorage(),
        network: FakeNetworkMonitor(true),
        remote: remote,
        local: local,
      );
      addTearDown(coordinator.dispose);
      await coordinator.syncProgress('book-a');
      expect(local.fullSnapshots, 0);
      expect(local.targetedSnapshots, 1);
      expect(remote.targetedProgressPulls, 2);
      expect(remote.allProgressPulls, 0);
      expect(remote.records.keys.toSet(), <String>{'progress:book-a'});
      expect(coordinator.pendingCount, 0);
      expect(coordinator.lastProgressSyncAt, isNotNull);
      expect(
        coordinator.lastSyncAt,
        isNull,
        reason: 'Progress must not advance the metadata delta cursor',
      );
    },
  );

  test(
    'per-book offline outbox survives and is retried on reconnect',
    () async {
      final FakeNetworkMonitor network = FakeNetworkMonitor(false);
      final FakeRemoteSyncGateway remote = FakeRemoteSyncGateway();
      final SyncCoordinator coordinator = await _coordinator(
        storage: MemoryAppStorage(),
        network: network,
        remote: remote,
        local: CountingLocalSyncDataSource(
          snapshots: <LocalSyncSnapshot>[
            LocalSyncSnapshot(
              entityType: SyncEntityType.progress,
              entityId: 'book-x',
              data: <String, dynamic>{
                'bookId': 'book-x',
                'chapterIndex': 15,
                'savedAt': DateTime.utc(2026, 11, 19, 23).toIso8601String(),
              },
            ),
          ],
        ),
      );
      addTearDown(coordinator.dispose);
      await coordinator.syncProgress('book-x');
      expect(coordinator.phase, SyncPhase.offline);
      expect(coordinator.pendingCount, 1);
      network.online = true;
      await coordinator.syncProgress('book-x');
      expect(coordinator.pendingCount, 0);
      expect(remote.records['progress:book-x']!.payload['chapterIndex'], 15);
    },
  );
}

class CountingLocalSyncDataSource extends FakeLocalSyncDataSource {
  CountingLocalSyncDataSource({required super.snapshots});

  int fullSnapshots = 0;
  int targetedSnapshots = 0;

  @override
  Future<List<LocalSyncSnapshot>> createSnapshot() async {
    fullSnapshots++;
    return snapshots;
  }

  @override
  Future<LocalSyncSnapshot?> loadProgressSnapshot(String bookId) async {
    targetedSnapshots++;
    for (final LocalSyncSnapshot snapshot in snapshots) {
      if (snapshot.entityType == SyncEntityType.progress &&
          snapshot.entityId == bookId) {
        return snapshot;
      }
    }
    return null;
  }
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
  int targetedProgressPulls = 0;
  int allProgressPulls = 0;
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
  Future<List<RemoteSyncRecord>> pullProgressForBook({
    required String userId,
    required String bookId,
  }) async {
    targetedProgressPulls++;
    if (expire) {
      throw const SyncRemoteException('Sessao expirada.', sessionExpired: true);
    }
    return records.values
        .where(
          (RemoteSyncRecord row) =>
              row.entityType == SyncEntityType.progress &&
              row.entityId == bookId,
        )
        .toList(growable: false);
  }

  @override
  Future<List<RemoteSyncRecord>> pullProgress({required String userId}) async {
    allProgressPulls++;
    if (expire) {
      throw const SyncRemoteException('Sessao expirada.', sessionExpired: true);
    }
    return records.values
        .where(
          (RemoteSyncRecord row) => row.entityType == SyncEntityType.progress,
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
