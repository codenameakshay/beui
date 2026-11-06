import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/search_recents_storage.dart';

void main() {
  test('reads only string entries from a stored array and applies the cap', () {
    final storage = SearchRecentsStorage(
      read: (_) => '["newest", 4, null, "older", "oldest"]',
      write: (_, _) {},
    );

    expect(storage.read('terms', 2), ['newest', 'older']);
  });

  test('corrupt JSON and non-array values leave recents unhydrated', () {
    final values = <String, String>{
      'corrupt': '{not json',
      'object': '{"term":"one"}',
    };
    final storage = SearchRecentsStorage(
      read: (key) => values[key],
      write: (_, _) {},
    );

    expect(storage.read('corrupt', 5), isNull);
    expect(storage.read('object', 5), isNull);
  });

  test('writes a JSON string array in newest-first order', () {
    String? written;
    final storage = SearchRecentsStorage(
      read: (_) => null,
      write: (_, value) => written = value,
    );

    expect(storage.write('terms', ['newest', 'older']), isTrue);
    expect(written, '["newest","older"]');
  });

  test('a storage write failure is contained and reported to the owner', () {
    final storage = SearchRecentsStorage(
      read: (_) => null,
      write: (_, _) => throw StateError('quota exceeded'),
    );

    expect(storage.write('terms', ['session term']), isFalse);
  });
}
