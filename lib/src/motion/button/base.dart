import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';

/// Visual style of a [BeuiButton].
enum BeuiButtonVariant {
  /// Filled, high-contrast call to action.
  primary,

  /// Bordered card surface.
  secondary,

  /// Text-only; tints on hover.
  ghost,

  /// Bordered, transparent fill.
  outline,
}

/// Size of a [BeuiButton].
enum BeuiButtonSize {
  /// Small — 32px tall.
  sm,

  /// Medium — 40px tall (default).
  md,

  /// Large — 48px tall.
  lg,

  /// Square 32px icon button.
  icon,
}

/// A spring-pressed button — the Flutter port of beUI's base `Button`.
///
/// Presses scale down (SPRING_PRESS); on hover-capable pointers it lifts to
/// 1.02. With [ripple] on, a Material-style ripple spawns from the press point.
/// Four [BeuiButtonVariant]s × four [BeuiButtonSize]s.
///
/// `onPressed: null` disables the button (dimmed, no input) — the Flutter idiom.
/// Reduced motion drops the hover/press scale and suppresses the ripple.
class BeuiButton extends StatefulWidget {
  /// Creates a button.
  const BeuiButton({
    required this.child,
    this.onPressed,
    this.variant = BeuiButtonVariant.primary,
    this.size = BeuiButtonSize.md,
    this.pressScale = 0.93,
    this.ripple = false,
    this.focusNode,
    super.key,
  });

  /// Button content (usually a [Text], or an [Icon] for [BeuiButtonSize.icon]).
  final Widget child;

  /// Tap/activation callback. Null disables the button.
  final VoidCallback? onPressed;

  /// Visual style.
  final BeuiButtonVariant variant;

  /// Size.
  final BeuiButtonSize size;

  /// Scale applied while pressed. Default 0.93.
  final double pressScale;

  /// Spawn a Material-style ripple from the press point. Off by default.
  final bool ripple;

  /// Optional external focus node.
  final FocusNode? focusNode;

  @override
  State<BeuiButton> createState() => _BeuiButtonState();
}

class _BeuiButtonState extends State<BeuiButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focusVisible = false;
  final List<_RippleData> _ripples = [];
  int _rippleId = 0;

  bool get _enabled => widget.onPressed != null;

  void _spawnRipple(Offset position, Size size) {
    final diameter = (size.width > size.height ? size.width : size.height) * 2;
    setState(() => _ripples.add(_RippleData(_rippleId++, position, diameter)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final spec = _SizeSpec.of(widget.size);
    final isIcon = widget.size == BeuiButtonSize.icon;

    final palette = _palette(widget.variant, colors, _hovered && _enabled);

    final scaleTarget = !_enabled || reduce
        ? 1.0
        : _pressed
            ? widget.pressScale
            : _hovered
                ? 1.02
                : 1.0;

    final radius = isIcon
        ? BorderRadius.circular(8) // rounded-lg
        : BorderRadius.circular(spec.height / 2); // rounded-full

    Widget content = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(
        fontSize: spec.textSize,
        fontWeight: FontWeight.w500,
        color: palette.text,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: palette.text, size: 16),
        child: widget.child,
      ),
    );

    // Size is static (SizedBox); only the surface colour transitions. Animating
    // width/height on AnimatedContainer would assert when the size prop changes
    // (lerp between a finite and an unbounded constraint).
    Widget box = SizedBox(
      height: spec.height,
      width: isIcon ? spec.height : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        padding: isIcon ? null : EdgeInsets.symmetric(horizontal: spec.padX),
        decoration: BoxDecoration(
          color: palette.background,
          border: palette.border == null
              ? null
              : Border.all(color: palette.border!),
          borderRadius: radius,
        ),
        // widthFactor: 1 hugs the content width (no `alignment` — that would
        // make the button greedily fill its parent's width); the content is
        // still centred vertically within the fixed height.
        child: Center(widthFactor: 1, child: content),
      ),
    );

    if (widget.ripple) {
      box = ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            box,
            for (final r in _ripples)
              _Ripple(
                key: ValueKey(r.id),
                data: r,
                color: palette.text,
                onDone: () =>
                    setState(() => _ripples.removeWhere((x) => x.id == r.id)),
              ),
          ],
        ),
      );
    }

    // Focus ring (keyboard only) — an a11y addition over the source's plain
    // button; harmless on pointer focus.
    if (_focusVisible) {
      box = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: colors.ring, spreadRadius: 3),
            BoxShadow(color: colors.background, spreadRadius: 1),
          ],
        ),
        child: box,
      );
    }

    Widget scaled = SingleMotionBuilder(
      value: scaleTarget,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Listener(
        onPointerDown: _enabled
            ? (event) {
                setState(() => _pressed = true);
                if (widget.ripple && !reduce) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    _spawnRipple(event.localPosition, renderBox.size);
                  }
                }
              }
            : null,
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: box,
        ),
      ),
    );

    if (!_enabled) scaled = Opacity(opacity: 0.5, child: scaled);

    return Semantics(
      button: true,
      enabled: _enabled,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        child: scaled,
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.background,
    required this.text,
    this.border,
  });
  final Color background;
  final Color text;
  final Color? border;
}

_Palette _palette(BeuiButtonVariant variant, BeuiColors c, bool hovered) {
  switch (variant) {
    case BeuiButtonVariant.primary:
      return _Palette(
        background: hovered ? c.primary.withValues(alpha: 0.9) : c.primary,
        text: c.primaryForeground,
      );
    case BeuiButtonVariant.secondary:
      return _Palette(
        background: c.card,
        text: c.foreground,
        border: c.border,
      );
    case BeuiButtonVariant.ghost:
      return _Palette(
        background:
            hovered ? c.primary.withValues(alpha: 0.05) : Colors.transparent,
        text: hovered ? c.foreground : c.mutedForeground,
      );
    case BeuiButtonVariant.outline:
      return _Palette(
        background:
            hovered ? c.primary.withValues(alpha: 0.05) : Colors.transparent,
        text: c.foreground,
        border: c.border,
      );
  }
}

class _SizeSpec {
  const _SizeSpec(this.height, this.padX, this.textSize);
  final double height;
  final double padX;
  final double textSize;

  static _SizeSpec of(BeuiButtonSize size) => switch (size) {
        BeuiButtonSize.sm => const _SizeSpec(32, 12, 12),
        BeuiButtonSize.md => const _SizeSpec(40, 20, 14),
        BeuiButtonSize.lg => const _SizeSpec(48, 24, 16),
        BeuiButtonSize.icon => const _SizeSpec(32, 0, 14),
      };
}

class _RippleData {
  const _RippleData(this.id, this.center, this.diameter);
  final int id;
  final Offset center;
  final double diameter;
}

/// A single press ripple: scales 0→1 while fading 0.3→0 over 1.6s (EASE_OUT).
class _Ripple extends StatefulWidget {
  const _Ripple({
    required this.data,
    required this.color,
    required this.onDone,
    super.key,
  });

  final _RippleData data;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  late final Animation<double> _t =
      CurvedAnimation(parent: _controller, curve: beuiEaseOut);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => Positioned(
        left: d.center.dx - d.diameter / 2,
        top: d.center.dy - d.diameter / 2,
        width: d.diameter,
        height: d.diameter,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.3 * (1 - _t.value),
            child: Transform.scale(
              scale: _t.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
