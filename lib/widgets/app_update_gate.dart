// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

/// Verifica novidades ao abrir e ao retomar. Nunca bloqueia a leitura offline.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child, this.service});
  final Widget child;
  final AppUpdateService? service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  late final AppUpdateService _service;
  late final bool _ownsService;
  DateTime? _lastCheckAt;
  bool _checking = false;

  static const _tagKey = 'veredra.update.last_prompted_tag';
  static const _timeKey = 'veredra.update.last_prompted_at';

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service = widget.service ?? AppUpdateService();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;
    final now = DateTime.now();
    if (_lastCheckAt != null &&
        now.difference(_lastCheckAt!) < const Duration(hours: 6)) {
      return;
    }
    _lastCheckAt = now;
    _checking = true;
    try {
      final result = await _service.check();
      if (!mounted || result.status != AppUpdateStatus.available) return;
      final release = result.release!;
      final prefs = await SharedPreferences.getInstance();
      final lastTag = prefs.getString(_tagKey);
      final lastShown = DateTime.tryParse(prefs.getString(_timeKey) ?? '');

      // Evita exibir o mesmo alerta em toda abertura; nova tag alerta na hora.
      if (lastTag == release.tag &&
          lastShown != null &&
          now.difference(lastShown) < const Duration(days: 3)) {
        return;
      }
      if (!mounted) return;
      await prefs.setString(_tagKey, release.tag);
      await prefs.setString(_timeKey, now.toIso8601String());
      if (!mounted) return;
      await showVeredraUpdateDialog(context, result);
    } catch (_) {
      // Sem internet, sem Release ou API indisponivel: modo offline continua.
      // O usuario pode verificar manualmente na tela Sobre.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Caixa informativa. Nunca baixa/instala binarios automaticamente.
Future<void> showVeredraUpdateDialog(
  BuildContext context,
  AppUpdateResult result,
) async {
  final release = result.release;
  if (release == null || result.status != AppUpdateStatus.available) return;

  final iosOutsideAppStore =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.system_update_alt_rounded, size: 35),
      title: const Text('Nova versao do Veredra'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Versao instalada: ' + result.installed.display),
            const SizedBox(height: 4),
            Text(
              'Nova versao: ' + release.version.display,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (release.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              const Text('Novidades:'),
              const SizedBox(height: 6),
              Text(
                release.notes,
                maxLines: 9,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (iosOutsideAppStore) ...<Widget>[
              const SizedBox(height: 16),
              const Text(
                'Esta copia do iOS foi instalada fora da App Store. '
                'Para atualizar, instale a nova versao pelo computador '
                'e faca backup da biblioteca antes.',
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Mais tarde'),
        ),
        FilledButton.icon(
          onPressed: () async {
            bool opened = false;
            try {
              opened = await launchUrl(
                release.url,
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {
              // Se nao houver navegador associado, apenas copia o link.
            }
            if (!dialogContext.mounted) return;
            if (!opened) {
              await Clipboard.setData(
                ClipboardData(text: release.url.toString()),
              );
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Link da atualizacao copiado.'),
                ),
              );
            }
            Navigator.of(dialogContext).pop();
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Ver atualizacao'),
        ),
      ],
    ),
  );
}
