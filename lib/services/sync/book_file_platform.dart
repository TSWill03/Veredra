// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'book_file_platform_stub.dart'
    if (dart.library.io) 'book_file_platform_io.dart'
    if (dart.library.js_interop) 'book_file_platform_web.dart' as platform;

/// Physical files are platform-specific. Synced chapters use AppStorage.
Future<Uint8List?> readPhysicalBookAsset(String path) =>
    platform.readPhysicalBookAsset(path);

/// Returns an actual file path on native and a veredra:// path on Web.
Future<String> storeSyncedBinary(String storageKey, Uint8List bytes) =>
    platform.storeSyncedBinary(storageKey, bytes);
