// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../services/sync/sync_coordinator.dart';
import '../services/sync/sync_models.dart';

/// Compact, passive reader status; never interrupts or moves the reading view.
class ReaderSyncStatusIndicator extends StatelessWidget {
  const ReaderSyncStatusIndicator({super.key, required this.coordinator});

  final SyncCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final SyncCoordinator? sync = coordinator;
    if (sync == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: sync,
      builder: (BuildContext context, Widget? child) {
        final SyncPhase phase = sync.preferences.enabled
            ? sync.phase
            : SyncPhase.localOnly;
        final IconData icon;
        final String message;
        switch (phase) {
          case SyncPhase.localOnly:
            icon = Icons.save_outlined;
            message = 'Somente local: sincronizacao desativada';
            break;
          case SyncPhase.synchronizing:
            icon = Icons.sync;
            message = 'Sincronizando leitura';
            break;
          case SyncPhase.synchronized:
            icon = Icons.cloud_done_outlined;
            message = 'Progresso sincronizado com a nuvem';
            break;
          case SyncPhase.offline:
            icon = Icons.cloud_off_outlined;
            message = 'Offline: progresso preservado localmente';
            break;
          case SyncPhase.pending:
            icon = Icons.cloud_upload_outlined;
            message = 'Salvo localmente: aguardando sincronizacao';
            break;
          case SyncPhase.error:
            icon = Icons.error_outline;
            message = sync.errorMessage ?? 'Erro de sincronizacao';
            break;
          case SyncPhase.sessionExpired:
            icon = Icons.person_off_outlined;
            message = 'Sessao expirada: progresso salvo localmente';
            break;
        }
        return Tooltip(
          message: message,
          child: Semantics(
            label: message,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
