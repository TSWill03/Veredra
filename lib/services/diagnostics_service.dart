// Signature: dev.tswicolly03
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'storage/app_storage.dart';

enum DiagnosticCategory {
  startup,
  authentication,
  synchronization,
  import,
  reader
}

class DiagnosticsService {
  DiagnosticsService({AppStorage? storage})
      : _storage = storage ?? createAppStorage();

  static const String _logKey = 'diagnostics/events.json';
  static const int _maxEvents = 200;
  final AppStorage _storage;
  Future<void> _pending = Future<void>.value();

  Future<void> record(
    DiagnosticCategory category,
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) {
    _pending = _pending.catchError((Object _) {}).then((_) async {
      try {
        final List<Map<String, dynamic>> events = await _load();
        events.add(<String, dynamic>{
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'category': category.name,
          'fatal': fatal,
          'platform': defaultTargetPlatform.name,
          'message': _sanitize(error.toString()),
          'stack': _sanitize(stackTrace.toString(), maxLength: 4000),
        });
        if (events.length > _maxEvents) {
          events.removeRange(0, events.length - _maxEvents);
        }
        await _storage.writeString(_logKey, jsonEncode(events));
      } catch (_) {
        // Diagnostics must never turn a recoverable app error into a crash.
      }
    });
    return _pending;
  }

  Future<List<Map<String, dynamic>>> readEvents() => _load();

  Future<void> clear() => _storage.delete(_logKey);

  Future<List<Map<String, dynamic>>> _load() async {
    final String? raw = await _storage.readString(_logKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      return (decoded as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
    } on FormatException {
      return <Map<String, dynamic>>[];
    }
  }

  String _sanitize(String input, {int maxLength = 1000}) {
    String value = input
        .replaceAll(
          RegExp(r'bearer\s+[a-z0-9._~+/-]+=*', caseSensitive: false),
          'Bearer [redacted]',
        )
        .replaceAll(
          RegExp(
            r'(password|token|secret|authorization|cookie)\s*[:=]\s*(?:Bearer\s+)?[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1=[redacted]',
        )
        .replaceAll(
          RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
          '[email redacted]',
        );
    if (value.length > maxLength) {
      value = value.substring(0, maxLength);
    }
    return value;
  }
}
