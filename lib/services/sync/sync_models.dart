// Signature: dev.tswicolly03
enum SyncEntityType {
  profile,
  preferences,
  book,
  progress,
  bookmark,
  annotation,
  highlight,
  readingStats,
}

enum SyncOperationType { upsert, delete }

enum SyncPhase {
  localOnly,
  synchronized,
  synchronizing,
  offline,
  pending,
  error,
  sessionExpired,
}

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.attemptCount = 0,
    this.nextAttemptAt,
  });

  final String id;
  final String userId;
  final String deviceId;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operationType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final int attemptCount;
  final DateTime? nextAttemptAt;

  bool isDue(DateTime now) =>
      nextAttemptAt == null || !nextAttemptAt!.isAfter(now);

  SyncOperation copyWith({
    Map<String, dynamic>? payload,
    DateTime? updatedAt,
    int? version,
    int? attemptCount,
    DateTime? nextAttemptAt,
  }) {
    return SyncOperation(
      id: id,
      userId: userId,
      deviceId: deviceId,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload ?? this.payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'entityType': entityType.name,
      'entityId': entityId,
      'operationType': operationType.name,
      'payload': payload,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'version': version,
      'attemptCount': attemptCount,
      'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
    };
  }

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      entityType: SyncEntityType.values.firstWhere(
        (SyncEntityType value) => value.name == json['entityType'],
        orElse: () => SyncEntityType.book,
      ),
      entityId: json['entityId'] as String? ?? '',
      operationType: SyncOperationType.values.firstWhere(
        (SyncOperationType value) => value.name == json['operationType'],
        orElse: () => SyncOperationType.upsert,
      ),
      payload: json['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['payload'] as Map<String, dynamic>)
          : <String, dynamic>{},
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      version: (json['version'] as num?)?.toInt() ?? 1,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      nextAttemptAt: DateTime.tryParse(
        json['nextAttemptAt'] as String? ?? '',
      ),
    );
  }
}

class RemoteSyncRecord {
  const RemoteSyncRecord({
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });

  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
}
