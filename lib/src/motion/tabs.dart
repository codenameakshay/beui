import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Weighty spring for the active-tab indicator — a one-to-one port of the
/// source `tabs.tsx` `transition` const. A touch of overshoot (low damping,
/// high mass) so the pill settles with life. Component-local: intentionally
/// heavier than the shared `beuiSpringLayout`.
const _indicatorSpring = SpringMotion(
  SpringDescription(mass: 1.2, stiffness: 170, damping: 24),
);

/// Test handle on the gliding indicator, so motion tests can read its bounds.
@visibleForTesting
const beuiTabsIndicatorKey = ValueKey<String>('beui_tabs_indicator');

/// The three tab looks from the source.
enum BeuiTabsVariant {
  /// Rounded pill that slides behind the active tab (filled `bg-primary`).
  pill,

  /// Squarer segmented control; same sliding-fill trick as [pill].
  segment,

  /// A thin underline that glides along the bottom edge.
  underline,
}

/// A single tab: a [value], its [label], and optional [content] panel.
@immutable
class BeuiTab<T> {
  /// Creates a tab.
  const BeuiTab({required this.value, required this.label, this.content});

  /// This tab's value.
  final T value;

  /// The trigger label (usually a [Text]).
  final Widget label;

  /// Optional panel shown below the bar when this tab is active.
  final Widget? content;
}

/// Animated tabs with a gliding active indicator — the Flutter port of beUI's
/// `tabs` (pill / segment / underline).
///
/// The indicator is a shared element: one pill/line is measured against the
/// active trigger and springs to it (position **and** size) with the
/// component-local indicator spring, the analog of the source's `layoutId`.
/// The active panel fades up; the text colour cross-fades as the pill passes.
///
/// Controlled **or** uncontrolled (per the source): pass [value] + [onChanged],
/// or seed [defaultValue]. Keyboard: arrows move (and wrap) the selection,
/// Enter/Space activates the focused tab.
///
/// Reduced motion snaps the indicator to the active tab (no glide — `motor`'s
/// NoMotion freezes at the source, so it is rendered at target) and drops the
/// panel's slide, keeping the fade. See `docs/PORTING_SPEC.md` §1.
class BeuiTabs<T> extends StatefulWidget {
  /// Creates a tab bar from [tabs].
  const BeuiTabs({
    required this.tabs,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.variant = BeuiTabsVariant.pill,
    this.wrap = false,
    this.gap,
    this.listBorderRadius,
    this.triggerPadding,
    super.key,
  });

  /// The tabs, in order.
  final List<BeuiTab<T>> tabs;

  /// The selected value (controlled). When null, the bar holds its own state.
  final T? value;

  /// The initial selection when uncontrolled.
  final T? defaultValue;

  /// Called with the newly selected value.
  final ValueChanged<T>? onChanged;

  /// Which look to render.
  final BeuiTabsVariant variant;

  /// Flows the triggers onto multiple centred runs instead of one row — the
  /// source's `TabsList className="flex-wrap justify-center"`. The indicator
  /// still measures each trigger's rect, so it glides between runs.
  final bool wrap;

  /// Gap between triggers, overriding the variant default (source list
  /// `gap-*`: `gap-1` for pill/underline, `gap-0` for segment).
  final double? gap;

  /// The list's corner radius, overriding the variant default (source list
  /// `rounded-*`).
  final BorderRadiusGeometry? listBorderRadius;

  /// Each trigger's padding, overriding the variant default (source trigger
  /// `px-* py-*`).
  final EdgeInsetsGeometry? triggerPadding;

  @override
  State<BeuiTabs<T>> createState() => _BeuiTabsState<T>();
}

class _BeuiTabsState<T> extends State<BeuiTabs<T>> {
  final GlobalKey _stackKey = GlobalKey();
  late Map<T, GlobalKey> _triggerKeys;
  late Map<T, FocusNode> _focusNodes;
  T? _internal;
  Rect? _indicator;

  bool get _controlled => widget.value != null;
  T? get _current => _controlled ? widget.value : _internal;

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValue ?? widget.tabs.first.value;
    _rebuildMaps();
  }

  @override
  void didUpdateWidget(BeuiTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final values = widget.tabs.map((t) => t.value).toSet();
    if (values.length != _triggerKeys.length ||
        !values.containsAll(_triggerKeys.keys)) {
      for (final node in _focusNodes.values) {
        node.dispose();
      }
      _rebuildMaps();
    }
  }

  void _rebuildMaps() {
    _triggerKeys = {for (final t in widget.tabs) t.value: GlobalKey()};
    _focusNodes = {for (final t in widget.tabs) t.value: FocusNode()};
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(T next) {
    if (!_controlled) setState(() => _internal = next);
    widget.onChanged?.call(next);
  }

  void _move(T from, int delta) {
    final values = widget.tabs.map((t) => t.value).toList();
    final i = values.indexOf(from);
    if (i < 0) return;
    final next = values[(i + delta) % values.length];
    _select(next);
    _focusNodes[next]?.requestFocus();
  }

  void _measure() {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = _current == null
        ? null
        : _triggerKeys[_current]?.currentContext?.findRenderObject()
              as RenderBox?;
    Rect? next;
    if (stackBox != null && box != null && box.hasSize) {
      final topLeft = stackBox.globalToLocal(box.localToGlobal(Offset.zero));
      final rect = topLeft & box.size;
      next = switch (widget.variant) {
        // Source: `absolute -bottom-px left-0 right-0 h-px` — a 1px rule that
        // sits 1px *below* the trigger box, so it rides under the list's
        // `border-b` rather than covering it.
        BeuiTabsVariant.underline => Rect.fromLTWH(
          rect.left,
          rect.bottom,
          rect.width,
          1,
        ),
        _ => rect,
      };
    }
    if (next != _indicator) setState(() => _indicator = next);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final variant = widget.variant;

    final triggers = <Widget>[];
    for (final tab in widget.tabs) {
      triggers.add(
        _TabTrigger<T>(
          key: ValueKey(tab.value),
          measureKey: _triggerKeys[tab.value]!,
          focusNode: _focusNodes[tab.value]!,
          label: tab.label,
          variant: variant,
          padding: widget.triggerPadding,
          active: tab.value == _current,
          onSelect: () => _select(tab.value),
          onMove: (delta) => _move(tab.value, delta),
        ),
      );
    }

    final gap = widget.gap ?? (variant == BeuiTabsVariant.segment ? 0.0 : 4.0);
    final row = widget.wrap
        ? Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: triggers,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < triggers.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                triggers[i],
              ],
            ],
          );

    final indicatorLayer = _indicator == null
        ? const SizedBox.shrink()
        : Positioned.fill(
            child: IgnorePointer(
              child: _Indicator(
                target: _indicator!,
                variant: variant,
                color: colors.primary,
                reduce: reduce,
              ),
            ),
          );

    final stack = Stack(
      key: _stackKey,
      // A wrapped list shrink-wraps to its widest run, so the Stack's default
      // top-start placement would pin those runs to the left of a stretched
      // list. Centre them, matching the source's `justify-center`. Harmless in
      // row mode, where the Stack is already the row's width.
      alignment: widget.wrap ? Alignment.center : AlignmentDirectional.topStart,
      // The underline rule is deliberately 1px outside the list box (the
      // source's `-bottom-px`), so it must not be clipped away.
      clipBehavior: variant == BeuiTabsVariant.underline
          ? Clip.none
          : Clip.hardEdge,
      children: variant == BeuiTabsVariant.underline
          ? [row, indicatorLayer] // line on top
          : [indicatorLayer, row], // pill behind the text
    );

    final list = Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: _listDecoration(variant, colors),
        child: Padding(padding: _listPadding(variant), child: stack),
      ),
    );

    // The list (TabsList) is `inline-flex` in the source — content-sized and
    // left-aligned within its block. Keep the widget content-sized; the parent
    // decides placement (don't be greedy).
    final activeContent = _activeContent();
    if (activeContent == null) return list;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        list,
        const SizedBox(height: 16), // mt-4
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: beuiEaseOut,
          // Default layoutBuilder stacks children centered, which makes the
          // panel text drift to center mid-transition then snap left. Keep it
          // left-aligned throughout.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previousChildren, ?currentChild],
          ),
          transitionBuilder: (child, animation) {
            final fade = FadeTransition(opacity: animation, child: child);
            if (reduce) return fade;
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Transform.translate(
                offset: Offset(0, (1 - animation.value) * 4), // y: 4 → 0
                child: fade,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(_current), child: activeContent),
        ),
      ],
    );
  }

  Widget? _activeContent() {
    if (!widget.tabs.any((t) => t.content != null)) return null;
    for (final tab in widget.tabs) {
      if (tab.value == _current) return tab.content ?? const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  Decoration _listDecoration(BeuiTabsVariant variant, BeuiColors colors) {
    return switch (variant) {
      BeuiTabsVariant.pill => BoxDecoration(
        color: colors.card,
        borderRadius: widget.listBorderRadius ?? BorderRadius.circular(9999),
      ),
      BeuiTabsVariant.segment => BoxDecoration(
        color: colors.card,
        borderRadius:
            widget.listBorderRadius ?? BorderRadius.circular(8), // rounded-lg
      ),
      BeuiTabsVariant.underline => BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
    };
  }

  EdgeInsets _listPadding(BeuiTabsVariant variant) {
    return switch (variant) {
      BeuiTabsVariant.pill => const EdgeInsets.all(4),
      BeuiTabsVariant.segment => const EdgeInsets.all(2),
      BeuiTabsVariant.underline => EdgeInsets.zero,
    };
  }
}

/// The gliding indicator (pill / segment fill, or underline). Springs to
/// [target]; under [reduce] it is placed directly at the target (snap), since
/// motor's NoMotion would freeze it at the source.
class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.target,
    required this.variant,
    required this.color,
    required this.reduce,
  });

  final Rect target;
  final BeuiTabsVariant variant;
  final Color color;
  final bool reduce;

  BorderRadius _radius(Rect r) => switch (variant) {
    BeuiTabsVariant.pill => BorderRadius.circular(r.height / 2),
    BeuiTabsVariant.segment => BorderRadius.circular(8),
    BeuiTabsVariant.underline => BorderRadius.zero,
  };

  Widget _at(Rect r) => Transform.translate(
    offset: r.topLeft,
    child: Align(
      alignment: Alignment.topLeft,
      child: Container(
        key: beuiTabsIndicatorKey,
        width: r.width,
        height: r.height,
        decoration: BoxDecoration(color: color, borderRadius: _radius(r)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (reduce) return _at(target);
    return MotionBuilder<Rect>(
      value: target,
      motion: _indicatorSpring,
      converter: const RectMotionConverter(),
      builder: (context, r, _) => _at(r),
    );
  }
}

class _TabTrigger<T> extends StatefulWidget {
  const _TabTrigger({
    required this.measureKey,
    required this.focusNode,
    required this.label,
    required this.variant,
    required this.padding,
    required this.active,
    required this.onSelect,
    required this.onMove,
    super.key,
  });

  final GlobalKey measureKey;
  final FocusNode focusNode;
  final Widget label;
  final BeuiTabsVariant variant;
  final EdgeInsetsGeometry? padding;
  final bool active;
  final VoidCallback onSelect;
  final ValueChanged<int> onMove;

  @override
  State<_TabTrigger<T>> createState() => _TabTriggerState<T>();
}

class _TabTriggerState<T> extends State<_TabTrigger<T>> {
  bool _hovered = false;
  bool _focusVisible = false;

  Color _textColor(BeuiColors colors) {
    if (widget.active) {
      return widget.variant == BeuiTabsVariant.underline
          ? colors.foreground
          : colors.primaryForeground;
    }
    return _hovered ? colors.foreground : colors.mutedForeground;
  }

  EdgeInsetsGeometry get _padding =>
      widget.padding ??
      (widget.variant == BeuiTabsVariant.underline
          ? const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 6));

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);

    Widget content = Container(
      key: widget.measureKey,
      constraints: widget.variant == BeuiTabsVariant.underline
          ? const BoxConstraints(minHeight: 44)
          : const BoxConstraints(),
      padding: _padding,
      decoration: _focusVisible
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: colors.ring, spreadRadius: 2)],
            )
          : null,
      // `widthFactor: 1` sizes the trigger to its label; a bare
      // `Container(alignment:)` fills whatever bounded width it is given, which
      // in a `Wrap` inflates every trigger to full width and puts each on its
      // own run. Height still fills, so the underline variant's minHeight
      // keeps centring the label vertically.
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          // Built from the ambient style, not from scratch: `AnimatedDefaultText
          // Style` *replaces* the inherited `DefaultTextStyle`, so a bare
          // `TextStyle` here would drop the host font family and render the
          // trigger in the platform fallback face.
          style: DefaultTextStyle.of(context).style.copyWith(
            fontSize: 14,
            // `text-sm` is 14px/20px. Without an explicit line box the trigger
            // renders ~3px shorter than the source (29 vs 32).
            height: 20 / 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0, // tracking-normal
            color: _textColor(colors),
          ),
          child: widget.label,
        ),
      ),
    );

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onSelect();
            return null;
          },
        ),
        _MoveIntent: CallbackAction<_MoveIntent>(
          onInvoke: (intent) {
            widget.onMove(intent.delta);
            return null;
          },
        ),
      },
      onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      child: Semantics(
        selected: widget.active,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelect,
          child: content,
        ),
      ),
    );
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}
