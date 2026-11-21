// Signature: dev.tswicolly03
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'update_service.dart';

enum UpdatePhase { idle, checking, available, downloading, error }

class UpdateController extends ChangeNotifier {
  UpdateController({UpdateService? service})
      : service = service ?? UpdateService(),
        _ownsService = service == null;
  final UpdateService service;
  final bool _ownsService;
  Timer? _timer;
  bool _disposed = false;
  String _seenVersion = '';
  UpdatePhase phase = UpdatePhase.idle;
  AppRelease? release;
  String? error;
  double downloadProgress = 0;

  bool get hasUnreadUpdate =>
      release != null && release!.version != _seenVersion;
  bool get isBusy =>
      phase == UpdatePhase.checking || phase == UpdatePhase.downloading;
  String get _seenKey => 'veredra.updates.seen.${service.target.name}';

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seenVersion = prefs.getString(_seenKey) ?? '';
    } catch (_) {
      // Optional badge must not block reading if preferences are unavailable.
    }
    if (_disposed) return;
    await check();
    if (!_disposed) {
      _timer = Timer.periodic(
          const Duration(minutes: 30), (_) => unawaited(check()));
    }
  }

  Future<void> check() async {
    if (_disposed || isBusy) return;
    phase = UpdatePhase.checking;
    error = null;
    notifyListeners();
    try {
      release = await service.check();
      phase = release == null ? UpdatePhase.idle : UpdatePhase.available;
    } catch (_) {
      phase = release == null ? UpdatePhase.error : UpdatePhase.available;
      error = 'Nao foi possivel buscar atualizacoes (offline?).';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> markSeen() async {
    if (release == null) return;
    _seenVersion = release!.version;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seenKey, _seenVersion);
    } catch (_) {/* only affects the badge across restarts */}
  }

  void beginDownload() {
    phase = UpdatePhase.downloading;
    downloadProgress = 0;
    error = null;
    notifyListeners();
  }

  void setDownloadProgress(double value) {
    if (_disposed) return;
    downloadProgress = value.clamp(0, 1);
    notifyListeners();
  }

  void failDownload(Object error) {
    phase = UpdatePhase.available;
    this.error = 'Instalacao nao concluida. Os livros nao foram alterados.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_ownsService) service.dispose();
    super.dispose();
  }
}
