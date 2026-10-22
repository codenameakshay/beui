import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'digit_swap.dart';

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
  late bool _open = widget.defaultOpen;
  late bool _detailsVisible = widget.defaultDetailsVisible;
  bool _pressed = false;

  bool get isOpen => widget.open ?? _open;
  bool get detailsVisible => widget.detailsVisible ?? _detailsVisible;

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
                from: isOpen ? 0 : 1,
                motion: motionFor(context, _purseMorph, isMovement: true),
                builder: (context, progress, _) {
                  final p = progress.clamp(0.0, 1.0);
                  final lift = math.sin(math.pi * p);
                  final purseOpacity =
                      (1 - ((p - 0.76) / 0.24).clamp(0.0, 1.0));
                  final backTransform =
                      reduce ? Matrix4.identity() : Matrix4.identity()
                        ..translateByDouble(0.0, height * 0.18 * p, 0, 1)
                        ..scaleByDouble(1.0, 1 - 0.82 * p, 1, 1);
                  final frontTransform = Matrix4.identity();
                  if (!reduce) {
                    frontTransform
                      ..setEntry(3, 2, -1 / 1200)
                      ..translateByDouble(0.0, height * 0.18 * p, 0, 1)
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
                            color: colors.foreground.withValues(alpha: 0.12),
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
                              color: colors.foreground.withValues(alpha: 0.12),
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
                    button: true,
                    enabled: !widget.disabled,
                    expanded: isOpen,
                    label: accessibleLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: widget.disabled
                          ? null
                          : (_) => setState(() => _pressed = true),
                      onTapUp: widget.disabled
                          ? null
                          : (_) => setState(() => _pressed = false),
                      onTapCancel: () => setState(() => _pressed = false),
                      onTap: widget.disabled
                          ? null
                          : () {
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
                            Transform.scale(scale: scale, child: child),
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
                              height: width * 0.586,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  reduce ? 0 : -height * 0.08 * lift,
                                ),
                                child: Transform.scale(
                                  scale: reduce ? 1 : 1 + 0.01 * lift,
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.card,
                                      border: Border.all(color: colors.border),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: widget.card,
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
                                        offset: Offset(0, offset),
                                        child: child,
                                      ),
                                  child: IconButton(
                                    tooltip:
                                        widget.actionLabel ??
                                        'Open actions for ${widget.title}',
                                    onPressed: widget.disabled
                                        ? null
                                        : widget.onAction,
                                    icon: Icon(
                                      LucideIcons.ellipsis_vertical,
                                      size: 16,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: detailsVisible ? 'Hide card details' : 'Show card details',
              child: IconButton(
                onPressed: disabled ? null : onToggle,
                tooltip: detailsVisible
                    ? 'Hide card details'
                    : 'Show card details',
                icon: Icon(
                  detailsVisible ? LucideIcons.eye_off : LucideIcons.eye,
                  size: 16,
                  color: colors.mutedForeground,
                ),
              ),
            ),
            const Spacer(),
            _MiniField(label: 'Expiry', value: expiry, colors: colors),
            const SizedBox(width: 16),
            _MiniField(label: 'CVV', value: cvv, colors: colors, animate: true),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            BeuiDigitSwap(
              value: cardNumber,
              animationKey: detailsVisible ? 'revealed' : 'masked',
              direction: detailsVisible
                  ? BeuiDigitSwapDirection.up
                  : BeuiDigitSwapDirection.down,
              suffixLength: 4,
              glyphStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 0.6,
                color: colors.mutedForeground,
              ),
              suffixStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 0.6,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.label,
    required this.value,
    required this.colors,
    this.animate = false,
  });
  final String label, value;
  final BeuiColors colors;
  final bool animate;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1,
          color: colors.mutedForeground.withValues(alpha: 0.65),
        ),
      ),
      if (animate)
        BeuiDigitSwap(
          value: value,
          glyphStyle: TextStyle(fontSize: 12, color: colors.foreground),
        )
      else
        Text(value, style: TextStyle(fontSize: 12, color: colors.foreground)),
    ],
  );
}
