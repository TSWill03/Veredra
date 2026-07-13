// Signature: dev.tswicolly03
import '../annotation_service.dart';
import '../bookmark_service.dart';
import '../library_service.dart';
import '../profile_service.dart';
import '../progress_service.dart';
import '../reading_stats_service.dart';
import '../../models/app_profile.dart';
import '../../models/book_reference.dart';
import '../../models/library_entry.dart';
import '../../models/reader_annotation.dart';
import '../../models/reader_bookmark.dart';
import '../../models/reading_progress.dart';
import 'sync_conflict_resolver.dart';
import 'sync_models.dart';

class LocalSyncSnapshot {
  const LocalSyncSnapshot({
    required this.entityType,
    required this.entityId,
    required this.data,
  });

  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> data;
}

abstract class LocalSyncDataSource {
  Future<List<LocalSyncSnapshot>> createSnapshot();

  Future<void> applyRemoteRecords(List<RemoteSyncRecord> records);
}

class LocalSyncRepository implements LocalSyncDataSource {
  LocalSyncRepository({
    required this.profileId,
    required this.profileService,
    required this.libraryService,
    required this.progressService,
    required this.bookmarkService,
    required this.annotationService,
    required this.readingStatsService,
    SyncConflictResolver conflictResolver = const SyncConflictResolver(),
  }) : _conflictResolver = conflictResolver;

  final String profileId;
  final ProfileService profileService;
  final LibraryService libraryService;
  final ProgressService progressService;
  final BookmarkService bookmarkService;
  final AnnotationService annotationService;
  final ReadingStatsService readingStatsService;
  final SyncConflictResolver _conflictResolver;

  @override
  Future<List<LocalSyncSnapshot>> createSnapshot() async {
    final List<LocalSyncSnapshot> snapshots = <LocalSyncSnapshot>[];
    for (final AppProfile profile in await profileService.loadProfiles()) {
      snapshots.add(
        LocalSyncSnapshot(
          entityType: SyncEntityType.profile,
          entityId: profile.id,
          data: profile.toJson(),
        ),
      );
    }

    final Map<String, dynamic> progressState =
        await progressService.exportState();
    snapshots.add(
      LocalSyncSnapshot(
        entityType: SyncEntityType.preferences,
        entityId: profileId,
        data: <String, dynamic>{
          'profileId': profileId,
          'themeMode': progressState['themeMode'],
          'readerPreferences': progressState['readerPreferences'],
        },
      ),
    );

    final dynamic rawProgresses = progressState['progresses'];
    if (rawProgresses is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawProgresses.entries) {
        if (entry.value is Map<String, dynamic>) {
          final String bookId = Uri.decodeComponent(entry.key);
          snapshots.add(
            LocalSyncSnapshot(
              entityType: SyncEntityType.progress,
              entityId: bookId,
              data: <String, dynamic>{
                'profileId': profileId,
                'bookId': bookId,
                ...Map<String, dynamic>.from(
                  entry.value as Map<String, dynamic>,
                ),
              },
            ),
          );
        }
      }
    }

    for (final LibraryEntry entry in await libraryService.loadEntries()) {
      snapshots.add(
        LocalSyncSnapshot(
          entityType: SyncEntityType.book,
          entityId: entry.id,
          data: _metadataOnlyBook(entry),
        ),
      );
    }

    final Map<String, List<ReaderBookmark>> bookmarks =
        await bookmarkService.loadAllBookmarks();
    for (final List<ReaderBookmark> records in bookmarks.values) {
      for (final ReaderBookmark record in records) {
        snapshots.add(
          LocalSyncSnapshot(
            entityType: SyncEntityType.bookmark,
            entityId: record.id,
            data: <String, dynamic>{
              'profileId': profileId,
              ...record.toJson(),
            },
          ),
        );
      }
    }

    final Map<String, List<ReaderAnnotation>> annotations =
        await annotationService.loadAllAnnotations();
    for (final List<ReaderAnnotation> records in annotations.values) {
      for (final ReaderAnnotation record in records) {
        final Map<String, dynamic> data = <String, dynamic>{
          'profileId': profileId,
          ...record.toJson(),
        };
        snapshots
          ..add(
            LocalSyncSnapshot(
              entityType: SyncEntityType.annotation,
              entityId: record.id,
              data: data,
            ),
          )
          ..add(
            LocalSyncSnapshot(
              entityType: SyncEntityType.highlight,
              entityId: record.id,
              data: data,
            ),
          );
      }
    }

    final Map<String, dynamic> stats = await readingStatsService.exportJson();
    for (final MapEntry<String, dynamic> entry in stats.entries) {
      if (entry.value is Map<String, dynamic>) {
        snapshots.add(
          LocalSyncSnapshot(
            entityType: SyncEntityType.readingStats,
            entityId: entry.key,
            data: <String, dynamic>{
              'profileId': profileId,
              ...Map<String, dynamic>.from(
                entry.value as Map<String, dynamic>,
              ),
            },
          ),
        );
      }
    }
    return snapshots;
  }

  @override
  Future<void> applyRemoteRecords(List<RemoteSyncRecord> records) async {
    for (final RemoteSyncRecord record in records) {
      switch (record.entityType) {
        case SyncEntityType.profile:
          if (record.deletedAt == null) {
            await profileService.upsertSyncedProfile(
              AppProfile.fromJson(record.payload),
            );
          }
          break;
        case SyncEntityType.preferences:
          if (record.deletedAt == null) {
            await _applyPreferences(record.payload);
          }
          break;
        case SyncEntityType.book:
          await _applyBook(record);
          break;
        case SyncEntityType.progress:
          await _applyProgress(record);
          break;
        case SyncEntityType.bookmark:
          await _applyBookmark(record);
          break;
        case SyncEntityType.annotation:
        case SyncEntityType.highlight:
          await _applyAnnotation(record);
          break;
        case SyncEntityType.readingStats:
          await _applyStats(record);
          break;
      }
    }
  }

  Map<String, dynamic> _metadataOnlyBook(LibraryEntry entry) {
    final Map<String, dynamic> reference = entry.reference.toJson()
      ..['directoryPath'] = null
      ..['coverPath'] = null
      ..['assetPaths'] = const <String>[]
      ..['sourceLabel'] = 'Metadados sincronizados';
    return <String, dynamic>{
      'id': entry.id,
      'profileId': profileId,
      'reference': reference,
      'chapterCount': entry.chapterCount,
      'importedAt': entry.importedAt.toUtc().toIso8601String(),
      'lastOpenedAt': entry.lastOpenedAt?.toUtc().toIso8601String(),
      'isFavorite': entry.isFavorite,
    };
  }

  Future<void> _applyPreferences(Map<String, dynamic> remote) async {
    final Map<String, dynamic> local = await progressService.exportState();
    if (remote['themeMode'] is String) {
      local['themeMode'] = remote['themeMode'];
    }
    if (remote['readerPreferences'] is Map<String, dynamic>) {
      local['readerPreferences'] = remote['readerPreferences'];
    }
    await progressService.importState(local);
  }

  Future<void> _applyBook(RemoteSyncRecord remote) async {
    final List<LibraryEntry> entries = await libraryService.loadEntries();
    final int index = entries.indexWhere(
      (LibraryEntry entry) => entry.id == remote.entityId,
    );
    if (remote.deletedAt != null) {
      if (index >= 0 && entries[index].reference.assetPaths.isEmpty) {
        entries.removeAt(index);
        await libraryService.replaceEntries(entries);
      }
      return;
    }
    final LibraryEntry incoming = LibraryEntry.fromJson(remote.payload);
    if (index < 0) {
      entries.add(incoming);
    } else {
      final LibraryEntry local = entries[index];
      final BookReference remoteReference = incoming.reference;
      entries[index] = local.copyWith(
        reference: local.reference.copyWith(
          title: remoteReference.title,
          author: remoteReference.author,
          description: remoteReference.description,
          series: remoteReference.series,
          volume: remoteReference.volume,
          altTitle: remoteReference.altTitle,
          tags: remoteReference.tags,
        ),
        chapterCount:
            local.chapterCount > 0 ? local.chapterCount : incoming.chapterCount,
        isFavorite: incoming.isFavorite,
      );
    }
    await libraryService.replaceEntries(entries);
  }

  Future<void> _applyProgress(RemoteSyncRecord remote) async {
    final Map<String, dynamic> state = await progressService.exportState();
    final Map<String, dynamic> progresses = state['progresses']
            is Map<String, dynamic>
        ? Map<String, dynamic>.from(state['progresses'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final String key = Uri.encodeComponent(remote.entityId);
    if (remote.deletedAt != null) {
      progresses.remove(key);
    } else {
      final Map<String, dynamic> remoteProgress =
          Map<String, dynamic>.from(remote.payload)
            ..['updated_at'] = remote.updatedAt.toUtc().toIso8601String()
            ..['version'] = remote.version;
      final Map<String, dynamic>? localProgress =
          progresses[key] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                  progresses[key] as Map<String, dynamic>,
                )
              : null;
      final Map<String, dynamic> winner = localProgress == null
          ? remoteProgress
          : _conflictResolver.resolveProgress(
              <String, dynamic>{
                ...localProgress,
                'chapter_index': localProgress['chapterIndex'],
                'chapter_progress': localProgress['chapterProgress'],
                'updated_at': localProgress['savedAt'],
              },
              <String, dynamic>{
                ...remoteProgress,
                'chapter_index': remoteProgress['chapterIndex'],
                'chapter_progress': remoteProgress['chapterProgress'],
              },
            );
      progresses[key] = ReadingProgress.fromJson(winner).toJson();
    }
    state['progresses'] = progresses;
    await progressService.importState(state);
  }

  Future<void> _applyBookmark(RemoteSyncRecord remote) async {
    final String bookId = remote.payload['bookId'] as String? ?? '';
    if (bookId.isEmpty) {
      return;
    }
    if (remote.deletedAt != null) {
      await bookmarkService.removeBookmark(bookId, remote.entityId);
    } else {
      await bookmarkService.saveBookmark(
        ReaderBookmark.fromJson(remote.payload),
      );
    }
  }

  Future<void> _applyAnnotation(RemoteSyncRecord remote) async {
    final String bookId = remote.payload['bookId'] as String? ?? '';
    if (bookId.isEmpty) {
      return;
    }
    if (remote.deletedAt != null) {
      await annotationService.removeAnnotation(bookId, remote.entityId);
    } else {
      await annotationService.saveAnnotation(
        ReaderAnnotation.fromJson(remote.payload),
      );
    }
  }

  Future<void> _applyStats(RemoteSyncRecord remote) async {
    final Map<String, dynamic> stats = await readingStatsService.exportJson();
    if (remote.deletedAt != null) {
      stats.remove(remote.entityId);
    } else {
      stats[remote.entityId] = remote.payload;
    }
    await readingStatsService.importJson(stats);
  }
}
