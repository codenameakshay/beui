import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One entry in a [BeuiBloomMenu] grid (source `MenuItem`).
@immutable
class BeuiBloomMenuItem {
  /// Creates a menu entry. [icon] is a framework-native glyph.
  const BeuiBloomMenuItem({required this.label, required this.icon});

  /// The label shown under the icon and passed to [BeuiBloomMenu.onSelect].
  final String label;

  /// The cell glyph.
  final IconData icon;
}

/// The source's default six-item bloom menu (`ITEMS`, overridable per menu).
const List<BeuiBloomMenuItem> beuiDefaultBloomMenuItems = [
  BeuiBloomMenuItem(label: 'Doc', icon: LucideIcons.file_text),
  BeuiBloomMenuItem(label: 'Board', icon: LucideIcons.layout_grid),
  BeuiBloomMenuItem(label: 'Table', icon: LucideIcons.table),
  BeuiBloomMenuItem(label: 'Folder', icon: LucideIcons.folder_closed),
  BeuiBloomMenuItem(label: 'Reminder', icon: LucideIcons.bell),
  BeuiBloomMenuItem(label: 'Link', icon: LucideIcons.link),
];

/// Folder-open feel: a touch of overshoot as the panel expands, kept subtle
/// (source `SPRING_FOLDER`, stiffness 300 · damping 32 · mass 0.9).
const _folderSpring = SpringMotion(
  SpringDescription(mass: 0.9, stiffness: 300, damping: 32),
);

/// Per-item bloom spring (source item transition, stiffness 440 · damping 34).
const _itemSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 440, damping: 34),
);

const _triggerSize = Size(144, 44); // source `h-11 w-36`
const _panelMaxWidth = 420.0; // min(86vw, 420px)
const _enterMs = 800; // hosts the 0.08s + 0.45s iris + item staggers

/// A "Create" pill that blooms open into a grid menu — the Flutter port of
/// beUI's `bloom-menu` block.
///
/// The pill and the open panel are one **shared element**: the box morphs its
/// size between them on [_folderSpring], growing from the shared centre outward
/// in every direction (source `layoutId` FLIP). As it opens, the grid does an
/// **iris reveal** — a clip that starts as a small centred box
/// (`inset(45% 34%)`) and opens to all four corners over 450ms `EASE_OUT` — and
/// each cell's content springs in on a **radial stagger** (delay ∝ distance
/// from the grid centre × 70ms, [_itemSpring], scale 0.85 through a 6px blur),
/// so the four corners animate together and the open reads centre-out, not
/// corner-by-corner.
///
/// Rendered through [BeuiOverlay] (transparent barrier): the panel is mounted in
/// the root overlay, so it escapes ancestor `Transform`/`ClipRect` and stays
/// tappable beyond the trigger's bounds — the containing-block-safe version of
/// the source's absolute overlay. Closes on Escape, on a tap outside, or on
/// selecting an item.
///
/// Reduced motion swaps trigger/panel with quick fades — no morph, iris, or
/// item movement — while keeping opacity transitions.
class BeuiBloomMenu extends StatefulWidget {
  /// Creates a bloom menu.
  const BeuiBloomMenu({
    this.items = beuiDefaultBloomMenuItems,
    this.onSelect,
    this.triggerLabel = 'Create',
    super.key,
  });

  /// The grid entries (3 columns). Defaults to [beuiDefaultBloomMenuItems].
  final List<BeuiBloomMenuItem> items;

  /// Called with an item's label when it is chosen; the menu closes after.
  final ValueChanged<String>? onSelect;

  /// Drives BOTH the collapsed pill and the open panel header.
  final String triggerLabel;

  @override
  State<BeuiBloomMenu> createState() => _BeuiBloomMenuState();
}

class _BeuiBloomMenuState extends State<BeuiBloomMenu>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  /// True while the overlay is mounted (open or morphing closed) — the in-tree
  /// trigger stays hidden until the box has shrunk back onto it.
  bool _overlayVisible = false;

  final GlobalKey _sizerKey = GlobalKey();
  Size? _panelSize;

  // Source's collapsed trigger is a fixed `w-36` (144px) with a hardcoded
  // "Create" label. The port adds an optional [triggerLabel]; to keep a longer
  // label from overflowing, the pill is min-width 144 (== source at the default
  // label) and content-sized beyond that. Measure it so the shared-element morph
  // starts from the real pill size.
  final GlobalKey _triggerKey = GlobalKey();
  Size? _triggerMeasured;

  /// One clock for the delayed choreography (content fade at 120ms, iris at
  /// 80–530ms, radial item staggers). Created eagerly: a lazily-initialized
  /// ticker first touched in dispose() trips TickerMode's deactivated-ancestor
  /// lookup.
  late final AnimationController _clock;

  /// Unhides the in-tree trigger once the shrink morph has landed; cancelled
  /// on dispose and whenever the menu reopens before it fires.
  Timer? _unhideTimer;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _enterMs),
    );
  }

  void _setOpen(bool value) {
    _unhideTimer?.cancel();
    setState(() {
      _open = value;
      if (value) _overlayVisible = true;
    });
    if (value) {
      _clock.forward(from: 0);
    } else {
      _clock.stop();
      // 420ms exit (see `exitDuration` below) plus ~60ms settle before the
      // in-tree trigger — hidden while the overlay's own copy morphs — comes
      // back.
      _unhideTimer = Timer(const Duration(milliseconds: 480), () {
        if (mounted && !_open) setState(() => _overlayVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _unhideTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _sizerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.size != _panelSize) {
        setState(() => _panelSize = box.size);
      }
      final trigger =
          _triggerKey.currentContext?.findRenderObject() as RenderBox?;
      if (trigger != null &&
          trigger.hasSize &&
          trigger.size != _triggerMeasured) {
        setState(() => _triggerMeasured = trigger.size);
      }
    });
  }

  double _panelWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.86, _panelMaxWidth);

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    _scheduleMeasure();

    return Stack(
      children: [
        // Offstage sizer: the open panel's natural size at the target width.
        Offstage(
          child: KeyedSubtree(
            key: _sizerKey,
            child: SizedBox(
              width: _panelWidth(context),
              child: _PanelContent(
                items: widget.items,
                colors: colors,
                title: widget.triggerLabel,
                measuring: true,
              ),
            ),
          ),
        ),
        BeuiOverlay(
          open: _open,
          onDismiss: () => _setOpen(false),
          barrierColor: const Color(0x00000000), // outside tap closes, unseen
          enterDuration: const Duration(milliseconds: 240),
          exitDuration: const Duration(milliseconds: 420),
          overlayBuilder: _buildOverlay,
          child: _Trigger(
            key: _triggerKey,
            label: widget.triggerLabel,
            colors: colors,
            hidden: _overlayVisible,
            onPressed: () => _setOpen(true),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final panelSize = _panelSize ?? Size(_panelWidth(context), 300);
    final triggerSize = _triggerMeasured ?? _triggerSize;

    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      // The morphing box grows from the shared centre outward (the source's
      // centering box).
      child: MotionBuilder<Size>(
        value: _open ? panelSize : triggerSize,
        from: triggerSize,
        converter: const SizeMotionConverter(),
        motion: motionFor(
          context,
          _folderSpring,
          isMovement: true,
          reducedFallback: const CurvedMotion(
            Duration(milliseconds: 150),
            beuiEaseOut,
          ),
        ),
        builder: (context, size, child) => Container(
          width: size.width,
          height: size.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: child,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Panel content: fades in after 120ms (200ms window), out on close.
            AnimatedBuilder(
              animation: Listenable.merge([_clock, animation]),
              builder: (context, child) {
                final closing =
                    animation.status == AnimationStatus.reverse || !_open;
                final elapsed = _clock.value * _enterMs;
                final opacity = closing
                    ? animation.value.clamp(0.0, 1.0)
                    : reduce
                    ? 1.0
                    : ((elapsed - 120) / 200).clamp(0.0, 1.0);
                return Opacity(opacity: opacity, child: child);
              },
              child: SizedBox(
                width: _panelWidth(context),
                child: _PanelContent(
                  items: widget.items,
                  colors: colors,
                  title: widget.triggerLabel,
                  clock: _clock,
                  reduce: reduce,
                  onClose: () => _setOpen(false),
                  onSelect: (label) {
                    widget.onSelect?.call(label);
                    _setOpen(false);
                  },
                ),
              ),
            ),
            // The trigger label rides the shrinking box on close, so the morph
            // lands seamlessly on the real (unhidden) trigger.
            if (!_open)
              IgnorePointer(
                child: FadeTransition(
                  opacity: ReverseAnimation(animation),
                  child: _TriggerLabel(
                    label: widget.triggerLabel,
                    colors: colors,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Trigger extends StatefulWidget {
  const _Trigger({
    super.key,
    required this.label,
    required this.colors,
    required this.hidden,
    required this.onPressed,
  });

  final String label;
  final BeuiColors colors;
  final bool hidden;
  final VoidCallback onPressed;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Source pill is fixed `w-36 h-11` (px-5). To support the additive
    // [triggerLabel] without overflow the port keeps the height fixed but makes
    // the width content-sized with a min of 144 — so the default "Create" keeps
    // the exact source resting width (144) and
    // longer labels grow instead of overflowing.
    // No `alignment:` here — a Container with one expands to the incoming
    // constraints even when they are merely loose, which rendered the pill
    // full-bleed. The label Row centres itself inside the min-width instead.
    Widget body = Container(
      height: _triggerSize.height,
      constraints: BoxConstraints(minWidth: _triggerSize.width),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _TriggerLabel(label: widget.label, colors: colors),
    );

    // Trigger press feedback — source `whileTap={{ scale: 0.97 }}`.
    body = SingleMotionBuilder(
      value: _pressed && !reduce ? 0.97 : 1.0,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: body,
    );

    return Visibility(
      visible: !widget.hidden,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        button: true,
        expanded: widget.hidden,
        label: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: body,
          ),
        ),
      ),
    );
  }
}

class _TriggerLabel extends StatelessWidget {
  const _TriggerLabel({required this.label, required this.colors});

  final String label;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8, // gap-2
      children: [
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.foreground,
          ),
        ),
        Icon(LucideIcons.plus, size: 16, color: colors.foreground),
      ],
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.items,
    required this.colors,
    required this.title,
    this.clock,
    this.reduce = false,
    this.measuring = false,
    this.onClose,
    this.onSelect,
  });

  final List<BeuiBloomMenuItem> items;
  final BeuiColors colors;
  final String title;
  final Animation<double>? clock;
  final bool reduce;
  final bool measuring;
  final VoidCallback? onClose;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    const cols = 3;
    final rows = (items.length / cols).ceil();

    Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < cols; c++)
                Expanded(
                  child: r * cols + c < items.length
                      ? _Cell(
                          item: items[r * cols + c],
                          colors: colors,
                          // Radial stagger: distance from the grid centre.
                          delayMs: reduce || measuring
                              ? 0
                              : 100 +
                                    math.sqrt(
                                          math.pow(c - (cols - 1) / 2, 2) +
                                              math.pow(r - (rows - 1) / 2, 2),
                                        ) *
                                        70,
                          clock: measuring ? null : clock,
                          reduce: reduce,
                          borderRight: c != cols - 1,
                          borderBottom: r != rows - 1,
                          onTap: onSelect == null
                              ? null
                              : () => onSelect!(items[r * cols + c].label),
                        )
                      : const SizedBox(height: 96),
                ),
            ],
          ),
      ],
    );

    // Iris reveal: inset(45% 34%) → inset(0) over 450ms EASE_OUT, 80ms delay.
    if (!measuring && clock != null && !reduce) {
      grid = AnimatedBuilder(
        animation: clock!,
        builder: (context, child) {
          final elapsed = clock!.value * _enterMs;
          final t = beuiEaseOut.transform(
            ((elapsed - 80) / 450).clamp(0.0, 1.0),
          );
          return ClipRect(
            clipper: _IrisClipper(progress: t),
            child: child,
          );
        },
        child: grid,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header (px-4 py-3, border-b) — shows [title] (the trigger label).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              _CloseButton(colors: colors, onTap: onClose),
            ],
          ),
        ),
        grid,
      ],
    );
  }
}

/// Tailwind `transition-colors` — 150ms on its default ease.
const _hoverFade = Duration(milliseconds: 150);
const _hoverCurve = Curves.fastOutSlowIn;

/// The header dismiss glyph (source `hover:text-foreground`).
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.colors, required this.onTap});

  final BeuiColors colors;
  final VoidCallback? onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Close menu',
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: TweenAnimationBuilder<Color?>(
          duration: _hoverFade,
          curve: _hoverCurve,
          tween: ColorTween(
            end: _hovered
                ? widget.colors.foreground
                : widget.colors.mutedForeground,
          ),
          builder: (context, color, _) =>
              Icon(LucideIcons.x, size: 16, color: color),
        ),
      ),
    ),
  );
}

/// Iris clip: `inset(45% 34% 45% 34%)` → `inset(0)`.
class _IrisClipper extends CustomClipper<Rect> {
  _IrisClipper({required this.progress});

  final double progress;

  @override
  Rect getClip(Size size) {
    final dx = size.width * 0.34 * (1 - progress);
    final dy = size.height * 0.45 * (1 - progress);
    return Rect.fromLTRB(dx, dy, size.width - dx, size.height - dy);
  }

  @override
  bool shouldReclip(_IrisClipper old) => old.progress != progress;
}

class _Cell extends StatefulWidget {
  const _Cell({
    required this.item,
    required this.colors,
    required this.delayMs,
    required this.clock,
    required this.reduce,
    required this.borderRight,
    required this.borderBottom,
    required this.onTap,
  });

  final BeuiBloomMenuItem item;
  final BeuiColors colors;
  final double delayMs;
  final Animation<double>? clock;
  final bool reduce;
  final bool borderRight;
  final bool borderBottom;
  final VoidCallback? onTap;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = widget.colors;
    final clock = widget.clock;
    final reduce = widget.reduce;
    final delayMs = widget.delayMs;
    final onTap = widget.onTap;

    // Source cell: `text-muted-foreground transition-colors
    // hover:text-foreground` — icon and label brighten together.
    Widget content = TweenAnimationBuilder<Color?>(
      duration: _hoverFade,
      curve: _hoverCurve,
      tween: ColorTween(
        end: _hovered ? colors.foreground : colors.mutedForeground,
      ),
      builder: (context, color, _) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8, // gap-2
        children: [
          Icon(item.icon, size: 20, color: color),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );

    // Bloom-in: released at the radial delay, spring 440/34 from scale 0.85
    // through a 6px blur.
    if (clock != null && !reduce) {
      content = AnimatedBuilder(
        animation: clock,
        builder: (context, child) {
          final released = clock.value * _enterMs >= delayMs;
          return SingleMotionBuilder(
            value: released ? 1.0 : 0.0,
            from: 0.0,
            motion: _itemSpring,
            builder: (context, t, inner) {
              final clamped = t.clamp(0.0, 1.0);
              final sigma = 3.0 * (1 - clamped); // blur(6px) ≈ σ3
              Widget body = inner!;
              if (sigma > 0.05) {
                body = ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                    tileMode: TileMode.decal,
                  ),
                  child: body,
                );
              }
              return Opacity(
                opacity: clamped,
                child: Transform.scale(scale: 0.85 + 0.15 * t, child: body),
              );
            },
            child: child,
          );
        },
        child: content,
      );
    }

    // Static cell with hairline borders (no animated fill) so the grid lines
    // never flicker as items stagger in.
    return Semantics(
      button: onTap != null,
      label: item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            decoration: BoxDecoration(
              border: Border(
                // Tailwind `border-r` / `border-b` are a full 1px.
                right: widget.borderRight
                    ? BorderSide(color: colors.border)
                    : BorderSide.none,
                bottom: widget.borderBottom
                    ? BorderSide(color: colors.border)
                    : BorderSide.none,
              ),
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
