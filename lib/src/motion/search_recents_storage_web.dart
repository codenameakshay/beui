import 'package:web/web.dart' as web;

String? readSearchRecents(String key) => web.window.localStorage.getItem(key);

void writeSearchRecents(String key, String value) {
  web.window.localStorage.setItem(key, value);
}
