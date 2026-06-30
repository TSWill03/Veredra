// Signature: dev.tswicolly03
import 'app_storage_base.dart';
import 'app_storage_stub.dart'
    if (dart.library.io) 'app_storage_io.dart'
    if (dart.library.js_interop) 'app_storage_web.dart' as platform_storage;

export 'app_storage_base.dart';

AppStorage createAppStorage() => platform_storage.createAppStorage();
