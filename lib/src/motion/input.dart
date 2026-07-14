import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';

/// Optional style overrides for [BeuiInput]. Null fields resolve from the
/// ambient [BeuiColors] theme extension (or sensible defaults). Mirrors the
/// source's `classNames` slot map (root / label / field / input / icons /
/// message) with typed fields rather than class strings.
@immutable
class BeuiInputStyle {
  /// Creates a set of [BeuiInput] overrides.
  const BeuiInputStyle({
    this.borderColor,
    this.focusedBorderColor,
    this.errorColor,
    this.successColor,
    this.height,
    this.borderRadius,
  });

  /// Idle field border. Defaults to `BeuiColors.border`.
  final Color? borderColor;

  /// Border + ring when focused (and not errored). Defaults to
  /// `BeuiColors.foreground` at 40% alpha, with a `BeuiColors.ring` glow.
  final Color? focusedBorderColor;

  /// Border + ring + message when errored. Defaults to `BeuiColors.destructive`.
  final Color? errorColor;

  /// Success check colour. Defaults to `BeuiColors.success`.
  final Color? successColor;

  /// Field height. Defaults to 44 (source `h-11`).
  final double? height;

  /// Corner radius. Defaults to half the [height] (source `rounded-full`).
  final double? borderRadius;

  /// Returns a copy with the given fields replaced.
  BeuiInputStyle copyWith({
    Color? borderColor,
    Color? focusedBorderColor,
    Color? errorColor,
    Color? successColor,
    double? height,
    double? borderRadius,
  }) {
    return BeuiInputStyle(
      borderColor: borderColor ?? this.borderColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

/// A pill text field with animated focus, error and success states — the
/// Flutter port of beUI's `input`.
///
/// The field colour-morphs its border/ring over 200ms between idle → focused →
/// error (matching the source's `transition-colors duration-200`). When an
/// [error] first appears the field **shakes** on a keyframed
/// `x: [0, -6, 6, -4, 4, -2, 0]` over 450ms; a string [error] also reveals an
/// alert message that slides down 4px and unblurs (σ2) over 200ms. Passing
/// [success] swaps the right slot for a green check that **strokes itself on**
/// (a `CustomPaint` path-draw, 350ms EASE_OUT).
///
/// **Controlled + uncontrolled**, following the source: pass [value] +
/// [onChanged] to control it, or omit [value] and seed with [defaultValue] for
/// internal state (Flutter's own field convention).
///
/// Reduced motion drops *movement* — no shake, no check path-draw (the mark
/// appears instantly), and the message fades opacity-only — while the border
/// colour transition is kept.
class BeuiInput extends StatefulWidget {
  /// Creates an input field.
  const BeuiInput({
    this.label,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.onSubmitted,
    this.placeholder,
    this.error,
    this.success = false,
    this.leftIcon,
    this.rightIcon,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.focusNode,
    this.controller,
    this.style,
    super.key,
  }) : assert(
         value == null || controller == null,
         'Provide either value (controlled) or controller, not both.',
       );

  /// Optional label rendered above the field.
  final String? label;

  /// Controlled value. When null the field manages its own text (seeded from
  /// [defaultValue]).
  final String? value;

  /// Initial text for the uncontrolled case. Ignored when [value] or
  /// [controller] is supplied.
  final String? defaultValue;

  /// Called with the full text on every edit.
  final ValueChanged<String>? onChanged;

  /// Called with the text when the user submits (keyboard done/enter).
  final ValueChanged<String>? onSubmitted;

  /// Placeholder shown when empty (source `placeholder`).
  final String? placeholder;

  /// Truthy error triggers the shake + red border/ring. A [String] also shows
  /// an alert message below the field; `true` shakes without a message.
  final Object? error;

  /// Shows the success check at the right edge (replaces [rightIcon]).
  final bool success;

  /// Leading icon (framework-native). Rendered at 16px, muted.
  final Widget? leftIcon;

  /// Trailing icon, shown when not [success]. Rendered at 16px, muted.
  final Widget? rightIcon;

  /// Whether the field accepts input. Disabled is dimmed (60%).
  final bool enabled;

  /// Obscure the text (password fields).
  final bool obscureText;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// An external focus node. One is created internally when null.
  final FocusNode? focusNode;

  /// An external controller. Mutually exclusive with [value]; when supplied the
  /// caller owns the text.
  final TextEditingController? controller;

  /// Optional visual overrides.
  final BeuiInputStyle? style;

  @override
  State<BeuiInput> createState() => _BeuiInputState();
}

class _BeuiInputState extends State<BeuiInput>
    with SingleTickerProviderStateMixin {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  late final AnimationController _shake;

  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _hasError => widget.error != null && widget.error != false;
  String? get _errorMessage =>
      widget.error is String ? widget.error as String : null;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    // Uncontrolled seed. (Controlled text is threaded in build via the
    // controller's value so the widget stays the source of truth.)
    if (widget.controller == null) {
      _controller.text = widget.value ?? widget.defaultValue ?? '';
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(BeuiInput old) {
    super.didUpdateWidget(old);
    // Controlled: mirror external value into the field without moving the caret
    // when it hasn't actually changed.
    if (widget.value != null && widget.value != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value!.length),
        composing: TextRange.empty,
      );
    }
    // Fire the shake on the rising edge of an error, mirroring the source's
    // `useEffect([hasError])`.
    final wasError = old.error != null && old.error != false;
    if (_hasError && !wasError && !MediaQuery.disableAnimationsOf(context)) {
      _shake.forward(from: 0);
    }
    if (widget.focusNode != old.focusNode) {
      old.focusNode?.removeListener(_onFocusChange);
      _internalFocusNode?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _shake.dispose();
    _internalController?.dispose();
    _internalFocusNode?.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    if (widget.focusNode != null) widget.focusNode!.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final s = widget.style;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final height = s?.height ?? 44.0;
    final radius = s?.borderRadius ?? height / 2;
    final errorColor = s?.errorColor ?? colors.destructive;
    final successColor = s?.successColor ?? colors.success;

    // Border + ring resolve by state; the box animates the colour over 200ms.
    final Color borderColor;
    final Color? ringColor;
    if (_hasError) {
      borderColor = errorColor;
      ringColor = errorColor.withValues(alpha: 0.25);
    } else if (_focused) {
      borderColor =
          s?.focusedBorderColor ?? colors.foreground.withValues(alpha: 0.4);
      ringColor = colors.ring.withValues(alpha: 0.4);
    } else {
      borderColor = s?.borderColor ?? colors.border;
      ringColor = null;
    }

    final hasLeft = widget.leftIcon != null;
    final rightSlot = widget.success
        ? _SuccessCheck(color: successColor, reduce: reduce)
        : widget.rightIcon;
    final hasRight = rightSlot != null;

    Widget field = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        // ring-2 → a 2px outer glow via a spread shadow, ramped by the same
        // AnimatedContainer clock.
        boxShadow: ringColor != null
            ? [BoxShadow(color: ringColor, spreadRadius: 2)]
            : null,
      ),
      child: Row(
        children: [
          if (hasLeft)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 2),
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: colors.mutedForeground),
                child: widget.leftIcon!,
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: hasLeft ? 4 : 14,
                right: hasRight ? 4 : 14,
              ),
              child: _EditableTextLine(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                placeholder: widget.placeholder,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                textColor: colors.foreground,
                placeholderColor: colors.mutedForeground.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (hasRight)
            Padding(
              padding: const EdgeInsets.only(right: 14, left: 2),
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: colors.mutedForeground),
                child: rightSlot,
              ),
            ),
        ],
      ),
    );

    // Keyframed shake on error appearance: x: [0,-6,6,-4,4,-2,0] over 450ms.
    if (!reduce) {
      field = AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shakeX(_shake.value), 0),
          child: child,
        ),
        child: field,
      );
    }

    return Opacity(
      opacity: widget.enabled ? 1 : 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            ),
          ],
          field,
          // Error message reveal / removal — slide-down + unblur, opacity-only
          // under reduced motion.
          _ErrorMessage(
            message: _errorMessage,
            color: errorColor,
            reduce: reduce,
          ),
        ],
      ),
    );
  }

  /// Piecewise-linear interpolation of the source keyframes
  /// `[0, -6, 6, -4, 4, -2, 0]` evenly spaced across `t ∈ [0, 1]`.
  static double _shakeX(double t) {
    const frames = [0.0, -6.0, 6.0, -4.0, 4.0, -2.0, 0.0];
    if (t <= 0) return 0;
    if (t >= 1) return 0;
    final scaled = t * (frames.length - 1);
    final i = scaled.floor();
    final f = scaled - i;
    return frames[i] + (frames[i + 1] - frames[i]) * f;
  }
}

/// A thin single-line editable text row wired to a [TextEditingController], with
/// a placeholder overlay. Split out so the field's decoration/layout stays
/// readable.
class _EditableTextLine extends StatelessWidget {
  const _EditableTextLine({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.obscureText,
    required this.keyboardType,
    required this.placeholder,
    required this.onChanged,
    required this.onSubmitted,
    required this.textColor,
    required this.placeholderColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color textColor;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: 16, height: 1.5, color: textColor);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: textColor,
      style: textStyle,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: placeholder,
        hintStyle: textStyle.copyWith(color: placeholderColor),
      ),
    );
  }
}

/// The green success check that strokes itself on (`M5 12.5l4.5 4.5L19 7.5`,
/// 350ms EASE_OUT). Under [reduce] it appears fully drawn.
class _SuccessCheck extends StatefulWidget {
  const _SuccessCheck({required this.color, required this.reduce});
  final Color color;
  final bool reduce;

  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _draw.value = 1;
    } else {
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _draw,
      builder: (context, _) => CustomPaint(
        size: const Size(20, 20),
        painter: _CheckPainter(
          progress: beuiEaseOut.transform(_draw.value),
          color: widget.color,
        ),
      ),
    );
  }
}

/// Draws a leading [progress] fraction of the check `M5 12.5l4.5 4.5L19 7.5`
/// in the source's 24×24 coordinate space.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0);
    final path = Path()
      ..moveTo(5, 12.5)
      ..lineTo(9.5, 17)
      ..lineTo(19, 7.5);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// The alert message under the field. Animates in (slide-down 4px + unblur σ2,
/// 200ms) when [message] appears and out when it clears — opacity-only under
/// [reduce]. Uses an [AnimatedSwitcher] so add/remove both animate, mirroring
/// the source's `AnimatePresence`.
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.message,
    required this.color,
    required this.reduce,
  });
  final String? message;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: beuiEaseOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: beuiEaseOut,
        switchOutCurve: beuiEaseOut,
        transitionBuilder: (child, animation) {
          if (reduce) return FadeTransition(opacity: animation, child: child);
          // y: -4 → 0, blur(4px) → 0 (σ2 → 0).
          return FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, inner) {
                final t = animation.value;
                final blur = 2.0 * (1 - t);
                Widget body = Transform.translate(
                  offset: Offset(0, -4 * (1 - t)),
                  child: inner,
                );
                if (blur > 0.05) {
                  body = ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: body,
                  );
                }
                return body;
              },
              child: child,
            ),
          );
        },
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(left: 4, top: 6),
                child: Text(
                  message!,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
      ),
    );
  }
}
