import 'dart:js_interop';

@JS('veredraSetReadingMode')
external void _setSiteReturnReadingMode(JSBoolean isReading);

void setSiteReturnReadingMode(bool isReading) {
  try {
    // Standalone Web builds may not ship the optional site return control.
    _setSiteReturnReadingMode(isReading.toJS);
  } catch (_) {
    // Reading must never depend on the host page's optional navigation.
  }
}
