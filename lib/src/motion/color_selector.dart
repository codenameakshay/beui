import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// A composable color radio group with a shared, spring-gliding selection ring.
class BeuiColorSelector extends StatefulWidget {
  const BeuiColorSelector({
    this.value,
    this.defaultValue,
    this.onChanged,
    this.name,
    this.requiredFlag = false,
    this.disabled = false,
    required this.children,
    super.key,
  });

  final String? value;
  final String? defaultValue;
  final ValueChanged<String>? onChanged;
  final String? name;
  final bool requiredFlag;
  final bool disabled;
  final List<Widget> children;

  @override
  State<BeuiColorSelector> createState() => _BeuiColorSelectorState();
}

class _BeuiColorSelectorState extends State<BeuiColorSelector> {
  final _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, Color> _itemColors = {};
  final Map<String, bool> _itemDisabled = {};
  final List<String> _itemOrder = [];
  String? _internal;
  Rect? _target;
  Color? _builtSelectedColor;
  String? _pressed;

  void _press(String? value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  bool get _controlled => widget.value != null;
  String? get _selected => _controlled ? widget.value : _internal;
  List<String> get _enabledOrder => _itemOrder
      .where((value) => !widget.disabled && _itemDisabled[value] != true)
      .toList();

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValue;
  }

  void _register(
    String value,
    GlobalKey key,
    FocusNode focusNode,
    Color color,
    bool disabled,
  ) {
    // Unkeyed items can keep their state while changing their value.
    _itemKeys.removeWhere((registeredValue, registeredKey) {
      if (registeredValue == value || registeredKey != key) return false;
      _focusNodes.remove(registeredValue);
      _itemColors.remove(registeredValue);
      _itemDisabled.remove(registeredValue);
      _itemOrder.remove(registeredValue);
      return true;
    });
    _itemKeys[value] = key;
    _focusNodes[value] = focusNode;
    _itemColors[value] = color;
    _itemDisabled[value] = disabled;
    if (!_itemOrder.contains(value)) _itemOrder.add(value);
  }

  void _select(String value) {
    if (widget.disabled || _itemDisabled[value] == true || _selected == value) {
      return;
    }
    if (!_controlled) setState(() => _internal = value);
    widget.onChanged?.call(value);
  }

  void _measure() {
    if (!mounted) return;
    final liveItems = <({String value, Offset position})>[];
    for (final entry in _itemKeys.entries.toList(growable: false)) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        final value = entry.key;
        _itemKeys.remove(value);
        _focusNodes.remove(value);
        _itemColors.remove(value);
        _itemDisabled.remove(value);
        continue;
      }
      liveItems.add((
        value: entry.key,
        position: box.localToGlobal(Offset.zero),
      ));
    }
    liveItems.sort((a, b) {
      final row = a.position.dy.compareTo(b.position.dy);
      return row == 0 ? a.position.dx.compareTo(b.position.dx) : row;
    });
    final order = liveItems.map((item) => item.value).toList();
    final orderChanged = !_sameOrder(order, _itemOrder);
    if (orderChanged) {
      _itemOrder
        ..clear()
        ..addAll(order);
    }
    final parent = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final item = _selected == null
        ? null
        : _itemKeys[_selected!]?.currentContext?.findRenderObject()
              as RenderBox?;
    Rect? next;
    if (parent != null && item != null && item.hasSize) {
      final topLeft = parent.globalToLocal(item.localToGlobal(Offset.zero));
      next = topLeft & item.size;
    }
    final selectedColor = _itemColors[_selected];
    if (next != _target ||
        orderChanged ||
        selectedColor != _builtSelectedColor) {
      setState(() => _target = next);
    }
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    _builtSelectedColor = _itemColors[_selected];
    return _ColorSelectorScope(
      state: this,
      selected: _selected,
      reduce: reduce,
      disabled: widget.disabled,
      tabStop: _enabledOrder.contains(_selected)
          ? _selected
          : _enabledOrder.firstOrNull,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            if (widget.children.any(
              (child) =>
                  child is BeuiColorSelectorLabel ||
                  child is BeuiColorSelectorList,
            ))
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: widget.children,
              ),
            if (_target != null && _itemOrder.contains(_selected))
              _SelectionRing(
                target: _target!.inflate(4),
                color: (_itemColors[_selected] ?? colors.primary).withValues(
                  alpha: 0.65,
                ),
                reduce: reduce,
                pressed: _pressed == _selected,
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorSelectorScope extends InheritedWidget {
  const _ColorSelectorScope({
    required this.state,
    required this.selected,
    required this.reduce,
    required this.disabled,
    required this.tabStop,
    required super.child,
  });
  final _BeuiColorSelectorState state;
  final String? selected;
  final bool reduce;
  final bool disabled;
  final String? tabStop;
  static _ColorSelectorScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ColorSelectorScope>()!;
  @override
  bool updateShouldNotify(_ColorSelectorScope old) =>
      selected != old.selected ||
      reduce != old.reduce ||
      disabled != old.disabled ||
      tabStop != old.tabStop;
}

/// Group label, rendered with Flutter's fieldset-equivalent [Semantics] label.
class BeuiColorSelectorLabel extends StatelessWidget {
  const BeuiColorSelectorLabel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: BeuiColors.resolve(context).mutedForeground,
        ),
        child: child,
      ),
    ),
  );
}

/// Horizontal, wrapping list of color choices.
class BeuiColorSelectorList extends StatelessWidget {
  const BeuiColorSelectorList({
    required this.children,
    this.spacing = 12,
    super.key,
  });
  final List<Widget> children;
  final double spacing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

/// An accessible radio choice displaying a color swatch.
class BeuiColorSelectorItem extends StatefulWidget {
  const BeuiColorSelectorItem({
    required this.value,
    required this.color,
    required this.label,
    this.disabled = false,
    super.key,
  });
  final String value;
  final Color color;
  final String label;
  final bool disabled;
  @override
  State<BeuiColorSelectorItem> createState() => _BeuiColorSelectorItemState();
}

class _BeuiColorSelectorItemState extends State<BeuiColorSelectorItem> {
  final _focus = FocusNode(debugLabel: 'Color selector option');
  final _itemKey = GlobalKey();
  bool _pressed = false;
  bool _focusVisible = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _ColorSelectorScope.of(context);
    final selected = scope.selected == widget.value;
    final state = scope.state;
    state._register(
      widget.value,
      _itemKey,
      _focus,
      widget.color,
      widget.disabled,
    );
    final unavailable = scope.disabled || widget.disabled;
    _focus.skipTraversal =
        unavailable ||
        (scope.tabStop ?? state._enabledOrder.firstOrNull) != widget.value;
    final scale = _pressed && !scope.reduce && !unavailable ? 0.94 : 1.0;
    return Semantics(
      key: _itemKey,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: widget.label,
      enabled: !unavailable,
      child: MouseRegion(
        cursor: unavailable
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: Opacity(
          opacity: unavailable ? 0.4 : 1,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final delta = switch (event.logicalKey) {
                LogicalKeyboardKey.arrowRight ||
                LogicalKeyboardKey.arrowDown => 1,
                LogicalKeyboardKey.arrowLeft ||
                LogicalKeyboardKey.arrowUp => -1,
                _ => 0,
              };
              if (delta == 0) return KeyEventResult.ignored;
              final all = state._enabledOrder;
              if (all.isEmpty) return KeyEventResult.ignored;
              final index = all.indexOf(widget.value);
              final next = all[(index + delta + all.length) % all.length];
              state._select(next);
              // Focus the corresponding choice after the group rebuild.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                state._focusNodes[next]?.requestFocus();
              });
              return KeyEventResult.handled;
            },
            child: FocusableActionDetector(
              focusNode: _focus,
              enabled: !unavailable,
              onShowFocusHighlight: (value) =>
                  setState(() => _focusVisible = value),
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    state._select(widget.value);
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                onTap: unavailable
                    ? null
                    : () {
                        _focus.requestFocus();
                        state._select(widget.value);
                      },
                onTapDown: unavailable
                    ? null
                    : (_) {
                        setState(() => _pressed = true);
                        state._press(widget.value);
                      },
                onTapUp: (_) {
                  setState(() => _pressed = false);
                  state._press(null);
                },
                onTapCancel: () {
                  setState(() => _pressed = false);
                  state._press(null);
                },
                child: SingleMotionBuilder(
                  value: scale,
                  motion: motionFor(context, beuiSpringPress, isMovement: true),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BeuiColors.resolve(
                              context,
                            ).muted.withValues(alpha: 0.6),
                            border: Border.all(
                              color: BeuiColors.resolve(
                                context,
                              ).foreground.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        if (_focusVisible)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: BeuiColors.resolve(context).foreground,
                                width: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionRing extends StatefulWidget {
  const _SelectionRing({
    required this.target,
    required this.color,
    required this.reduce,
    required this.pressed,
  });
  final Rect target;
  final Color color;
  final bool reduce;
  final bool pressed;

  @override
  State<_SelectionRing> createState() => _SelectionRingState();
}

class _SelectionRingState extends State<_SelectionRing>
    with SingleTickerProviderStateMixin {
  late Rect _from = widget.target;
  late Rect _to = widget.target;
  late final SingleMotionController _progress;

  @override
  void initState() {
    super.initState();
    _progress = SingleMotionController(
      motion: beuiSpringLayout,
      vsync: this,
      initialValue: 1,
    );
  }

  Rect _atProgress(double progress) {
    final t = progress.clamp(0.0, 1.0);
    final delta = _to.center - _from.center;
    // Source arc({strength: -0.2}) peaks at 10% of the travel distance.
    final normal = delta.dx.abs() >= delta.dy.abs()
        ? Offset(delta.dy * delta.dx.sign, -delta.dx.abs())
        : Offset(-delta.dy.abs(), delta.dx * delta.dy.sign);
    return Rect.lerp(_from, _to, t)!.shift(normal * (0.4 * t * (1 - t)));
  }

  @override
  void didUpdateWidget(_SelectionRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target != _to) {
      _from = _atProgress(_progress.value);
      _to = widget.target;
      _progress.value = widget.reduce ? 1 : 0;
      if (!widget.reduce) {
        final destination = _to;
        _progress.animateTo(1).whenCompleteOrCancel(() {
          if (mounted && _to == destination) _progress.value = 1;
        });
      }
    } else if (widget.reduce && !oldWidget.reduce) {
      _progress.value = 1;
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Widget at(Rect rect) => Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: IgnorePointer(
      child: SingleMotionBuilder(
        value: widget.pressed && !widget.reduce ? 0.94 : 1.0,
        motion: motionFor(context, beuiSpringPress, isMovement: true),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: DecoratedBox(
          key: const ValueKey('beui_color_selector_ring'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 2),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) return at(widget.target);
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) => at(_atProgress(_progress.value)),
    );
  }
}
