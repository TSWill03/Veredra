// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'book_asset_gateway.dart';
import 'book_asset_package.dart';
import 'remote_sync_gateway.dart';
import 'sync_models.dart';

class SupabaseSyncGateway implements RemoteSyncGateway, BookAssetRemoteGateway {
  SupabaseSyncGateway(this._client, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid(),
        _bookAssets = SupabaseBookAssetGateway(_client, uuid: uuid);

  final SupabaseClient _client;
  final Uuid _uuid;
  final SupabaseBookAssetGateway _bookAssets;

  static const Map<SyncEntityType, String> _tables = <SyncEntityType, String>{
    SyncEntityType.profile: 'profiles',
    SyncEntityType.preferences: 'user_preferences',
    SyncEntityType.book: 'books',
    SyncEntityType.progress: 'reading_progress',
    SyncEntityType.bookmark: 'bookmarks',
    SyncEntityType.annotation: 'annotations',
    SyncEntityType.highlight: 'highlights',
    SyncEntityType.readingStats: 'reading_stats',
  };

  @override
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String name,
    required String platform,
  }) async {
    try {
      await _client.from('devices').upsert(
        <String, dynamic>{
          'id': deviceId,
          'user_id': userId,
          'name': name,
          'platform': platform,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } on PostgrestException catch (_) {
      throw const SyncRemoteException('O dispositivo nao pode ser registrado.');
    }
  }

  @override
  Future<void> push(SyncOperation operation) async {
    final String table = _tables[operation.entityType]!;
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      operation.payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final Map<String, dynamic> row = <String, dynamic>{
      'id': operation.payload['remote_id'] ?? _remoteId(operation),
      'user_id': operation.userId,
      'device_id': operation.deviceId,
      'local_id': operation.entityId,
      'data': data,
      'version': operation.version,
      'updated_at': operation.updatedAt.toUtc().toIso8601String(),
      'deleted_at': operation.operationType == SyncOperationType.delete
          ? operation.updatedAt.toUtc().toIso8601String()
          : null,
      ..._typedColumns(operation.entityType, data),
    };

    try {
      await _client.from(table).upsert(
            row,
            onConflict: 'user_id,local_id',
          );
      await _client.from('sync_operations').upsert(
        <String, dynamic>{
          'id': operation.id,
          'user_id': operation.userId,
          'device_id': operation.deviceId,
          'entity_type': operation.entityType.name,
          'entity_id': row['id'],
          'operation': operation.operationType.name,
          'payload': <String, dynamic>{
            'local_id': operation.entityId,
            'version': operation.version,
          },
          'created_at': operation.createdAt.toUtc().toIso8601String(),
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } on PostgrestException catch (_) {
      throw const SyncRemoteException('O servidor recusou uma alteracao.');
    } catch (_) {
      throw const SyncRemoteException('Falha de rede ao enviar alteracoes.');
    }
  }

  @override
  Future<List<RemoteSyncRecord>> pullSince({
    required String userId,
    required DateTime? since,
  }) async {
    final List<RemoteSyncRecord> records = <RemoteSyncRecord>[];
    try {
      for (final MapEntry<SyncEntityType, String> entry in _tables.entries) {
        dynamic query = _client
            .from(entry.value)
            .select('local_id,data,updated_at,deleted_at,version')
            .eq('user_id', userId);
        if (since != null) {
          query = query.gte('updated_at', since.toUtc().toIso8601String());
        }
        final List<dynamic> rows = await query.order('updated_at');
        for (final dynamic raw in rows) {
          if (raw is! Map<String, dynamic>) {
            continue;
          }
          final String localId = raw['local_id'] as String? ?? '';
          if (localId.isEmpty) {
            continue;
          }
          records.add(
            RemoteSyncRecord(
              entityType: entry.key,
              entityId: localId,
              payload: raw['data'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(
                      raw['data'] as Map<String, dynamic>,
                    )
                  : <String, dynamic>{},
              updatedAt:
                  DateTime.tryParse(raw['updated_at'] as String? ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              deletedAt: DateTime.tryParse(
                raw['deleted_at'] as String? ?? '',
              ),
              version: (raw['version'] as num?)?.toInt() ?? 1,
            ),
          );
        }
      }
      return records;
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } on PostgrestException catch (_) {
      throw const SyncRemoteException('Nao foi possivel receber alteracoes.');
    } catch (_) {
      throw const SyncRemoteException('Falha de rede ao receber alteracoes.');
    }
  }

  @override
  Future<void> upload({
    required String userId,
    required BookAssetPackage package,
  }) {
    return _bookAssets.upload(userId: userId, package: package);
  }

  @override
  Future<List<RemoteBookAsset>> list({required String userId}) {
    return _bookAssets.list(userId: userId);
  }

  @override
  Future<Uint8List> download({
    required String userId,
    required RemoteBookAsset asset,
  }) {
    return _bookAssets.download(userId: userId, asset: asset);
  }

  Map<String, dynamic> _typedColumns(
    SyncEntityType type,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case SyncEntityType.profile:
        return <String, dynamic>{
          'display_name': data['name'] ?? 'Usuario',
        };
      case SyncEntityType.preferences:
        return <String, dynamic>{
          'profile_local_id': data['profileId'] ?? 'principal',
        };
      case SyncEntityType.book:
        final Map<String, dynamic> reference =
            data['reference'] is Map<String, dynamic>
                ? data['reference'] as Map<String, dynamic>
                : <String, dynamic>{};
        return <String, dynamic>{
          'profile_local_id': data['profileId'] ?? 'principal',
          'title': reference['title'] ?? 'Livro',
          'format': reference['format'] ?? 'text',
          'is_favorite': data['isFavorite'] ?? false,
        };
      case SyncEntityType.progress:
        return <String, dynamic>{
          'profile_local_id': data['profileId'] ?? 'principal',
          'book_local_id': data['bookId'] ?? '',
          'chapter_index': data['chapterIndex'] ?? 0,
          'chapter_progress': data['chapterProgress'] ?? 0,
        };
      case SyncEntityType.bookmark:
      case SyncEntityType.annotation:
      case SyncEntityType.highlight:
      case SyncEntityType.readingStats:
        return <String, dynamic>{
          'profile_local_id': data['profileId'] ?? 'principal',
          'book_local_id': data['bookId'] ?? '',
        };
    }
  }

  String _remoteId(SyncOperation operation) => _uuid.v5(
        Namespace.url.value,
        '${operation.userId}:${operation.entityType.name}:${operation.entityId}',
      );
}
