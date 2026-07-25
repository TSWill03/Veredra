// Signature: dev.tswicolly03
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'book_asset_package.dart';
import 'remote_sync_gateway.dart';

class RemoteBookAsset {
  const RemoteBookAsset({
    required this.bookId,
    required this.storagePath,
    required this.checksumSha256,
    required this.sizeBytes,
    required this.updatedAt,
  });

  final String bookId;
  final String storagePath;
  final String checksumSha256;
  final int sizeBytes;
  final DateTime updatedAt;
}

abstract class BookAssetRemoteGateway {
  Future<void> upload({
    required String userId,
    required BookAssetPackage package,
  });

  Future<List<RemoteBookAsset>> list({required String userId});

  Future<Uint8List> download({
    required String userId,
    required RemoteBookAsset asset,
  });
}

class SupabaseBookAssetGateway implements BookAssetRemoteGateway {
  SupabaseBookAssetGateway(this._client, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const String _bucket = 'veredra-books';

  final SupabaseClient _client;
  final Uuid _uuid;

  @override
  Future<void> upload({
    required String userId,
    required BookAssetPackage package,
  }) async {
    try {
      final dynamic rawBook = await _client
          .from('books')
          .select('id')
          .eq('user_id', userId)
          .eq('local_id', package.bookId)
          .maybeSingle();
      if (rawBook is! Map<String, dynamic> || rawBook['id'] is! String) {
        throw const SyncRemoteException(
          'Sincronize os metadados do livro antes de enviar os capitulos.',
        );
      }

      final String bookHash =
          sha256.convert(utf8.encode(package.bookId)).toString();
      final String storagePath =
          '$userId/books/$bookHash/${package.checksumSha256}.zip';
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            package.bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/zip',
              cacheControl: '3600',
            ),
          );

      await _client.from('book_assets').upsert(
        <String, dynamic>{
          'id': _uuid.v5(
            Namespace.url.value,
            '$userId:book-package:${package.bookId}',
          ),
          'user_id': userId,
          'book_id': rawBook['id'],
          'local_id': 'package:${package.bookId}',
          'storage_path': storagePath,
          'checksum_sha256': package.checksumSha256,
          'mime_type': 'application/zip',
          'size_bytes': package.bytes.length,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'deleted_at': null,
        },
        onConflict: 'user_id,local_id',
      );
    } on SyncRemoteException {
      rethrow;
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } on StorageException catch (_) {
      throw const SyncRemoteException(
        'Nao foi possivel enviar os capitulos do livro.',
      );
    } on PostgrestException catch (_) {
      throw const SyncRemoteException(
        'O servidor recusou o manifesto do livro.',
      );
    } catch (_) {
      throw const SyncRemoteException(
        'Falha de rede ao enviar os capitulos do livro.',
      );
    }
  }

  @override
  Future<List<RemoteBookAsset>> list({required String userId}) async {
    try {
      final List<dynamic> rows = await _client
          .from('book_assets')
          .select(
            'local_id,storage_path,checksum_sha256,size_bytes,updated_at',
          )
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .eq('mime_type', 'application/zip')
          .order('updated_at');
      return rows.whereType<Map<String, dynamic>>().map((row) {
        final String localId = row['local_id'] as String? ?? '';
        return RemoteBookAsset(
          bookId: localId.startsWith('package:')
              ? localId.substring('package:'.length)
              : localId,
          storagePath: row['storage_path'] as String? ?? '',
          checksumSha256: row['checksum_sha256'] as String? ?? '',
          sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
          updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      }).where((asset) {
        return asset.bookId.isNotEmpty &&
            asset.storagePath.startsWith('$userId/') &&
            asset.checksumSha256.length == 64 &&
            asset.sizeBytes > 0 &&
            asset.sizeBytes <= BookAssetPackageCodec.maxPackageBytes;
      }).toList(growable: false);
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } on PostgrestException catch (_) {
      throw const SyncRemoteException(
        'Nao foi possivel listar os livros sincronizados.',
      );
    } catch (_) {
      throw const SyncRemoteException(
        'Falha de rede ao listar os livros sincronizados.',
      );
    }
  }

  @override
  Future<Uint8List> download({
    required String userId,
    required RemoteBookAsset asset,
  }) async {
    if (!asset.storagePath.startsWith('$userId/')) {
      throw const SyncRemoteException('Caminho remoto do livro invalido.');
    }
    try {
      final Uint8List bytes =
          await _client.storage.from(_bucket).download(asset.storagePath);
      if (bytes.length != asset.sizeBytes) {
        throw const SyncRemoteException(
          'O tamanho do livro baixado nao corresponde ao manifesto.',
        );
      }
      return bytes;
    } on SyncRemoteException {
      rethrow;
    } on AuthException catch (_) {
      throw const SyncRemoteException(
        'A sessao expirou. Entre novamente.',
        sessionExpired: true,
      );
    } on StorageException catch (_) {
      throw const SyncRemoteException(
        'Nao foi possivel baixar os capitulos do livro.',
      );
    } catch (_) {
      throw const SyncRemoteException(
        'Falha de rede ao baixar os capitulos do livro.',
      );
    }
  }
}
