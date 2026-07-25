// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../book_service.dart';
import '../diagnostics_service.dart';
import '../storage/app_storage.dart';
import 'book_asset_gateway.dart';
import 'book_asset_sync_service.dart';
import 'device_identity_service.dart';
import 'local_sync_repository.dart';
import 'network_monitor.dart';
import 'remote_sync_gateway.dart';
import 'sync_models.dart';
import 'sync_preferences_service.dart';
import 'sync_queue.dart';

class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator({
    required this.profileId,
    required this.currentUserId,
    required this.localRepository,
    required this.queue,
    required this.preferencesService,
    required this.deviceIdentityService,
    required this.networkMonitor,
    required this.remoteGateway,
    this.bookAssetSynchronizer,
    AppStorage? storage,
    DiagnosticsService? diagnostics,
  })  : _storage = storage ?? createAppStorage(),
        _diagnostics = diagnostics ?? DiagnosticsService();

  final String profileId;
  final String? Function() currentUserId;
  final LocalSyncDataSource localRepository;
  final SyncQueue queue;
  final SyncPreferencesService preferencesService;
  final DeviceIdentityService deviceIdentityService;
  final NetworkMonitor networkMonitor;
  final RemoteSyncGateway? remoteGateway;
  final BookAssetSynchronizer? bookAssetSynchronizer;
  final AppStorage _storage;
  final DiagnosticsService _diagnostics;
  BookAssetSynchronizer? _resolvedBookAssetSynchronizer;

  SyncPhase phase = SyncPhase.localOnly;
  SyncPreferences preferences = const SyncPreferences.defaults();
  DateTime? lastSyncAt;
  int pendingCount = 0;
  String? errorMessage;
  Future<void>? _activeSync;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _automaticTimer;

  Future<void> initialize() async {
    preferences = await preferencesService.load();
    pendingCount = (await queue.load()).length;
    lastSyncAt = DateTime.tryParse(
      await _storage.readString(_lastSyncKey) ?? '',
    );
    phase = preferences.enabled
        ? pendingCount > 0
            ? SyncPhase.pending
            : SyncPhase.synchronized
        : SyncPhase.localOnly;
    _networkSubscription = networkMonitor.changes.listen((bool online) {
      if (!online) {
        phase = pendingCount > 0 ? SyncPhase.pending : SyncPhase.offline;
        notifyListeners();
        return;
      }
      if (preferences.enabled && preferences.automatic) {
        unawaited(syncNow(stageSnapshot: true));
      }
    });
    _scheduleAutomaticSync();
    notifyListeners();
  }

  Future<void> setConsent(bool enabled) async {
    preferences = await preferencesService.setEnabled(enabled);
    phase = enabled ? SyncPhase.pending : SyncPhase.localOnly;
    errorMessage = null;
    _scheduleAutomaticSync();
    notifyListeners();
    if (enabled) {
      await syncNow(stageSnapshot: true);
    }
  }

  Future<void> setAutomatic(bool enabled) async {
    preferences = preferences.copyWith(automatic: enabled);
    await preferencesService.save(preferences);
    _scheduleAutomaticSync();
    notifyListeners();
  }

  Future<void> setBookFiles(bool enabled) async {
    preferences = await preferencesService.setBookFiles(enabled);
    errorMessage = null;
    notifyListeners();
    if (enabled) {
      await syncNow(stageSnapshot: true);
    }
  }

  Future<void> syncNow({bool stageSnapshot = true}) {
    return _activeSync ??=
        _synchronize(stageSnapshot: stageSnapshot).whenComplete(
      () => _activeSync = null,
    );
  }

  Future<void> _synchronize({required bool stageSnapshot}) async {
    final String? userId = currentUserId();
    if (!preferences.enabled) {
      phase = SyncPhase.localOnly;
      notifyListeners();
      return;
    }
    if (userId == null || remoteGateway == null) {
      phase = userId == null ? SyncPhase.sessionExpired : SyncPhase.error;
      errorMessage = userId == null
          ? 'Entre na conta para sincronizar.'
          : 'O backend de sincronizacao nao esta configurado.';
      notifyListeners();
      return;
    }

    phase = SyncPhase.synchronizing;
    errorMessage = null;
    notifyListeners();
    final String deviceId = await deviceIdentityService.loadOrCreateId();

    if (stageSnapshot) {
      for (final LocalSyncSnapshot snapshot
          in await localRepository.createSnapshot()) {
        await queue.enqueue(
          userId: userId,
          deviceId: deviceId,
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
          payload: <String, dynamic>{'data': snapshot.data},
        );
      }
    }
    pendingCount = (await queue.load()).length;

    if (!await networkMonitor.isOnline()) {
      phase = SyncPhase.offline;
      notifyListeners();
      return;
    }

    bool hadFailure = false;
    try {
      await remoteGateway!.upsertDevice(
        userId: userId,
        deviceId: deviceId,
        name: 'Veredra ${deviceIdentityService.platformLabel}',
        platform: deviceIdentityService.platformLabel,
      );
      for (final SyncOperation operation in await queue.due()) {
        try {
          await remoteGateway!.push(operation);
          await queue.markSucceeded(operation.id);
        } on SyncRemoteException catch (error, stackTrace) {
          hadFailure = true;
          await queue.markFailed(operation.id);
          if (error.sessionExpired) {
            phase = SyncPhase.sessionExpired;
            errorMessage = error.message;
            await _diagnostics.record(
              DiagnosticCategory.synchronization,
              error,
              stackTrace,
            );
            break;
          }
        }
      }

      if (phase != SyncPhase.sessionExpired) {
        final List<RemoteSyncRecord> records =
            await remoteGateway!.pullSince(userId: userId, since: lastSyncAt);
        await localRepository.applyRemoteRecords(records);

        if (preferences.syncBookFiles) {
          final BookAssetSynchronizer? synchronizer =
              _resolveBookAssetSynchronizer();
          if (synchronizer == null) {
            throw const SyncRemoteException(
              'A sincronizacao de arquivos nao esta configurada neste build.',
            );
          }
          await synchronizer.syncAll(userId: userId);
        }

        lastSyncAt = DateTime.now().toUtc();
        await _storage.writeString(
          _lastSyncKey,
          lastSyncAt!.toIso8601String(),
        );
      }
    } on SyncRemoteException catch (error, stackTrace) {
      hadFailure = true;
      phase = error.sessionExpired ? SyncPhase.sessionExpired : SyncPhase.error;
      errorMessage = error.message;
      await _diagnostics.record(
        DiagnosticCategory.synchronization,
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      hadFailure = true;
      phase = SyncPhase.error;
      errorMessage = 'A sincronizacao falhou sem afetar os dados locais.';
      await _diagnostics.record(
        DiagnosticCategory.synchronization,
        error,
        stackTrace,
      );
    }

    pendingCount = (await queue.load()).length;
    if (phase != SyncPhase.sessionExpired && phase != SyncPhase.error) {
      phase = hadFailure || pendingCount > 0
          ? SyncPhase.pending
          : SyncPhase.synchronized;
    }
    notifyListeners();
  }

  BookAssetSynchronizer? _resolveBookAssetSynchronizer() {
    if (bookAssetSynchronizer != null) {
      return bookAssetSynchronizer;
    }
    if (_resolvedBookAssetSynchronizer != null) {
      return _resolvedBookAssetSynchronizer;
    }
    final RemoteSyncGateway? remote = remoteGateway;
    if (remote is! BookAssetRemoteGateway) {
      return null;
    }
    final LocalSyncDataSource local = localRepository;
    if (local is! LocalSyncRepository) {
      return null;
    }
    final BookService bookService = BookService()..configureProfile(profileId);
    return _resolvedBookAssetSynchronizer = BookAssetSyncService(
      profileId: profileId,
      libraryService: local.libraryService,
      bookService: bookService,
      remoteGateway: remote,
    );
  }

  void _scheduleAutomaticSync() {
    _automaticTimer?.cancel();
    if (preferences.enabled && preferences.automatic) {
      _automaticTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        unawaited(syncNow(stageSnapshot: true));
      });
    }
  }

  String get _lastSyncKey => 'profiles/$profileId/sync/last_sync.txt';

  @override
  void dispose() {
    _automaticTimer?.cancel();
    unawaited(_networkSubscription?.cancel());
    super.dispose();
  }
}

extension SyncPhaseLabel on SyncPhase {
  String get label {
    switch (this) {
      case SyncPhase.localOnly:
        return 'Somente local';
      case SyncPhase.synchronized:
        return 'Sincronizado';
      case SyncPhase.synchronizing:
        return 'Sincronizando';
      case SyncPhase.offline:
        return 'Offline';
      case SyncPhase.pending:
        return 'Alteracoes pendentes';
      case SyncPhase.error:
        return 'Erro de sincronizacao';
      case SyncPhase.sessionExpired:
        return 'Sessao expirada';
    }
  }
}
