// Signature: dev.tswicolly03
import 'dart:typed_data';

import '../storage/app_storage.dart';

Future<Uint8List?> readPhysicalBookAsset(String path) async => null;

Future<String> storeSyncedBinary(String storageKey, Uint8List bytes) async {
  final String key = normalizeStorageKey(storageKey);
  if (!key.contains('/storage/synced_books/')) {
    throw StateError('Destino local de arquivo invalido.');
  }
  await createAppStorage().writeBytes(key, bytes);
  return 'veredra://$key';
}
