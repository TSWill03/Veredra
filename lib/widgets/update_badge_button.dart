// Signature: dev.tswicolly03
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update/update_controller.dart';
import '../services/update/update_service.dart';
import '../services/update/windows_installer_stub.dart'
    if (dart.library.io) '../services/update/windows_installer_io.dart';
import '../services/update/web_reload_stub.dart'
    if (dart.library.js_interop) '../services/update/web_reload_web.dart';

class UpdateBadgeButton extends StatelessWidget {
  const UpdateBadgeButton({super.key, required this.controller});
  final UpdateController controller;

  Future<void> _open(BuildContext context) async {
    await controller.markSeen();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _UpdateDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) => IconButton(
        key: const Key('app-update-button'),
        tooltip: controller.hasUnreadUpdate
            ? 'Nova atualizacao disponivel'
            : 'Atualizacoes do Veredra',
        onPressed: () => _open(context),
        icon: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Icon(Icons.system_update_alt_rounded),
            if (controller.hasUnreadUpdate)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  key: const Key('update-blue-dot'),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.controller});
  final UpdateController controller;

  Future<void> _apply(BuildContext context, AppRelease release) async {
    switch (controller.service.target) {
      case UpdateTarget.web:
        Navigator.of(context).pop();
        reloadWebApp();
        return;
      case UpdateTarget.windows:
        if (!release.hasVerifiedWindowsInstaller) {
          await _openReleaseLink(context, release);
          return;
        }
        controller.beginDownload();
        try {
          await installWindowsRelease(release, controller.setDownloadProgress);
        } catch (error) {
          controller.failDownload(error);
        }
        return;
      default:
        await _openReleaseLink(context, release);
    }
  }

  Future<void> _openReleaseLink(
      BuildContext context, AppRelease release) async {
    final bool launched = await launchUrl(
      release.releaseUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nao foi possivel abrir a pagina de releases.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final AppRelease? release = controller.release;
        final bool busy = controller.isBusy;
        final String actionLabel = switch (controller.service.target) {
          UpdateTarget.web => 'Atualizar e recarregar',
          UpdateTarget.windows => release?.hasVerifiedWindowsInstaller == true
              ? 'Baixar e instalar automaticamente'
              : 'Ver downloads no GitHub',
          UpdateTarget.ios => 'Ver novidades',
          UpdateTarget.android => 'Ver novidades',
          _ => 'Abrir GitHub Releases',
        };
        return AlertDialog(
          title: Row(children: <Widget>[
            Icon(
                release == null
                    ? Icons.check_circle_outline_rounded
                    : Icons.new_releases_rounded,
                color: release == null ? null : Colors.blueAccent),
            const SizedBox(width: 12),
            const Flexible(child: Text('Atualizacoes do Veredra')),
          ]),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (release == null) ...<Widget>[
                    Text(busy
                        ? 'Verificando atualizacoes...'
                        : 'Voce esta usando a versao mais recente conhecida.'),
                    const SizedBox(height: 8),
                    Text(
                        'Versao instalada: ${controller.service.currentVersion}'),
                  ] else ...<Widget>[
                    Text('Nova versao: ${release.version}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Instalada: ${controller.service.currentVersion}'),
                    const SizedBox(height: 12),
                    Text('Novidades',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    SelectableText(release.notes.length > 3500
                        ? '${release.notes.substring(0, 3500)}...'
                        : release.notes),
                    if (controller.service.target == UpdateTarget.windows &&
                        !release.hasVerifiedWindowsInstaller) ...<Widget>[
                      const SizedBox(height: 12),
                      const Text('O instalador Windows assinado por hash ainda '
                          'nao foi disponibilizado. Nao sera executado nenhum arquivo desconhecido.'),
                    ],
                    if (controller.service.target == UpdateTarget.ios ||
                        controller.service.target ==
                            UpdateTarget.android) ...<Widget>[
                      const SizedBox(height: 12),
                      const Text('A atualizacao nativa depende do canal de '
                          'distribuicao (TestFlight/App Store ou instalador Android). '
                          'A versao Web pode ser atualizada separadamente.'),
                    ],
                  ],
                  if (controller.phase == UpdatePhase.downloading) ...<Widget>[
                    const SizedBox(height: 18),
                    LinearProgressIndicator(value: controller.downloadProgress),
                    const SizedBox(height: 6),
                    const Text('Baixando e verificando integridade SHA-256...'),
                  ],
                  if (controller.error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(controller.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Agora nao'),
            ),
            if (release == null)
              TextButton(
                onPressed: busy ? null : () => unawaited(controller.check()),
                child: const Text('Verificar novamente'),
              ),
            if (release != null)
              FilledButton(
                onPressed:
                    busy ? null : () => unawaited(_apply(context, release)),
                child: Text(actionLabel),
              ),
          ],
        );
      },
    );
  }
}
