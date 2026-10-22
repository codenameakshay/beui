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
    required this.children,
    super.key,
  });

  final String? value;
  final String? defaultValue;
  final ValueChanged<String>? onChanged;
  final String? name;
  final bool requiredFlag;
  final List<Widget> children;

  @override
  State<BeuiColorSelector> createState() => _BeuiColorSelectorState();
}

class _BeuiColorSelectorState extends State<BeuiColorSelector> {
  final _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _internal;
  Rect? _target;

  bool get _controlled => widget.value != null;
  String? get _selected => _controlled ? widget.value : _internal;

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValue;
  }

  void _register(String value, GlobalKey key, FocusNode focusNode) {
    _itemKeys[value] = key;
    _focusNodes[value] = focusNode;
  }

  void _select(String value) {
    if (_selected == value) return;
    if (!_controlled) setState(() => _internal = value);
    widget.onChanged?.call(value);
  }

  void _measure() {
    if (!mounted) return;
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
    if (next != _target) setState(() => _target = next);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    return _ColorSelectorScope(
      state: this,
      selected: _selected,
      reduce: reduce,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: widget.children,
            ),
            if (_target != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _SelectionRing(
                    target: _target!,
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
}

class _ColorSelectorScope extends InheritedWidget {
  const _ColorSelectorScope({
    required this.state,
    required this.selected,
    required this.reduce,
    required super.child,
  });
  final _BeuiColorSelectorState state;
  final String? selected;
  final bool reduce;
  static _ColorSelectorScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ColorSelectorScope>()!;
  @override
  bool updateShouldNotify(_ColorSelectorScope old) =>
      selected != old.selected || reduce != old.reduce;
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
    super.key,
  });
  final String value;
  final Color color;
  final String label;
  @override
  State<BeuiColorSelectorItem> createState() => _BeuiColorSelectorItemState();
}

class _BeuiColorSelectorItemState extends State<BeuiColorSelectorItem> {
  final _focus = FocusNode(debugLabel: 'Color selector option');
  final _itemKey = GlobalKey();
  bool _pressed = false;
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
    state._register(widget.value, _itemKey, _focus);
    final scale = _pressed && !scope.reduce ? 0.94 : 1.0;
    return Semantics(
      key: _itemKey,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: widget.label,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final delta = switch (event.logicalKey) {
            LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown => 1,
            LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => -1,
            _ => 0,
          };
          if (delta == 0) return KeyEventResult.ignored;
          final all = state._itemKeys.keys.toList(growable: false);
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
        child: GestureDetector(
          onTap: () {
            _focus.requestFocus();
            state._select(widget.value);
          },
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Transform.scale(
            scale: scale,
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
                  if (_focus.hasFocus)
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
    );
  }
}

class _SelectionRing extends StatelessWidget {
  const _SelectionRing({
    required this.target,
    required this.color,
    required this.reduce,
  });
  final Rect target;
  final Color color;
  final bool reduce;
  Widget at(Rect rect) => Transform.translate(
    offset: rect.topLeft,
    child: Container(
      key: const ValueKey('beui_color_selector_ring'),
      width: rect.width,
      height: rect.height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.65), width: 2),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (reduce) return at(target);
    return MotionBuilder<Rect>(
      value: target,
      motion: motionFor(context, beuiSpringLayout, isMovement: true),
      converter: const RectMotionConverter(),
      builder: (context, rect, _) => at(rect),
    );
  }
}
