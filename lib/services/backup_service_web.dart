// Signature: dev.tswicolly03
import '../models/app_profile.dart';
import 'annotation_service.dart';
import 'bookmark_service.dart';
import 'library_service.dart';
import 'profile_service.dart';
import 'progress_service.dart';
import 'reading_stats_service.dart';

class BackupService {
  BackupService({
    required this.profileService,
    required this.libraryService,
    required this.progressService,
    required this.bookmarkService,
    required this.annotationService,
    required this.readingStatsService,
  });

  final ProfileService profileService;
  final LibraryService libraryService;
  final ProgressService progressService;
  final BookmarkService bookmarkService;
  final AnnotationService annotationService;
  final ReadingStatsService readingStatsService;

  Future<String?> exportCurrentProfile(AppProfile profile) async {
    throw StateError(
      'Backup e restauracao ainda estao disponiveis apenas no desktop.',
    );
  }

  Future<AppProfile?> importProfileBackup() async {
    throw StateError(
      'Backup e restauracao ainda estao disponiveis apenas no desktop.',
    );
  }
}
