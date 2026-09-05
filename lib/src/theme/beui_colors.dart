/// The beUI color system — a [ThemeExtension] port of the source design tokens.
///
/// A one-to-one port of the source's `lib/themes.ts` (the canonical inlined
/// palette) and `lib/theme-css.ts` (the alias / glass tier). Components read
/// their colors from [BeuiColors.resolve], never from
/// hardcoded literals.
///
/// The palette is computed at build time, not runtime: oklch source values are
/// precomputed to sRGB by `tool/generate_colors.dart` and committed as the
/// `Color` literals in `beui_colors.g.dart`. The published package ships no
/// runtime oklch parser. See `docs/PORTING_SPEC.md` §2.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

part 'beui_colors.g.dart';

/// The selectable color themes — the neutral [defaultMono] base plus the ten
/// brand themes. Combined with a [Brightness], each resolves to a complete
/// [BeuiColors] palette via [BeuiColors.of].
///
/// Color theme and brightness are **independent axes**: any theme is valid in
/// either brightness. Each value carries picker metadata — a display [name] and
/// a [swatch] dot color — mirroring the source `THEME_LIST`.
enum BeuiColorTheme {
  /// Neutral monochrome base (source slug `default`, display name `Mono`).
  defaultMono('Mono', 'default', _monoSwatch),

  /// Violet brand theme.
  violet('Violet', 'violet', _violetSwatch),

  /// Blue brand theme.
  blue('Blue', 'blue', _blueSwatch),

  /// Green brand theme.
  green('Green', 'green', _greenSwatch),

  /// Amber brand theme.
  amber('Amber', 'amber', _amberSwatch),

  /// Blood-orange brand theme (source slug `blood-orange`).
  bloodOrange('Blood Orange', 'blood-orange', _bloodOrangeSwatch),

  /// Rose brand theme.
  rose('Rose', 'rose', _roseSwatch),

  /// Red brand theme.
  red('Red', 'red', _redSwatch),

  /// Teal brand theme.
  teal('Teal', 'teal', _tealSwatch),

  /// Indigo brand theme.
  indigo('Indigo', 'indigo', _indigoSwatch),

  /// Lime brand theme.
  lime('Lime', 'lime', _limeSwatch);

  const BeuiColorTheme(this.name, this.slug, this.swatch);

  /// Human-readable name for a theme picker (e.g. `Mono`, `Blood Orange`).
  final String name;

  /// The source `ColorTheme` slug (e.g. `default`, `blood-orange`), kept for
  /// traceability against `themes.ts`.
  final String slug;

  /// The picker dot color — deliberately distinct from `--primary` for the
  /// neutral theme (a mid-gray), and the light brand hue for colored themes.
  final Color swatch;
}

/// A frosted-glass surface descriptor — the source `glass` / `glass-strong` /
/// `glass-thin` tiers grouped so overlay components read one cohesive surface.
///
/// Carries both the translucent fill [Color]s and their backdrop **blur radii**.
///
/// **Documented blur exception.** The global motion rules cap blur at ≤ 10px,
/// but glass surfaces deliberately use 12–20px backdrop blur ([blur] 20,
/// [strongBlur] 16, [thinBlur] 12), matching the source `theme-css.ts`. This is
/// a sanctioned exception to the cap, not a rule violation — it applies to these
/// static surface backdrops only, never to transform motion.
@immutable
class BeuiGlass {
  /// Creates a glass surface descriptor. Blur radii default to the source
  /// values (the documented 12–20px exception to the ≤10px motion cap).
  const BeuiGlass({
    required this.bg,
    required this.border,
    required this.strongBg,
    required this.thinBg,
    this.blur = 20.0,
    this.strongBlur = 16.0,
    this.thinBlur = 12.0,
  });

  /// Standard glass fill (source `--glass-bg`).
  final Color bg;

  /// Hairline glass border (source `--glass-border`).
  final Color border;

  /// Stronger, more opaque fill for modals / sheets (source `--glass-strong-bg`).
  final Color strongBg;

  /// Lighter fill for subtle overlays (source `--glass-thin-bg`).
  final Color thinBg;

  /// Backdrop blur radius for [bg], in logical pixels (source `glass`, 20px).
  final double blur;

  /// Backdrop blur radius for [strongBg] (source `glass-strong`, 16px).
  final double strongBlur;

  /// Backdrop blur radius for [thinBg] (source `glass-thin`, 12px).
  final double thinBlur;

  /// Returns a copy with the given fields replaced.
  BeuiGlass copyWith({
    Color? bg,
    Color? border,
    Color? strongBg,
    Color? thinBg,
    double? blur,
    double? strongBlur,
    double? thinBlur,
  }) {
    return BeuiGlass(
      bg: bg ?? this.bg,
      border: border ?? this.border,
      strongBg: strongBg ?? this.strongBg,
      thinBg: thinBg ?? this.thinBg,
      blur: blur ?? this.blur,
      strongBlur: strongBlur ?? this.strongBlur,
      thinBlur: thinBlur ?? this.thinBlur,
    );
  }

  /// Linearly interpolates between two glass surfaces (colors via [Color.lerp],
  /// blur radii via [lerpDouble]).
  static BeuiGlass lerp(BeuiGlass a, BeuiGlass b, double t) {
    return BeuiGlass(
      bg: Color.lerp(a.bg, b.bg, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      strongBg: Color.lerp(a.strongBg, b.strongBg, t)!,
      thinBg: Color.lerp(a.thinBg, b.thinBg, t)!,
      blur: lerpDouble(a.blur, b.blur, t)!,
      strongBlur: lerpDouble(a.strongBlur, b.strongBlur, t)!,
      thinBlur: lerpDouble(a.thinBlur, b.thinBlur, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiGlass &&
        other.bg == bg &&
        other.border == border &&
        other.strongBg == strongBg &&
        other.thinBg == thinBg &&
        other.blur == blur &&
        other.strongBlur == strongBlur &&
        other.thinBlur == thinBlur;
  }

  @override
  int get hashCode =>
      Object.hash(bg, border, strongBg, thinBg, blur, strongBlur, thinBlur);
}

/// The five brand-token overrides a colored theme applies on top of the neutral
/// base, mirroring the source `brand()` helper in `themes.ts`.
class _Brand {
  const _Brand({
    required this.primary,
    required this.primaryForeground,
    required this.accent,
    required this.accentForeground,
    required this.ring,
    required this.focusRing,
  });

  final Color primary;
  final Color primaryForeground;
  final Color accent;
  final Color accentForeground;
  final Color ring;
  final Color focusRing;
}

/// The resolved beUI palette for one [colorTheme] × [brightness] combination,
/// exposed to the widget tree as a [ThemeExtension].
///
/// Carries the core 18 design tokens plus the second-tier tokens components
/// actually read ([borderStrong] and the [glass] surface descriptor). Resolve
/// one with [BeuiColors.of], or the neutral [BeuiColors.light] / [BeuiColors.dark]
/// factories, then install it:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: [BeuiColors.of(BeuiColorTheme.violet, Brightness.light)]),
/// );
/// ```
///
/// Components read it back with [BeuiColors.resolve].
@immutable
class BeuiColors extends ThemeExtension<BeuiColors> {
  /// Creates a fully-specified palette. Prefer [BeuiColors.of] / [BeuiColors.light]
  /// / [BeuiColors.dark] over calling this directly.
  const BeuiColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.border,
    required this.input,
    required this.ring,
    required this.borderStrong,
    required this.focusRing,
    required this.success,
    required this.warning,
    required this.glass,
    required this.colorTheme,
    required this.brightness,
  });

  /// Resolves the palette for [theme] in [brightness]. The two axes are
  /// independent — any [BeuiColorTheme] is valid in either [Brightness].
  ///
  /// Colored themes start from the neutral base and override only the brand
  /// tokens ([primary], [primaryForeground], [accent], [accentForeground],
  /// [ring]), exactly as the source `brand()` helper does — plus the port-added
  /// [focusRing], which follows the same brand hue.
  factory BeuiColors.of(BeuiColorTheme theme, Brightness brightness) {
    final base = _base(theme, brightness);
    final brand = _brandFor(theme, brightness);
    if (brand == null) return base;
    return base.copyWith(
      primary: brand.primary,
      primaryForeground: brand.primaryForeground,
      accent: brand.accent,
      accentForeground: brand.accentForeground,
      ring: brand.ring,
      focusRing: brand.focusRing,
    );
  }

  /// The palette installed on the nearest [Theme], or the neutral palette for
  /// that theme's brightness when the consumer did not add the extension.
  ///
  /// Every component reads its colors through this so a bare `MaterialApp`
  /// renders instead of throwing on a missing extension.
  static BeuiColors resolve(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
  }

  /// The neutral [BeuiColorTheme.defaultMono] palette in light mode.
  factory BeuiColors.light() =>
      _base(BeuiColorTheme.defaultMono, Brightness.light);

  /// The neutral [BeuiColorTheme.defaultMono] palette in dark mode.
  factory BeuiColors.dark() =>
      _base(BeuiColorTheme.defaultMono, Brightness.dark);

  /// App / page background (source `--background`).
  final Color background;

  /// Default foreground / text on [background] (source `--foreground`).
  final Color foreground;

  /// Card surface (source `--card`).
  final Color card;

  /// Foreground on [card] (source `--card-foreground`).
  final Color cardForeground;

  /// Popover / floating surface (source `--popover`).
  final Color popover;

  /// Foreground on [popover] (source `--popover-foreground`).
  final Color popoverForeground;

  /// Primary brand color (source `--primary`).
  final Color primary;

  /// Foreground on [primary] (source `--primary-foreground`).
  final Color primaryForeground;

  /// Secondary surface (source `--secondary`).
  final Color secondary;

  /// Foreground on [secondary] (source `--secondary-foreground`).
  final Color secondaryForeground;

  /// Muted surface (source `--muted`).
  final Color muted;

  /// Muted foreground / secondary text (source `--muted-foreground`).
  final Color mutedForeground;

  /// Accent color (source `--accent`).
  final Color accent;

  /// Foreground on [accent] (source `--accent-foreground`).
  final Color accentForeground;

  /// Destructive / danger color (source `--destructive`).
  final Color destructive;

  /// Hairline border, translucent (source `--border`).
  final Color border;

  /// Input border, aliases [border] in the source (source `--input`).
  final Color input;

  /// Focus ring. Aliases [borderStrong] for the neutral theme; colored themes
  /// override it with a hue-tinted [primary] (source `--ring`).
  final Color ring;

  /// Stronger border for emphasis — second-tier token consumed by switch, dock,
  /// radio, checkbox and otp-input (source `--border-strong`).
  final Color borderStrong;

  /// **Use this for keyboard focus indicators.** [ring] is for hairline
  /// borders — it is the source's 6–12% `--border-strong` alias and composites
  /// to ~1.3:1 on [background], well under WCAG 2.2 SC 1.4.11's 3:1 floor for a
  /// focus indicator. This role exists so the two jobs stop sharing one token.
  ///
  /// A **port addition** with no source counterpart. Every value clears 3:1
  /// against [background] in both brightnesses: the neutral theme is
  /// [foreground] at 0.55 light (4.36:1) / 0.6 dark (6.49:1); colored themes use
  /// their brand hue at full opacity (4.18–6.26:1 light, 5.80–10.27:1 dark),
  /// with amber and lime darkened to 60% oklch lightness because their light
  /// brand hues cannot clear 3:1 at *any* alpha.
  ///
  /// Paint it **outside layout** — a `foregroundDecoration` or an overlay — so
  /// focusing never insets the child. See `lib/src/motion/_focus_ring.dart`.
  final Color focusRing;

  /// Positive / success accent (source `--success`, `oklch(70% 0.18 155)`).
  /// Brightness-independent — the source defines it once with no dark override.
  /// Read by input (success check) and feedback-widget.
  final Color success;

  /// Caution / warning accent (source `--warning`, `oklch(78% 0.18 75)`).
  /// Brightness-independent, like [success].
  final Color warning;

  /// Frosted-glass surface descriptor (source `--glass-*`), read by overlay
  /// components as one cohesive surface. See [BeuiGlass].
  final BeuiGlass glass;

  /// The [BeuiColorTheme] this palette was resolved from.
  final BeuiColorTheme colorTheme;

  /// The [Brightness] this palette was resolved for.
  final Brightness brightness;

  /// Display name of [colorTheme], for a theme picker.
  String get name => colorTheme.name;

  /// Picker dot color of [colorTheme], for a theme picker. See
  /// [BeuiColorTheme.swatch].
  Color get swatch => colorTheme.swatch;

  @override
  BeuiColors copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? border,
    Color? input,
    Color? ring,
    Color? borderStrong,
    Color? focusRing,
    Color? success,
    Color? warning,
    BeuiGlass? glass,
    BeuiColorTheme? colorTheme,
    Brightness? brightness,
  }) {
    return BeuiColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      borderStrong: borderStrong ?? this.borderStrong,
      focusRing: focusRing ?? this.focusRing,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      glass: glass ?? this.glass,
      colorTheme: colorTheme ?? this.colorTheme,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  BeuiColors lerp(covariant ThemeExtension<BeuiColors>? other, double t) {
    if (other is! BeuiColors) return this;
    return BeuiColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      popoverForeground: Color.lerp(
        popoverForeground,
        other.popoverForeground,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      glass: BeuiGlass.lerp(glass, other.glass, t),
      // Discrete identity fields snap at the midpoint — they cannot meaningfully
      // interpolate.
      colorTheme: t < 0.5 ? colorTheme : other.colorTheme,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }

  // Value equality is **load-bearing, not a nicety.** `ThemeData` compares its
  // `extensions` map by value, so without this two structurally identical
  // palettes compare unequal and every rebuild that reconstructs the theme
  // (`ThemeData.light().copyWith(extensions: [BeuiColors.light()])` inside a
  // `build`, which is exactly how the gallery and the tests wire it) looks like
  // a *theme change* to `AnimatedTheme`. That restarts its 200ms lerp, and the
  // drifting interpolated `ThemeData` then re-triggers Material's own implicit
  // animations (`AnimatedPhysicalModel`, `AnimatedDefaultTextStyle`) for a
  // further 200ms as they chase it — a ~400ms tail of pure phantom animation on
  // every setState, which reduced motion does not suppress because a color
  // transition is not movement. See `test/theme/beui_colors_test.dart`.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiColors &&
        other.background == background &&
        other.foreground == foreground &&
        other.card == card &&
        other.cardForeground == cardForeground &&
        other.popover == popover &&
        other.popoverForeground == popoverForeground &&
        other.primary == primary &&
        other.primaryForeground == primaryForeground &&
        other.secondary == secondary &&
        other.secondaryForeground == secondaryForeground &&
        other.muted == muted &&
        other.mutedForeground == mutedForeground &&
        other.accent == accent &&
        other.accentForeground == accentForeground &&
        other.destructive == destructive &&
        other.border == border &&
        other.input == input &&
        other.ring == ring &&
        other.borderStrong == borderStrong &&
        other.focusRing == focusRing &&
        other.success == success &&
        other.warning == warning &&
        other.glass == glass &&
        other.colorTheme == colorTheme &&
        other.brightness == brightness;
  }

  // 25 fields — past `Object.hash`'s 20-argument ceiling, so hash the list.
  @override
  int get hashCode => Object.hashAll([
    background,
    foreground,
    card,
    cardForeground,
    popover,
    popoverForeground,
    primary,
    primaryForeground,
    secondary,
    secondaryForeground,
    muted,
    mutedForeground,
    accent,
    accentForeground,
    destructive,
    border,
    input,
    ring,
    borderStrong,
    focusRing,
    success,
    warning,
    glass,
    colorTheme,
    brightness,
  ]);
}

/// Builds the neutral base palette for [brightness], tagged with [theme] so a
/// colored override (applied by [BeuiColors.of]) carries the right identity.
BeuiColors _base(BeuiColorTheme theme, Brightness brightness) {
  if (brightness == Brightness.light) {
    return BeuiColors(
      background: _lBackground,
      foreground: _lForeground,
      card: _lCard,
      cardForeground: _lCardForeground,
      popover: _lPopover,
      popoverForeground: _lPopoverForeground,
      primary: _lPrimary,
      primaryForeground: _lPrimaryForeground,
      secondary: _lSecondary,
      secondaryForeground: _lSecondaryForeground,
      muted: _lMuted,
      mutedForeground: _lMutedForeground,
      accent: _lAccent,
      accentForeground: _lAccentForeground,
      destructive: _lDestructive,
      border: _lBorder,
      input: _lInput,
      ring: _lRing,
      borderStrong: _lBorderStrong,
      focusRing: _lFocusRing,
      success: _success,
      warning: _warning,
      glass: _glassLight,
      colorTheme: theme,
      brightness: Brightness.light,
    );
  }
  return BeuiColors(
    background: _dBackground,
    foreground: _dForeground,
    card: _dCard,
    cardForeground: _dCardForeground,
    popover: _dPopover,
    popoverForeground: _dPopoverForeground,
    primary: _dPrimary,
    primaryForeground: _dPrimaryForeground,
    secondary: _dSecondary,
    secondaryForeground: _dSecondaryForeground,
    muted: _dMuted,
    mutedForeground: _dMutedForeground,
    accent: _dAccent,
    accentForeground: _dAccentForeground,
    destructive: _dDestructive,
    border: _dBorder,
    input: _dInput,
    ring: _dRing,
    borderStrong: _dBorderStrong,
    focusRing: _dFocusRing,
    success: _success,
    warning: _warning,
    glass: _glassDark,
    colorTheme: theme,
    brightness: Brightness.dark,
  );
}

/// The brand-token overrides for a colored [theme] in [brightness], or `null`
/// for the neutral [BeuiColorTheme.defaultMono].
_Brand? _brandFor(BeuiColorTheme theme, Brightness brightness) {
  final isLight = brightness == Brightness.light;
  switch (theme) {
    case BeuiColorTheme.defaultMono:
      return null;
    case BeuiColorTheme.violet:
      return isLight ? _violetLight : _violetDark;
    case BeuiColorTheme.blue:
      return isLight ? _blueLight : _blueDark;
    case BeuiColorTheme.green:
      return isLight ? _greenLight : _greenDark;
    case BeuiColorTheme.amber:
      return isLight ? _amberLight : _amberDark;
    case BeuiColorTheme.bloodOrange:
      return isLight ? _bloodOrangeLight : _bloodOrangeDark;
    case BeuiColorTheme.rose:
      return isLight ? _roseLight : _roseDark;
    case BeuiColorTheme.red:
      return isLight ? _redLight : _redDark;
    case BeuiColorTheme.teal:
      return isLight ? _tealLight : _tealDark;
    case BeuiColorTheme.indigo:
      return isLight ? _indigoLight : _indigoDark;
    case BeuiColorTheme.lime:
      return isLight ? _limeLight : _limeDark;
  }
}
