import 'dart:js_interop';

@JS('globalThis.__beuiCapture')
external set _capture(JSAny? value);

void publishCaptureProbe(Map<String, Object?> value) {
  _capture = value.jsify();
}
