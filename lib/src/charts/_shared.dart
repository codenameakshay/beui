/// Shared chart primitives — color parse, formatters, legend, spring helpers.
///
/// Chart widgets live in `lib/src/charts/` and import motor types only through
/// `lib/src/motion/_engine.dart`. Colors come from [BeuiColors.resolve].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/_engine.dart';
import '../motion/number_ticker.dart';
import '../motion/tooltip.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';

/// Default tile / series palette (source `TREEMAP_COLORS` / chart defaults).
const beuiChartPalette = <Color>[
  Color(0xFF1D4ED8),
  Color(0xFF7C3AED),
  Color(0xFF0F766E),
  Color(0xFFB45309),
  Color(0xFFBE123C),
  Color(0xFF475569),
];

/// Bump-chart series palette (source `BUMP_COLORS`).
const beuiBumpPalette = <Color>[
  Color(0xFF8B5CF6),
  Color(0xFF0D9488),
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFFF43F5E),
  Color(0xFFA3A33A),
];

/// Parses chart CSS colors, including hex, RGB/HSL, named colors, and the
/// chart theme's supported `var(--token)` aliases.
///
/// CSS expressions requiring a browser style context (for example `var()`
/// fallbacks, `color()`, `color-mix()`, and relative colors) cannot be resolved
/// here and use [fallback] (or the primary theme color). `currentColor` maps
/// to the chart foreground token because this API has no DOM inheritance tree.
Color beuiChartColor(String? css, BeuiColors colors, {Color? fallback}) {
  if (css == null || css.isEmpty) return fallback ?? colors.primary;
  final trimmed = css.trim();
  if (trimmed.startsWith('var(')) {
    return switch (trimmed) {
      'var(--muted-foreground)' => colors.mutedForeground,
      'var(--foreground)' => colors.foreground,
      'var(--background)' => colors.background,
      'var(--muted)' => colors.muted,
      'var(--border)' => colors.border,
      'var(--primary)' => colors.primary,
      'var(--accent)' => colors.accent,
      'var(--success)' => colors.success,
      'var(--warning)' => colors.warning,
      'var(--destructive)' => colors.destructive,
      _ => fallback ?? colors.primary,
    };
  }
  final lower = trimmed.toLowerCase();
  if (lower == 'currentcolor') return colors.foreground;
  if (lower == 'transparent') return const Color(0x00000000);
  return _parseHex(trimmed) ??
      _parseRgb(trimmed) ??
      _parseHsl(trimmed) ??
      (_cssNamedColors[lower] == null
          ? null
          : Color(0xFF000000 | _cssNamedColors[lower]!)) ??
      fallback ??
      colors.primary;
}

Color? _parseHex(String css) {
  var hex = css;
  final hasCssPrefix = hex.startsWith('#');
  if (hasCssPrefix) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  } else if (hasCssPrefix && hex.length == 4) {
    // CSS #RGBA stores alpha last, while Flutter Color stores it first.
    hex =
        '${hex[3]}${hex[3]}${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  } else if (hasCssPrefix && hex.length == 8) {
    hex = '${hex.substring(6)}${hex.substring(0, 6)}';
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}

Color? _parseRgb(String css) {
  final match = RegExp(
    r'^rgba?\((.*)\)$',
    caseSensitive: false,
  ).firstMatch(css.trim());
  if (match == null) return null;
  final parts = _splitCssComponents(match.group(1)!);
  if (parts == null || (parts.length != 3 && parts.length != 4)) return null;
  final channels = <int>[];
  for (final part in parts.take(3)) {
    final value = _cssNumber(part);
    if (value == null) return null;
    final channel = part.trim().endsWith('%') ? value * 255 / 100 : value;
    channels.add(channel.clamp(0, 255).round());
  }
  final alpha = parts.length == 4 ? _cssAlpha(parts[3]) : 1.0;
  if (alpha == null) return null;
  return Color.fromARGB(
    (alpha * 255).round().clamp(0, 255),
    channels[0],
    channels[1],
    channels[2],
  );
}

Color? _parseHsl(String css) {
  final match = RegExp(
    r'^hsla?\((.*)\)$',
    caseSensitive: false,
  ).firstMatch(css.trim());
  if (match == null) return null;
  final parts = _splitCssComponents(match.group(1)!);
  if (parts == null || (parts.length != 3 && parts.length != 4)) return null;
  final hue = _parseHue(parts[0]);
  final saturation = _cssPercent(parts[1]);
  final lightness = _cssPercent(parts[2]);
  final alpha = parts.length == 4 ? _cssAlpha(parts[3]) : 1.0;
  if (hue == null || saturation == null || lightness == null || alpha == null) {
    return null;
  }
  final h = ((hue % 360) + 360) % 360 / 360;
  final s = saturation.clamp(0, 1);
  final l = lightness.clamp(0, 1);
  final chroma = (1 - (2 * l - 1).abs()) * s;
  final x = chroma * (1 - ((h * 6) % 2 - 1).abs());
  final m = l - chroma / 2;
  final rgb = switch ((h * 6).floor()) {
    0 => (chroma, x, 0.0),
    1 => (x, chroma, 0.0),
    2 => (0.0, chroma, x),
    3 => (0.0, x, chroma),
    4 => (x, 0.0, chroma),
    _ => (chroma, 0.0, x),
  };
  return Color.fromARGB(
    (alpha * 255).round().clamp(0, 255),
    ((rgb.$1 + m) * 255).round().clamp(0, 255),
    ((rgb.$2 + m) * 255).round().clamp(0, 255),
    ((rgb.$3 + m) * 255).round().clamp(0, 255),
  );
}

List<String>? _splitCssComponents(String body) {
  final source = body.trim();
  if (source.isEmpty) return null;
  if (source.contains(',')) {
    if (source.contains('/')) return null;
    final result = source.split(',').map((part) => part.trim()).toList();
    return result.any((part) => part.isEmpty) ? null : result;
  }
  final slashParts = source.split('/');
  if (slashParts.length > 2) return null;
  final channels = slashParts.first.trim().split(RegExp(r'\s+'));
  if (slashParts.length == 1) return channels;
  final alpha = slashParts[1].trim();
  if (alpha.isEmpty || alpha.contains(RegExp(r'\s'))) return null;
  return [...channels, alpha];
}

double? _cssNumber(String input) {
  final value = input.trim();
  if (!RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)%?$').hasMatch(value)) {
    return null;
  }
  final number = double.tryParse(value.replaceFirst('%', ''));
  return number != null && number.isFinite ? number : null;
}

double? _cssPercent(String input) {
  final value = input.trim();
  if (!value.endsWith('%')) return null;
  final number = _cssNumber(value);
  return number == null ? null : number / 100;
}

double? _cssAlpha(String input) {
  final value = input.trim();
  final number = _cssNumber(value);
  if (number == null) return null;
  return (value.endsWith('%') ? number / 100 : number).clamp(0, 1);
}

double? _parseHue(String input) {
  final value = input.trim().toLowerCase();
  final match = RegExp(
    r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+))(deg|grad|rad|turn)?$',
  ).firstMatch(value);
  if (match == null) return null;
  final number = double.tryParse(match.group(1)!);
  if (number == null || !number.isFinite) return null;
  final degrees = switch (match.group(2)) {
    'turn' => number * 360,
    'grad' => number * 0.9,
    'rad' => number * 180 / 3.141592653589793,
    _ => number,
  };
  return degrees.isFinite ? degrees : null;
}

// CSS Color 4's 148 opaque named colors, encoded as RGB hex values.
const _cssNamedColors = <String, int>{
  'aliceblue': 0xF0F8FF,
  'antiquewhite': 0xFAEBD7,
  'aqua': 0x00FFFF,
  'aquamarine': 0x7FFFD4,
  'azure': 0xF0FFFF,
  'beige': 0xF5F5DC,
  'bisque': 0xFFE4C4,
  'black': 0x000000,
  'blanchedalmond': 0xFFEBCD,
  'blue': 0x0000FF,
  'blueviolet': 0x8A2BE2,
  'brown': 0xA52A2A,
  'burlywood': 0xDEB887,
  'cadetblue': 0x5F9EA0,
  'chartreuse': 0x7FFF00,
  'chocolate': 0xD2691E,
  'coral': 0xFF7F50,
  'cornflowerblue': 0x6495ED,
  'cornsilk': 0xFFF8DC,
  'crimson': 0xDC143C,
  'cyan': 0x00FFFF,
  'darkblue': 0x00008B,
  'darkcyan': 0x008B8B,
  'darkgoldenrod': 0xB8860B,
  'darkgray': 0xA9A9A9,
  'darkgreen': 0x006400,
  'darkgrey': 0xA9A9A9,
  'darkkhaki': 0xBDB76B,
  'darkmagenta': 0x8B008B,
  'darkolivegreen': 0x556B2F,
  'darkorange': 0xFF8C00,
  'darkorchid': 0x9932CC,
  'darkred': 0x8B0000,
  'darksalmon': 0xE9967A,
  'darkseagreen': 0x8FBC8F,
  'darkslateblue': 0x483D8B,
  'darkslategray': 0x2F4F4F,
  'darkslategrey': 0x2F4F4F,
  'darkturquoise': 0x00CED1,
  'darkviolet': 0x9400D3,
  'deeppink': 0xFF1493,
  'deepskyblue': 0x00BFFF,
  'dimgray': 0x696969,
  'dimgrey': 0x696969,
  'dodgerblue': 0x1E90FF,
  'firebrick': 0xB22222,
  'floralwhite': 0xFFFAF0,
  'forestgreen': 0x228B22,
  'fuchsia': 0xFF00FF,
  'gainsboro': 0xDCDCDC,
  'ghostwhite': 0xF8F8FF,
  'gold': 0xFFD700,
  'goldenrod': 0xDAA520,
  'gray': 0x808080,
  'green': 0x008000,
  'greenyellow': 0xADFF2F,
  'grey': 0x808080,
  'honeydew': 0xF0FFF0,
  'hotpink': 0xFF69B4,
  'indianred': 0xCD5C5C,
  'indigo': 0x4B0082,
  'ivory': 0xFFFFF0,
  'khaki': 0xF0E68C,
  'lavender': 0xE6E6FA,
  'lavenderblush': 0xFFF0F5,
  'lawngreen': 0x7CFC00,
  'lemonchiffon': 0xFFFACD,
  'lightblue': 0xADD8E6,
  'lightcoral': 0xF08080,
  'lightcyan': 0xE0FFFF,
  'lightgoldenrodyellow': 0xFAFAD2,
  'lightgray': 0xD3D3D3,
  'lightgreen': 0x90EE90,
  'lightgrey': 0xD3D3D3,
  'lightpink': 0xFFB6C1,
  'lightsalmon': 0xFFA07A,
  'lightseagreen': 0x20B2AA,
  'lightskyblue': 0x87CEFA,
  'lightslategray': 0x778899,
  'lightslategrey': 0x778899,
  'lightsteelblue': 0xB0C4DE,
  'lightyellow': 0xFFFFE0,
  'lime': 0x00FF00,
  'limegreen': 0x32CD32,
  'linen': 0xFAF0E6,
  'magenta': 0xFF00FF,
  'maroon': 0x800000,
  'mediumaquamarine': 0x66CDAA,
  'mediumblue': 0x0000CD,
  'mediumorchid': 0xBA55D3,
  'mediumpurple': 0x9370DB,
  'mediumseagreen': 0x3CB371,
  'mediumslateblue': 0x7B68EE,
  'mediumspringgreen': 0x00FA9A,
  'mediumturquoise': 0x48D1CC,
  'mediumvioletred': 0xC71585,
  'midnightblue': 0x191970,
  'mintcream': 0xF5FFFA,
  'mistyrose': 0xFFE4E1,
  'moccasin': 0xFFE4B5,
  'navajowhite': 0xFFDEAD,
  'navy': 0x000080,
  'oldlace': 0xFDF5E6,
  'olive': 0x808000,
  'olivedrab': 0x6B8E23,
  'orange': 0xFFA500,
  'orangered': 0xFF4500,
  'orchid': 0xDA70D6,
  'palegoldenrod': 0xEEE8AA,
  'palegreen': 0x98FB98,
  'paleturquoise': 0xAFEEEE,
  'palevioletred': 0xDB7093,
  'papayawhip': 0xFFEFD5,
  'peachpuff': 0xFFDAB9,
  'peru': 0xCD853F,
  'pink': 0xFFC0CB,
  'plum': 0xDDA0DD,
  'powderblue': 0xB0E0E6,
  'purple': 0x800080,
  'rebeccapurple': 0x663399,
  'red': 0xFF0000,
  'rosybrown': 0xBC8F8F,
  'royalblue': 0x4169E1,
  'saddlebrown': 0x8B4513,
  'salmon': 0xFA8072,
  'sandybrown': 0xF4A460,
  'seagreen': 0x2E8B57,
  'seashell': 0xFFF5EE,
  'sienna': 0xA0522D,
  'silver': 0xC0C0C0,
  'skyblue': 0x87CEEB,
  'slateblue': 0x6A5ACD,
  'slategray': 0x708090,
  'slategrey': 0x708090,
  'snow': 0xFFFAFA,
  'springgreen': 0x00FF7F,
  'steelblue': 0x4682B4,
  'tan': 0xD2B48C,
  'teal': 0x008080,
  'thistle': 0xD8BFD8,
  'tomato': 0xFF6347,
  'turquoise': 0x40E0D0,
  'violet': 0xEE82EE,
  'wheat': 0xF5DEB3,
  'white': 0xFFFFFF,
  'whitesmoke': 0xF5F5F5,
  'yellow': 0xFFFF00,
  'yellowgreen': 0x9ACD32,
};

/// Locale-free integer/decimal grouping matching `toLocaleString('en-US')`.
String beuiChartFormatNumber(
  num value, {
  int maximumFractionDigits = 0,
  int minimumFractionDigits = 0,
  bool compact = false,
}) {
  final special = _formatNonFinite(value);
  if (special != null) return special;
  final maximum = maximumFractionDigits.clamp(0, 20);
  final minimum = minimumFractionDigits.clamp(0, maximum);
  if (compact) {
    // The pre-existing compact helper always used one fractional digit. Keep
    // that contract when callers omit precision (the default is zero for the
    // non-compact formatter), while allowing a non-zero max to tune it.
    return _compact(value, maximumFractionDigits: maximum == 0 ? 1 : maximum);
  }
  final sign = value.isNegative ? '-' : '';
  final abs = value.abs();
  final rounded = _roundDecimal(abs, maximum);
  final digits = rounded.toString().padLeft(maximum + 1, '0');
  final whole = maximum == 0
      ? digits
      : digits.substring(0, digits.length - maximum);
  var fraction = maximum == 0 ? '' : digits.substring(digits.length - maximum);
  while (fraction.length > minimum && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '$sign${_group(whole)}${fraction.isEmpty ? '' : '.$fraction'}';
}

String? _formatNonFinite(num value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  return null;
}

String _compact(num value, {required int maximumFractionDigits}) {
  final abs = value.abs();
  final sign = value.isNegative ? '-' : '';
  const scales = <({int exponent, String suffix})>[
    (exponent: 3, suffix: 'K'),
    (exponent: 6, suffix: 'M'),
    (exponent: 9, suffix: 'B'),
    (exponent: 12, suffix: 'T'),
  ];
  var scaleIndex = -1;
  for (var index = 0; index < scales.length; index++) {
    if (abs >= _pow10Double(scales[index].exponent)) scaleIndex = index;
  }

  // Round the source decimal representation after moving its decimal point;
  // dividing a large double by a scale first can lose a boundary digit.
  var scaleExponent = scaleIndex < 0 ? 0 : scales[scaleIndex].exponent;
  var rounded = _roundDecimal(
    abs,
    maximumFractionDigits,
    scaleExponent: -scaleExponent,
  );
  final promotionThreshold =
      BigInt.from(1000) * BigInt.from(10).pow(maximumFractionDigits);
  if (scaleIndex < 0 && rounded >= promotionThreshold) {
    scaleIndex = 0;
    scaleExponent = scales[scaleIndex].exponent;
    rounded = _roundDecimal(
      abs,
      maximumFractionDigits,
      scaleExponent: -scaleExponent,
    );
  } else if (scaleIndex >= 0 &&
      rounded >= promotionThreshold &&
      scaleIndex + 1 < scales.length) {
    scaleIndex++;
    scaleExponent = scales[scaleIndex].exponent;
    rounded = _roundDecimal(
      abs,
      maximumFractionDigits,
      scaleExponent: -scaleExponent,
    );
  }
  final digits = rounded.toString().padLeft(maximumFractionDigits + 1, '0');
  final whole = maximumFractionDigits == 0
      ? digits
      : digits.substring(0, digits.length - maximumFractionDigits);
  var fraction = maximumFractionDigits == 0
      ? ''
      : digits.substring(digits.length - maximumFractionDigits);
  while (fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  final suffix = scaleIndex < 0 ? '' : scales[scaleIndex].suffix;
  // ICU compact formatting leaves a four-digit mantissa such as 1000T
  // ungrouped, but groups longer mantissas (for example 10,000T).
  final groupedWhole = whole.length > 4 ? _group(whole) : whole;
  return '$sign$groupedWhole${fraction.isEmpty ? '' : '.$fraction'}$suffix';
}

BigInt _roundDecimal(num value, int fractionDigits, {int scaleExponent = 0}) {
  final text = value.toString().toLowerCase();
  final parts = text.split('e');
  final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
  final decimal = parts.first;
  final point = decimal.indexOf('.');
  final decimalDigits = point < 0 ? 0 : decimal.length - point - 1;
  final digits = decimal.replaceAll('.', '');
  final integer = BigInt.parse(digits);
  final shift = fractionDigits + exponent + scaleExponent - decimalDigits;
  if (shift >= 0) return integer * BigInt.from(10).pow(shift);
  final divisor = BigInt.from(10).pow(-shift);
  final quotient = integer ~/ divisor;
  final remainder = integer % divisor;
  return quotient +
      (remainder * BigInt.two >= divisor ? BigInt.one : BigInt.zero);
}

double _pow10Double(int n) => BigInt.from(10).pow(n).toDouble();

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Share of a total as `12.4%`.
String beuiChartPercent(num share, {int digits = 1}) {
  return '${(share * 100).toStringAsFixed(digits)}%';
}

/// Signed percent with a true minus (`−`) matching source `signed()`.
String beuiChartSignedPercent(num value, {int digits = 1}) {
  final mag = value.abs().toStringAsFixed(digits);
  return value >= 0 ? '+$mag%' : '−$mag%';
}

/// Tooltip placement, matching the source `side` union.
enum BeuiChartTooltipSide {
  /// Above the trigger (default).
  top,

  /// To the right.
  right,

  /// Below.
  bottom,

  /// To the left.
  left,
}

/// Maps [BeuiChartTooltipSide] onto [BeuiTooltipSide].
BeuiTooltipSide beuiChartToTooltipSide(BeuiChartTooltipSide side) =>
    switch (side) {
      BeuiChartTooltipSide.top => BeuiTooltipSide.top,
      BeuiChartTooltipSide.right => BeuiTooltipSide.right,
      BeuiChartTooltipSide.bottom => BeuiTooltipSide.bottom,
      BeuiChartTooltipSide.left => BeuiTooltipSide.left,
    };

/// A compact color swatch used by chart legends.
class BeuiChartSwatch extends StatelessWidget {
  /// Creates a 6×6 circular swatch (source `size-1.5 rounded-full`).
  const BeuiChartSwatch({
    required this.color,
    super.key,
    this.size = 6,
    this.circular = true,
  });

  /// Fill color.
  final Color color;

  /// Square size.
  final double size;

  /// When true, paints a circle; otherwise a 2px-radius square.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(2),
      ),
    );
  }
}

/// Horizontal wrap of legend items. Each child is typically a button.
class BeuiChartLegend extends StatelessWidget {
  /// Creates a wrapping legend row.
  const BeuiChartLegend({required this.children, super.key, this.spacing = 16});

  /// Legend entries.
  final List<Widget> children;

  /// Gap between items.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// A single legend entry: swatch + label (+ optional trailing value).
class BeuiChartLegendItem extends StatelessWidget {
  /// Creates a legend item. When [onPressed] is set it is a button.
  const BeuiChartLegendItem({
    required this.color,
    required this.label,
    super.key,
    this.value,
    this.selected = false,
    this.dimmed = false,
    this.onPressed,
    this.onHover,
  });

  /// Swatch color.
  final Color color;

  /// Name.
  final String label;

  /// Optional trailing value.
  final String? value;

  /// Pressed / pinned.
  final bool selected;

  /// De-emphasize when another series is pinned.
  final bool dimmed;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Hover enter/exit. `true` on enter.
  final ValueChanged<bool>? onHover;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final style = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      color: dimmed
          ? colors.mutedForeground.withValues(alpha: 0.55)
          : colors.foreground,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BeuiChartSwatch(color: color.withValues(alpha: dimmed ? 0.4 : 1)),
        const SizedBox(width: 6),
        Text(label, style: style),
        if (value != null) ...[
          const SizedBox(width: 6),
          Text(value!, style: style.copyWith(color: colors.mutedForeground)),
        ],
      ],
    );
    Widget child = row;
    if (onPressed != null) {
      child = Semantics(
        button: true,
        selected: selected,
        label: label,
        child: MouseRegion(
          onEnter: onHover == null ? null : (_) => onHover!(true),
          onExit: onHover == null ? null : (_) => onHover!(false),
          child: GestureDetector(
            onTap: onPressed,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: row,
            ),
          ),
        ),
      );
    }
    return Opacity(opacity: dimmed ? 0.55 : 1, child: child);
  }
}

/// Springs [value] on [beuiSpringLayout]. Reduced motion snaps to the target.
class BeuiChartSpring extends StatelessWidget {
  /// Creates a 1D spring toward [value].
  const BeuiChartSpring({
    required this.value,
    required this.builder,
    super.key,
  });

  /// Target.
  final double value;

  /// Builds from the animated (or snapped) value.
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    if (motion is NoMotion) return builder(context, value);
    return SingleMotionBuilder(
      value: value,
      motion: motion,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Source-timed chart entrance or emphasis. The delay runs only on mount.
class BeuiChartTween extends StatefulWidget {
  /// Animates a scalar using the source ease-out curve.
  const BeuiChartTween({
    required this.value,
    required this.duration,
    required this.builder,
    this.from,
    this.delay = Duration.zero,
    this.isMovement = false,
    this.snapWhenReduced = false,
    this.motion,
    super.key,
  });

  final double value;
  final double? from;
  final Duration duration;
  final Duration delay;
  final bool isMovement;
  final bool snapWhenReduced;
  final Motion? motion;
  final Widget Function(BuildContext, double) builder;

  @override
  State<BeuiChartTween> createState() => _BeuiChartTweenState();
}

class _BeuiChartTweenState extends State<BeuiChartTween> {
  Timer? _timer;
  late bool _ready;

  @override
  void initState() {
    super.initState();
    _ready = widget.delay == Duration.zero;
    if (!_ready) {
      _timer = Timer(widget.delay, () => setState(() => _ready = true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && (widget.isMovement || widget.snapWhenReduced)) {
      return widget.builder(context, widget.value);
    }
    return SingleMotionBuilder(
      from: widget.from,
      value: _ready || reduce ? widget.value : widget.from ?? widget.value,
      motion: widget.motion ?? CurvedMotion(widget.duration, beuiEaseOut),
      builder: (context, value, _) => widget.builder(context, value),
    );
  }
}

/// Springs a [Rect] on [beuiSpringLayout]. Reduced motion snaps to the target.
class BeuiChartSpringRect extends StatelessWidget {
  /// Creates a rect spring toward [value].
  const BeuiChartSpringRect({
    required this.value,
    required this.builder,
    super.key,
  });

  /// Target rect.
  final Rect value;

  /// Builds from the animated (or snapped) rect.
  final Widget Function(BuildContext context, Rect rect) builder;

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    if (motion is NoMotion) return builder(context, value);
    return MotionBuilder<Rect>(
      value: value,
      motion: motion,
      converter: const RectMotionConverter(),
      builder: (context, rect, _) => builder(context, rect),
    );
  }
}

/// Opacity-only fade (kept under reduced motion).
class BeuiChartFade extends StatelessWidget {
  /// Fades [child] to [opacity].
  const BeuiChartFade({required this.opacity, required this.child, super.key});

  /// Target opacity.
  final double opacity;

  /// Child.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(
      context,
      const CurvedMotion(Duration(milliseconds: 180), beuiEaseOut),
      isMovement: false,
    );
    return SingleMotionBuilder(
      value: opacity,
      motion: motion,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: child,
    );
  }
}

/// Chart tooltip / readout number — source `NumberTicker` with
/// `startOnView={false}`, `duration={0.2}`, `stagger={0}`.
///
/// [format] receives the live [value]. Its formatted digits animate, while
/// separators and other non-digit characters stay static.
class BeuiChartTicker extends StatelessWidget {
  /// Creates a short digit roll toward [value].
  const BeuiChartTicker({
    required this.value,
    required this.format,
    super.key,
    this.duration = const Duration(milliseconds: 200),
    this.style,
  });

  /// Numeric input. [format] receives this value without rounding.
  final num value;

  /// Display string. Its digits animate; other characters stay static.
  final String Function(num value) format;

  /// Roll duration (source tooltip default 0.2s).
  final Duration duration;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return BeuiNumberTicker(
      value: value,
      format: (_) => format(value),
      startOnView: false,
      duration: duration,
      stagger: Duration.zero,
      style: style,
    );
  }
}

/// Tooltip surface used by charts that need a custom body. Built on
/// [BeuiTooltip] so it shares the overlay, spring, and reduced-motion path.
class BeuiChartTooltip extends StatefulWidget {
  /// Wraps [child] with [content].
  const BeuiChartTooltip({
    required this.content,
    required this.child,
    super.key,
    this.side = BeuiChartTooltipSide.top,
    this.enabled = true,
    this.open,
    this.onOpenChange,
    this.followCursor = false,
  });

  /// Tooltip body.
  final Widget content;

  /// Trigger.
  final Widget child;

  /// Placement.
  final BeuiChartTooltipSide side;

  /// When false, renders [child] only.
  final bool enabled;

  /// Chart-owned inspection visibility. Focus and pointer state are fallbacks.
  final bool? open;
  final ValueChanged<bool>? onOpenChange;
  final bool followCursor;

  @override
  State<BeuiChartTooltip> createState() => _BeuiChartTooltipState();
}

class _BeuiChartTooltipState extends State<BeuiChartTooltip> {
  final _anchor = GlobalKey();
  final _anchorLink = LayerLink();
  bool _open = false;
  Offset? _pointer;
  bool _keyboard = false;
  void _setOpen(bool open) {
    if (_open != open) setState(() => _open = open);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final cursorAnchor = widget.followCursor && !_keyboard && _pointer != null;
    final target = CompositedTransformTarget(
      key: _anchor,
      link: _anchorLink,
      child: const SizedBox.expand(),
    );
    return MouseRegion(
      onEnter: (event) {
        if (widget.followCursor) {
          setState(() {
            _pointer = event.localPosition;
            _keyboard = false;
          });
        }
        _setOpen(true);
      },
      onHover: (event) {
        if (widget.followCursor) {
          setState(() {
            _pointer = event.localPosition;
            _keyboard = false;
          });
        }
      },
      onExit: (_) => _setOpen(false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          if (focused) _keyboard = true;
          _setOpen(focused);
        },
        onKeyEvent: (_, event) {
          _keyboard = true;
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _setOpen(false);
            widget.onOpenChange?.call(false);
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned(
              left: cursorAnchor ? _pointer!.dx : 0,
              top: cursorAnchor ? _pointer!.dy : 0,
              right: cursorAnchor ? null : 0,
              bottom: cursorAnchor ? null : 0,
              width: cursorAnchor ? 1 : null,
              height: cursorAnchor ? 1 : null,
              child: IgnorePointer(child: target),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: BeuiTooltip(
                content: widget.content,
                side: beuiChartToTooltipSide(widget.side),
                open: widget.open ?? _open,
                delay: Duration.zero,
                followCursor: widget.followCursor,
                externalAnchor: _anchor,
                anchorLink: _anchorLink,
                onOpenChange: (open) {
                  if (!open) {
                    _setOpen(false);
                    widget.onOpenChange?.call(false);
                  }
                },
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard tooltip card: title + muted lines.
class BeuiChartTooltipCard extends StatelessWidget {
  /// Creates a compact tooltip card.
  const BeuiChartTooltipCard({
    required this.title,
    super.key,
    this.titleWidget,
    this.lines = const [],
    this.details,
    this.swatch,
  });

  /// Headline.
  final String title;

  /// Optional headline widget (e.g. a [BeuiChartTicker]). Overrides [title]
  /// visually; [title] stays the accessible name.
  final Widget? titleWidget;

  /// Extra rows as static text.
  final List<String> lines;

  /// Extra rows as widgets. When non-null, [lines] are not painted.
  final List<Widget>? details;

  /// Optional leading swatch.
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final muted = TextStyle(
      fontSize: 11,
      height: 16 / 11,
      color: colors.mutedForeground,
    );
    final rows =
        details ?? [for (final line in lines) Text(line, style: muted)];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (swatch != null) ...[
                BeuiChartSwatch(color: swatch!),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.popoverForeground,
                  ),
                  child: Semantics(
                    label: title,
                    excludeSemantics: true,
                    child:
                        titleWidget ??
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.popoverForeground,
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: DefaultTextStyle.merge(style: muted, child: row),
            ),
        ],
      ),
    );
  }
}

/// Column of chart parts with an accessible name. Default `space-y-3/4`.
class BeuiChartFrame extends StatelessWidget {
  /// Creates a labeled chart frame.
  const BeuiChartFrame({required this.label, required this.child, super.key});

  /// Accessible name.
  final String label;

  /// Plot / legend / tooltip stack.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: child,
    );
  }
}

/// Keyboard inspector over a 1D list of ids (period / bin / candle).
///
/// Arrow keys move, Home/End jump, Escape clears. Used by charts whose source
/// inspection is a range input or a slider role.
mixin BeuiChartInspectorKeys {
  /// Currently highlighted id.
  String? get activeId;

  /// Ordered identities.
  List<String> get inspectableIds;

  /// Apply a new id (or null to clear).
  void setActiveId(String? id);

  /// Handle a key. Returns true when consumed.
  bool handleInspectorKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final ids = inspectableIds;
    if (ids.isEmpty) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (activeId == null) return false;
      setActiveId(null);
      return true;
    }
    if (key == LogicalKeyboardKey.home) {
      setActiveId(ids.first);
      return true;
    }
    if (key == LogicalKeyboardKey.end) {
      setActiveId(ids.last);
      return true;
    }
    final step = switch (key) {
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (step == 0) return false;
    final current = activeId == null ? -1 : ids.indexOf(activeId!);
    final nextIndex = current < 0
        ? (step > 0 ? 0 : ids.length - 1)
        : (current + step).clamp(0, ids.length - 1);
    setActiveId(ids[nextIndex]);
    return true;
  }
}

/// Mixes a controlled/uncontrolled `String?` active id into a [State].
mixin BeuiChartActiveState<T extends StatefulWidget> on State<T> {
  String? _internal;

  /// Controlled value, or null when uncontrolled.
  String? get widgetActiveId;

  /// Uncontrolled seed.
  String? get widgetDefaultActiveId;

  /// Change callback.
  ValueChanged<String?>? get widgetOnActiveChange;

  /// Known identities; a stale id is treated as null.
  Iterable<String> get knownIds;

  /// Resolved active id.
  String? get activeId {
    final requested = widgetActiveId ?? _internal;
    if (requested == null) return null;
    for (final id in knownIds) {
      if (id == requested) return requested;
    }
    return null;
  }

  /// Seed internal state.
  void initActive() => _internal = widgetDefaultActiveId;

  /// Apply a new id.
  void setActiveId(String? id) {
    final previous = activeId;
    if (widgetActiveId == null && _internal != id) {
      setState(() => _internal = id);
    }
    if (previous != id) widgetOnActiveChange?.call(id);
  }
}
