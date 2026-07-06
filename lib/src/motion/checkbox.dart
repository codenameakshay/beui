import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Optional style overrides for [BeuiCheckbox]. Null fields resolve from the
/// ambient [BeuiColors] theme extension (or sensible defaults).
@immutable
class BeuiCheckboxStyle {
  /// Creates a set of [BeuiCheckbox] overrides.
  const BeuiCheckboxStyle({
    this.fillColor,
    this.markColor,
    this.borderColor,
    this.size,
    this.borderRadius,
  });

  /// Box fill + border when checked/indeterminate. Defaults to `BeuiColors.primary`.
  final Color? fillColor;

  /// Check/indeterminate stroke colour. Defaults to `BeuiColors.primaryForeground`.
  final Color? markColor;

  /// Border colour when unchecked. Defaults to `BeuiColors.mutedForeground` at 50% alpha.
  final Color? borderColor;

  /// Box edge length. Defaults to 20.
  final double? size;

  /// Corner radius. Defaults to 6.
  final double? borderRadius;

  /// Returns a copy with the given fields replaced.
  BeuiCheckboxStyle copyWith({
    Color? fillColor,
    Color? markColor,
    Color? borderColor,
    double? size,
    double? borderRadius,
  }) {
    return BeuiCheckboxStyle(
      fillColor: fillColor ?? this.fillColor,
      markColor: markColor ?? this.markColor,
      borderColor: borderColor ?? this.borderColor,
      size: size ?? this.size,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

/// A checkbox with an animated check/indeterminate draw — the Flutter port of
/// beUI's `checkbox`.
///
/// The mark strokes itself on (a `CustomPaint` path-draw), the box cross-fades
/// its colour over 200ms, and pressing scales the box (SPRING_PRESS). Supports
/// an [indeterminate] (mixed) state with its own bar mark.
///
/// **Controlled only** (matching the source and the `AGENTS.md` rule): pass
/// [value] and handle [onChanged]; there is no internal state.
///
/// Reduced motion makes the mark appear instantly (opacity only — no scale, no
/// path-draw) and drops the press scale, while the box colour transition is
/// kept.
class BeuiCheckbox extends StatefulWidget {
  /// Creates a checkbox. [value] and [onChanged] are required (controlled-only).
  const BeuiCheckbox({
    required this.value,
    required this.onChanged,
    this.indeterminate = false,
    this.enabled = true,
    this.label,
    this.style,
    super.key,
  });

  /// Whether the checkbox is checked.
  final bool value;

  /// Called with the toggled value when the user activates the checkbox.
  final ValueChanged<bool> onChanged;

  /// Whether to show the indeterminate (mixed) bar instead of a check. Mirrors
  /// the source's separate `indeterminate` prop; takes visual precedence over
  /// [value].
  final bool indeterminate;

  /// Whether the checkbox responds to input. Disabled is dimmed and unfocusable.
  final bool enabled;

  /// Optional label rendered after the box; tapping it toggles the checkbox.
  final String? label;

  /// Optional visual overrides.
  final BeuiCheckboxStyle? style;

  @override
  State<BeuiCheckbox> createState() => _BeuiCheckboxState();
}

class _BeuiCheckboxState extends State<BeuiCheckbox> {
  late final FocusNode _focusNode = FocusNode();
  bool _pressed = false;
  bool _focusVisible = false;
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final style = widget.style;

    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;
    final showMark = widget.value || widget.indeterminate;

    final size = style?.size ?? 20.0;
    final radius = style?.borderRadius ?? 6.0;
    final fill = style?.fillColor ?? colors.primary;
    final markColor = style?.markColor ?? colors.primaryForeground;
    final uncheckedBorder =
        style?.borderColor ?? colors.mutedForeground.withValues(alpha: 0.5);
    final borderColor = showMark
        ? fill
        : (_hovered && enabled ? colors.mutedForeground : uncheckedBorder);

    // Press scale uses SPRING_PRESS directly with a reduce-gated target: under
    // reduced motion the target stays 1 so there is no squish. (Routing this
    // through motionFor → NoMotion would freeze a press mid-squish, since
    // motor's NoMotion holds the source value — see BeuiSwitch.)
    final pressTarget = (_pressed && enabled && !reduce) ? 0.92 : 1.0;

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: showMark ? fill : colors.background,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: beuiEaseOut,
        switchOutCurve: beuiEaseOut,
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          if (reduce) return fade; // opacity only under reduced motion
          return ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1).animate(animation),
            child: fade,
          );
        },
        child: showMark
            ? _CheckMark(
                key: ValueKey(
                  widget.indeterminate ? 'indeterminate' : 'checked',
                ),
                indeterminate: widget.indeterminate,
                color: markColor,
                reduce: reduce,
                boxSize: size,
              )
            : SizedBox(key: const ValueKey('none'), width: size, height: size),
      ),
    );

    final ringed = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 4),
        boxShadow: _focusVisible
            ? [
                BoxShadow(color: colors.ring, spreadRadius: 4),
                BoxShadow(color: colors.background, spreadRadius: 2),
              ]
            : null,
      ),
      child: box,
    );

    final control = Listener(
      onPointerDown: (_) {
        if (enabled) setState(() => _pressed = true);
      },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: _focusNode,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: SingleMotionBuilder(
            value: pressTarget,
            motion: beuiSpringPress,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Opacity(opacity: enabled ? 1.0 : 0.6, child: ringed),
          ),
        ),
      ),
    );

    final Widget result = widget.label == null
        ? control
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              control,
              const SizedBox(width: 12),
              GestureDetector(
                onTap: enabled ? _toggle : null,
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: enabled ? 1.0 : 0.6,
                    child: Text(
                      widget.label!,
                      style: TextStyle(fontSize: 14, color: colors.foreground),
                    ),
                  ),
                ),
              ),
            ],
          );

    return MergeSemantics(
      child: Semantics(
        checked: widget.indeterminate ? null : widget.value,
        mixed: widget.indeterminate ? true : null,
        enabled: enabled,
        label: widget.label,
        child: result,
      ),
    );
  }
}

/// The check / indeterminate mark. Strokes itself on with a path-draw when
/// mounted (under [reduce], it appears fully drawn).
class _CheckMark extends StatefulWidget {
  const _CheckMark({
    required this.indeterminate,
    required this.color,
    required this.reduce,
    required this.boxSize,
    super.key,
  });

  final bool indeterminate;
  final Color color;
  final bool reduce;
  final double boxSize;

  @override
  State<_CheckMark> createState() => _CheckMarkState();
}

class _CheckMarkState extends State<_CheckMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _draw;

  @override
  void initState() {
    super.initState();
    // Source: indeterminate draw 0.2s, check 0.3s, EASE_OUT, +0.04s delay.
    final drawMs = widget.indeterminate ? 200 : 300;
    const delayMs = 40;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: drawMs + delayMs),
    );
    _draw = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayMs / (drawMs + delayMs), 1, curve: beuiEaseOut),
    );
    if (widget.reduce) {
      _controller.value = 1; // appear fully drawn, no stroke animation
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 12px mark centered in the box, mirroring the source's 12x12 svg.
    return AnimatedBuilder(
      animation: _draw,
      builder: (context, _) => CustomPaint(
        size: const Size(12, 12),
        painter: _MarkPainter(
          progress: _draw.value,
          indeterminate: widget.indeterminate,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Paints the check (`M5 13l4 4L19 7`) or indeterminate bar (`M6 12h12`) in the
/// source's 24×24 coordinate space, drawing a leading fraction [progress] of the
/// stroke.
class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.progress,
    required this.indeterminate,
    required this.color,
  });

  final double progress;
  final bool indeterminate;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0);

    final path = Path();
    if (indeterminate) {
      path.moveTo(6, 12);
      path.lineTo(18, 12); // h12
    } else {
      path.moveTo(5, 13);
      path.lineTo(9, 17); // l4 4
      path.lineTo(19, 7);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (progress >= 1.0) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress ||
      old.indeterminate != indeterminate ||
      old.color != color;
}
