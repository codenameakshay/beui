import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

const double _inset =
    4; // source `inset-1` — dot is the circle minus 4px each side.

/// Test handle on the shared selection dot, so motion tests can read its position.
@visibleForTesting
const beuiRadioDotKey = ValueKey<String>('beui_radio_dot');

/// A radio group with a single selection dot that **glides** between items —
/// the Flutter port of beUI's `radio`.
///
/// The dot is a shared element: rather than each item owning a dot, the group
/// overlays one dot (measured against the selected item) and springs it to the
/// chosen item with [beuiSpringLayout], the analog of the source's `layoutId`
/// shared-layout transition. Items render only their ring + press feedback.
///
/// Controlled **or** uncontrolled (per the source and `AGENTS.md`): pass [value]
/// + [onChanged], or seed [defaultValue] and let the group hold state.
///
/// Reduced motion snaps the dot to the selected item (no glide) — `motor`'s
/// NoMotion freezes at the source, so the dot is rendered directly at its
/// target rather than piped through the builder (see `docs/PORTING_SPEC.md` §1).
class BeuiRadioGroup<T> extends StatefulWidget {
  /// Creates a radio group from a list of [items].
  const BeuiRadioGroup({
    required this.items,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.orientation = Axis.vertical,
    this.spacing = 12,
    super.key,
  });

  /// The selectable items, each carrying a distinct [BeuiRadioItem.value].
  final List<BeuiRadioItem<T>> items;

  /// The selected value (controlled). When null, the group holds its own state.
  final T? value;

  /// The initial selection when uncontrolled.
  final T? defaultValue;

  /// Called with the newly selected value.
  final ValueChanged<T>? onChanged;

  /// Lay items out in a column ([Axis.vertical]) or wrapped row.
  final Axis orientation;

  /// Gap between items.
  final double spacing;

  @override
  State<BeuiRadioGroup<T>> createState() => _BeuiRadioGroupState<T>();
}

class _BeuiRadioGroupState<T> extends State<BeuiRadioGroup<T>> {
  final GlobalKey _stackKey = GlobalKey();
  late Map<T, GlobalKey> _circleKeys;
  T? _internal;
  Rect? _dotTarget;

  bool get _controlled => widget.value != null;
  T? get _current => _controlled ? widget.value : _internal;

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValue;
    _rebuildKeys();
  }

  @override
  void didUpdateWidget(BeuiRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final values = widget.items.map((i) => i.value).toSet();
    if (!values.containsAll(_circleKeys.keys) ||
        _circleKeys.length != values.length) {
      _rebuildKeys();
    }
  }

  void _rebuildKeys() {
    _circleKeys = {for (final item in widget.items) item.value: GlobalKey()};
  }

  void _select(T next) {
    if (!_controlled) setState(() => _internal = next);
    widget.onChanged?.call(next);
  }

  void _measure() {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final circleBox = _current == null
        ? null
        : _circleKeys[_current]?.currentContext?.findRenderObject()
              as RenderBox?;
    Rect? next;
    if (stackBox != null && circleBox != null && circleBox.hasSize) {
      final topLeft = stackBox.globalToLocal(
        circleBox.localToGlobal(Offset.zero),
      );
      next = Rect.fromLTWH(
        topLeft.dx + _inset,
        topLeft.dy + _inset,
        circleBox.size.width - 2 * _inset,
        circleBox.size.height - 2 * _inset,
      );
    }
    if (next != _dotTarget) setState(() => _dotTarget = next);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final list = widget.orientation == Axis.vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _withSpacing(widget.items, widget.spacing, Axis.vertical),
          )
        : Wrap(
            spacing: widget.spacing,
            runSpacing: widget.spacing,
            children: widget.items,
          );

    return _RadioScope<T>(
      selected: _current,
      onSelect: _select,
      circleKeys: _circleKeys,
      reduce: reduce,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Stack(
          key: _stackKey,
          children: [
            list,
            if (_dotTarget != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _GlidingDot(
                    target: _dotTarget!,
                    color: colors.primary,
                    reduce: reduce,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items, double gap, Axis axis) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(items[i]);
    }
    return out;
  }
}

/// Inherited group state read by [BeuiRadioItem].
class _RadioScope<T> extends InheritedWidget {
  const _RadioScope({
    required this.selected,
    required this.onSelect,
    required this.circleKeys,
    required this.reduce,
    required super.child,
  });

  final T? selected;
  final ValueChanged<T> onSelect;
  final Map<T, GlobalKey> circleKeys;
  final bool reduce;

  static _RadioScope<T> of<T>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RadioScope<T>>();
    assert(scope != null, 'BeuiRadioItem must be used inside a BeuiRadioGroup');
    return scope!;
  }

  @override
  bool updateShouldNotify(_RadioScope<T> old) =>
      selected != old.selected || reduce != old.reduce;
}

/// A single radio option. Renders its ring + press feedback; the selection dot
/// is supplied by the enclosing [BeuiRadioGroup].
class BeuiRadioItem<T> extends StatefulWidget {
  /// Creates a radio option with the given [value].
  const BeuiRadioItem({
    required this.value,
    this.label,
    this.enabled = true,
    this.size = 20,
    super.key,
  });

  /// This option's value; selecting it reports this through the group.
  final T value;

  /// Optional label rendered after the ring; tapping it selects this option.
  final String? label;

  /// Whether this option responds to input.
  final bool enabled;

  /// Ring diameter. Defaults to 20.
  final double size;

  @override
  State<BeuiRadioItem<T>> createState() => _BeuiRadioItemState<T>();
}

class _BeuiRadioItemState<T> extends State<BeuiRadioItem<T>> {
  late final FocusNode _focusNode = FocusNode();
  bool _pressed = false;
  bool _focusVisible = false;
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _RadioScope.of<T>(context);
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    final enabled = widget.enabled;
    final reduce = scope.reduce;
    final selected = scope.selected == widget.value;
    final size = widget.size;

    final borderColor = selected
        ? colors.primary
        : (_hovered && enabled
              ? colors.mutedForeground
              : colors.mutedForeground.withValues(alpha: 0.5));

    // Press scale: SPRING_PRESS with a reduce-gated target (NoMotion would
    // freeze a press mid-squish — see docs/PORTING_SPEC.md §1).
    final pressTarget = (_pressed && enabled && !reduce) ? 0.92 : 1.0;

    final ring = AnimatedContainer(
      key: scope.circleKeys[widget.value],
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );

    final ringed = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: _focusVisible
            ? [
                BoxShadow(color: colors.ring, spreadRadius: 4),
                BoxShadow(color: colors.background, spreadRadius: 2),
              ]
            : null,
      ),
      child: ring,
    );

    final control = Listener(
      onPointerDown: (_) {
        if (enabled) setState(() => _pressed = true);
      },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: _focusNode,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (enabled) scope.onSelect(widget.value);
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => scope.onSelect(widget.value) : null,
          child: SingleMotionBuilder(
            value: pressTarget,
            motion: beuiSpringPress,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Opacity(opacity: enabled ? 1.0 : 0.6, child: ringed),
          ),
        ),
      ),
    );

    final Widget row = widget.label == null
        ? control
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              control,
              const SizedBox(width: 12),
              GestureDetector(
                onTap: enabled ? () => scope.onSelect(widget.value) : null,
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: enabled ? 1.0 : 0.6,
                    child: Text(
                      widget.label!,
                      style: TextStyle(fontSize: 14, color: colors.foreground),
                    ),
                  ),
                ),
              ),
            ],
          );

    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: enabled,
        label: widget.label,
        child: row,
      ),
    );
  }
}

/// The shared selection dot. Glides to [target] with [beuiSpringLayout]; under
/// [reduce] it is placed directly at the target (no glide), since motor's
/// NoMotion would otherwise freeze it at the source position.
class _GlidingDot extends StatelessWidget {
  const _GlidingDot({
    required this.target,
    required this.color,
    required this.reduce,
  });

  final Rect target;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      key: beuiRadioDotKey,
      width: target.width,
      height: target.height,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    Widget at(Offset offset) => Transform.translate(
      offset: offset,
      child: Align(alignment: Alignment.topLeft, child: dot),
    );

    if (reduce) return at(target.topLeft);

    return MotionBuilder<Offset>(
      value: target.topLeft,
      motion: beuiSpringLayout,
      converter: const OffsetMotionConverter(),
      builder: (context, offset, _) => at(offset),
    );
  }
}
