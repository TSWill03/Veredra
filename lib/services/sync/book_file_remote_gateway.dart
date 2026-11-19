// Signature: dev.tswicolly03
import 'dart:typed_data';

class RemoteBookAsset {
  const RemoteBookAsset({
    required this.bookId,
    required this.storagePath,
    required this.checksum,
    required this.sizeBytes,
  });

  final String bookId;
  final String storagePath;
  final String checksum;
  final int sizeBytes;
}

abstract class BookFileRemoteGateway {
  Future<List<RemoteBookAsset>> listAssets({required String userId});

  Future<void> upload({
    required String userId,
    required String deviceId,
    required String bookId,
    required Uint8List bytes,
    required String checksum,
  });

  Future<Uint8List> download(RemoteBookAsset asset);
}
