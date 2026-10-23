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

/// Parses a source CSS color: hex (`#rgb` / `#rrggbb` / `#rrggbbaa`) or a
/// handful of `var(--token)` aliases the chart family actually uses.
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
  return _parseHex(trimmed) ?? fallback ?? colors.primary;
}

Color? _parseHex(String css) {
  var hex = css;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// Locale-free integer/decimal grouping matching `toLocaleString('en-US')`.
String beuiChartFormatNumber(
  num value, {
  int maximumFractionDigits = 0,
  bool compact = false,
}) {
  if (compact) return _compact(value);
  final sign = value.isNegative ? '-' : '';
  final abs = value.abs();
  if (maximumFractionDigits <= 0) {
    return '$sign${_group(abs.round().toString())}';
  }
  final factor = _pow10(maximumFractionDigits);
  final scaled = (abs * factor).round();
  final whole = scaled ~/ factor;
  final frac = (scaled % factor).toString().padLeft(maximumFractionDigits, '0');
  return '$sign${_group(whole.toString())}.$frac';
}

String _compact(num value) {
  final abs = value.abs();
  final sign = value.isNegative ? '-' : '';
  if (abs >= 1e9) return '$sign${(abs / 1e9).toStringAsFixed(1)}B';
  if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(1)}M';
  if (abs >= 1e3) return '$sign${(abs / 1e3).toStringAsFixed(1)}K';
  return '$sign${abs.round()}';
}

int _pow10(int n) {
  var v = 1;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}

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
