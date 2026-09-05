import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/motion.dart';
import '../_engine.dart' show SingleMotionBuilder, SpringMotion;
import '_constants.dart';

/// Shared geometry passed to a morph panel body so it can react to the growth.
@immutable
class WalletMorphInfo {
  const WalletMorphInfo({
    required this.progress,
    required this.armed,
    required this.open,
    required this.width,
    required this.triggerLeft,
    required this.triggerWidth,
  });

  /// Morph progress, 0 (trigger) → 1 (full panel), on [kWalletMorph].
  final double progress;

  /// Whether hover interactions have armed (after the morph settles).
  final bool armed;

  /// The logical open flag (true from the moment it opens).
  final bool open;

  /// Final panel width in follower coordinates.
  final double width;

  /// X of the trigger's left edge inside the follower (where the box grows
  /// from) — used by the search bar to glide its leading icon in.
  final double triggerLeft;

  /// Trigger width, for glide math.
  final double triggerWidth;
}

/// Inherited handle to the wallet header row, shared by the account switcher and
/// the search bar so their morph panels can anchor to (and span) the full header
/// row — the Flutter stand-in for the source's shared `layoutId` living on the
/// `relative` header container.
class WalletHeaderScope extends InheritedWidget {
  /// Creates the scope.
  const WalletHeaderScope({
    required this.headerLink,
    required this.headerKey,
    required super.child,
    super.key,
  });

  /// Link the panels follow with a [CompositedTransformFollower].
  final LayerLink headerLink;

  /// Key on the header row's render box, used to measure its width.
  final GlobalKey headerKey;

  /// Reads the nearest scope.
  static WalletHeaderScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WalletHeaderScope>();
    assert(scope != null, 'WalletHeaderScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(WalletHeaderScope old) =>
      old.headerLink != headerLink || old.headerKey != headerKey;
}

/// A trigger that morphs into a full-header-width panel and back — the Flutter
/// port of the source's shared-`layoutId` morph (account switcher + search bar).
///
/// Framer animates the FLIP between the small trigger and the wide panel for us;
/// here the two rects are measured at runtime and the box is lerped between them
/// on [kWalletMorph] (spring, `duration 0.5 · bounce 0.22`). The panel renders
/// through an [OverlayPortal] anchored to the header row (via the shared
/// [LayerLink]) so it can span the row and cover the header icons while still
/// receiving pointer input — the DOM version relied on absolute `-left-2
/// -right-2` positioning inside the `relative` header. Dismisses on Escape or a
/// tap outside.
class MorphPanel extends StatefulWidget {
  /// Creates a morph panel.
  const MorphPanel({
    required this.open,
    required this.onOpen,
    required this.onDismiss,
    required this.trigger,
    required this.panelBuilder,
    this.armDelayMs = 280,
    super.key,
  });

  /// Whether the panel is open.
  final bool open;

  /// Called when the closed trigger is tapped.
  final VoidCallback onOpen;

  /// Called on Escape / tap-outside.
  final VoidCallback onDismiss;

  /// The in-flow, tappable trigger (sizes its row cell). Hidden while open.
  final Widget trigger;

  /// Builds the full-size panel content, given the live [WalletMorphInfo].
  final Widget Function(BuildContext, WalletMorphInfo) panelBuilder;

  /// Delay after opening before hover interactions arm (source 280/260ms).
  final int armDelayMs;

  @override
  State<MorphPanel> createState() => _MorphPanelState();
}

class _MorphPanelState extends State<MorphPanel> {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _measureKey = GlobalKey();
  final FocusScopeNode _focusNode = FocusScopeNode();

  double _headerWidth = 300;
  Rect _triggerRect = const Rect.fromLTWH(0, 0, 40, 40);
  double _panelHeight = 44;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  void didUpdateWidget(MorphPanel old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _armed = false;
      final reduce = MediaQuery.disableAnimationsOf(context);
      Future<void>.delayed(
        Duration(milliseconds: reduce ? 0 : widget.armDelayMs),
        () {
          if (mounted && widget.open) setState(() => _armed = true);
        },
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _measure() {
    final scope = WalletHeaderScope.of(context);
    final header =
        scope.headerKey.currentContext?.findRenderObject() as RenderBox?;
    final trigger =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final measure =
        _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (header == null || !header.hasSize) return;

    var changed = false;
    if (header.size.width != _headerWidth) {
      _headerWidth = header.size.width;
      changed = true;
    }
    if (trigger != null && trigger.hasSize) {
      final origin = header.localToGlobal(const Offset(-8, 0));
      final tg = trigger.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(
        tg.dx - origin.dx,
        tg.dy - origin.dy,
        trigger.size.width,
        trigger.size.height,
      );
      if (rect != _triggerRect) {
        _triggerRect = rect;
        changed = true;
      }
    }
    if (measure != null &&
        measure.hasSize &&
        measure.size.height != _panelHeight) {
      _panelHeight = measure.size.height;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final scope = WalletHeaderScope.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final panelWidth = _headerWidth + 16;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) =>
          _buildOverlay(overlayContext, scope.headerLink, panelWidth, reduce),
      // In-flow trigger. Kept in layout (maintainSize) but hidden + inert while
      // open, so the header row width never shifts.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Off-stage measure of the panel body at its final width/height.
          Positioned(
            left: 0,
            top: 0,
            child: Offstage(
              child: SizedBox(
                key: _measureKey,
                width: panelWidth,
                child: widget.panelBuilder(
                  context,
                  WalletMorphInfo(
                    progress: 1,
                    armed: false,
                    open: true,
                    width: panelWidth,
                    triggerLeft: _triggerRect.left,
                    triggerWidth: _triggerRect.width,
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: !widget.open,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.open ? null : widget.onOpen,
              child: KeyedSubtree(key: _triggerKey, child: widget.trigger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    LayerLink link,
    double panelWidth,
    bool reduce,
  ) {
    final colors = BeuiColors.resolve(context);

    // Under reduced motion the box snaps (stiff spring) rather than animating a
    // movement; the content still cross-fades.
    const snap = SpringMotion(
      SpringDescription(mass: 1, stiffness: 700, damping: 60),
    );

    return SingleMotionBuilder(
      value: widget.open ? 1.0 : 0.0,
      motion: reduce ? snap : kWalletMorph,
      builder: (context, p, _) {
        if (p < 0.001 && !widget.open) return const SizedBox.shrink();

        final target = Rect.fromLTWH(0, 0, panelWidth, _panelHeight);
        final rect = Rect.lerp(_triggerRect, target, p)!;
        final radius = _lerpDouble(
          _triggerRect.height / 2 < kPanelRadius
              ? _triggerRect.height / 2
              : kPanelRadius,
          kPanelRadius,
          p,
        );

        final info = WalletMorphInfo(
          progress: p,
          armed: _armed,
          open: widget.open,
          width: panelWidth,
          triggerLeft: _triggerRect.left,
          triggerWidth: _triggerRect.width,
        );

        return Stack(
          children: [
            // Transparent tap-outside barrier (source dismiss on pointerdown
            // outside). No dark scrim — matches the source.
            if (widget.open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDismiss,
                ),
              ),
            CompositedTransformFollower(
              link: link,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(-8, 0),
              child: FocusScope(
                node: _focusNode,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        widget.onDismiss,
                  },
                  child: SizedBox(
                    width: panelWidth,
                    height: _panelHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: rect.left,
                          top: rect.top,
                          width: rect.width,
                          height: rect.height,
                          child: _MorphBox(
                            radius: radius,
                            colors: colors,
                            reduce: reduce,
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: panelWidth,
                              maxWidth: panelWidth,
                              minHeight: _panelHeight,
                              maxHeight: _panelHeight,
                              child: widget.panelBuilder(context, info),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// The morphing surface chrome: bordered, background-filled, backdrop-blurred
/// rounded rect that clips its content as it grows (source `border
/// border-border/30 bg-background backdrop-blur-md`).
class _MorphBox extends StatelessWidget {
  const _MorphBox({
    required this.radius,
    required this.colors,
    required this.reduce,
    required this.child,
  });

  final double radius;
  final BeuiColors colors;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rrect = BorderRadius.circular(radius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(
          color: colors.border.withValues(alpha: colors.border.a * 0.3),
        ),
        borderRadius: rrect,
      ),
      child: child,
    );
    final clipped = ClipRRect(borderRadius: rrect, child: content);
    if (reduce) return clipped;
    // backdrop-blur-md (12px → σ6, within the σ10 static-glass budget).
    return ClipRRect(
      borderRadius: rrect,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: content,
      ),
    );
  }
}

/// A single list item that reveals with the source `ITEM` variant — rises from
/// `y:-6` under a `blur(3px)` and fades in, staggered by its [index]
/// (`delayChildren 0.12s + index·0.035s`). Reduced motion shows it instantly.
class WalletRevealItem extends StatefulWidget {
  /// Creates a staggered reveal wrapper.
  const WalletRevealItem({required this.index, required this.child, super.key});

  /// Position in the list (drives the stagger delay).
  final int index;

  /// The item content.
  final Widget child;

  @override
  State<WalletRevealItem> createState() => _WalletRevealItemState();
}

class _WalletRevealItemState extends State<WalletRevealItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // One controller spanning the stagger delay + the 260ms entrance; the delay
    // is folded into an [Interval] so no `Timer` is left dangling (source
    // `delayChildren + index·staggerChildren`).
    final delay = kListDelayChildrenMs + widget.index * kListStaggerMs;
    const enterMs = 260;
    final totalMs = delay + enterMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / totalMs, 1, curve: beuiEaseOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1; // appear instantly under reduced motion
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        final dy = kItemOffsetY * (1 - t);
        final sigma = beuiBlurSigma(kItemBlurPx) * (1 - t);
        Widget body = child!;
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
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: body),
        );
      },
    );
  }
}
