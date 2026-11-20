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
  DateTime? lastProgressSyncAt;
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
  bool _activeSyncIsProgress = false;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _automaticTimer;
  Timer? _progressIdleTimer;
  Timer? _continuousProgressTimer;
  Future<void>? _progressFlush;
  final Set<String> _dirtyProgressBooks = <String>{};
  final Set<String> _registeredDevices = <String>{};

  /// The reader has already persisted its local checkpoint. An idle flush
  /// sends only the changed book, never an entire library snapshot.
  /// Continuous scroll checkpoints use a 45-second remote cadence.
  void notifyLocalProgressSaved(String bookId, {bool continuous = false}) {
    if (!preferences.enabled ||
        !preferences.automatic ||
        currentUserId() == null) {
      return;
    }
    _dirtyProgressBooks.add(bookId);
    if (phase != SyncPhase.synchronizing) {
      phase = SyncPhase.pending;
      notifyListeners();
    }
    _continuousProgressTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_flushPendingProgress()),
    );
    if (!continuous) {
      _progressIdleTimer?.cancel();
      _progressIdleTimer = Timer(
        const Duration(seconds: 5),
        () => unawaited(_flushPendingProgress()),
      );
    }
  }

  Future<void> _drainPendingProgress() async {
    while (_dirtyProgressBooks.isNotEmpty) {
      final String bookId = _dirtyProgressBooks.first;
      _dirtyProgressBooks.remove(bookId);
      await syncProgress(bookId);
    }
  }

  Future<void> _flushPendingProgress() {
    _progressIdleTimer?.cancel();
    return _progressFlush ??= _drainPendingProgress().whenComplete(() {
      _progressFlush = null;
      if (_dirtyProgressBooks.isEmpty) {
        _continuousProgressTimer?.cancel();
        _continuousProgressTimer = null;
      }
    });
  }

  /// Load only the requested checkpoint, avoiding a full remote pull when
  /// opening a single book. Offline reading keeps using the local cache.
  Future<void> refreshReadingProgress([String? bookId]) async {
    final String? userId = currentUserId();
    if (!preferences.enabled ||
        !preferences.automatic ||
        userId == null ||
        remoteGateway == null ||
        !await networkMonitor.isOnline()) {
      return;
    }
    try {
      final List<RemoteSyncRecord> records = bookId == null
          ? await remoteGateway!.pullProgress(userId: userId)
          : await remoteGateway!
              .pullProgressForBook(userId: userId, bookId: bookId)
              .timeout(const Duration(seconds: 3));
      _ensureCurrentUser(userId);
      await localRepository.applyRemoteRecords(records);
    } catch (error, stackTrace) {
      await _diagnostics.record(
        DiagnosticCategory.synchronization,
        error,
        stackTrace,
      );
    }
  }

  Future<void> flushReadingProgress(String bookId) {
    if (!preferences.enabled ||
        !preferences.automatic ||
        currentUserId() == null) {
      return Future<void>.value();
    }
    _dirtyProgressBooks.add(bookId);
    if (phase != SyncPhase.synchronizing) {
      phase = SyncPhase.pending;
      notifyListeners();
    }
    return _flushPendingProgress();
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
    final Future<void>? active = _activeSync;
    if (active != null) {
      // A manual/periodic full sync must not be swallowed by an active
      // lightweight per-book checkpoint.
      if (_activeSyncIsProgress) {
        return active.then((_) => syncNow(stageSnapshot: stageSnapshot));
      }
      return active;
    }
    _activeSyncIsProgress = false;
    return _activeSync = _synchronize(
      stageSnapshot: stageSnapshot,
    ).whenComplete(() => _activeSync = null);
  }

  void _ensureCurrentUser(String userId) {
    if (currentUserId() != userId) {
      throw const SyncRemoteException(
        'A conta mudou durante a sincronizacao.',
        sessionExpired: true,
      );
    }
  }

  /// A book-scoped offline-first checkpoint transfer. It never uploads book
  /// files or stages other metadata. Local outbox persistence comes first.
  Future<void> syncProgress(String bookId) async {
    // Never let a per-book merge race with a full-library reconciliation.
    while (_activeSync != null) {
      await _activeSync;
    }
    _activeSyncIsProgress = true;
    _activeSync = _synchronizeProgress(bookId).whenComplete(() {
      _activeSync = null;
      _activeSyncIsProgress = false;
    });
    await _activeSync;
  }

  Future<void> _synchronizeProgress(String bookId) async {
    final String? userId = currentUserId();
    if (!preferences.enabled || !preferences.automatic) return;
    if (userId == null || remoteGateway == null) {
      phase = userId == null ? SyncPhase.sessionExpired : SyncPhase.error;
      errorMessage = userId == null
          ? 'Entre na conta para sincronizar.'
          : 'O backend de sincronizacao nao esta configurado.';
      notifyListeners();
      return;
    }

    phase = SyncPhase.synchronizing;
    activeStep = 'Sincronizando progresso';
    errorMessage = null;
    notifyListeners();
    try {
      final LocalSyncSnapshot? snapshot =
          await localRepository.loadProgressSnapshot(bookId);
      final String deviceId = await deviceIdentityService.loadOrCreateId();

      // Persist the outbox before attempting any network operation. The
      // remote comparison below can safely discard an obsolete checkpoint.
      if (snapshot != null) {
        _ensureCurrentUser(userId);
        await queue.enqueue(
          userId: userId,
          deviceId: deviceId,
          entityType: SyncEntityType.progress,
          entityId: bookId,
          payload: <String, dynamic>{'data': snapshot.data},
        );
      }

      if (!await networkMonitor.isOnline()) {
        phase = SyncPhase.offline;
        return;
      }

      _ensureCurrentUser(userId);
      final String registrationKey = userId + ':' + deviceId;
      if (_registeredDevices.add(registrationKey)) {
        try {
          await remoteGateway!.upsertDevice(
            userId: userId,
            deviceId: deviceId,
            name: 'Veredra ' + deviceIdentityService.platformLabel,
            platform: deviceIdentityService.platformLabel,
          );
        } catch (_) {
          _registeredDevices.remove(registrationKey);
          rethrow;
        }
      }

      final List<RemoteSyncRecord> before = await remoteGateway!
          .pullProgressForBook(userId: userId, bookId: bookId);
      _ensureCurrentUser(userId);
      final RemoteSyncRecord? remote = before.isEmpty ? null : before.last;
      final DateTime? remoteTime = remote == null
          ? null
          : SyncConflictResolver.progressSavedAt(remote.payload);
      final DateTime? localTime = snapshot == null
          ? null
          : SyncConflictResolver.progressSavedAt(snapshot.data);

      if (remote != null && remote.deletedAt == null && remoteTime != null) {
        // The comparison happens again under the queue's mutation lock:
        // a newer checkpoint enqueued during this pull must survive.
        await queue.discardEntity(
          userId: userId,
          entityType: SyncEntityType.progress,
          entityId: bookId,
          maxProgressSavedAt: remoteTime,
        );
        if (localTime == null || remoteTime.isAfter(localTime)) {
          _ensureCurrentUser(userId);
          await localRepository.applyRemoteRecords(<RemoteSyncRecord>[remote]);
        }
      }

      final List<SyncOperation> due = (await queue.due())
          .where(
            (SyncOperation op) =>
                op.userId == userId &&
                op.entityType == SyncEntityType.progress &&
                op.entityId == bookId,
          )
          .toList(growable: false);
      for (final SyncOperation operation in due) {
        _ensureCurrentUser(userId);
        try {
          await remoteGateway!.push(operation);
          _ensureCurrentUser(userId);
          // ACK A must not discard the newer local operation B.
          await queue.markSucceeded(
            operation.id,
            expectedVersion: operation.version,
          );
        } on SyncRemoteException {
          await queue.markFailed(
            operation.id,
            expectedVersion: operation.version,
          );
          rethrow;
        }
      }

      final List<RemoteSyncRecord> after = await remoteGateway!
          .pullProgressForBook(userId: userId, bookId: bookId);
      _ensureCurrentUser(userId);
      await localRepository.applyRemoteRecords(after);
      // Do NOT advance lastSyncAt here: it is the metadata delta cursor.
      lastProgressSyncAt = DateTime.now().toUtc();
      phase = SyncPhase.synchronized;
    } on SyncRemoteException catch (error, stackTrace) {
      phase = error.sessionExpired ? SyncPhase.sessionExpired : SyncPhase.error;
      errorMessage = error.message;
      await _diagnostics.record(
        DiagnosticCategory.synchronization,
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      phase = SyncPhase.error;
      errorMessage =
          'Nao foi possivel enviar o progresso; copia local preservada.';
      await _diagnostics.record(
        DiagnosticCategory.synchronization,
        error,
        stackTrace,
      );
    } finally {
      pendingCount = (await queue.load()).length;
      if (phase == SyncPhase.synchronized &&
          (pendingCount > 0 || _dirtyProgressBooks.isNotEmpty)) {
        phase = SyncPhase.pending;
      }
      activeStep = null;
      notifyListeners();
    }
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
      _ensureCurrentUser(userId);
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
        final DateTime? remoteTime = SyncConflictResolver.progressSavedAt(
          remote.payload,
        );
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
            maxProgressSavedAt: remoteTime,
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
                    operation.payload['data'] as Map<String, dynamic>,
                  )
                : <String, dynamic>{};
        final DateTime? queuedTime = SyncConflictResolver.progressSavedAt(data);
        final DateTime? serverTime = SyncConflictResolver.progressSavedAt(
          remote.payload,
        );
        if (serverTime != null &&
            (queuedTime == null || !queuedTime.isAfter(serverTime))) {
          await queue.discardEntity(
            userId: userId,
            entityType: SyncEntityType.progress,
            entityId: operation.entityId,
            maxProgressSavedAt: serverTime,
          );
        }
      }

      for (final LocalSyncSnapshot snapshot in snapshots) {
        if (snapshot.entityType != SyncEntityType.progress) {
          continue;
        }
        final RemoteSyncRecord? remote = remoteByBook[snapshot.entityId];
        final DateTime? localTime = SyncConflictResolver.progressSavedAt(
          snapshot.data,
        );
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
          _ensureCurrentUser(userId);
          await remoteGateway!.push(operation);
          _ensureCurrentUser(userId);
          await queue.markSucceeded(
            operation.id,
            expectedVersion: operation.version,
          );
        } on SyncRemoteException catch (error, stackTrace) {
          hadFailure = true;
          await queue.markFailed(
            operation.id,
            expectedVersion: operation.version,
          );
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
        final List<RemoteSyncRecord> records = await remoteGateway!.pullSince(
          userId: userId,
          since: lastSyncAt,
        );
        activeStep = 'Aplicando dados de leitura';
        notifyListeners();
        _ensureCurrentUser(userId);
        await localRepository.applyRemoteRecords(records);
        // The upload can race with another device. A final pull reconciles
        // the result of the server-side newer-only progress upsert.
        final List<RemoteSyncRecord> latestProgress =
            await remoteGateway!.pullProgress(userId: userId);
        _ensureCurrentUser(userId);
        await localRepository.applyRemoteRecords(latestProgress);
        lastSyncAt = DateTime.now().toUtc();
        await _storage.writeString(_lastSyncKey, lastSyncAt!.toIso8601String());
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
    _continuousProgressTimer?.cancel();
    _continuousProgressTimer = null;
    if (!preferences.enabled || !preferences.automatic) {
      _dirtyProgressBooks.clear();
    }
    if (preferences.enabled && preferences.automatic) {
      _automaticTimer = Timer.periodic(
        Duration(minutes: preferences.syncIntervalMinutes),
        (_) {
          unawaited(syncNow(stageSnapshot: true));
        },
      );
    }
  }

  String get _lastSyncKey => 'profiles/$profileId/sync/last_sync.txt';

  @override
  void dispose() {
    _automaticTimer?.cancel();
    _progressIdleTimer?.cancel();
    _continuousProgressTimer?.cancel();
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
