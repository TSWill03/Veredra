// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'book_file_remote_gateway.dart';
import 'remote_sync_gateway.dart';

/// The book-assets table is authoritative; blobs are never publicly shared.
class SupabaseBookFileGateway implements BookFileRemoteGateway {
  SupabaseBookFileGateway(this._client, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const String bucket = 'veredra-books';
  final SupabaseClient _client;
  final Uuid _uuid;

  @override
  Future<List<RemoteBookAsset>> listAssets({required String userId}) async {
    _checkUser(userId);
    try {
      final List<dynamic> rows = await _client
          .from('book_assets')
          .select('local_id,storage_path,checksum_sha256,size_bytes')
          .eq('user_id', userId)
          .isFilter('deleted_at', null);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        return RemoteBookAsset(
          bookId: row['local_id'] as String,
          storagePath: row['storage_path'] as String,
          checksum: row['checksum_sha256'] as String,
          sizeBytes: (row['size_bytes'] as num).toInt(),
        );
      }).toList();
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } catch (_) {
      throw const SyncRemoteException(
        'Nao foi possivel consultar os arquivos remotos.',
      );
    }
  }

  @override
  Future<void> upload({
    required String userId,
    required String deviceId,
    required String bookId,
    required Uint8List bytes,
    required String checksum,
  }) async {
    _checkUser(userId);
    // Include book ID in the immutable object path; RLS also checks user ID.
    final String path = '$userId/$bookId/$checksum.zip';
    try {
      await _client.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'application/zip',
          upsert: true,
        ),
      );
      await _client.from('book_assets').upsert(
        <String, dynamic>{
          'user_id': userId,
          'device_id': deviceId,
          'book_id': _uuid.v5(
            Namespace.url.value,
            '$userId:book:$bookId',
          ),
          'local_id': bookId,
          'storage_path': path,
          'checksum_sha256': checksum,
          'mime_type': 'application/zip',
          'size_bytes': bytes.length,
          'deleted_at': null,
        },
        onConflict: 'user_id,local_id',
      );
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } catch (_) {
      throw const SyncRemoteException(
        'Falha no upload de um livro. A copia local foi preservada.',
      );
    }
  }

  @override
  Future<Uint8List> download(RemoteBookAsset asset) async {
    final String? currentId = _client.auth.currentUser?.id;
    if (currentId == null ||
        !asset.storagePath.startsWith('$currentId/')) {
      throw const SyncRemoteException('Sessao invalida para baixar o livro.',
          sessionExpired: true);
    }
    try {
      return await _client.storage.from(bucket).download(asset.storagePath);
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } catch (_) {
      throw const SyncRemoteException(
        'Falha no download de um livro. A copia local foi preservada.',
      );
    }
  }

  void _checkUser(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const SyncRemoteException(
        'A sessao mudou durante a sincronizacao.',
        sessionExpired: true,
      );
    }
  }
}
