/// The beUI typography contract — font family names, plus the letter-spacing
/// normalisation beUI components need from the ambient [ThemeData].
///
/// The published package bundles **no font files**. This type names the families
/// the source uses so consumers can wire them up themselves (a pubspec `fonts:`
/// section or `google_fonts`); the `example/` gallery is the only place that may
/// bundle the fonts for visual parity. See `docs/PORTING_SPEC.md` §2.
library;

import 'package:flutter/material.dart';

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

  /// Returns [theme] with Material's baked-in letter-spacing neutralised.
  ///
  /// **Install this on the theme you hand beUI components.** Material 3's 2021
  /// typography bakes a non-zero `letterSpacing` into every text style —
  /// `bodyLarge` 0.5, `bodyMedium` 0.25, `labelLarge` 0.1, and so on. The beUI
  /// source is Tailwind, which leaves tracking at `normal` (0) unless a
  /// `tracking-*` class says otherwise, so those Material defaults widen every
  /// beUI label relative to the original: a 20-character `bodyMedium` string
  /// measures 5px too wide, a 15-character `bodyLarge` one 7.5px too wide.
  ///
  /// Components set [TextStyle.letterSpacing] explicitly wherever the source
  /// asks for tracking (`tracking-wider`, `tracking-[-0.04em]`, …). Those
  /// values win over the theme under [TextStyle.merge], so zeroing the default
  /// here neutralises only the tracking nobody asked for.
  ///
  /// ```dart
  /// MaterialApp(
  ///   theme: BeuiTextTheme.trackingNormal(
  ///     ThemeData(fontFamily: 'Geist').copyWith(extensions: [BeuiColors.dark()]),
  ///   ),
  /// );
  /// ```
  static ThemeData trackingNormal(ThemeData theme) {
    return theme.copyWith(
      textTheme: trackingNormalTextTheme(theme.textTheme),
      primaryTextTheme: trackingNormalTextTheme(theme.primaryTextTheme),
    );
  }

  /// Returns [base] with every style's [TextStyle.letterSpacing] zeroed.
  ///
  /// The [TextTheme]-level primitive behind [trackingNormal], for callers that
  /// compose a text theme by hand.
  ///
  /// Styles are pinned to an explicit `0`, and that detail is load-bearing: a
  /// bare [ThemeData]'s text styles leave `letterSpacing` **null**, and the
  /// Material values (`bodyMedium` 0.25, `bodyLarge` 0.5, …) arrive later from
  /// [Typography.englishLike2021], which `ThemeData.localize` merges *beneath*
  /// the theme's own text theme. A null would therefore let the Material value
  /// through; an explicit zero is what blocks it.
  ///
  /// For the same reason this cannot be expressed as
  /// `base.apply(letterSpacingFactor: 0)` — that would preserve the nulls, and
  /// [TextStyle.apply] asserts on them besides.
  static TextTheme trackingNormalTextTheme(TextTheme base) {
    TextStyle? flat(TextStyle? style) => style?.copyWith(letterSpacing: 0);
    return base.copyWith(
      displayLarge: flat(base.displayLarge),
      displayMedium: flat(base.displayMedium),
      displaySmall: flat(base.displaySmall),
      headlineLarge: flat(base.headlineLarge),
      headlineMedium: flat(base.headlineMedium),
      headlineSmall: flat(base.headlineSmall),
      titleLarge: flat(base.titleLarge),
      titleMedium: flat(base.titleMedium),
      titleSmall: flat(base.titleSmall),
      bodyLarge: flat(base.bodyLarge),
      bodyMedium: flat(base.bodyMedium),
      bodySmall: flat(base.bodySmall),
      labelLarge: flat(base.labelLarge),
      labelMedium: flat(base.labelMedium),
      labelSmall: flat(base.labelSmall),
    );
  }

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
