// Signature: dev.tswicolly03
import 'dart:js_interop';

@JS('window.location.href')
external JSString get _href;

Uri getWebManifestUri() =>
    Uri.parse(_href.toDart).resolve('/veredra/updates.json');
