import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shake.dart';

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
    this.semanticLabel,
    this.errorNonce = 0,
    this.autofillHints,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.inputFormatters,
    this.onEditingComplete,
    this.readOnly = false,
    this.enableSuggestions = true,
    this.autofocus = false,
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

  /// Accessible name for the field. Defaults to [label].
  ///
  /// A visible [label] is associated with the field automatically (they share
  /// one semantics node), so this is only needed when the field has no visible
  /// label — a search box whose only cue is its placeholder, say. A placeholder
  /// is not a label: it disappears the moment the user types.
  final String? semanticLabel;

  /// Bump this to replay the shake for an error that has not changed.
  ///
  /// The shake fires on the *rising edge* of [error], mirroring the source's
  /// `useEffect([hasError])`. Submitting the same invalid value twice therefore
  /// produced no feedback at all — the second rejection looked like the form
  /// had ignored the press. Increment [errorNonce] on each failed submit (or
  /// pass a submit counter) and the field shakes again.
  final int errorNonce;

  /// Platform autofill hints, e.g. `[AutofillHints.email]`.
  final List<String>? autofillHints;

  /// The keyboard's action button (next / done / search).
  final TextInputAction? textInputAction;

  /// Auto-capitalisation behaviour for the soft keyboard.
  final TextCapitalization textCapitalization;

  /// Maximum input length.
  ///
  /// The character counter Material would add below the field is suppressed —
  /// the pill has no room for it and the source has no counter. Show remaining
  /// characters yourself if you need them.
  final int? maxLength;

  /// Input formatters (masking, digit-only, …).
  final List<TextInputFormatter>? inputFormatters;

  /// Called when the user finishes editing (keyboard action, focus loss).
  final VoidCallback? onEditingComplete;

  /// Renders the current value without allowing edits, while staying focusable
  /// and selectable — unlike `enabled: false`, which also dims the field.
  final bool readOnly;

  /// Whether to enable the platform's suggestion/autocorrect bar.
  final bool enableSuggestions;

  /// Focus the field on mount.
  final bool autofocus;

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
    // `useEffect([hasError])` — or whenever the caller bumps `errorNonce`, so a
    // repeated rejection of the same value still registers as a rejection.
    final replay =
        _hasError &&
        (widget.errorNonce != old.errorNonce || widget.error != old.error);
    if (replay && !MediaQuery.disableAnimationsOf(context)) {
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
    widget.focusNode?.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final s = widget.style;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final fieldTextStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: colors.foreground,
    );

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
      // `ring-ring/40` scales the ring token's *own* alpha by 40% — it does not
      // replace it. The dark token is white@10%, so the ring lands at white@4%.
      ringColor = colors.ring.withValues(alpha: colors.ring.a * 0.4);
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
      ),
      child: Row(
        children: [
          // Source geometry: the icon sits at `left-3` (12) and is 16 wide, and
          // the input carries `pl-10` (40) — so the gap between icon and text
          // is 40 - 12 - 16 = 12.
          if (hasLeft)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: colors.mutedForeground),
                child: widget.leftIcon!,
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: hasLeft ? 0 : 14,
                right: hasRight ? 0 : 14,
              ),
              // Full-strength `mutedForeground` (5.9:1) keeps the 4.5:1 AA
              // floor on placeholder text that is often the field's only
              // label.
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: colors.foreground,
                style: fieldTextStyle,
                autofillHints: widget.autofillHints,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                maxLength: widget.maxLength,
                inputFormatters: widget.inputFormatters,
                onEditingComplete: widget.onEditingComplete,
                readOnly: widget.readOnly,
                enableSuggestions: widget.enableSuggestions,
                autofocus: widget.autofocus,
                decoration: InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: widget.placeholder,
                  hintStyle: fieldTextStyle.copyWith(
                    color: colors.mutedForeground,
                  ),
                  // Material would append a character counter under the
                  // field when `maxLength` is set. The pill is a
                  // fixed-height single line with no room for one, and the
                  // source has no counter — suppress it and leave the
                  // remaining-character affordance to the caller.
                  counterText: '',
                ),
              ),
            ),
          ),
          // The success check is 20 wide at `right-3.5` (14); a right icon is 16
          // wide, centred in a 44-square button flush to the right edge (so its
          // right edge also lands at 14). The input reserves `pr-10` (40) for
          // both, which fixes the leading gap at 6 and 10 respectively.
          if (hasRight)
            Padding(
              padding: EdgeInsets.only(
                right: 14,
                left: widget.success ? 6 : 10,
              ),
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: colors.mutedForeground),
                child: rightSlot,
              ),
            ),
        ],
      ),
    );

    // `ring-2` is a CSS *outset* ring: a 2px band sitting immediately outside
    // the border box, never over the field's interior. A Flutter BoxShadow
    // cannot express that — it paints the whole rounded rect behind the box,
    // and because this decoration has no fill there is nothing to occlude the
    // middle, so the field would flood with the ring colour on focus. Draw the
    // ring as its own stroked rounded rect, inflated 2px and laid out-of-flow
    // so it costs no space (as `ring` does in CSS).
    field = Stack(
      clipBehavior: Clip.none,
      children: [
        field,
        Positioned(
          left: -2,
          top: -2,
          right: -2,
          bottom: -2,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 2),
                border: Border.all(
                  color: ringColor ?? const Color(0x00000000),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
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

    // Source dims the *field* only (`disabled && "opacity-60"` on the field
    // div) — the label and the alert message keep full opacity.
    if (!widget.enabled) {
      field = Opacity(opacity: 0.6, child: field);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The visible label and the field are one semantics node, so a screen
        // reader announces "Email, edit box, hello" instead of a stray "Email"
        // followed by an anonymous text field — the association a `<label for>`
        // gives you for free on the web and Flutter gives you not at all.
        // `semanticLabel` names the field when there is no visible label.
        MergeSemantics(
          child: Semantics(
            label: widget.semanticLabel ?? widget.label,
            // Read after the value on focus, so a user who tabs back into a
            // rejected field hears why it was rejected. The live region below
            // covers the moment the error *arrives*; this covers every visit
            // afterwards.
            hint: _errorMessage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.label != null)
                  // Excluded because the name is supplied above; left in the
                  // tree it would be read twice.
                  ExcludeSemantics(
                    child: Padding(
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
                  ),
                field,
              ],
            ),
          ),
        ),
        // Error message reveal / removal — slide-down + unblur, opacity-only
        // under reduced motion.
        _ErrorMessage(
          message: _errorMessage,
          color: errorColor,
          reduce: reduce,
        ),
      ],
    );
  }

  // Source keyframes `[0, -6, 6, -4, 4, -2, 0]`. The source passes no `ease`,
  // and Framer eases each keyframe segment with its multi-keyframe default
  // (`easeInOut`) rather than stepping linearly between them.
  static const _shakeFrames = [0.0, -6.0, 6.0, -4.0, 4.0, -2.0, 0.0];

  static double _shakeX(double t) =>
      beuiShakeOffset(t, _shakeFrames, Curves.easeInOut);
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
        // Left-aligns the message under the field (AnimatedSwitcher's default
        // layout builder centres children); directional so RTL still starts
        // at the correct edge.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.topStart,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          if (reduce) return FadeTransition(opacity: animation, child: child);
          // y: -4 → 0, blur(4px) → 0 (σ2 → 0).
          return FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, inner) {
                final t = animation.value;
                final blur = beuiBlurSigma(4) * (1 - t);
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
            : Semantics(
                key: ValueKey(message),
                // Announced the moment validation fails, without stealing
                // focus — the error is otherwise invisible to a screen-reader
                // user until they happen to tab back into the field.
                liveRegion: true,
                container: true,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
                  child: Text(
                    message!,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              ),
      ),
    );
  }
}
