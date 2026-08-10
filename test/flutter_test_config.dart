// Lets CI skip golden comparison without touching the 21 golden tests.
//
// Flutter goldens are platform-specific: text rasterisation and shader
// compilation differ between macOS (where these goldens were authored, and
// where they are regenerated with `flutter test --update-goldens`) and the
// Linux runners CI uses. All 21 pass locally on macOS and 19 fail on Linux
// purely from that difference — nothing about the widgets is wrong.
//
// So CI sets BEUI_SKIP_GOLDENS=1 and every other assertion still runs. Goldens
// remain a real gate, but a macOS-local one. Unset the variable (the default)
// and they compare normally.
//
// The alternative is running the package job on a macos-latest runner, which
// would validate goldens in CI at roughly 10x the runner-minute cost.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.environment['BEUI_SKIP_GOLDENS'] == '1') {
    goldenFileComparator = _SkipGoldenComparator();
  }
  return testMain();
}

/// Accepts any golden. Used only when BEUI_SKIP_GOLDENS=1.
class _SkipGoldenComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}
