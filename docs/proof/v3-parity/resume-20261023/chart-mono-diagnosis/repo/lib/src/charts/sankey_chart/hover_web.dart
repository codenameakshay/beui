import 'dart:js_interop';

@JS('window.matchMedia')
external _MediaQuery _matchMedia(String query);
extension type _MediaQuery(JSObject _) implements JSObject {
  external bool get matches;
}
bool get sankeyHoverCapable =>
    _matchMedia('(hover: hover) and (pointer: fine)').matches;
