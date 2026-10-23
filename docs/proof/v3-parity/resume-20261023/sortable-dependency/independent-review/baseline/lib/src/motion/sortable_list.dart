import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// A sortable, accessible list with controlled or internal ordering and undo.
///
/// Supply [items] and [onItemsChange] for controlled use, or seed
/// [defaultItems] for internal state. [children] receives items in their
/// current order and can compose [BeuiSortableListGroup],
/// [BeuiSortableListItem], [BeuiSortableListHandle],
/// [BeuiSortableListItemContent], and [BeuiSortableListUndo].
class BeuiSortableList<T extends Object> extends StatefulWidget {
  /// Creates a sortable list.
  const BeuiSortableList({
    required this.getItemId,
    required this.getItemLabel,
    this.items,
    this.defaultItems = const [],
    this.onItemsChange,
    this.children,
    this.renderItem,
    this.label = 'Sortable items',
    this.disabled = false,
    this.showUndo = true,
    this.itemDecoration,
    super.key,
  });

  /// Returns the stable, unique id used to track an item while reordering.
  final String Function(T item) getItemId;

  /// Returns the accessible label used by the reorder handle and announcements.
  final String Function(T item) getItemLabel;

  /// Controlled items. When omitted, [defaultItems] seeds internal state.
  final List<T>? items;

  /// Initial items for uncontrolled use.
  final List<T> defaultItems;

  /// Called with the complete new order after a move.
  final ValueChanged<List<T>>? onItemsChange;

  /// Composed parts; the callback receives items in current order.
  final Widget Function(List<T> items)? children;

  /// Convenience content builder when [children] is omitted.
  final Widget Function(T item, int index)? renderItem;

  /// Accessible label for the list.
  final String label;

  /// Disables drag, keyboard movement, and undo.
  final bool disabled;

  /// Shows the undo button in the convenience layout.
  final bool showUndo;

  /// Optional row decoration override.
  final BoxDecoration? itemDecoration;

  @override
  State<BeuiSortableList<T>> createState() => _BeuiSortableListState<T>();
}

class _BeuiSortableListState<T extends Object>
    extends State<BeuiSortableList<T>> {
  late List<T> _internalItems = List<T>.of(widget.defaultItems);
  List<String>? _previousIds;
  String _announcement = '';
  String? _focusedId;

  bool get _controlled => widget.items != null;
  List<T> get _items => widget.items ?? _internalItems;
  List<String> get _ids => _items.map(widget.getItemId).toList();

  @override
  void didUpdateWidget(covariant BeuiSortableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMembers(_previousIds, _ids)) _previousIds = null;
  }

  bool _sameMembers(List<String>? prior, List<String> current) =>
      prior != null &&
      prior.length == current.length &&
      prior.toSet().length == current.length &&
      current.toSet().containsAll(prior);

  bool get _canUndo {
    final prior = _previousIds;
    final ids = _ids;
    return _sameMembers(prior, ids) &&
        prior!.asMap().entries.any((entry) => entry.value != ids[entry.key]);
  }

  void _publish(List<T> next) {
    if (!_controlled) setState(() => _internalItems = next);
    widget.onItemsChange?.call(List<T>.unmodifiable(next));
  }

  void _reorder(List<String> nextIds) {
    if (widget.disabled) return;
    final current = _items;
    final byId = {for (final item in current) widget.getItemId(item): item};
    if (nextIds.length != current.length ||
        nextIds.toSet().length != current.length ||
        !nextIds.toSet().containsAll(byId.keys)) {
      return;
    }
    final next = nextIds.map((id) => byId[id]!).toList();
    if (nextIds.asMap().entries.every((e) => e.value == _ids[e.key])) return;
    _previousIds = _ids;
    _publish(next);
  }

  void _move(String id, int destination) {
    if (widget.disabled) return;
    final current = _items;
    final ids = _ids;
    final from = ids.indexOf(id);
    if (from < 0 || destination < 0 || destination >= current.length) return;
    if (from == destination) return;
    final next = List<T>.of(current);
    final item = next.removeAt(from);
    next.insert(destination, item);
    _previousIds = ids;
    _focusedId = id;
    _publish(next);
    setState(() {
      _announcement =
          '${widget.getItemLabel(item)} moved to position ${destination + 1} of ${current.length}.';
    });
  }

  void _undo() {
    final prior = _previousIds;
    final current = _items;
    if (widget.disabled || prior == null || !_canUndo) return;
    final byId = {for (final item in current) widget.getItemId(item): item};
    _focusedId = prior.firstWhere(
      (id) => prior.indexOf(id) != _ids.indexOf(id),
      orElse: () => prior.first,
    );
    _publish(prior.map((id) => byId[id]!).toList());
    setState(() {
      _previousIds = null;
      _announcement = 'Previous order restored.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('BeuiSortableList requires unique item ids.');
    }
    if (widget.children == null && widget.renderItem == null) {
      throw ArgumentError(
        'Provide children or renderItem to BeuiSortableList.',
      );
    }
    final labels = {
      for (final item in _items)
        widget.getItemId(item): widget.getItemLabel(item),
    };
    final scope = _SortableListScope(
      ids: ids,
      labels: labels,
      listLabel: widget.label,
      disabled: widget.disabled,
      itemDecoration: widget.itemDecoration,
      move: _move,
      reorder: _reorder,
      canUndo: _canUndo,
      undo: _undo,
      focusedId: _focusedId,
    );
    final content =
        widget.children?.call(_items) ??
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiSortableListGroup(
              children: [
                for (var i = 0; i < _items.length; i++)
                  BeuiSortableListItem(
                    id: widget.getItemId(_items[i]),
                    child: Row(
                      children: [
                        const BeuiSortableListHandle(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BeuiSortableListItemContent(
                            child: widget.renderItem!(_items[i], i),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (widget.showUndo) const BeuiSortableListUndo(),
          ],
        );

    return _SortableListScopeHost(
      scope: scope,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(container: true, label: widget.label, child: content),
          Semantics(
            liveRegion: true,
            label: _announcement,
            child: const SizedBox(height: 1),
          ),
        ],
      ),
    );
  }
}

/// Ordered group. Keep headings and undo controls outside [children].
class BeuiSortableListGroup extends StatelessWidget {
  /// Creates an ordered sortable group.
  const BeuiSortableListGroup({required this.children, super.key});

  /// Rows in the current item order.
  final List<BeuiSortableListItem> children;

  @override
  Widget build(BuildContext context) {
    final scope = _SortableListScopeHost.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: scope.listLabel,
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        padding: EdgeInsets.zero,
        proxyDecorator: (child, index, animation) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return _SortableListScopeHost(
              scope: scope,
              child: Material(color: Colors.transparent, child: child),
            );
          }
          final motion = motionFor(context, beuiSpringLayout, isMovement: true);
          return _SortableListScopeHost(
            scope: scope,
            child: SingleMotionBuilder(
              value: 1.025,
              from: 1,
              motion: motion,
              builder: (context, scale, _) => Material(
                color: Colors.transparent,
                elevation: 8 * animation.value,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          );
        },
        onReorderItem: (from, target) {
          final ids = List<String>.of(scope.ids);
          final id = ids.removeAt(from);
          ids.insert(target, id);
          scope.reorder(ids);
        },
        children: [
          for (var index = 0; index < children.length; index++)
            children[index]._build(context, index, scope),
        ],
      ),
    );
  }
}

/// One row. Its [id] must refer to an item in the root list.
class BeuiSortableListItem extends StatelessWidget {
  /// Creates a sortable row.
  const BeuiSortableListItem({
    required this.id,
    required this.child,
    super.key,
  });

  /// Stable identity of the root item.
  final String id;

  /// Row content, typically a handle and [BeuiSortableListItemContent].
  final Widget child;

  Widget _build(BuildContext context, int index, _SortableListScope scope) {
    final label = scope.labels[id];
    if (label == null) {
      throw ArgumentError('BeuiSortableListItem $id is not in the root list.');
    }
    return _SortableItemScope(
      key: ValueKey<String>('sortable-row-$id'),
      id: id,
      label: label,
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          key: ValueKey<String>('sortable-item-$id'),
          container: true,
          explicitChildNodes: true,
          sortKey: OrdinalSortKey(index.toDouble()),
          value: 'Position ${index + 1} of ${scope.ids.length}',
          child: SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration:
                  scope.itemDecoration ??
                  BoxDecoration(
                    color: BeuiColors.resolve(context).background,
                    border: Border.all(
                      color: BeuiColors.resolve(context).border,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
              child: Padding(padding: const EdgeInsets.all(12), child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}

/// Keyboard- and pointer-accessible reorder grip.
class BeuiSortableListHandle extends StatelessWidget {
  /// Creates a reorder handle.
  const BeuiSortableListHandle({
    this.child,
    this.onPressed,
    this.enabled = true,
    super.key,
  });

  /// Optional icon/content replacing the default grip glyph.
  final Widget? child;

  /// Optional callback for an explicit activation.
  final VoidCallback? onPressed;

  /// Whether this handle is enabled in addition to the root state.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scope = _SortableListScopeHost.of(context);
    final item = _SortableItemScope.of(context);
    final colors = BeuiColors.resolve(context);
    final active = enabled && !scope.disabled;
    return ReorderableDragStartListener(
      index: item.index,
      enabled: active,
      child: FocusableActionDetector(
        enabled: active,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveUpIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveDownIntent(),
          SingleActivator(LogicalKeyboardKey.home): _MoveFirstIntent(),
          SingleActivator(LogicalKeyboardKey.end): _MoveLastIntent(),
        },
        actions: {
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (_) => scope.move(item.id, item.index - 1),
          ),
          _MoveDownIntent: CallbackAction<_MoveDownIntent>(
            onInvoke: (_) => scope.move(item.id, item.index + 1),
          ),
          _MoveFirstIntent: CallbackAction<_MoveFirstIntent>(
            onInvoke: (_) => scope.move(item.id, 0),
          ),
          _MoveLastIntent: CallbackAction<_MoveLastIntent>(
            onInvoke: (_) => scope.move(item.id, scope.ids.length - 1),
          ),
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Semantics(
              button: true,
              enabled: active,
              label: 'Reorder ${item.label}',
              hint:
                  'Drag to reorder. Use Up and Down to move; Home and End to move to the edges.',
              child: IconButton(
                tooltip: 'Reorder ${item.label}',
                onPressed: active ? (onPressed ?? () {}) : null,
                icon: child ?? const Icon(LucideIcons.grip_vertical, size: 18),
                focusColor: colors.accent,
                style:
                    IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ).copyWith(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? colors.foreground
                            : colors.mutedForeground,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? colors.muted
                            : Colors.transparent,
                      ),
                    ),
                autofocus: focused && scope.focusedId == item.id,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Flexible row-content slot.
class BeuiSortableListItemContent extends StatelessWidget {
  /// Creates a row-content slot.
  const BeuiSortableListItemContent({required this.child, super.key});

  /// The row's main content.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerLeft, child: child);
}

/// Short alias for [BeuiSortableListItemContent].
typedef BeuiSortableListContent = BeuiSortableListItemContent;

/// Restores the last valid order. It is disabled until a move has occurred.
class BeuiSortableListUndo extends StatelessWidget {
  /// Creates an undo button.
  const BeuiSortableListUndo({this.child, super.key});

  /// Optional label replacing the default.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scope = _SortableListScopeHost.of(context);
    final colors = BeuiColors.resolve(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: scope.canUndo && !scope.disabled ? scope.undo : null,
        icon: const Icon(LucideIcons.undo_2, size: 14),
        label: child ?? const Text('Undo reorder'),
        style: TextButton.styleFrom(foregroundColor: colors.mutedForeground)
            .copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered)
                    ? colors.foreground
                    : colors.mutedForeground,
              ),
            ),
      ),
    );
  }
}

class _SortableListScope {
  const _SortableListScope({
    required this.ids,
    required this.labels,
    required this.listLabel,
    required this.disabled,
    required this.itemDecoration,
    required this.move,
    required this.reorder,
    required this.canUndo,
    required this.undo,
    required this.focusedId,
  });

  final List<String> ids;
  final Map<String, String> labels;
  final String listLabel;
  final bool disabled;
  final BoxDecoration? itemDecoration;
  final void Function(String id, int to) move;
  final ValueChanged<List<String>> reorder;
  final bool canUndo;
  final VoidCallback undo;
  final String? focusedId;
}

class _SortableListScopeHost extends InheritedWidget {
  const _SortableListScopeHost({required this.scope, required super.child});

  final _SortableListScope scope;

  static _SortableListScope of(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_SortableListScopeHost>();
    assert(
      host != null,
      'Sortable list parts must be inside BeuiSortableList.',
    );
    return host!.scope;
  }

  @override
  bool updateShouldNotify(_SortableListScopeHost oldWidget) =>
      !identical(scope, oldWidget.scope);
}

class _SortableItemScope extends InheritedWidget {
  const _SortableItemScope({
    super.key,
    required this.id,
    required this.label,
    required this.index,
    required super.child,
  });

  final String id;
  final String label;
  final int index;

  static _SortableItemScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SortableItemScope>();
    assert(scope != null, 'BeuiSortableListHandle must be inside an item.');
    return scope!;
  }

  @override
  bool updateShouldNotify(_SortableItemScope oldWidget) =>
      index != oldWidget.index;
}

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

class _MoveDownIntent extends Intent {
  const _MoveDownIntent();
}

class _MoveFirstIntent extends Intent {
  const _MoveFirstIntent();
}

class _MoveLastIntent extends Intent {
  const _MoveLastIntent();
}
