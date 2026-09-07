/// The glyph-scramble reveal shared by the loader, reasoning-text, and
/// not-found widgets: random glyphs settle into the target text left to
/// right as more characters become "revealed".
library;

import 'dart:math' as math;

/// Returns [target] with its first [settled] characters shown as-is (plus
/// any space, which always passes through unscrambled) and the rest replaced
/// by a random character from [glyphs].
///
/// Callers each compute [settled] from their own progress/timing model, then
/// share this per-character reveal so the three widgets stay in lockstep on
/// behaviour without duplicating the loop.
String beuiScramble(
  String target,
  int settled,
  math.Random random,
  String glyphs,
) {
  final buffer = StringBuffer();
  for (var i = 0; i < target.length; i++) {
    final ch = target[i];
    buffer.write(
      i < settled || ch == ' ' ? ch : glyphs[random.nextInt(glyphs.length)],
    );
  }
  return buffer.toString();
}
