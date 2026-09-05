import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart' show beuiSpringPanel;
import '_engine.dart' show CurvedMotion, SingleMotionBuilder;

/// Which side of the trigger the panel morphs out of.
enum BeuiMorphPopoverSide {
  /// Below the trigger (default) — the panel grows from its top corner.
  bottom,

  /// Above the trigger — the panel grows from its bottom corner.
  top,
}

/// Alignment of the panel along the trigger's edge — picks which corner the
/// morph originates from.
enum BeuiMorphPopoverAlign {
  /// Left-aligned (start edge). Morph origin is the left corner.
  start,

  /// Right-aligned (end edge, default). Morph origin is the right corner.
  end,
}

/// Fraction of the panel hidden along an axis in the collapsed (corner) clip —
/// the source's `92%` inset. Only an ~8% sliver at the origin corner shows.
const double _clipHidden = 0.92;

/// Close animates on the same spring as open, so the panel morphs back into its
/// corner instead of snapping shut. Reduced motion swaps to this brief fade.
const _reduceFade = CurvedMotion(Duration(milliseconds: 120));

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A popover whose panel **morphs open from the trigger corner** — the Flutter
/// port of beUI's `popover-morph` (the morph variant of popover).
///
/// The panel is laid out at full size next to the trigger, then clipped to the
/// corner nearest it and unclipped as one piece so it appears to grow out of
/// that corner. Two channels ride the source's `SPRING_PANEL`
/// ([beuiSpringPanel], stiffness 420 · damping 40 · mass 0.5) in lockstep: the
/// wrapper scales `0.96 → 1` and fades `0 → 1` from the origin corner, while an
/// `inset(...)` rounded-rect clip morphs from the corner sliver to the full
/// panel. A drop-shadow hugs the growing clipped shape (a box-shadow would just
/// be clipped away, exactly as the source notes). Close runs the same spring in
/// reverse, morphing back into the corner rather than snapping shut.
///
/// **Collapsed from the source's compound `MorphPopover`/`MorphPopoverTrigger`/
/// `MorphPopoverContent`** into a single widget with a [child] trigger and a
/// [content] panel — the same shape as `BeuiPopover`/`BeuiTooltip`, and the
/// Flutter-idiomatic form of the source's context-wired parts. Distinct from
/// `BeuiPopover` (the gooey/liquid variant); this is the corner-morph variant.
///
/// Controlled ([open] + [onOpenChange]) or uncontrolled ([defaultOpen]). Closes
/// on Escape and on tap-outside. Reduced motion drops the scale and the clip
/// morph and shows the panel with a brief 120ms opacity fade only (movement is
/// dropped, opacity is kept — the library-wide reduced-motion rule).
class BeuiMorphPopover extends StatefulWidget {
  /// Creates a morph popover around [child].
  const BeuiMorphPopover({
    required this.child,
    required this.content,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.side = BeuiMorphPopoverSide.bottom,
    this.align = BeuiMorphPopoverAlign.end,
    this.sideOffset = 8,
    this.radius = 16,
    super.key,
  });

  /// The trigger. Toggles the popover on tap.
  final Widget child;

  /// The panel body. Provides its own size and inner padding (like the source's
  /// `className`-styled content), so it is rendered without extra insets.
  final Widget content;

  /// Controlled open state. When null the popover manages its own.
  final bool? open;

  /// Uncontrolled initial open state.
  final bool defaultOpen;

  /// Notified when the open state should change (toggle / Esc / tap-outside).
  final ValueChanged<bool>? onOpenChange;

  /// Which side the panel morphs out of. Defaults to [BeuiMorphPopoverSide.bottom].
  final BeuiMorphPopoverSide side;

  /// Alignment along the trigger edge. Defaults to [BeuiMorphPopoverAlign.end].
  final BeuiMorphPopoverAlign align;

  /// Gap between trigger and panel, in px (source default 8).
  final double sideOffset;

  /// Panel corner radius, in px (source default 16).
  final double radius;

  @override
  State<BeuiMorphPopover> createState() => _BeuiMorphPopoverState();
}

class _BeuiMorphPopoverState extends State<BeuiMorphPopover> {
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _measureKey = GlobalKey();

  bool _internalOpen = false;
  Size _triggerSize = Size.zero;
  Size _panelSize = Size.zero;

  bool get _open => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    _internalOpen = widget.defaultOpen;
  }

  void _setOpen(bool next) {
    final was = _open;
    if (widget.open == null) {
      setState(() => _internalOpen = next);
    }
    if (was != next) widget.onOpenChange?.call(next);
  }

  void _measure() {
    final t = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final p = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (t != null && t.hasSize && t.size != _triggerSize) {
      setState(() => _triggerSize = t.size);
    }
    if (p != null && p.hasSize && p.size != _panelSize) {
      setState(() => _panelSize = p.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final geo = _buildGeo(
      _triggerSize,
      _panelSize,
      widget.side,
      widget.align,
      widget.sideOffset,
    );

    final trigger = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setOpen(!_open),
      child: KeyedSubtree(key: _triggerKey, child: widget.child),
    );

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        // Off-stage measurement of the panel content at its natural size.
        Positioned(
          left: 0,
          top: 0,
          child: Offstage(
            child: ConstrainedBox(
              key: _measureKey,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.92,
              ),
              child: widget.content,
            ),
          ),
        ),
        // Trigger.
        trigger,
        // The morphing panel.
        if (geo != null)
          Positioned(
            left: geo.left,
            top: geo.top,
            width: geo.width,
            height: geo.height,
            child: SingleMotionBuilder(
              value: _open ? 1.0 : 0.0,
              motion: reduce ? _reduceFade : beuiSpringPanel,
              builder: (context, p, _) {
                if (p <= 0.001 && !_open) {
                  return const SizedBox.shrink();
                }
                return _MorphPanel(
                  width: geo.width,
                  height: geo.height,
                  radius: widget.radius,
                  side: widget.side,
                  align: widget.align,
                  progress: p.clamp(0.0, 1.0),
                  reduce: reduce,
                  interactive: _open,
                  colors: colors,
                  content: widget.content,
                );
              },
            ),
          ),
      ],
    );

    if (!_open) return stack;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _setOpen(false),
      },
      child: Focus(
        autofocus: true,
        child: TapRegion(onTapOutside: (_) => _setOpen(false), child: stack),
      ),
    );
  }
}

/// Panel rect relative to the trigger's top-left, plus its own size. A morph
/// port of the source's absolute `top-full`/`bottom-full` + `right-0`/`left-0`
/// positioning with a `sideOffset` margin.
class _Geo {
  const _Geo({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final double left;
  final double top;
  final double width;
  final double height;
}

_Geo? _buildGeo(
  Size t,
  Size c,
  BeuiMorphPopoverSide side,
  BeuiMorphPopoverAlign align,
  double gap,
) {
  if (t == Size.zero || c == Size.zero) return null;
  final tW = t.width, tH = t.height, cW = c.width, cH = c.height;
  final top = side == BeuiMorphPopoverSide.bottom ? tH + gap : -(gap + cH);
  final left = align == BeuiMorphPopoverAlign.end ? tW - cW : 0.0;
  return _Geo(left: left, top: top, width: cW, height: cH);
}

/// The morphing panel: a wrapper that scales + fades from the origin corner,
/// wrapping a drop-shadow and the content clipped by the morphing inset rect.
class _MorphPanel extends StatelessWidget {
  const _MorphPanel({
    required this.width,
    required this.height,
    required this.radius,
    required this.side,
    required this.align,
    required this.progress,
    required this.reduce,
    required this.interactive,
    required this.colors,
    required this.content,
  });

  final double width;
  final double height;
  final double radius;
  final BeuiMorphPopoverSide side;
  final BeuiMorphPopoverAlign align;
  final double progress;
  final bool reduce;
  final bool interactive;
  final BeuiColors colors;
  final Widget content;

  /// The transform origin corner — `originFor(side, align)` in the source:
  /// vertical is the edge nearest the trigger, horizontal the aligned edge.
  Alignment get _origin {
    final top = side == BeuiMorphPopoverSide.bottom;
    final right = align == BeuiMorphPopoverAlign.end;
    if (top) return right ? Alignment.topRight : Alignment.topLeft;
    return right ? Alignment.bottomRight : Alignment.bottomLeft;
  }

  /// The current clip rect. Collapsed, only an ~8% sliver at the origin corner
  /// shows; at [progress] 1 the whole panel shows. Reduced motion always shows
  /// the full panel (movement dropped).
  Rect _clipRect() {
    if (reduce) return Rect.fromLTWH(0, 0, width, height);
    final hidden = 1.0 - progress; // 1 at corner, 0 when open
    final top =
        (side == BeuiMorphPopoverSide.bottom ? 0.0 : _clipHidden) * hidden;
    final bottom =
        (side == BeuiMorphPopoverSide.bottom ? _clipHidden : 0.0) * hidden;
    final right =
        (align == BeuiMorphPopoverAlign.end ? 0.0 : _clipHidden) * hidden;
    final left =
        (align == BeuiMorphPopoverAlign.end ? _clipHidden : 0.0) * hidden;
    return Rect.fromLTRB(
      left * width,
      top * height,
      width - right * width,
      height - bottom * height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clipRect();
    final scale = reduce ? 1.0 : _lerp(0.96, 1.0, progress);

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.foreground),
        child: SizedBox(width: width, height: height, child: content),
      ),
    );

    final morphed = Stack(
      clipBehavior: Clip.none,
      children: [
        // Drop-shadow that hugs the growing clipped shape: source
        // `drop-shadow(0 10px 18px rgba(0,0,0,0.14))`.
        Positioned.fromRect(
          rect: clip,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
        // Content, clipped by the morphing rounded-rect.
        ClipRRect(clipper: _InsetClipper(clip, radius), child: panel),
      ],
    );

    return IgnorePointer(
      ignoring: !interactive,
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: scale,
          alignment: _origin,
          child: morphed,
        ),
      ),
    );
  }
}

/// Clips to the morphing inset rounded-rect — the port of the source's
/// `inset(top right bottom left round radius)` clip-path.
class _InsetClipper extends CustomClipper<RRect> {
  const _InsetClipper(this.rect, this.radius);
  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_InsetClipper old) =>
      old.rect != rect || old.radius != radius;
}
