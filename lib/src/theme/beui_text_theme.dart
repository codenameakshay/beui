/// The beUI typography contract — font family **names only**.
///
/// The published package bundles **no font files**. This type names the families
/// the source uses so consumers can wire them up themselves (a pubspec `fonts:`
/// section or `google_fonts`); the `example/` gallery is the only place that may
/// bundle the fonts for visual parity. See `docs/PORTING_SPEC.md` §2.
library;

import 'package:flutter/foundation.dart';

/// Names the sans and mono font families a beUI app should use, with a platform
/// monospace fallback for when the mono family is not provided.
///
/// Exposes **names**, not assets — nothing here loads a font. The source's pixel
/// font is docs-site chrome and is intentionally not ported.
///
/// ```dart
/// const text = BeuiTextTheme();
/// Text('code', style: TextStyle(
///   fontFamily: text.monoFamily,
///   fontFamilyFallback: text.monoFamilyFallback,
/// ));
/// ```
@immutable
class BeuiTextTheme {
  /// Creates a typography contract. Defaults to the source families
  /// ([sansFamily] `Inter`, [monoFamily] `JetBrains Mono`).
  const BeuiTextTheme({
    this.sansFamily = 'Inter',
    this.monoFamily = 'JetBrains Mono',
  });

  /// The sans-serif family name (source: Inter).
  final String sansFamily;

  /// The monospace family name (source: JetBrains Mono — **not** Geist Mono).
  final String monoFamily;

  /// Fallback families for [monoFamily]. Resolves to the platform's built-in
  /// monospace when the named mono family is absent, so code renders in a
  /// fixed-width face even before the consumer wires up JetBrains Mono.
  List<String> get monoFamilyFallback => const ['monospace'];

  /// Fallback families for [sansFamily] — the platform's default sans-serif.
  List<String> get sansFamilyFallback => const ['sans-serif'];

  /// Returns a copy with the given families replaced.
  BeuiTextTheme copyWith({String? sansFamily, String? monoFamily}) {
    return BeuiTextTheme(
      sansFamily: sansFamily ?? this.sansFamily,
      monoFamily: monoFamily ?? this.monoFamily,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiTextTheme &&
        other.sansFamily == sansFamily &&
        other.monoFamily == monoFamily;
  }

  @override
  int get hashCode => Object.hash(sansFamily, monoFamily);
}
