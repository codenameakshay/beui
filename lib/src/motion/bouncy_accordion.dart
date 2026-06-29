import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One row of a [BeuiBouncyAccordion].
///
/// Mirrors the source's `BouncyAccordionItem`: an [id] (the controlled value),
/// a [title], an optional [description] panel that springs open, an optional
/// leading [icon], and a [disabled] flag.
@immutable
class BeuiBouncyAccordionItem {
  /// Creates an accordion item. [id] uniquely identifies the row for the
  /// controlled/uncontrolled `value`.
  const BeuiBouncyAccordionItem({
    required this.id,
    required this.title,
    this.description,
    this.icon,
    this.disabled = false,
  });

  /// The row's identity — the value reported by [BeuiBouncyAccordion.onChanged]
  /// and matched against [BeuiBouncyAccordion.value].
  final String id;

  /// The always-visible trigger label.
  final Widget title;

  /// The collapsible panel content. When null, the row never expands (the
  /// chevron is omitted).
  final Widget? description;

  /// Optional leading glyph. Framework-native: an [IconData] glyph picked by the
  /// consumer; rendered in the muted foreground colour.
  final IconData? icon;

  /// When true, the row is dimmed and not tappable.
  final bool disabled;
}

// ---------------------------------------------------------------------------
// Component-local springs — the source's per-transition `duration`/`bounce`
// Framer specs converted to SpringDescription. These are NOT the canonical
// SPRING_* tokens (lib/src/tokens/motion.dart); they are bespoke to this
// component, exactly the localized-coupling case the spec allows.
//
// Conversion (Framer's underdamped duration+bounce resolver):
//   mass        = 1
//   ζ (zeta)    = 1 - bounce                       (damping ratio)
//   ω_d         = 2π / duration                    (damped angular freq)
//   ω₀          = ω_d / √(1 - ζ²)                   (undamped natural freq)
//   stiffness   = ω₀² · mass
//   damping     = ζ · 2 · √(stiffness · mass)
// `duration` is the *perceptual* reach time (≈ first crossing of target), not
// the full settle — matching how Framer interprets the spec. Lower bounce →
// less overshoot; the values below were validated by simulation.
// ---------------------------------------------------------------------------

/// Connected-group morph: row margin-top + corner radii (source `ROW_TRANSITION`,
/// duration 0.55 / bounce 0.38). The springiest of the four.
const _rowSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 212.0, damping: 18.05),
);

/// Panel height **opening** (source `CONTENT_OPEN_TRANSITION`, 0.58 / 0.32) —
/// a weighted, gently-bouncy expand.
const _contentOpenSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 218.3, damping: 20.09),
);

/// Panel height **closing** (source `CONTENT_CLOSE_TRANSITION`, 0.46 / 0.26) —
/// quicker and tighter than the open, so exits beat entrances.
const _contentCloseSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 412.4, damping: 30.06),
);

/// Chevron rotation (source `CHEVRON_TRANSITION`, 0.42 / 0.28).
const _chevronSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 464.7, damping: 31.04),
);

/// The description fade (source `DESCRIPTION_TRANSITION`, 0.18s EASE_OUT). A
/// pure opacity curve — kept even under reduced motion.
const _descriptionFade = CurvedMotion(Duration(milliseconds: 180), beuiEaseOut);

/// Test handle on a row's clipped, height-morphing content panel.
@visibleForTesting
ValueKey<String> beuiAccordionPanelKey(String id) =>
    ValueKey<String>('beui_accordion_panel_$id');

/// A single-open accordion whose panels **spring open by morphing height** with
/// a soft, weighted bounce, while the chevron rotates — the Flutter port of
/// beUI's `bouncy-accordion`.
///
/// Tapping a row opens it (and closes any other open row); tapping the open row
/// collapses it when [collapsible]. The panel's height is measured off-screen
/// (`GlobalKey` + `RenderBox`, post-frame) and animated with a spring
/// ([_contentOpenSpring] opening, [_contentCloseSpring] closing) under a clip,
/// the chevron rotates 0→180° on [_chevronSpring], and adjacent rows separate /
/// round their corners on [_rowSpring] — the source's connected-group motion.
///
/// Controlled when [value] is supplied (drive it from [onChanged]); otherwise
/// internal state seeded by [defaultValue]. Reduced motion snaps every morph
/// instantly while keeping the opacity fade and all content intact.
class BeuiBouncyAccordion extends StatefulWidget {
  /// Creates a single-open bouncy accordion over [items].
  const BeuiBouncyAccordion({
    required this.items,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.collapsible = true,
    super.key,
  });

  /// The rows, top to bottom.
  final List<BeuiBouncyAccordionItem> items;

  /// The open item's [BeuiBouncyAccordionItem.id], or null for all-collapsed.
  /// When non-null the accordion is *controlled* — keep it in sync via
  /// [onChanged]. Leave null for the uncontrolled pattern.
  final String? value;

  /// The initially-open id in the uncontrolled case (ignored when [value] is
  /// supplied).
  final String? defaultValue;

  /// Called with the new open id (or null when collapsing) on every toggle.
  final ValueChanged<String?>? onChanged;

  /// Whether tapping the open row may collapse it back to all-closed. When
  /// false, one row stays open once opened.
  final bool collapsible;

  @override
  State<BeuiBouncyAccordion> createState() => _BeuiBouncyAccordionState();
}

class _BeuiBouncyAccordionState extends State<BeuiBouncyAccordion> {
  String? _internalValue;

  bool get _isControlled => widget.value != null;
  String? get _activeValue => _isControlled ? widget.value : _internalValue;

  @override
  void initState() {
    super.initState();
    _internalValue = widget.defaultValue;
  }

  void _toggle(String id) {
    final next = _activeValue == id ? (widget.collapsible ? null : id) : id;
    if (next == _activeValue) return;
    if (!_isControlled) setState(() => _internalValue = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeValue;
    final activeIndex = widget.items.indexWhere((it) => it.id == active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Builder(
            builder: (context) {
              final item = widget.items[i];
              final open = item.id == active;
              final previousIsOpen = activeIndex == i - 1;
              final nextIsOpen = activeIndex == i + 1;
              // Source: grouped rows fuse (square inner corners); the open row
              // and the rows flanking the open one round + separate.
              final startsGroup = open || i == 0 || previousIsOpen;
              final endsGroup =
                  open || i == widget.items.length - 1 || nextIsOpen;
              final separatedFromPrevious = i > 0 && (open || previousIsOpen);

              return _AccordionRow(
                key: ValueKey<String>(item.id),
                item: item,
                open: open,
                startsGroup: startsGroup,
                endsGroup: endsGroup,
                separatedFromPrevious: separatedFromPrevious,
                onToggle: () => _toggle(item.id),
              );
            },
          ),
      ],
    );
  }
}

class _AccordionRow extends StatefulWidget {
  const _AccordionRow({
    required this.item,
    required this.open,
    required this.startsGroup,
    required this.endsGroup,
    required this.separatedFromPrevious,
    required this.onToggle,
    super.key,
  });

  final BeuiBouncyAccordionItem item;
  final bool open;
  final bool startsGroup;
  final bool endsGroup;
  final bool separatedFromPrevious;
  final VoidCallback onToggle;

  @override
  State<_AccordionRow> createState() => _AccordionRowState();
}

class _AccordionRowState extends State<_AccordionRow> {
  // Measures the natural panel height off the laid-out (but height-clipped to 0)
  // content, the same GlobalKey + RenderBox + post-frame pattern as
  // shared_layout_bg.dart.
  final GlobalKey _contentKey = GlobalKey();
  double _contentHeight = 0;

  /// Keyboard focus-visible state (source `focus-visible:bg-muted/25`). Hover is
  /// intentionally NOT tracked — the source button has no hover background.
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(_AccordionRow old) {
    super.didUpdateWidget(old);
    // Content may reflow (theme/text scale); re-measure each frame is cheap and
    // keeps the spring target honest.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _contentHeight).abs() > 0.5) {
      setState(() => _contentHeight = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final item = widget.item;

    final targetHeight = widget.open && item.description != null
        ? _contentHeight
        : 0.0;
    final heightMotion = widget.open ? _contentOpenSpring : _contentCloseSpring;

    final topRadius = widget.startsGroup ? 28.0 : 0.0;
    final bottomRadius = widget.endsGroup ? 28.0 : 0.0;

    // The measured content, rendered for layout but clipped by the morph above.
    final content = Padding(
      key: _contentKey,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), // px-5 pb-5
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 15,
          height: 24 / 15, // leading-6
          color: colors.mutedForeground,
        ),
        child: item.description ?? const SizedBox.shrink(),
      ),
    );

    final panel = ClipRect(
      child: _morph(
        targetHeight,
        heightMotion,
        reduce,
        _fadingContent(content),
      ),
    );

    // Stable inner content: the trigger (tap target) + panel, built once per
    // open/group change and threaded through the corner/margin springs as their
    // `child`, so a tap is never lost to the subtree being rebuilt mid-bounce.
    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_trigger(colors, reduce), panel],
    );

    // The surface morphs its corner radii on the row spring (snapped under
    // reduced motion). The two radii share one spring per side.
    final surface = _animDouble(
      topRadius,
      _rowSpring,
      reduce,
      inner,
      (tr, child) => _animDouble(bottomRadius, _rowSpring, reduce, child, (
        br,
        child,
      ) {
        // Springs can briefly overshoot below 0; radii must stay ≥ 0.
        final radius = BorderRadius.only(
          topLeft: Radius.circular(tr < 0 ? 0 : tr),
          topRight: Radius.circular(tr < 0 ? 0 : tr),
          bottomLeft: Radius.circular(br < 0 ? 0 : br),
          bottomRight: Radius.circular(br < 0 ? 0 : br),
        );
        return Container(
          decoration: BoxDecoration(color: colors.card, borderRadius: radius),
          clipBehavior: Clip.antiAlias, // overflow-hidden
          foregroundDecoration: item.disabled
              ? BoxDecoration(
                  color: colors.card.withValues(alpha: 0.5),
                  borderRadius: radius,
                )
              : null,
          child: child,
        );
      }),
    );

    // Separation from the previous row (source: animate marginTop 0 ↔ 12).
    // The source explicitly forbids positive-y overshoot here (it would drift a
    // row past its resting gap and overlap the next); clamp the spring at 0 so a
    // bouncy close never produces a negative top inset.
    return _animDouble(
      widget.separatedFromPrevious ? 12.0 : 0.0,
      _rowSpring,
      reduce,
      surface,
      (mt, child) => Padding(
        padding: EdgeInsets.only(top: mt < 0 ? 0.0 : mt),
        child: child,
      ),
    );
  }

  /// Spring-drives [target] through [build], threading a **stable** [child] so
  /// the wrapped subtree (notably the tap target) is built once, not rebuilt on
  /// every spring frame. Snaps instantly under reduced motion (movement → no
  /// animation; `NoMotion` would *hold* the old value rather than jump).
  Widget _animDouble(
    double target,
    Motion motion,
    bool reduce,
    Widget child,
    Widget Function(double value, Widget child) build,
  ) {
    if (reduce) return build(target, child);
    return SingleMotionBuilder(
      value: target,
      motion: motion,
      child: child,
      builder: (context, v, c) => build(v, c!),
    );
  }

  /// The clipped height morph over the measured [child]. Reduced motion snaps to
  /// the open/closed height; otherwise the height springs and the clip follows.
  Widget _morph(double target, Motion motion, bool reduce, Widget child) {
    Widget clip(double h) => Align(
      alignment: Alignment.topCenter,
      heightFactor: _contentHeight > 0
          ? (h / _contentHeight).clamp(0.0, 1.0)
          : (h > 0 ? 1.0 : 0.0),
      child: child,
    );
    if (reduce) return clip(target);
    return SingleMotionBuilder(
      value: target,
      motion: motion,
      builder: (context, h, _) => clip(h),
    );
  }

  /// The description's opacity fade. A pure opacity curve, so it is **kept**
  /// under reduced motion (only movement is dropped).
  Widget _fadingContent(Widget content) {
    return SingleMotionBuilder(
      value: widget.open ? 1.0 : 0.0,
      motion: _descriptionFade,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      child: KeyedSubtree(
        key: beuiAccordionPanelKey(widget.item.id),
        child: content,
      ),
    );
  }

  Widget _trigger(BeuiColors colors, bool reduce) {
    final item = widget.item;
    final hasPanel = item.description != null;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20), // px-5
        child: Row(
          children: [
            if (item.icon != null) ...[
              SizedBox(
                width: 28,
                height: 28,
                child: Icon(item.icon, size: 16, color: colors.mutedForeground),
              ),
              const SizedBox(width: 16), // gap-4
            ],
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                child: item.title,
              ),
            ),
            if (hasPanel) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: _animDouble(
                    widget.open ? 180.0 : 0.0,
                    _chevronSpring,
                    reduce,
                    Icon(
                      LucideIcons.chevron_down,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                    (deg, child) => Transform.rotate(
                      angle: deg * 3.1415926535897932 / 180.0,
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Focus-visible background only (source `focus-visible:bg-muted/25`); no
    // hover splash — the source button has none, and an InkWell paints its ink
    // on the ancestor Material (outside this row's rounded clip), so its hover
    // ignored the corners. This bg is inside the clipped surface, so it rounds
    // correctly. transition-colors → a short colour tween.
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: _focused && !item.disabled
          ? colors.muted.withValues(alpha: 0.25)
          : Colors.transparent,
      child: row,
    );

    return Semantics(
      button: true,
      enabled: !item.disabled,
      expanded: hasPanel ? widget.open : null,
      child: FocusableActionDetector(
        enabled: !item.disabled,
        mouseCursor:
            item.disabled ? MouseCursor.defer : SystemMouseCursors.click,
        onShowFocusHighlight: (focused) {
          if (mounted) setState(() => _focused = focused);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        // A plain opaque tap target — reliable (no ancestor-Material dependency)
        // and stable across spring frames since it's threaded as a child above.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: item.disabled ? null : widget.onToggle,
          child: body,
        ),
      ),
    );
  }
}
