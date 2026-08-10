// Loads the gallery's real typefaces before any test runs.
//
// Without this, `flutter test` renders every glyph in Flutter's fallback test
// font, which is substantially wider than Geist. That makes any width-sensitive
// assertion measure the wrong thing — demo_unbounded_height_test reported
// horizontal overflow in text-animation (246px), image-generation (16px) and
// loading-states (55px) that does NOT exist in the browser at the same width.
//
// Registering the same families the app declares in pubspec.yaml (`Geist`, and
// `monospace` backed by Geist Mono) makes those measurements real.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final path in assets) {
    loader.addFont(rootBundle.load(path));
  }
  await loader.load();
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _load('Geist', const [
    'assets/fonts/Geist-Regular.ttf',
    'assets/fonts/Geist-Medium.ttf',
    'assets/fonts/Geist-SemiBold.ttf',
    'assets/fonts/Geist-Bold.ttf',
  ]);
  // The gallery registers Geist Mono under the generic `monospace` name so
  // code surfaces resolve on web; mirror that here.
  await _load('monospace', const [
    'assets/fonts/GeistMono-Regular.ttf',
    'assets/fonts/GeistMono-Medium.ttf',
  ]);

  return testMain();
}
