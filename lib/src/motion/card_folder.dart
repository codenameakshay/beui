import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'digit_swap.dart';
import 'tooltip.dart';

const _purseMorph = CurvedMotion(Duration(milliseconds: 280), beuiEaseInOut);
const _pressScale = 0.96;

/// A payment card tucked into an animated purse pocket.
class BeuiCardFolder extends StatefulWidget {
  const BeuiCardFolder({
    required this.title,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.card,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.detailsVisible,
    this.defaultDetailsVisible = false,
    this.onDetailsVisibleChange,
    this.onClick,
    this.onAction,
    this.semanticLabel,
    this.actionLabel,
    this.disabled = false,
    super.key,
  });

  final String title;
  final String cardNumber;
  final String expiry;
  final String cvv;
  final Widget card;
  final bool? open;
  final bool defaultOpen;
  final ValueChanged<bool>? onOpenChange;
  final bool? detailsVisible;
  final bool defaultDetailsVisible;
  final ValueChanged<bool>? onDetailsVisibleChange;
  final VoidCallback? onClick;
  final VoidCallback? onAction;
  final String? semanticLabel;
  final String? actionLabel;
  final bool disabled;

  @override
  State<BeuiCardFolder> createState() => _BeuiCardFolderState();
}

class _BeuiCardFolderState extends State<BeuiCardFolder> {
  final _folderFocus = FocusNode();
  late bool _open = widget.defaultOpen;
  late bool _detailsVisible = widget.defaultDetailsVisible;
  bool _pressed = false;
  bool _focusVisible = false;

  bool get isOpen => widget.open ?? _open;
  bool get detailsVisible => widget.detailsVisible ?? _detailsVisible;

  @override
  void dispose() {
    _folderFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool value) {
    if (widget.disabled) return;
    if (widget.open == null) setState(() => _open = value);
    widget.onOpenChange?.call(value);
  }

  void _toggleDetails() {
    if (widget.disabled || isOpen) return;
    final next = !detailsVisible;
    if (widget.detailsVisible == null) setState(() => _detailsVisible = next);
    widget.onDetailsVisibleChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final digits = widget.cardNumber.replaceAll(RegExp(r'\D'), '');
    final lastFour = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits.padLeft(4, '•');
    final expandedNumber = digits.isEmpty
        ? lastFour
        : RegExp('.{1,4}').allMatches(digits).map((m) => m[0]!).join(' ');
    final accessibleLabel =
        widget.semanticLabel ??
        '${isOpen ? 'Close' : 'Open'} ${widget.title}, card ending in $lastFour, expires ${widget.expiry}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 384.0);
        final height = width * 592 / 1029;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SingleMotionBuilder(
                value: isOpen ? 1 : 0,
                from: isOpen ? 1 : 0,
                motion: motionFor(context, _purseMorph, isMovement: true),
                builder: (context, progress, _) {
                  final p = progress.clamp(0.0, 1.0);
                  final lift = math.sin(math.pi * p);
                  final purseOpacity =
                      (1 - ((p - 0.76) / 0.24).clamp(0.0, 1.0));
                  final backTransform = Matrix4.identity();
                  if (!reduce) {
                    backTransform
                      ..translateByDouble(0.0, height * 0.9 * 0.18 * p, 0, 1)
                      ..scaleByDouble(1.0, 1 - 0.82 * p, 1, 1);
                  }
                  final frontTransform = Matrix4.identity();
                  if (!reduce) {
                    frontTransform
                      ..setEntry(3, 2, -1 / 1200)
                      ..translateByDouble(0.0, height * 0.5 * 0.18 * p, 0, 1)
                      ..rotateX(-72 * math.pi / 180 * p);
                  }
                  Widget purseBack = Opacity(
                    opacity: reduce ? (isOpen ? 0 : 1) : purseOpacity,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: backTransform,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.background,
                          border: Border.all(
                            color: colors.foreground.withValues(alpha: 0.1),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                  Widget purseFront = Opacity(
                    opacity: reduce ? (isOpen ? 0 : 1) : purseOpacity,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: frontTransform,
                      child: _Pocket(
                        colors: colors,
                        child: _PocketDetails(
                          title: widget.title,
                          expiry: widget.expiry,
                          cvv: detailsVisible
                              ? widget.cvv
                              : '•' * math.max(3, widget.cvv.length),
                          cardNumber: detailsVisible
                              ? expandedNumber
                              : '•••• •••• •••• $lastFour',
                          detailsVisible: detailsVisible,
                          disabled: widget.disabled,
                          onToggle: _toggleDetails,
                          colors: colors,
                        ),
                      ),
                    ),
                  );
                  if (reduce) {
                    purseBack = AnimatedOpacity(
                      opacity: isOpen ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: beuiEaseOut,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.identity(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.background,
                            border: Border.all(
                              color: colors.foreground.withValues(alpha: 0.1),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                    purseFront = AnimatedOpacity(
                      opacity: isOpen ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: beuiEaseOut,
                      child: _Pocket(
                        colors: colors,
                        child: _PocketDetails(
                          title: widget.title,
                          expiry: widget.expiry,
                          cvv: detailsVisible
                              ? widget.cvv
                              : '•' * math.max(3, widget.cvv.length),
                          cardNumber: detailsVisible
                              ? expandedNumber
                              : '•••• •••• •••• $lastFour',
                          detailsVisible: detailsVisible,
                          disabled: widget.disabled,
                          onToggle: _toggleDetails,
                          colors: colors,
                        ),
                      ),
                    );
                  }
                  return Semantics(
                    container: true,
                    explicitChildNodes: true,
                    button: true,
                    enabled: !widget.disabled,
                    expanded: isOpen,
                    label: accessibleLabel,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: FocusableActionDetector(
                            focusNode: _folderFocus,
                            enabled: !widget.disabled,
                            onShowFocusHighlight: (visible) =>
                                setState(() => _focusVisible = visible),
                            shortcuts: const {
                              SingleActivator(LogicalKeyboardKey.enter):
                                  ActivateIntent(),
                              SingleActivator(LogicalKeyboardKey.space):
                                  ActivateIntent(),
                            },
                            actions: {
                              ActivateIntent: CallbackAction<ActivateIntent>(
                                onInvoke: (_) {
                                  _setOpen(!isOpen);
                                  widget.onClick?.call();
                                  return null;
                                },
                              ),
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: widget.disabled
                                  ? null
                                  : (_) => setState(() => _pressed = true),
                              onTapUp: widget.disabled
                                  ? null
                                  : (_) => setState(() => _pressed = false),
                              onTapCancel: () =>
                                  setState(() => _pressed = false),
                              onTap: widget.disabled
                                  ? null
                                  : () {
                                      _folderFocus.requestFocus();
                                      _setOpen(!isOpen);
                                      widget.onClick?.call();
                                    },
                              child: SingleMotionBuilder(
                                value: _pressed && !reduce ? _pressScale : 1,
                                from: 1,
                                motion: motionFor(
                                  context,
                                  beuiSpringPress,
                                  isMovement: true,
                                ),
                                builder: (context, scale, child) =>
                                    Transform.scale(
                                      scale: scale,
                                      child: Opacity(
                                        opacity: widget.disabled ? 0.5 : 1,
                                        child: CustomPaint(
                                          foregroundPainter: _focusVisible
                                              ? _FolderFocusPainter(colors.ring)
                                              : null,
                                          child: child,
                                        ),
                                      ),
                                    ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: height * 0.1,
                                      bottom: 0,
                                      child: purseBack,
                                    ),
                                    Positioned(
                                      left: width * 0.047,
                                      right: width * 0.047,
                                      top: 0,
                                      height: width * 0.906 / 1.586,
                                      child: Transform.translate(
                                        offset: Offset(
                                          0,
                                          reduce
                                              ? 0
                                              : -width *
                                                    0.906 /
                                                    1.586 *
                                                    0.08 *
                                                    lift,
                                        ),
                                        child: Transform.scale(
                                          scale: reduce ? 1 : 1 + 0.01 * lift,
                                          alignment: Alignment.bottomCenter,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: colors.background,
                                              border: Border.all(
                                                color: colors.foreground
                                                    .withValues(alpha: 0.1),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              child: widget.card,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: height / 2,
                          bottom: 0,
                          child: ExcludeSemantics(
                            excluding: isOpen,
                            child: IgnorePointer(
                              ignoring: isOpen,
                              child: purseFront,
                            ),
                          ),
                        ),
                        if (widget.onAction != null)
                          Positioned(
                            right: width * 0.026,
                            top: height * 0.1,
                            child: SingleMotionBuilder(
                              value: isOpen && !reduce ? -14 : 0,
                              from: 0,
                              motion: motionFor(
                                context,
                                _purseMorph,
                                isMovement: true,
                              ),
                              builder: (context, offset, child) =>
                                  Transform.translate(
                                    offset: Offset(0, offset - 20),
                                    child: child,
                                  ),
                              child: _FolderControl(
                                label:
                                    widget.actionLabel ??
                                    'Open actions for ${widget.title}',
                                onPressed: widget.disabled
                                    ? null
                                    : widget.onAction,
                                colors: colors,
                                action: true,
                                child: const Icon(
                                  LucideIcons.ellipsis_vertical,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FolderFocusPainter extends CustomPainter {
  const _FolderFocusPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(5),
      const Radius.circular(21),
    ),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  @override
  bool shouldRepaint(_FolderFocusPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _Pocket extends StatelessWidget {
  const _Pocket({required this.colors, required this.child});
  final BeuiColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(child: CustomPaint(painter: _PocketPainter(colors))),
      child,
    ],
  );
}

class _PocketPainter extends CustomPainter {
  const _PocketPainter(this.colors);
  final BeuiColors colors;

  static const _outline =
      'M0 17C15 7 31 4 49 4H87C110 4 126 17 144 32L158 44C176 59 206 59 225 43L240 30C257 16 271 4 295 4H335C354 4 370 8 384 18V94C384 103 377 110 368 110H16C7 110 0 103 0 94Z';
  static const _stitch =
      'M10 21C22 13 35 11 51 11H85C105 11 120 23 137 37L153 50C175 68 208 68 231 49L246 36C262 23 275 11 297 11H333C350 11 363 14 374 22V89C374 97 369 101 360 101H24C15 101 10 96 10 89Z';

  @override
  void paint(Canvas canvas, Size size) {
    final scale = Matrix4.diagonal3Values(
      size.width / 384,
      size.height / 110,
      1,
    );
    final outline = _path(_outline).transform(scale.storage);
    final stitch = _path(_stitch).transform(scale.storage);
    canvas.drawPath(
      outline,
      Paint()
        ..color = colors.background
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = colors.foreground.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final dash = <double>[5, 5];
    for (final metric in stitch.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      var index = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash[index % 2], metric.length);
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, end),
            Paint()
              ..color = colors.foreground.withValues(alpha: 0.22)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..strokeCap = StrokeCap.round,
          );
        }
        distance = end;
        draw = !draw;
        index++;
      }
    }
  }

  Path _path(String source) {
    final path = Path();
    final tokens = RegExp(
      r'[A-Za-z]|-?\d+(?:\.\d+)?',
    ).allMatches(source).map((m) => m[0]!).toList();
    var i = 0;
    var x = 0.0;
    var y = 0.0;
    while (i < tokens.length) {
      final command = tokens[i++];
      if (command == 'M') {
        x = double.parse(tokens[i++]);
        y = double.parse(tokens[i++]);
        path.moveTo(x, y);
      } else if (command == 'H') {
        x = double.parse(tokens[i++]);
        path.lineTo(x, y);
      } else if (command == 'V') {
        y = double.parse(tokens[i++]);
        path.lineTo(x, y);
      } else if (command == 'C') {
        final a = List.generate(6, (_) => double.parse(tokens[i++]));
        x = a[4];
        y = a[5];
        path.cubicTo(a[0], a[1], a[2], a[3], x, y);
      } else if (command == 'Z') {
        path.close();
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_PocketPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _FolderControl extends StatefulWidget {
  const _FolderControl({
    required this.label,
    required this.onPressed,
    required this.colors,
    required this.child,
    this.toggled,
    this.tooltip = false,
    this.action = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BeuiColors colors;
  final Widget child;
  final bool? toggled;
  final bool tooltip, action;

  @override
  State<_FolderControl> createState() => _FolderControlState();
}

class _FolderControlState extends State<_FolderControl> {
  final _focusNode = FocusNode();
  bool _hovered = false;
  bool _pressed = false;
  bool _focusVisible = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final foreground = widget.action
        ? Colors.white.withValues(alpha: _hovered && enabled ? 1 : 0.65)
        : (_hovered && enabled
              ? widget.colors.foreground
              : widget.colors.mutedForeground);
    Widget control = FocusableActionDetector(
      focusNode: _focusNode,
      enabled: enabled,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: enabled
            ? () {
                _focusNode.requestFocus();
                widget.onPressed!();
              }
            : null,
        child: SingleMotionBuilder(
          value: _pressed && enabled && !reduce ? _pressScale : 1,
          from: 1,
          motion: motionFor(context, beuiSpringPress, isMovement: true),
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.action && _hovered && enabled
                      ? Colors.white.withValues(alpha: 0.1)
                      : null,
                  border: _focusVisible && enabled
                      ? Border.all(
                          color: widget.action
                              ? Colors.white
                              : widget.colors.ring,
                          width: 2,
                        )
                      : null,
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: foreground),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip) {
      control = BeuiTooltip(
        disabled: !enabled,
        content: ExcludeSemantics(child: Text(widget.label)),
        child: control,
      );
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      focusable: enabled,
      label: widget.label,
      toggled: widget.toggled,
      onTap: widget.onPressed,
      child: control,
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  const _PrivacyIcon({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: 16,
      child: Stack(
        children: [
          for (final hidden in [false, true])
            Positioned.fill(
              child: SingleMotionBuilder(
                value: visible == hidden ? 1 : 0,
                from: visible == hidden ? 1 : 0,
                motion: CurvedMotion(
                  Duration(milliseconds: reduce ? 120 : 300),
                  reduce ? Curves.linear : const _PrivacySpringCurve(),
                ),
                builder: (context, value, child) {
                  final opacity = value.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity,
                    child: reduce
                        ? child
                        : Transform.scale(
                            scale: 0.25 + 0.75 * opacity,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: beuiBlurSigma(4) * (1 - opacity),
                                sigmaY: beuiBlurSigma(4) * (1 - opacity),
                              ),
                              child: child,
                            ),
                          ),
                  );
                },
                child: Icon(
                  hidden ? LucideIcons.eye_off : LucideIcons.eye,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Motion 12's duration=300, bounce=0 spring resolves to omega=30.778044921505288.
class _PrivacySpringCurve extends Curve {
  const _PrivacySpringCurve();
  @override
  double transformInternal(double t) =>
      1 - (1 + 9.233413476451586 * t) * math.exp(-9.233413476451586 * t);
}

class _PocketDetails extends StatelessWidget {
  const _PocketDetails({
    required this.title,
    required this.expiry,
    required this.cvv,
    required this.cardNumber,
    required this.detailsVisible,
    required this.disabled,
    required this.onToggle,
    required this.colors,
  });
  final String title, expiry, cvv, cardNumber;
  final bool detailsVisible, disabled;
  final VoidCallback onToggle;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth * 0.05,
        vertical: 16,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FolderControl(
                colors: colors,
                label: detailsVisible
                    ? 'Hide card details'
                    : 'Show card details',
                toggled: detailsVisible,
                onPressed: disabled ? null : onToggle,
                tooltip: true,
                child: _PrivacyIcon(visible: detailsVisible),
              ),
              const Spacer(),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MiniField(
                        label: 'Expiry',
                        value: expiry,
                        colors: colors,
                      ),
                      const SizedBox(width: 14),
                      _MiniField(
                        label: 'CVV',
                        value: cvv,
                        colors: colors,
                        animate: true,
                        revealed: detailsVisible,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          IgnorePointer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                BeuiDigitSwap(
                  value: cardNumber,
                  animationKey: detailsVisible ? 'revealed' : 'masked',
                  direction: detailsVisible
                      ? BeuiDigitSwapDirection.up
                      : BeuiDigitSwapDirection.down,
                  suffixLength: 4,
                  glyphStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0.96,
                    color: detailsVisible
                        ? colors.foreground
                        : colors.mutedForeground,
                  ),
                  suffixStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0.96,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.label,
    required this.value,
    required this.colors,
    this.animate = false,
    this.revealed = false,
  });
  final String label, value;
  final BeuiColors colors;
  final bool animate;
  final bool revealed;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          height: 1.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.08,
          color: colors.mutedForeground.withValues(alpha: 0.65),
        ),
      ),
      const SizedBox(height: 2),
      if (animate)
        BeuiDigitSwap(
          value: value,
          animationKey: revealed ? 'revealed' : 'masked',
          direction: revealed
              ? BeuiDigitSwapDirection.up
              : BeuiDigitSwapDirection.down,
          glyphStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.foreground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        )
      else
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: colors.foreground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
    ],
  );
}
