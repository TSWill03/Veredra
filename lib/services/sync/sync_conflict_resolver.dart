// Signature: dev.tswicolly03
class SyncConflictResolver {
  const SyncConflictResolver();

  /// A user's latest reading session wins, even when they revisit an
  /// earlier chapter. Chapter index and percentage are not clocks.
  Map<String, dynamic> resolveProgress(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final DateTime localSaved = progressSavedAt(local) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final DateTime remoteSaved = progressSavedAt(remote) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (localSaved.isAfter(remoteSaved)) return local;
    if (remoteSaved.isAfter(localSaved)) return remote;
    // An equal savedAt means the same reading checkpoint. The server record
    // is authoritative for the tie and avoids an upload ping-pong.
    return remote;
  }

  /// Interpret legacy local timestamps, modern UTC timestamps and the
  /// historical fallback field without comparing how far someone has read.
  static DateTime? progressSavedAt(Map<String, dynamic> data) {
    final String? raw =
        (data['savedAt'] ?? data['saved_at'] ?? data['updated_at']) as String?;
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Map<String, dynamic> resolveLastWrite(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final DateTime localUpdated = _date(local['updated_at']);
    final DateTime remoteUpdated = _date(remote['updated_at']);
    if (localUpdated != remoteUpdated) {
      return localUpdated.isAfter(remoteUpdated) ? local : remote;
    }
    final int localVersion = (local['version'] as num?)?.toInt() ?? 0;
    final int remoteVersion = (remote['version'] as num?)?.toInt() ?? 0;
    return localVersion >= remoteVersion ? local : remote;
  }

  List<Map<String, dynamic>> mergeById(
    Iterable<Map<String, dynamic>> local,
    Iterable<Map<String, dynamic>> remote,
  ) {
    final Map<String, Map<String, dynamic>> merged =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> record in <Map<String, dynamic>>[
      ...local,
      ...remote,
    ]) {
      final String id = record['id'] as String? ?? '';
      if (id.isEmpty) {
        continue;
      }
      final Map<String, dynamic>? previous = merged[id];
      merged[id] =
          previous == null ? record : resolveLastWrite(previous, record);
    }
    return merged.values.toList(growable: false);
  }

  DateTime _date(Object? value) =>
      DateTime.tryParse(value as String? ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
