final Map<String, String> _processStorage = {};

String? readSearchRecents(String key) => _processStorage[key];

void writeSearchRecents(String key, String value) {
  _processStorage[key] = value;
}
