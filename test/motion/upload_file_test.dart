import 'dart:typed_data';

import 'package:beui/beui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exposes metadata and reads bytes and streams lazily and repeatedly',
    () async {
      const payload = [0, 1, 2, 255];
      var byteReads = 0;
      var streamReads = 0;
      final file = BeuiUploadFile(
        name: 'sample.bin',
        size: payload.length,
        mimeType: 'application/octet-stream',
        readAsBytes: () async {
          byteReads++;
          return Uint8List.fromList(payload);
        },
        openRead: () {
          streamReads++;
          return Stream<List<int>>.value(payload);
        },
      );

      expect(file.name, 'sample.bin');
      expect(file.size, 4);
      expect(file.mimeType, 'application/octet-stream');
      expect(byteReads, 0);
      expect(streamReads, 0);

      expect(await file.readAsBytes(), payload);
      expect(await file.readAsBytes(), payload);
      expect(byteReads, 2);

      expect(await file.openRead().toList(), [payload]);
      expect(await file.openRead().toList(), [payload]);
      expect(streamReads, 2);
    },
  );
}
