// Signature: dev.tswicolly03
class ProfileBackupPreview {
  const ProfileBackupPreview({
    required this.sourceProfileName,
    required this.exportedAt,
    required this.booksCount,
    required this.bookmarksCount,
    required this.annotationsCount,
    required this.trackedBooksCount,
  });

  final String sourceProfileName;
  final DateTime? exportedAt;
  final int booksCount;
  final int bookmarksCount;
  final int annotationsCount;
  final int trackedBooksCount;

  String get suggestedProfileName => '$sourceProfileName Importado';
}
