// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics_service.dart';
import '../storage/app_storage.dart';
import 'book_file_sync_service.dart';
import 'device_identity_service.dart';
import 'local_sync_repository.dart';
import 'network_monitor.dart';
import 'remote_sync_gateway.dart';
import 'sync_conflict_resolver.dart';
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
    this.bookFileSyncService,
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
  final BookFileSyncService? bookFileSyncService;
  final AppStorage _storage;
  final DiagnosticsService _diagnostics;

  SyncPhase phase = SyncPhase.localOnly;
  SyncPreferences preferences = const SyncPreferences.defaults();
  DateTime? lastSyncAt;
  int pendingCount = 0;
  String? errorMessage;

  /// Metadata operation progress and separate book transfer progress.
  String? activeStep;
  int processedOperations = 0;
  int totalOperations = 0;
  int processedBooks = 0;
  int totalBooks = 0;
  int uploadedBooks = 0;
  int downloadedBooks = 0;
  String? bookSyncWarning;

  double? get operationProgress {
    if (phase != SyncPhase.synchronizing) return null;
    if (activeStep == 'Sincronizando livros' && totalBooks > 0) {
      return processedBooks / totalBooks;
    }
    if (activeStep == 'Enviando dados de leitura' && totalOperations > 0) {
      return processedOperations / totalOperations;
    }
    return null;
  }

  Future<void>? _activeSync;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _automaticTimer;
  Timer? _progressIdleTimer;

  /// On an idle reader, the latest scroll checkpoint is uploaded quickly.
  /// Continuous scrolling is still covered by the regular five-minute timer.
  void notifyLocalProgressSaved() {
    if (!preferences.enabled ||
        !preferences.automatic ||
        currentUserId() == null) {
      return;
    }
    _progressIdleTimer?.cancel();
    _progressIdleTimer = Timer(const Duration(seconds: 5), () {
      unawaited(syncNow(stageSnapshot: true));
    });
  }

  /// A reader waits for the latest cloud checkpoint before choosing its
  /// initial scroll position. This does not re-upload the entire library.
  Future<void> refreshReadingProgress() async {
    final String? userId = currentUserId();
    if (!preferences.enabled ||
        !preferences.automatic ||
        userId == null ||
        remoteGateway == null ||
        !await networkMonitor.isOnline()) {
      return;
    }
    try {
      final List<RemoteSyncRecord> records =
          await remoteGateway!.pullProgress(userId: userId);
      await localRepository.applyRemoteRecords(records);
    } catch (error, stackTrace) {
      await _diagnostics.record(
        DiagnosticCategory.synchronization,
        error,
        stackTrace,
      );
      // A cloud outage must never prevent reading the cached local book.
    }
  }

  Future<void> flushReadingProgress() {
    _progressIdleTimer?.cancel();
    if (!preferences.enabled ||
        !preferences.automatic ||
        currentUserId() == null) {
      return Future<void>.value();
    }
    return syncNow(stageSnapshot: true);
  }

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

  Future<void> setSyncInterval(int minutes) async {
    if (!const <int>{1, 5, 10, 15}.contains(minutes)) {
      throw StateError('Intervalo automatico invalido.');
    }
    preferences = preferences.copyWith(syncIntervalMinutes: minutes);
    await preferencesService.save(preferences);
    _scheduleAutomaticSync();
    notifyListeners();
  }

  Future<void> setSyncBookFiles(bool enabled) async {
    preferences = await preferencesService.setSyncBookFiles(enabled);
    bookSyncWarning = null;
    notifyListeners();
    if (enabled) await syncNow(stageSnapshot: true);
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
    activeStep = 'Preparando dados de leitura';
    processedOperations = 0;
    totalOperations = 0;
    processedBooks = 0;
    totalBooks = 0;
    uploadedBooks = 0;
    downloadedBooks = 0;
    bookSyncWarning = null;
    notifyListeners();
    final String deviceId = await deviceIdentityService.loadOrCreateId();

    // Keep existing offline-first semantics for metadata. Progress checkpoints
    // are deliberately staged AFTER fetching remote state on a live connection:
    // otherwise an untouched Web session can overwrite a newer desktop read.
    final List<LocalSyncSnapshot> snapshots = stageSnapshot
        ? await localRepository.createSnapshot()
        : <LocalSyncSnapshot>[];
    for (final LocalSyncSnapshot snapshot in snapshots) {
      if (snapshot.entityType == SyncEntityType.progress) continue;
      await queue.enqueue(
        userId: userId,
        deviceId: deviceId,
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
        payload: <String, dynamic>{'data': snapshot.data},
      );
    }
    pendingCount = (await queue.load()).length;
    activeStep = 'Verificando conexao';
    notifyListeners();

    if (!await networkMonitor.isOnline()) {
      // Store the user's most recent local checkpoint for a later reconnect.
      for (final LocalSyncSnapshot snapshot in snapshots) {
        if (snapshot.entityType != SyncEntityType.progress) {
          continue;
        }
        await queue.enqueue(
          userId: userId,
          deviceId: deviceId,
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
          payload: <String, dynamic>{'data': snapshot.data},
        );
      }
      pendingCount = (await queue.load()).length;
      activeStep = null;
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
      activeStep = 'Comparando posicoes de leitura';
      notifyListeners();
      final List<RemoteSyncRecord> remoteProgresses =
          await remoteGateway!.pullProgress(userId: userId);
      final Map<String, RemoteSyncRecord> remoteByBook =
          <String, RemoteSyncRecord>{
        for (final RemoteSyncRecord record in remoteProgresses)
          record.entityId: record,
      };
      final Map<String, LocalSyncSnapshot> localByBook =
          <String, LocalSyncSnapshot>{
        for (final LocalSyncSnapshot snapshot in snapshots)
          if (snapshot.entityType == SyncEntityType.progress)
            snapshot.entityId: snapshot,
      };

      // Remote checkpoints are applied first, only if newer. An earlier
      // chapter saved later is a valid "resume here" position.
      for (final RemoteSyncRecord remote in remoteProgresses) {
        if (remote.deletedAt != null) {
          continue;
        }
        final LocalSyncSnapshot? local = localByBook[remote.entityId];
        final DateTime? localTime = local == null
            ? null
            : SyncConflictResolver.progressSavedAt(local.data);
        final DateTime? remoteTime =
            SyncConflictResolver.progressSavedAt(remote.payload);
        if (local == null ||
            remoteTime != null &&
                (localTime == null || remoteTime.isAfter(localTime))) {
          await localRepository.applyRemoteRecords(<RemoteSyncRecord>[remote]);
        }
        if (local == null ||
            remoteTime != null &&
                (localTime == null || !localTime.isAfter(remoteTime))) {
          await queue.discardEntity(
            userId: userId,
            entityType: SyncEntityType.progress,
            entityId: remote.entityId,
          );
        }
      }

      // Old queue records may have survived an offline period or a prior
      // release; drop them when the cloud already owns a newer checkpoint.
      final List<SyncOperation> pending = await queue.load();
      for (final SyncOperation operation in pending) {
        if (operation.userId != userId ||
            operation.entityType != SyncEntityType.progress) {
          continue;
        }
        final RemoteSyncRecord? remote = remoteByBook[operation.entityId];
        if (remote == null || remote.deletedAt != null) {
          continue;
        }
        final Map<String, dynamic> data =
            operation.payload['data'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(
                    operation.payload['data'] as Map<String, dynamic>)
                : <String, dynamic>{};
        final DateTime? queuedTime = SyncConflictResolver.progressSavedAt(data);
        final DateTime? serverTime =
            SyncConflictResolver.progressSavedAt(remote.payload);
        if (serverTime != null &&
            (queuedTime == null || !queuedTime.isAfter(serverTime))) {
          await queue.discardEntity(
            userId: userId,
            entityType: SyncEntityType.progress,
            entityId: operation.entityId,
          );
        }
      }

      for (final LocalSyncSnapshot snapshot in snapshots) {
        if (snapshot.entityType != SyncEntityType.progress) {
          continue;
        }
        final RemoteSyncRecord? remote = remoteByBook[snapshot.entityId];
        final DateTime? localTime =
            SyncConflictResolver.progressSavedAt(snapshot.data);
        final DateTime? remoteTime = remote == null
            ? null
            : SyncConflictResolver.progressSavedAt(remote.payload);
        if (remote == null ||
            remote.deletedAt != null ||
            (localTime != null &&
                (remoteTime == null || localTime.isAfter(remoteTime)))) {
          await queue.enqueue(
            userId: userId,
            deviceId: deviceId,
            entityType: snapshot.entityType,
            entityId: snapshot.entityId,
            payload: <String, dynamic>{'data': snapshot.data},
          );
        }
      }

      final List<SyncOperation> operations = await queue.due();
      totalOperations = operations.length;
      activeStep = operations.isEmpty
          ? 'Buscando dados de leitura'
          : 'Enviando dados de leitura';
      notifyListeners();

      for (final SyncOperation operation in operations) {
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
        } finally {
          processedOperations++;
          notifyListeners();
        }
      }

      if (phase != SyncPhase.sessionExpired) {
        activeStep = 'Buscando dados de leitura';
        notifyListeners();
        final List<RemoteSyncRecord> records =
            await remoteGateway!.pullSince(userId: userId, since: lastSyncAt);
        activeStep = 'Aplicando dados de leitura';
        notifyListeners();
        await localRepository.applyRemoteRecords(records);
        // The upload can race with another device. A final pull reconciles
        // the result of the server-side newer-only progress upsert.
        final List<RemoteSyncRecord> latestProgress =
            await remoteGateway!.pullProgress(userId: userId);
        await localRepository.applyRemoteRecords(latestProgress);
        lastSyncAt = DateTime.now().toUtc();
        await _storage.writeString(
          _lastSyncKey,
          lastSyncAt!.toIso8601String(),
        );
        if (preferences.syncBookFiles && bookFileSyncService != null) {
          activeStep = 'Sincronizando livros';
          notifyListeners();
          final BookFileSyncReport report =
              await bookFileSyncService!.synchronize(
            userId: userId,
            deviceId: deviceId,
            onProgress: (String stage, int done, int total) {
              activeStep = stage;
              processedBooks = done;
              totalBooks = total;
              notifyListeners();
            },
          );
          uploadedBooks = report.uploaded;
          downloadedBooks = report.downloaded;
          if (report.hasErrors) {
            hadFailure = true;
            bookSyncWarning = report.errors.take(3).join(' ');
          }
        } else if (preferences.syncBookFiles) {
          hadFailure = true;
          bookSyncWarning = 'Transferencia de livros indisponivel neste build.';
        }
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
    activeStep = null;
    notifyListeners();
  }

  void _scheduleAutomaticSync() {
    _automaticTimer?.cancel();
    _progressIdleTimer?.cancel();
    if (preferences.enabled && preferences.automatic) {
      _automaticTimer = Timer.periodic(
          Duration(minutes: preferences.syncIntervalMinutes), (_) {
        unawaited(syncNow(stageSnapshot: true));
      });
    }
  }

  String get _lastSyncKey => 'profiles/$profileId/sync/last_sync.txt';

  @override
  void dispose() {
    _automaticTimer?.cancel();
    _progressIdleTimer?.cancel();
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
