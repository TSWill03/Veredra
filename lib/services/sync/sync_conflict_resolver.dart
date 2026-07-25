// Signature: dev.tswicolly03
class SyncConflictResolver {
  const SyncConflictResolver();

  Map<String, dynamic> resolveProgress(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final int localChapter = (local['chapter_index'] as num?)?.toInt() ?? 0;
    final int remoteChapter = (remote['chapter_index'] as num?)?.toInt() ?? 0;
    if (localChapter != remoteChapter) {
      return localChapter > remoteChapter ? local : remote;
    }

    final double localProgress =
        (local['chapter_progress'] as num?)?.toDouble() ?? 0;
    final double remoteProgress =
        (remote['chapter_progress'] as num?)?.toDouble() ?? 0;
    if ((localProgress - remoteProgress).abs() > 0.0001) {
      return localProgress > remoteProgress ? local : remote;
    }
    return resolveLastWrite(local, remote);
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
