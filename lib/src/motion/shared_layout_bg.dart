import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Test handle on the gliding pill.
@visibleForTesting
const beuiSharedPillKey = ValueKey<String>('beui_shared_pill');

/// A vertical list whose hover highlight is a single pill that **glides**
/// between rows — the Flutter port of beUI's `shared-layout-bg`.
///
/// Hovering a row springs a soft pill (rounded, a faint primary tint) behind it
/// with [beuiSpringLayout] (the source's `layoutId` shared layout); moving to
/// another row glides the same pill. The pill fades in/out with blur as the
/// pointer enters/leaves the list. Hover-only (built on `MouseRegion`, so it
/// never appears on touch); reduced motion snaps position and fades opacity
/// only.
class BeuiSharedLayoutBg extends StatefulWidget {
  /// Creates a hover-pill list around [children] (the rows, top to bottom).
  const BeuiSharedLayoutBg({
    required this.children,
    this.inset = 20,
    this.pillColor,
    super.key,
  });

  /// The rows.
  final List<Widget> children;

  /// Horizontal inset (px) the pill extends past each row on both sides.
  final double inset;

  /// Pill colour. Defaults to `BeuiColors.primary` at 6% alpha.
  final Color? pillColor;

  @override
  State<BeuiSharedLayoutBg> createState() => _BeuiSharedLayoutBgState();
}

class _BeuiSharedLayoutBgState extends State<BeuiSharedLayoutBg>
    with SingleTickerProviderStateMixin {
  final GlobalKey _stackKey = GlobalKey();
  late List<GlobalKey> _itemKeys;
  late final AnimationController _fade =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 160),
      )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _rect != null) {
          setState(() => _rect = null);
        }
      });
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.children.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(BeuiSharedLayoutBg old) {
    super.didUpdateWidget(old);
    if (widget.children.length != _itemKeys.length) {
      _itemKeys = List.generate(widget.children.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _hover(int i) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _itemKeys[i].currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || itemBox == null || !itemBox.hasSize) return;
    final topLeft = stackBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
    setState(() {
      _rect = Rect.fromLTWH(
        topLeft.dx - widget.inset,
        topLeft.dy,
        itemBox.size.width + 2 * widget.inset,
        itemBox.size.height,
      );
    });
    _fade.forward();
  }

  void _leave() => _fade.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final color = widget.pillColor ?? colors.primary.withValues(alpha: 0.06);

    return MouseRegion(
      onExit: (_) => _leave(),
      child: Stack(
        key: _stackKey,
        children: [
          if (_rect != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _Pill(
                  rect: _rect!,
                  fade: _fade,
                  color: color,
                  reduce: reduce,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                MouseRegion(
                  onEnter: (_) => _hover(i),
                  child: KeyedSubtree(
                    key: _itemKeys[i],
                    child: widget.children[i],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.rect,
    required this.fade,
    required this.color,
    required this.reduce,
  });

  final Rect rect;
  final Animation<double> fade;
  final Color color;
  final bool reduce;

  Widget _at(Rect r) {
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) {
        final f = fade.value.clamp(0.0, 1.0);
        Widget box = Container(
          key: beuiSharedPillKey,
          width: r.width,
          height: r.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16), // rounded-2xl
          ),
        );
        // Only wrap in a blur layer while actually blurring — an ImageFiltered
        // at sigma 0 still rasterises through a saveLayer (soft, "low quality"
        // edges). Source blur(6px) → sigma 3.0 (σ = px / 2).
        final blur = reduce ? 0.0 : (1 - f) * 3.0;
        if (blur > 0.1) {
          box = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: box,
          );
        }
        return Opacity(
          opacity: f,
          child: Transform.translate(
            offset: r.topLeft,
            child: Align(alignment: Alignment.topLeft, child: box),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reduce) return _at(rect); // snap position, fade opacity only
    return MotionBuilder<Rect>(
      value: rect,
      motion: beuiSpringLayout,
      converter: const RectMotionConverter(),
      builder: (context, r, _) => _at(r),
    );
  }
}
