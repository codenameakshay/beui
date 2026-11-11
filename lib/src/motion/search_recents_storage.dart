import 'dart:convert';

import 'search_recents_storage_stub.dart'
    if (dart.library.js_interop) 'search_recents_storage_web.dart'
    as platform;

/// Reads a raw storage value by key.
typedef SearchRecentsReadRaw = String? Function(String key);

/// Writes a raw storage value by key.
typedef SearchRecentsWriteRaw = void Function(String key, String value);

/// The persisted shape is a JSON array of recent search strings, newest first.
class SearchRecentsStorage {
  /// Creates an adapter with platform storage operations.
  const SearchRecentsStorage({
    required SearchRecentsReadRaw read,
    required SearchRecentsWriteRaw write,
  }) : _readRaw = read,
       _writeRaw = write;

  final SearchRecentsReadRaw _readRaw;
  final SearchRecentsWriteRaw _writeRaw;

  /// Returns valid string entries, capped newest-first, or null if unavailable.
  List<String>? read(String key, int maxRecents) {
    try {
      final decoded = jsonDecode(_readRaw(key) ?? 'null');
      if (decoded is! List) return null;
      return decoded.whereType<String>().take(maxRecents).toList();
    } catch (_) {
      return null;
    }
  }

  /// Writes recents and returns false when storage rejects the write.
  bool write(String key, List<String> recents) {
    try {
      _writeRaw(key, jsonEncode(recents));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Platform-selected storage used by the search chips widget.
final searchRecentsStorage = SearchRecentsStorage(
  read: platform.readSearchRecents,
  write: platform.writeSearchRecents,
);
