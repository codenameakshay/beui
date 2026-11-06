import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';

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

enum _BloomMenuPhase { closed, open, closing }

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
  _BloomMenuPhase _phase = _BloomMenuPhase.closed;

  int _activeIndex = 0;

  final FocusNode _triggerFocusNode = FocusNode(
    debugLabel: 'Bloom menu trigger',
  );
  final List<FocusNode> _itemFocusNodes = [];
  bool _restoreTriggerFocus = false;
  bool _closeHasFocus = false;

  bool get _open => _phase == _BloomMenuPhase.open;

  /// Keeps the trigger hidden through the overlay's closing morph.
  bool get _overlayVisible => _phase != _BloomMenuPhase.closed;

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
    _syncItemFocusNodes();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _enterMs),
    );
  }

  @override
  void didUpdateWidget(covariant BeuiBloomMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItems(oldWidget.items, widget.items)) {
      final activeLabel = _activeIndex < oldWidget.items.length
          ? oldWidget.items[_activeIndex].label
          : null;
      final available = <String, List<FocusNode>>{};
      for (var i = 0; i < oldWidget.items.length; i++) {
        available
            .putIfAbsent(oldWidget.items[i].label, () => [])
            .add(_itemFocusNodes[i]);
      }
      _itemFocusNodes.clear();
      for (final item in widget.items) {
        final retained = available[item.label];
        _itemFocusNodes.add(
          retained != null && retained.isNotEmpty
              ? retained.removeAt(0)
              : FocusNode(debugLabel: 'Bloom menu item ${item.label}'),
        );
      }
      for (final removed in available.values.expand((nodes) => nodes)) {
        removed.dispose();
      }
      final retainedIndex = widget.items.indexWhere(
        (item) => item.label == activeLabel,
      );
      _activeIndex = retainedIndex < 0 ? 0 : retainedIndex;
      if (_open && retainedIndex < 0) {
        _requestActiveItemFocus();
      }
    }
  }

  bool _sameItems(List<BeuiBloomMenuItem> a, List<BeuiBloomMenuItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label || a[i].icon != b[i].icon) return false;
    }
    return true;
  }

  void _syncItemFocusNodes() {
    for (var i = 0; i < widget.items.length; i++) {
      _itemFocusNodes.add(
        FocusNode(debugLabel: 'Bloom menu item ${widget.items[i].label}'),
      );
    }
  }

  void _disposeItemFocusNodes() {
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    _itemFocusNodes.clear();
  }

  void _setOpen(bool value, {bool returnFocus = false}) {
    if (!mounted) return;
    _unhideTimer?.cancel();
    if (!value && returnFocus && _menuHasFocus) {
      _restoreTriggerFocus = true;
    }
    setState(() {
      _phase = value ? _BloomMenuPhase.open : _BloomMenuPhase.closing;
      if (value) {
        _activeIndex = 0;
      }
    });
    if (value) {
      _clock.forward(from: 0);
      _requestActiveItemFocus();
    } else {
      _clock.stop();
      // 420ms exit (see `exitDuration` below) plus ~60ms settle before the
      // in-tree trigger — hidden while the overlay's own copy morphs — comes
      // back.
      _unhideTimer = Timer(const Duration(milliseconds: 480), () {
        if (!mounted || _open) return;
        setState(() => _phase = _BloomMenuPhase.closed);
        if (_restoreTriggerFocus) {
          _restoreTriggerFocus = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _open) return;
            final currentFocus = FocusManager.instance.primaryFocus;
            if (currentFocus == null ||
                currentFocus is FocusScopeNode ||
                _menuHasFocus) {
              _triggerFocusNode.requestFocus();
            }
          });
        }
      });
    }
  }

  bool get _menuHasFocus =>
      _closeHasFocus || _itemFocusNodes.any((node) => node.hasFocus);

  void _requestActiveItemFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open && _itemFocusNodes.isNotEmpty) {
          _itemFocusNodes[_activeIndex].requestFocus();
        }
      });
    });
  }

  void _focusItem(int index) {
    if (_itemFocusNodes.isEmpty) return;
    final next = index.clamp(0, _itemFocusNodes.length - 1);
    setState(() => _activeIndex = next);
    _itemFocusNodes[next].requestFocus();
  }

  KeyEventResult _handleGridKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.items.isEmpty) {
      return KeyEventResult.ignored;
    }
    final last = widget.items.length - 1;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown => 3,
      LogicalKeyboardKey.arrowUp => -3,
      _ => null,
    };
    if (step != null) {
      final target = _activeIndex + step;
      if (target >= 0 && target <= last) _focusItem(target);
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      _focusItem(0);
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _focusItem(last);
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelect?.call(widget.items[_activeIndex].label);
      _setOpen(false, returnFocus: true);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _setOpen(false, returnFocus: true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _handleTriggerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _setOpen(true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _checkFocusLeaving() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open && !_menuHasFocus) _setOpen(false);
      });
    });
  }

  @override
  void dispose() {
    _unhideTimer?.cancel();
    _clock.dispose();
    _triggerFocusNode.dispose();
    _disposeItemFocusNodes();
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
    final reduce = MediaQuery.disableAnimationsOf(context);
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
                focusNodes: const [],
                activeIndex: _activeIndex,
                onItemFocus: (index) => _activeIndex = index,
                onGridKey: _handleGridKey,
                onFocusLeaving: _checkFocusLeaving,
                onCloseFocus: (_) {},
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
          trapFocus: false,
          enterDuration: const Duration(milliseconds: 240),
          exitDuration: const Duration(milliseconds: 420),
          overlayBuilder: (context, animation, link) =>
              _buildOverlay(context, animation, link, reduce: reduce),
          child: _Trigger(
            key: _triggerKey,
            label: widget.triggerLabel,
            colors: colors,
            hidden: _overlayVisible,
            focusNode: _triggerFocusNode,
            onKeyEvent: _handleTriggerKey,
            expanded: _open,
            onPressed: () => _setOpen(true),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    Animation<double> animation,
    LayerLink link, {
    required bool reduce,
  }) {
    final colors = BeuiColors.resolve(context);
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
                  focusNodes: _itemFocusNodes,
                  activeIndex: _activeIndex,
                  onItemFocus: (index) {
                    if (_activeIndex != index) {
                      setState(() => _activeIndex = index);
                    }
                  },
                  onGridKey: _handleGridKey,
                  onFocusLeaving: _checkFocusLeaving,
                  onCloseFocus: (focused) {
                    _closeHasFocus = focused;
                    if (!focused) _checkFocusLeaving();
                  },
                  colors: colors,
                  title: widget.triggerLabel,
                  clock: _clock,
                  reduce: reduce,
                  onClose: () => _setOpen(false, returnFocus: true),
                  onSelect: (label) {
                    widget.onSelect?.call(label);
                    if (mounted) _setOpen(false, returnFocus: true);
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
    required this.focusNode,
    required this.onKeyEvent,
    required this.expanded,
    required this.onPressed,
  });

  final String label;
  final BeuiColors colors;
  final bool hidden;
  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _pressed = false;
  bool _focusVisible = false;

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
    body = BeuiFocusRing(
      focused: _focusVisible,
      borderRadius: BorderRadius.circular(16),
      child: body,
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
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: !widget.hidden,
        skipTraversal: widget.hidden,
        onKeyEvent: widget.onKeyEvent,
        onFocusChange: (hasFocus) {
          setState(
            () => _focusVisible =
                hasFocus &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional,
          );
        },
        child: Semantics(
          container: true,
          button: true,
          focusable: true,
          focused: widget.focusNode.hasFocus,
          expanded: widget.expanded,
          label: widget.label,
          onTap: widget.onPressed,
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
    required this.focusNodes,
    required this.activeIndex,
    required this.onItemFocus,
    required this.onGridKey,
    required this.onFocusLeaving,
    required this.onCloseFocus,
    required this.colors,
    required this.title,
    this.clock,
    this.reduce = false,
    this.measuring = false,
    this.onClose,
    this.onSelect,
  });

  final List<BeuiBloomMenuItem> items;
  final List<FocusNode> focusNodes;
  final int activeIndex;
  final ValueChanged<int> onItemFocus;
  final KeyEventResult Function(FocusNode, KeyEvent) onGridKey;
  final VoidCallback onFocusLeaving;
  final ValueChanged<bool> onCloseFocus;
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
                          index: r * cols + c,
                          focusNode: measuring
                              ? null
                              : focusNodes[r * cols + c],
                          active: activeIndex == r * cols + c,
                          onFocus: onItemFocus,
                          onKeyEvent: onGridKey,
                          onFocusLeaving: onFocusLeaving,
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
                          borderBottom: r == 0,
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

    if (items.isNotEmpty) {
      grid = Semantics(
        container: true,
        explicitChildNodes: true,
        label: title,
        role: SemanticsRole.menu,
        child: grid,
      );
    }

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
              _CloseButton(
                colors: colors,
                onTap: onClose,
                onFocusChange: onCloseFocus,
              ),
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
  const _CloseButton({
    required this.colors,
    required this.onTap,
    required this.onFocusChange,
  });

  final BeuiColors colors;
  final VoidCallback? onTap;
  final ValueChanged<bool> onFocusChange;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;
  bool _focusVisible = false;
  late final FocusNode _focusNode = FocusNode(debugLabel: 'Close bloom menu');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focusNode,
    canRequestFocus: widget.onTap != null,
    skipTraversal: widget.onTap == null,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    onFocusChange: (focused) {
      setState(
        () => _focusVisible =
            focused &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional,
      );
      widget.onFocusChange(focused);
    },
    child: Semantics(
      button: widget.onTap != null,
      label: 'Close menu',
      onTap: widget.onTap,
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
            builder: (context, color, _) => BeuiFocusRing(
              focused: _focusVisible,
              borderRadius: BorderRadius.circular(4),
              child: Icon(LucideIcons.x, size: 16, color: color),
            ),
          ),
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
    required this.index,
    required this.focusNode,
    required this.active,
    required this.onFocus,
    required this.onKeyEvent,
    required this.onFocusLeaving,
    required this.colors,
    required this.delayMs,
    required this.clock,
    required this.reduce,
    required this.borderRight,
    required this.borderBottom,
    required this.onTap,
  });

  final BeuiBloomMenuItem item;
  final int index;
  final FocusNode? focusNode;
  final bool active;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final VoidCallback onFocusLeaving;
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
  bool _focusVisible = false;

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
        end: _hovered || _focusVisible
            ? colors.foreground
            : colors.mutedForeground,
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
    Widget cell = Semantics(
      button: onTap != null,
      focusable: onTap != null,
      focused: widget.focusNode?.hasFocus ?? false,
      label: item.label,
      role: onTap == null ? null : SemanticsRole.menuItem,
      onTap: onTap,
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
              color: _focusVisible ? colors.muted.withValues(alpha: 0.6) : null,
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
    final focusNode = widget.focusNode;
    if (focusNode != null) {
      cell = Focus(
        focusNode: focusNode,
        canRequestFocus: onTap != null,
        skipTraversal: !widget.active,
        onKeyEvent: widget.onKeyEvent,
        onFocusChange: (focused) {
          setState(
            () => _focusVisible =
                focused &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional,
          );
          if (focused) {
            widget.onFocus(widget.index);
          } else {
            widget.onFocusLeaving();
          }
        },
        child: cell,
      );
    }
    return cell;
  }
}
