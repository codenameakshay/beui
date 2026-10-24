import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import 'base.dart';

/// Chrome rim stops used by [BeuiMetallicButton] — the source's 105° silver
/// sweep. These are the metal, not theme tokens.
const _silverStops = [
  Color(0xFF111111),
  Color(0xFF737373),
  Color(0xFFFAFAFA),
  Color(0xFF525252),
  Color(0xFF0A0A0A),
  Color(0xFFA3A3A3),
  Color(0xFFFFFFFF),
  Color(0xFF404040),
  Color(0xFF111111),
];

const _silverPositions = [0.0, 0.14, 0.26, 0.38, 0.50, 0.64, 0.75, 0.87, 1.0];

/// A neutral button framed by a chrome rim with a traveling reflection — the
/// Flutter port of beUI's `MetallicButton`.
///
/// The silver sweep drifts slowly (`8s` [beuiEaseInOut], looping). On hover a
/// 2.4s highlight slides across the face. [paused] (and reduced motion) freeze
/// both layers while keeping the rim. Press scale uses [beuiSpringPress].
class BeuiMetallicButton extends StatefulWidget {
  /// Creates a metallic button.
  const BeuiMetallicButton({
    required this.child,
    this.onPressed,
    this.size = BeuiButtonSize.md,
    this.pressScale = 0.93,
    this.paused = false,
    this.focusNode,
    super.key,
  });

  /// Button content (label, icons).
  final Widget child;

  /// Tap/activation callback. Null disables the button.
  final VoidCallback? onPressed;

  /// Size — same four values as [BeuiButtonSize].
  final BeuiButtonSize size;

  /// Scale applied while pressed. Default 0.93.
  final double pressScale;

  /// Stops the traveling reflection while preserving the chrome rim.
  final bool paused;

  /// Optional external focus node.
  final FocusNode? focusNode;

  @override
  State<BeuiMetallicButton> createState() => _BeuiMetallicButtonState();
}

class _BeuiMetallicButtonState extends State<BeuiMetallicButton>
    with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _pressed = false;
  bool _hovered = false;
  bool _focusVisible = false;

  bool get _enabled => widget.onPressed != null;

  bool get _still => widget.paused || MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDrift();
  }

  @override
  void didUpdateWidget(BeuiMetallicButton old) {
    super.didUpdateWidget(old);
    if (old.paused != widget.paused) _syncDrift();
  }

  void _syncDrift() {
    if (_still) {
      _drift.stop();
      _shimmer.stop();
    } else {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  (double height, double padX, double textSize) get _spec =>
      switch (widget.size) {
        BeuiButtonSize.sm => (32, 12, 12),
        BeuiButtonSize.md => (40, 20, 14),
        BeuiButtonSize.lg => (48, 24, 16),
        BeuiButtonSize.icon => (32, 0, 14),
      };

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isIcon = widget.size == BeuiButtonSize.icon;
    final (height, padX, textSize) = _spec;
    final radius = BorderRadius.circular(isIcon ? height / 2 : height / 2);
    final scaleTarget = !_enabled || reduce
        ? 1.0
        : _pressed
        ? widget.pressScale
        : _hovered
        ? 1.02
        : 1.0;
    final inherited = DefaultTextStyle.of(context).style;
    final still = _still;

    Widget content = DefaultTextStyle(
      style: TextStyle(
        fontFamily: inherited.fontFamily,
        fontFamilyFallback: inherited.fontFamilyFallback,
        fontSize: textSize,
        fontWeight: FontWeight.w500,
        color: colors.foreground,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: colors.foreground, size: 16),
        child: widget.child,
      ),
    );

    Widget chrome = AnimatedBuilder(
      animation: Listenable.merge([_drift, _shimmer]),
      builder: (context, child) {
        final driftT = still ? 0.0 : beuiEaseInOut.transform(_drift.value);
        final shimmerT = still ? 0.0 : _shimmer.value;
        return Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final layerWidth = w * 1.36;
                  final h = constraints.maxHeight;
                  final dx = math.sin(105 * math.pi / 180);
                  final dy = -math.cos(105 * math.pi / 180);
                  final length = layerWidth * dx.abs() + h * dy.abs();
                  final end = Alignment(
                    dx * length / layerWidth,
                    dy * length / h,
                  );
                  return Transform.translate(
                    offset: Offset(-0.18 * w + driftT * 0.13 * layerWidth, 0),
                    child: OverflowBox(
                      maxWidth: w * 1.36,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: w * 1.36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: Alignment(-end.x, -end.y),
                              end: end,
                              colors: _silverStops,
                              stops: _silverPositions,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return Transform.translate(
                    offset: Offset(-0.58 * w + shimmerT * 3.1 * w * 0.52, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: w * 0.52,
                        child: Transform(
                          transform: Matrix4.skewX(-0.21),
                          alignment: Alignment.center,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: beuiBlurSigma(3),
                              sigmaY: beuiBlurSigma(3),
                            ),
                            child: Opacity(
                              opacity: 0.5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.5),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, 0.48, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _hovered
                        ? colors.muted.withValues(alpha: 0.4)
                        : colors.background,
                    borderRadius: radius,
                    boxShadow: const [
                      BoxShadow(color: Color(0x47FFFFFF), offset: Offset(0, 1)),
                      BoxShadow(
                        color: Color(0x29000000),
                        offset: Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padX),
              child: child,
            ),
          ],
        );
      },
      child: Center(widthFactor: isIcon ? null : 1, child: content),
    );

    Widget box = SizedBox(
      height: height,
      width: isIcon ? height : null,
      child: ClipRRect(borderRadius: radius, child: chrome),
    );

    box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          const BoxShadow(
            color: Color(0x29000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
          if (_focusVisible) BoxShadow(color: colors.ring, spreadRadius: 3),
        ],
      ),
      child: box,
    );

    final scaled = SingleMotionBuilder(
      value: scaleTarget,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Listener(
        onPointerDown: _enabled ? (_) => setState(() => _pressed = true) : null,
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

    return Semantics(
      button: true,
      enabled: _enabled,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
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
        onShowHoverHighlight: (v) {
          setState(() => _hovered = v);
          if (!still) {
            _shimmer.animateTo(
              v ? 1 : 0,
              duration: const Duration(milliseconds: 2400),
              curve: beuiEaseInOut,
            );
          }
        },
        child: AnimatedOpacity(
          opacity: _enabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: scaled,
        ),
      ),
    );
  }
}
