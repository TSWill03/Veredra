// Compact the return-to-site control only while a book is open on Web.
export 'site_return_bridge_stub.dart'
    if (dart.library.js_interop) 'site_return_bridge_web.dart';
