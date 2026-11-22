// Signature: dev.tswicolly03
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import '../storage/app_documents_io.dart';

import '../storage/app_storage.dart';

Future<Uint8List?> readPhysicalBookAsset(String path) async {
  final File file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<String> storeSyncedBinary(String storageKey, Uint8List bytes) async {
  final String key = normalizeStorageKey(storageKey);
  if (!key.contains('/storage/synced_books/')) {
    throw StateError('Destino local de arquivo invalido.');
  }
  final AppStorage storage = createAppStorage();
  await storage.writeBytes(key, bytes);
  final Directory root = await getVeredraDocumentsDirectory();
  return p.joinAll(<String>[root.path, ...key.split('/')]);
}
