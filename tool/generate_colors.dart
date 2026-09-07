// Dev-only color generator — NOT shipped with the package.
//
// Reproducibly converts the beUI source palette (oklch / hex / rgb) into the
// sRGB `Color` literals used by `lib/src/theme/beui_colors.dart`. The source
// mixes three formats (see docs/PORTING_SPEC.md §2), so this script:
//
//   * converts oklch → oklab → linear sRGB → gamma-encoded sRGB, *preserving*
//     any `/ alpha` term,
//   * passes raw `#hex` and `rgb(r g b / a)` literals straight through (NO
//     oklch conversion),
//   * keeps the original source literal in a `//` comment for traceability.
//
// The library ships only the generated literals — there is no runtime oklch
// parser. Regenerate and review the diff with:
//
//   dart run tool/generate_colors.dart > lib/src/theme/beui_colors.g.dart
//
// Source: starc007/ui-components — lib/themes.ts + lib/theme-css.ts.

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// Color value model — carries the resolved 0xAARRGGBB plus the source literal.
// ---------------------------------------------------------------------------

class Col {
  Col(this.argb, this.source);
  final int argb; // 0xAARRGGBB
  final String source; // original source literal, for the trailing comment

  String get literal =>
      'Color(0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}

// ── Format parsers ─────────────────────────────────────────────────────────

/// oklch(L% C H [/ a]) → sRGB, alpha preserved.
Col oklch(double lPct, double c, double h, {double a = 1.0, String? src}) {
  final l = lPct / 100.0;
  final hr = h * math.pi / 180.0;
  final ca = c * math.cos(hr);
  final cb = c * math.sin(hr);

  // oklab → LMS'  (Ottosson inverse M2)
  final lp = l + 0.3963377774 * ca + 0.2158037573 * cb;
  final mp = l - 0.1055613458 * ca - 0.0638541728 * cb;
  final sp = l - 0.0894841775 * ca - 1.2914855480 * cb;

  // LMS' → LMS (cube)
  final lc = lp * lp * lp;
  final mc = mp * mp * mp;
  final sc = sp * sp * sp;

  // LMS → linear sRGB  (Ottosson inverse M1)
  final r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
  final g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
  final b = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;

  final argb = (_a8(a) << 24) | (_enc(r) << 16) | (_enc(g) << 8) | _enc(b);
  return Col(argb, src ?? _oklchSrc(lPct, c, h, a));
}

/// `#rrggbb` → sRGB, opaque (no source hex carries alpha here).
Col hex(String h) {
  final clean = h.replaceFirst('#', '');
  final rgb = int.parse(clean, radix: 16);
  return Col(0xFF000000 | rgb, h);
}

/// `rgb(r g b / a)` → sRGB, alpha preserved.
Col rgb(int r, int g, int b, {double a = 1.0, String? src}) {
  final argb = (_a8(a) << 24) | (r << 16) | (g << 8) | b;
  return Col(argb, src ?? _rgbSrc(r, g, b, a));
}

// gamma-encode one linear channel → 8-bit, gamut-clipped to [0, 1].
int _enc(double linear) {
  final x = linear.clamp(0.0, 1.0);
  final v = x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
  return (v * 255.0).round().clamp(0, 255);
}

int _a8(double a) => (a * 255.0).round().clamp(0, 255);

String _num(double v) {
  final s = v.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _oklchSrc(double lPct, double c, double h, double a) {
  final base = 'oklch(${_num(lPct)}% ${_num(c)} ${_num(h)}';
  return a == 1.0 ? '$base)' : '$base / ${_num(a)})';
}

String _rgbSrc(int r, int g, int b, double a) {
  final base = 'rgb($r $g $b';
  return a == 1.0 ? '$base)' : '$base / ${_num(a)})';
}

// ---------------------------------------------------------------------------
// Source palette — a 1:1 transcription of themes.ts + theme-css.ts.
// ---------------------------------------------------------------------------

// Neutral base — light (themes.ts BASE_LIGHT, + theme-css.ts second tier).
final _light = <String, Col>{
  'background': oklch(99, 0, 0),
  'foreground': oklch(15, 0, 0),
  'card': oklch(97, 0, 0),
  'cardForeground': oklch(15, 0, 0),
  'popover': oklch(97, 0, 0),
  'popoverForeground': oklch(15, 0, 0),
  'primary': oklch(15, 0, 0),
  'primaryForeground': oklch(99, 0, 0),
  'secondary': oklch(97, 0, 0),
  'secondaryForeground': oklch(15, 0, 0),
  'muted': oklch(97, 0, 0),
  'mutedForeground': oklch(50, 0, 0),
  'accent': oklch(72, 0.18, 195),
  'accentForeground': oklch(15, 0, 0),
  'destructive': oklch(62, 0.22, 25),
  'border': oklch(15, 0, 0, a: 0.06),
  'input': oklch(15, 0, 0, a: 0.06),
  'ring': oklch(15, 0, 0, a: 0.12), // = --border-strong (theme-css.ts alias)
  'borderStrong': oklch(15, 0, 0, a: 0.12),
  // NOT a source token — a port addition. `--ring` is a 6-12% hairline and
  // composites to 1.30:1, far under WCAG 2.2's 3:1 floor for a focus
  // indicator. This is `--foreground` at 0.55 → 4.36:1 on `--background`.
  'focusRing': oklch(15, 0, 0, a: 0.55),
};

final _lightGlass = <String, Col>{
  'bg': oklch(99, 0, 0, a: 0.55),
  'border': oklch(15, 0, 0, a: 0.08),
};

// Neutral base — dark (themes.ts BASE_DARK, + theme-css.ts second tier).
final _dark = <String, Col>{
  'background': hex('#151515'),
  'foreground': oklch(96, 0, 0),
  'card': hex('#1c1c1c'),
  'cardForeground': oklch(96, 0, 0),
  'popover': hex('#1c1c1c'),
  'popoverForeground': oklch(96, 0, 0),
  'primary': oklch(96, 0, 0),
  'primaryForeground': hex('#151515'),
  'secondary': hex('#1c1c1c'),
  'secondaryForeground': oklch(96, 0, 0),
  'muted': hex('#1c1c1c'),
  'mutedForeground': oklch(62, 0, 0),
  'accent': oklch(80, 0.18, 195),
  'accentForeground': hex('#151515'),
  'destructive': oklch(62, 0.22, 25),
  'border': rgb(255, 255, 255, a: 0.05),
  'input': rgb(255, 255, 255, a: 0.05),
  'ring': rgb(255, 255, 255, a: 0.1), // = --border-strong (theme-css.ts alias)
  'borderStrong': rgb(255, 255, 255, a: 0.1),
  // Port addition — see the light note above. `--foreground` at 0.6 → 6.49:1.
  'focusRing': oklch(96, 0, 0, a: 0.6),
};

final _darkGlass = <String, Col>{
  'bg': rgb(28, 28, 28, a: 0.55),
  'border': rgb(255, 255, 255, a: 0.08),
};

// A colored theme overrides only the five brand tokens (themes.ts brand()):
// primary, primary-foreground, accent (== primary hue), accent-foreground,
// ring (== a hue-tinted primary at alpha 0.5 light / 0.55 dark) — plus the
// port-added `focusRing` (see _focusRing below).
class Brand {
  Brand(this.name, this.swatch, this.light, this.dark);
  final String name;
  final Col swatch;
  final Map<String, Col> light;
  final Map<String, Col> dark;
}

Map<String, Col> _brand(Col hue, Col onHue, Col ring, Col focusRing) => {
  'primary': hue,
  'primaryForeground': onHue,
  'accent': hue,
  'accentForeground': onHue,
  'ring': ring,
  'focusRing': focusRing,
};

/// The port-added focus-ring hue for a colored theme: the brand hue at **full
/// opacity**, with its oklch lightness clamped to [_focusRingMaxL] in light
/// mode.
///
/// The source's `--ring` is the brand hue at 0.5 / 0.55 alpha, which composites
/// to 1.5-2.5:1 on `--background` in light mode (and 2.55-3.90:1 in dark) —
/// under WCAG 2.2's 3:1 floor for a focus indicator on every light theme. Full
/// opacity clears 3:1 for eight of the ten hues; amber (2.30:1) and lime
/// (2.29:1) are too bright to clear it at *any* alpha, so the clamp darkens
/// those two only (74% → 60% and 72% → 60%, giving 3.97:1 and 3.64:1) while
/// preserving their chroma and hue. Dark mode needs no clamp — every dark brand
/// hue is 5.80:1 or better on `--background`.
const _focusRingMaxL = 60.0;

Col focusRingLight(double lPct, double c, double h) =>
    oklch(math.min(lPct, _focusRingMaxL), c, h);

final _brands = <Brand>[
  Brand(
    'Violet',
    oklch(55, 0.2, 290),
    _brand(
      oklch(55, 0.2, 290),
      oklch(99, 0, 0),
      oklch(55, 0.2, 290, a: 0.5),
      focusRingLight(55, 0.2, 290),
    ),
    _brand(
      oklch(72, 0.16, 290),
      oklch(15, 0, 0),
      oklch(72, 0.16, 290, a: 0.55),
      oklch(72, 0.16, 290),
    ),
  ),
  Brand(
    'Blue',
    oklch(55, 0.18, 255),
    _brand(
      oklch(55, 0.18, 255),
      oklch(99, 0, 0),
      oklch(55, 0.18, 255, a: 0.5),
      focusRingLight(55, 0.18, 255),
    ),
    _brand(
      oklch(70, 0.15, 255),
      oklch(15, 0, 0),
      oklch(70, 0.15, 255, a: 0.55),
      oklch(70, 0.15, 255),
    ),
  ),
  Brand(
    'Green',
    oklch(56, 0.14, 150),
    _brand(
      oklch(56, 0.14, 150),
      oklch(99, 0, 0),
      oklch(56, 0.14, 150, a: 0.5),
      focusRingLight(56, 0.14, 150),
    ),
    _brand(
      oklch(72, 0.15, 150),
      oklch(15, 0, 0),
      oklch(72, 0.15, 150, a: 0.55),
      oklch(72, 0.15, 150),
    ),
  ),
  Brand(
    'Amber',
    oklch(74, 0.15, 70),
    _brand(
      oklch(74, 0.15, 70),
      oklch(20, 0.02, 70),
      oklch(74, 0.15, 70, a: 0.5),
      focusRingLight(74, 0.15, 70), // clamped 74% → 60%
    ),
    _brand(
      oklch(80, 0.15, 75),
      oklch(18, 0.02, 75),
      oklch(80, 0.15, 75, a: 0.55),
      oklch(80, 0.15, 75),
    ),
  ),
  Brand(
    'Blood Orange',
    oklch(60, 0.19, 40),
    _brand(
      oklch(60, 0.19, 40),
      oklch(99, 0, 0),
      oklch(60, 0.19, 40, a: 0.5),
      focusRingLight(60, 0.19, 40),
    ),
    _brand(
      oklch(72, 0.17, 42),
      oklch(15, 0, 0),
      oklch(72, 0.17, 42, a: 0.55),
      oklch(72, 0.17, 42),
    ),
  ),
  Brand(
    'Rose',
    oklch(58, 0.2, 12),
    _brand(
      oklch(58, 0.2, 12),
      oklch(99, 0, 0),
      oklch(58, 0.2, 12, a: 0.5),
      focusRingLight(58, 0.2, 12),
    ),
    _brand(
      oklch(70, 0.17, 12),
      oklch(15, 0, 0),
      oklch(70, 0.17, 12, a: 0.55),
      oklch(70, 0.17, 12),
    ),
  ),
  Brand(
    'Red',
    oklch(55, 0.22, 25),
    _brand(
      oklch(55, 0.22, 25),
      oklch(99, 0, 0),
      oklch(55, 0.22, 25, a: 0.5),
      focusRingLight(55, 0.22, 25),
    ),
    _brand(
      oklch(68, 0.19, 25),
      oklch(15, 0, 0),
      oklch(68, 0.19, 25, a: 0.55),
      oklch(68, 0.19, 25),
    ),
  ),
  Brand(
    'Teal',
    oklch(55, 0.12, 185),
    _brand(
      oklch(55, 0.12, 185),
      oklch(99, 0, 0),
      oklch(55, 0.12, 185, a: 0.5),
      focusRingLight(55, 0.12, 185),
    ),
    _brand(
      oklch(72, 0.13, 185),
      oklch(15, 0, 0),
      oklch(72, 0.13, 185, a: 0.55),
      oklch(72, 0.13, 185),
    ),
  ),
  Brand(
    'Indigo',
    oklch(50, 0.2, 275),
    _brand(
      oklch(50, 0.2, 275),
      oklch(99, 0, 0),
      oklch(50, 0.2, 275, a: 0.5),
      focusRingLight(50, 0.2, 275),
    ),
    _brand(
      oklch(70, 0.16, 275),
      oklch(15, 0, 0),
      oklch(70, 0.16, 275, a: 0.55),
      oklch(70, 0.16, 275),
    ),
  ),
  Brand(
    'Lime',
    oklch(72, 0.18, 130),
    _brand(
      oklch(72, 0.18, 130),
      oklch(20, 0.04, 130),
      oklch(72, 0.18, 130, a: 0.5),
      focusRingLight(72, 0.18, 130), // clamped 72% → 60%
    ),
    _brand(
      oklch(80, 0.18, 130),
      oklch(18, 0.04, 130),
      oklch(80, 0.18, 130, a: 0.55),
      oklch(80, 0.18, 130),
    ),
  ),
];

// default/Mono swatch — a mid-gray, deliberately distinct from the near-black /
// near-white primaries so the picker dot reads (themes.ts THEMES.default).
final _monoSwatch = oklch(40, 0, 0);

// Semantic status colors (theme-css.ts `--success` / `--warning`). Defined once
// in `:root` with no `.dark` override, so they are brightness-independent —
// emitted as standalone consts, like the picker swatches. Read by input
// (success check) and feedback-widget.
final _success = oklch(70, 0.18, 155);
final _warning = oklch(78, 0.18, 75);

// Order of the 18 core + borderStrong + focusRing fields, for emitting base
// consts.
const _fieldOrder = <String>[
  'background',
  'foreground',
  'card',
  'cardForeground',
  'popover',
  'popoverForeground',
  'primary',
  'primaryForeground',
  'secondary',
  'secondaryForeground',
  'muted',
  'mutedForeground',
  'accent',
  'accentForeground',
  'destructive',
  'border',
  'input',
  'ring',
  'borderStrong',
  'focusRing',
];

// ---------------------------------------------------------------------------
// Emit
// ---------------------------------------------------------------------------

final _out = StringBuffer();

void _line([String s = '']) => _out.writeln(s);

void _colConst(String name, Col c) =>
    _line('const Color $name = ${c.literal}; // ${c.source}');

void _baseColors(String prefix, Map<String, Col> map) {
  for (final field in _fieldOrder) {
    final cap = field[0].toUpperCase() + field.substring(1);
    _colConst('_$prefix$cap', map[field]!);
  }
}

void _glassConst(String name, Map<String, Col> g) {
  _line('const BeuiGlass $name = BeuiGlass(');
  _line('  bg: ${g['bg']!.literal}, // ${g['bg']!.source}');
  _line('  border: ${g['border']!.literal}, // ${g['border']!.source}');
  _line(');');
}

void _brandConst(String name, Map<String, Col> b) {
  _line('const _Brand $name = _Brand(');
  for (final k in [
    'primary',
    'primaryForeground',
    'accent',
    'accentForeground',
    'ring',
    'focusRing',
  ]) {
    _line('  $k: ${b[k]!.literal}, // ${b[k]!.source}');
  }
  _line(');');
}

void main() {
  _line('// GENERATED CODE — do not modify by hand.');
  _line(
    '// Run `dart run tool/generate_colors.dart` to regenerate, then review',
  );
  _line('// the diff. Source: starc007/ui-components (lib/themes.ts +');
  _line('// lib/theme-css.ts). oklch values are precomputed to sRGB here; raw');
  _line(
    '// hex / rgb() literals pass through unchanged. See tool/generate_colors.dart.',
  );
  _line('//');
  _line('// ignore_for_file: lines_longer_than_80_chars');
  _line();
  _line("part of 'beui_colors.dart';");
  _line();

  _line('// ── Neutral base — light ─────────────────────────────────────────');
  _baseColors('l', _light);
  _glassConst('_glassLight', _lightGlass);
  _line();

  _line('// ── Neutral base — dark ──────────────────────────────────────────');
  _baseColors('d', _dark);
  _glassConst('_glassDark', _darkGlass);
  _line();

  _line(
    '// ── Brand overrides (colored themes start from the neutral base) ──',
  );
  for (final brand in _brands) {
    final cap = brand.name.replaceAll(' ', '');
    final id = cap[0].toLowerCase() + cap.substring(1);
    _brandConst('_${id}Light', brand.light);
    _brandConst('_${id}Dark', brand.dark);
  }
  _line();

  _line('// ── Semantic status (brightness-independent) ─────────────────────');
  _colConst('_success', _success);
  _colConst('_warning', _warning);
  _line();

  _line(
    '// ── Picker swatches (brightness-independent) ──────────────────────',
  );
  _colConst('_monoSwatch', _monoSwatch);
  for (final brand in _brands) {
    final cap = brand.name.replaceAll(' ', '');
    final id = cap[0].toLowerCase() + cap.substring(1);
    _colConst('_${id}Swatch', brand.swatch);
  }

  // ignore: avoid_print
  print(_out.toString().trimRight());
}
