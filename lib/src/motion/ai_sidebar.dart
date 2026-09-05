import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
import 'popover_morph.dart';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Kind of a [BeuiSidebarResource] node — mirrors source `SidebarResourceKind`.
enum BeuiSidebarResourceKind {
  /// Container that can hold children (folder glyph).
  folder,

  /// Container that can hold children (project glyph — same as folder).
  project,

  /// Selectable leaf (file glyph).
  file,

  /// Selectable leaf (bookmark glyph).
  bookmark,
}

/// One node in a [BeuiAiSidebar] resource tree — the Flutter port of
/// `SidebarResource`.
@immutable
class BeuiSidebarResource {
  /// Creates a resource descriptor.
  const BeuiSidebarResource({
    required this.id,
    required this.label,
    required this.kind,
    this.children,
    this.disabled = false,
  });

  /// Stable identity within the tree.
  final String id;

  /// Display label (also the rename draft seed).
  final String label;

  /// Visual / structural kind.
  final BeuiSidebarResourceKind kind;

  /// Nested resources. Only [BeuiSidebarResourceKind.folder] /
  /// [BeuiSidebarResourceKind.project] kinds accept children on
  /// "inside" moves; empty containers still expand/collapse.
  final List<BeuiSidebarResource>? children;

  /// When true, the row is non-interactive (no select / rename / move).
  final bool disabled;

  /// Whether this kind can own children (`folder` / `project`).
  bool get canContain =>
      kind == BeuiSidebarResourceKind.folder ||
      kind == BeuiSidebarResourceKind.project;

  /// Copy with replaced fields.
  BeuiSidebarResource copyWith({
    String? id,
    String? label,
    BeuiSidebarResourceKind? kind,
    List<BeuiSidebarResource>? children,
    bool? disabled,
  }) {
    return BeuiSidebarResource(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      children: children ?? this.children,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiSidebarResource &&
        other.id == id &&
        other.label == label &&
        other.kind == kind &&
        other.disabled == disabled &&
        listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    kind,
    disabled,
    children == null ? null : Object.hashAll(children!),
  );
}

/// Where a moved item lands relative to a drop target — source
/// `SidebarResourceDropPosition`.
enum BeuiSidebarResourceDropPosition {
  /// Insert as a sibling before the target.
  before,

  /// Insert as the last child of the target (folders / projects only).
  inside,

  /// Insert as a sibling after the target.
  after,
}

/// A request to relocate [itemId] relative to [targetId] — source
/// `SidebarResourceMove`.
@immutable
class BeuiSidebarResourceMove {
  /// Creates a move descriptor.
  const BeuiSidebarResourceMove({
    required this.itemId,
    required this.targetId,
    required this.position,
  });

  /// Id of the resource being moved.
  final String itemId;

  /// Id of the reference resource, or `null` for top-level append.
  final String? targetId;

  /// Relative placement against [targetId].
  final BeuiSidebarResourceDropPosition position;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiSidebarResourceMove &&
        other.itemId == itemId &&
        other.targetId == targetId &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(itemId, targetId, position);
}

/// Menu callbacks handed to [BeuiAiSidebar.menuBuilder] — source
/// `SidebarResourceMenuControls`.
@immutable
class BeuiSidebarResourceMenuControls {
  /// Creates menu controls for one open row menu.
  const BeuiSidebarResourceMenuControls({
    required this.close,
    required this.rename,
  });

  /// Dismisses the overflow menu.
  final VoidCallback close;

  /// Closes the menu and starts inline rename for that row.
  final VoidCallback rename;
}

// ---------------------------------------------------------------------------
// Tree helpers (pure — mirrored from the source)
// ---------------------------------------------------------------------------

/// Whether [kind] can contain children.
bool beuiSidebarCanContain(BeuiSidebarResourceKind kind) =>
    kind == BeuiSidebarResourceKind.folder ||
    kind == BeuiSidebarResourceKind.project;

/// Flatten [items] respecting [expanded] folder ids.
List<_FlatResource> _flatten(
  List<BeuiSidebarResource> items,
  Set<String> expanded, {
  int depth = 0,
  String? parentId,
}) {
  final out = <_FlatResource>[];
  for (final item in items) {
    out.add(_FlatResource(item: item, depth: depth, parentId: parentId));
    final kids = item.children;
    if (kids != null && kids.isNotEmpty && expanded.contains(item.id)) {
      out.addAll(_flatten(kids, expanded, depth: depth + 1, parentId: item.id));
    }
  }
  return out;
}

/// Depth-first find by [id].
BeuiSidebarResource? beuiSidebarFind(
  List<BeuiSidebarResource> items,
  String id,
) {
  for (final item in items) {
    if (item.id == id) return item;
    final kids = item.children;
    if (kids != null) {
      final child = beuiSidebarFind(kids, id);
      if (child != null) return child;
    }
  }
  return null;
}

/// Whether [item] (or any descendant) has [id].
bool beuiSidebarContains(BeuiSidebarResource item, String id) {
  if (item.id == id) return true;
  final kids = item.children;
  if (kids == null) return false;
  return kids.any((c) => beuiSidebarContains(c, id));
}

/// Remove [id] from the tree. Returns the new list and the removed node.
({List<BeuiSidebarResource> items, BeuiSidebarResource? removed})
beuiSidebarRemove(List<BeuiSidebarResource> items, String id) {
  BeuiSidebarResource? removed;
  final next = <BeuiSidebarResource>[];
  for (final item in items) {
    if (item.id == id) {
      removed = item;
      continue;
    }
    final kids = item.children;
    if (kids != null && kids.isNotEmpty) {
      final childResult = beuiSidebarRemove(kids, id);
      if (childResult.removed != null) {
        removed = childResult.removed;
        next.add(item.copyWith(children: childResult.items));
        continue;
      }
    }
    next.add(item);
  }
  return (items: next, removed: removed);
}

/// Insert [resource] relative to [targetId] / [position].
List<BeuiSidebarResource> beuiSidebarInsert(
  List<BeuiSidebarResource> items,
  BeuiSidebarResource resource,
  String? targetId,
  BeuiSidebarResourceDropPosition position,
) {
  if (targetId == null) return [...items, resource];

  final next = <BeuiSidebarResource>[];
  for (final item in items) {
    if (item.id == targetId) {
      switch (position) {
        case BeuiSidebarResourceDropPosition.before:
          next
            ..add(resource)
            ..add(item);
        case BeuiSidebarResourceDropPosition.after:
          next
            ..add(item)
            ..add(resource);
        case BeuiSidebarResourceDropPosition.inside:
          next.add(item.copyWith(children: [...?item.children, resource]));
      }
      continue;
    }
    final kids = item.children;
    if (kids != null && kids.isNotEmpty) {
      next.add(
        item.copyWith(
          children: beuiSidebarInsert(kids, resource, targetId, position),
        ),
      );
    } else {
      next.add(item);
    }
  }
  return next;
}

/// Apply a [move], returning `null` when illegal.
List<BeuiSidebarResource>? beuiSidebarMove(
  List<BeuiSidebarResource> items,
  BeuiSidebarResourceMove move,
) {
  final source = beuiSidebarFind(items, move.itemId);
  if (source == null || source.disabled) return null;
  if (move.targetId != null && beuiSidebarContains(source, move.targetId!)) {
    return null;
  }

  final target = move.targetId != null
      ? beuiSidebarFind(items, move.targetId!)
      : null;
  if (move.position == BeuiSidebarResourceDropPosition.inside &&
      (target == null || target.disabled || !target.canContain)) {
    return null;
  }

  final removed = beuiSidebarRemove(items, move.itemId);
  if (removed.removed == null) return null;
  return beuiSidebarInsert(
    removed.items,
    removed.removed!,
    move.targetId,
    move.position,
  );
}

/// Rename [id] to [label] throughout the tree.
List<BeuiSidebarResource> beuiSidebarRename(
  List<BeuiSidebarResource> items,
  String id,
  String label,
) {
  return [
    for (final item in items)
      item.copyWith(
        label: item.id == id ? label : item.label,
        children: item.children != null
            ? beuiSidebarRename(item.children!, id, label)
            : null,
      ),
  ];
}

// ---------------------------------------------------------------------------
// Internal flat row
// ---------------------------------------------------------------------------

@immutable
class _FlatResource {
  const _FlatResource({
    required this.item,
    required this.depth,
    required this.parentId,
  });

  final BeuiSidebarResource item;
  final int depth;
  final String? parentId;
}

// ---------------------------------------------------------------------------
// Keys / constants
// ---------------------------------------------------------------------------

/// Root key for the AI sidebar tree.
const beuiAiSidebarKey = ValueKey<String>('beui.ai-sidebar');

/// Row key for [id] (used by tests and focus).
ValueKey<String> beuiAiSidebarRowKey(String id) =>
    ValueKey<String>('beui.ai-sidebar.row.$id');

/// Inline-rename field key for [id].
ValueKey<String> beuiAiSidebarRenameKey(String id) =>
    ValueKey<String>('beui.ai-sidebar.rename.$id');

const _indentPerDepth = 16.0;
const _basePadLeft = 12.0;
const _rowMinHeight = 36.0;

/// Leading accent bar on the selected row, in logical pixels. Reserved
/// (transparent) on every other row so selection costs no reflow.
const _selectionBarWidth = 2.0;

/// The one dimming factor a disabled row gets.
///
/// It used to compound two: `mutedForeground` pre-multiplied to 0.55 *and* an
/// `Opacity(0.45)` over the whole row, landing the label at about 1.42:1 —
/// unreadable, where "disabled" should mean "clearly not available", not
/// "invisible". One mechanism, at a level that still reads.
const _disabledAlpha = 0.7;

// ---------------------------------------------------------------------------
// BeuiAiSidebar
// ---------------------------------------------------------------------------

/// A collapsible AI workspace resource tree — the Flutter port of beUI's
/// `ai-sidebar`.
///
/// Renders a hierarchical list of [BeuiSidebarResource] nodes (folders,
/// projects, files, bookmarks) with:
///
/// - **Expand / collapse** for containers (`folder` / `project`)
/// - **Selection** for leaves (`file` / `bookmark`) via [activeId] /
///   [onActiveChange]
/// - **Inline rename** (double-tap leaf, F2, or overflow → Rename)
/// - **Keyboard navigation** (↑/↓, Home/End, ←/→ expand/collapse, Enter/Space)
/// - **Optimistic moves** via **Alt+Shift+arrows** (↑/↓ reorder siblings,
///   → nest into previous container, ← unnest after parent)
/// - **Spring layout** on list shifts ([beuiSpringLayout]) and overflow
///   **marquee** labels on hover
///
/// Controlled when [items] / [activeId] are non-null; otherwise seeded by
/// [defaultItems] / [defaultActiveId]. [onMove] may return a [Future] — reject
/// it to roll the optimistic tree back ([onMoveError]).
///
/// ### Scope notes (pragmatic cuts)
///
/// - **Pointer drag-and-drop reorder** from the source is **not** ported. Use
///   keyboard Alt+Shift+arrows (or drive [items] + [onMove] yourself). Pointer
///   DnD would need a full drop-indicator system; the keyboard path covers the
///   same `SidebarResourceMove` API.
/// - Row overflow menu uses [BeuiMorphPopover] (source `MorphPopover`); custom
///   menus via [menuBuilder].
///
/// ### Scrolling: the consumer owns the viewport
///
/// By default this renders a plain shrink-wrapping [Column] of every visible
/// row and **provides no scroll container of its own** — a 200-node tree is
/// 7,200 logical pixels tall and will overflow whatever box you put it in. That
/// is deliberate: a sidebar is normally one section of a larger scrolling pane,
/// and nesting scrollables is worse than not having one.
///
/// Either wrap it yourself:
///
/// ```dart
/// Expanded(child: SingleChildScrollView(child: BeuiAiSidebar(...)))
/// ```
///
/// or set [maxHeight] and let the widget cap and scroll itself, with a bottom
/// fade so the clipped rows read as "more".
class BeuiAiSidebar extends StatefulWidget {
  /// Creates an AI workspace resource sidebar.
  const BeuiAiSidebar({
    this.items,
    this.defaultItems = const [],
    this.onItemsChange,
    this.onMove,
    this.onMoveError,
    this.onRename,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.defaultExpandedIds = const [],
    this.iconBuilder,
    this.menuBuilder,
    this.emptyPlaceholder,
    this.maxHeight,
    this.semanticLabel = 'Resources',
    super.key,
  });

  /// Controlled tree. When non-null, keep it in sync via [onItemsChange].
  final List<BeuiSidebarResource>? items;

  /// Uncontrolled seed tree (ignored when [items] is set).
  final List<BeuiSidebarResource> defaultItems;

  /// Fires after any local tree mutation (move / rename).
  final ValueChanged<List<BeuiSidebarResource>>? onItemsChange;

  /// Called after an optimistic move is applied. Throw / reject to roll back.
  final FutureOr<void> Function(BeuiSidebarResourceMove move)? onMove;

  /// Called when [onMove] fails (after the tree is restored).
  final void Function(Object error, BeuiSidebarResourceMove move)? onMoveError;

  /// Called after an optimistic rename. Throw / reject to roll back.
  final FutureOr<void> Function(BeuiSidebarResource item, String label)?
  onRename;

  /// Controlled selection id (leaves).
  final String? activeId;

  /// Uncontrolled initial selection.
  final String? defaultActiveId;

  /// Selection callback (leaves and any explicit select).
  final ValueChanged<String>? onActiveChange;

  /// Folder / project ids expanded on first build.
  final List<String> defaultExpandedIds;

  /// Override the default kind glyph. Receives the resource and whether its
  /// container is currently expanded.
  final Widget Function(BeuiSidebarResource item, {required bool expanded})?
  iconBuilder;

  /// Custom overflow menu body. Defaults to a single "Rename" action.
  final Widget Function(
    BeuiSidebarResource item,
    BeuiSidebarResourceMenuControls controls,
  )?
  menuBuilder;

  /// Shown when the tree has no rows at all. Defaults to a muted
  /// "No resources yet".
  ///
  /// An empty tree used to render as a zero-height box, which is
  /// indistinguishable from a layout bug.
  final Widget? emptyPlaceholder;

  /// Caps the tree's height and scrolls it, with a bottom fade.
  ///
  /// Null (the default) keeps the source behaviour: the tree shrink-wraps and
  /// the consumer owns the viewport. See the class docs.
  final double? maxHeight;

  /// Accessibility label for the tree (source `ariaLabel`).
  final String semanticLabel;

  @override
  State<BeuiAiSidebar> createState() => _BeuiAiSidebarState();
}

class _BeuiAiSidebarState extends State<BeuiAiSidebar> {
  late List<BeuiSidebarResource> _internalItems =
      List<BeuiSidebarResource>.from(widget.items ?? widget.defaultItems);
  late String? _internalActiveId = widget.defaultActiveId;
  late Set<String> _expanded = {...widget.defaultExpandedIds};
  String? _focusedId;
  String? _menuOpenId;
  String? _renamingId;
  String _announcement = '';
  bool _movePending = false;

  final Map<String, FocusNode> _rowFocus = {};

  bool get _itemsControlled => widget.items != null;
  List<BeuiSidebarResource> get _rendered => widget.items ?? _internalItems;

  String? get _selectedId => widget.activeId ?? _internalActiveId;

  List<_FlatResource> get _flat => _flatten(_rendered, _expanded);

  FocusNode _focusFor(String id) =>
      _rowFocus.putIfAbsent(id, () => FocusNode(debugLabel: 'ai-sidebar-$id'));

  @override
  void didUpdateWidget(BeuiAiSidebar old) {
    super.didUpdateWidget(old);
    if (widget.items != null && widget.items != old.items) {
      _internalItems = List<BeuiSidebarResource>.from(widget.items!);
    }
  }

  @override
  void dispose() {
    for (final n in _rowFocus.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _updateItems(List<BeuiSidebarResource> next) {
    if (!_itemsControlled) {
      setState(() => _internalItems = next);
    } else {
      setState(() {}); // re-render while parent echoes
    }
    widget.onItemsChange?.call(next);
  }

  void _select(String id) {
    if (widget.activeId == null) {
      setState(() => _internalActiveId = id);
    }
    widget.onActiveChange?.call(id);
  }

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
      // Copy so == checks see a new set identity when needed.
      _expanded = {..._expanded};
    });
  }

  void _focusRow(String id) {
    setState(() => _focusedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _rowFocus[id];
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  Future<void> _performMove(BeuiSidebarResourceMove move) async {
    if (_movePending) {
      setState(() => _announcement = 'Wait for the current move to finish.');
      return;
    }
    final before = _rendered;
    final next = beuiSidebarMove(before, move);
    if (next == null) return;

    _movePending = true;
    _updateItems(next);
    final moved = beuiSidebarFind(before, move.itemId);
    final target = move.targetId != null
        ? beuiSidebarFind(before, move.targetId!)
        : null;
    setState(() {
      _announcement = target != null
          ? 'Moved ${moved?.label ?? 'item'} ${move.position.name} ${target.label}.'
          : 'Moved ${moved?.label ?? 'item'} to the top level.';
    });

    try {
      await widget.onMove?.call(move);
    } catch (error) {
      _updateItems(before);
      setState(() {
        _announcement = 'Move failed. ${moved?.label ?? 'Item'} was restored.';
      });
      widget.onMoveError?.call(error, move);
    } finally {
      _movePending = false;
    }
  }

  Future<void> _commitRename(_FlatResource row, String label) async {
    final trimmed = label.trim();
    setState(() => _renamingId = null);
    if (trimmed.isEmpty || trimmed == row.item.label) return;
    final before = _rendered;
    _updateItems(beuiSidebarRename(before, row.item.id, trimmed));
    try {
      await widget.onRename?.call(row.item, trimmed);
    } catch (_) {
      _updateItems(before);
      setState(() {
        _announcement = 'Rename failed. ${row.item.label} was restored.';
      });
    }
  }

  KeyEventResult _onRowKey(KeyEvent event, _FlatResource row) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final flat = _flat;
    final index = flat.indexWhere((r) => r.item.id == row.item.id);
    final previous = index > 0 ? flat[index - 1] : null;
    final next = index >= 0 && index < flat.length - 1 ? flat[index + 1] : null;
    final moveModifier =
        HardwareKeyboard.instance.isAltPressed &&
        HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.arrowDown && !moveModifier && next != null) {
      _focusRow(next.item.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp &&
        !moveModifier &&
        previous != null) {
      _focusRow(previous.item.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home && flat.isNotEmpty) {
      _focusRow(flat.first.item.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end && flat.isNotEmpty) {
      _focusRow(flat.last.item.id);
      return KeyEventResult.handled;
    }

    if (row.item.disabled) {
      if (key == LogicalKeyboardKey.arrowLeft && row.parentId != null) {
        _focusRow(row.parentId!);
        return KeyEventResult.handled;
      }
      if (moveModifier ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.f2 ||
          key == LogicalKeyboardKey.contextMenu ||
          (HardwareKeyboard.instance.isShiftPressed &&
              key == LogicalKeyboardKey.f10)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (moveModifier && key == LogicalKeyboardKey.arrowUp && previous != null) {
      unawaited(
        _performMove(
          BeuiSidebarResourceMove(
            itemId: row.item.id,
            targetId: previous.item.id,
            position: BeuiSidebarResourceDropPosition.before,
          ),
        ),
      );
      return KeyEventResult.handled;
    }
    if (moveModifier && key == LogicalKeyboardKey.arrowDown && next != null) {
      unawaited(
        _performMove(
          BeuiSidebarResourceMove(
            itemId: row.item.id,
            targetId: next.item.id,
            position: BeuiSidebarResourceDropPosition.after,
          ),
        ),
      );
      return KeyEventResult.handled;
    }
    if (moveModifier &&
        key == LogicalKeyboardKey.arrowRight &&
        previous != null &&
        previous.item.canContain) {
      setState(() => _expanded = {..._expanded, previous.item.id});
      unawaited(
        _performMove(
          BeuiSidebarResourceMove(
            itemId: row.item.id,
            targetId: previous.item.id,
            position: BeuiSidebarResourceDropPosition.inside,
          ),
        ),
      );
      return KeyEventResult.handled;
    }
    if (moveModifier &&
        key == LogicalKeyboardKey.arrowLeft &&
        row.parentId != null) {
      unawaited(
        _performMove(
          BeuiSidebarResourceMove(
            itemId: row.item.id,
            targetId: row.parentId,
            position: BeuiSidebarResourceDropPosition.after,
          ),
        ),
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight && row.item.canContain) {
      if (!_expanded.contains(row.item.id)) {
        _toggle(row.item.id);
      } else if (next?.parentId == row.item.id) {
        _focusRow(next!.item.id);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_expanded.contains(row.item.id)) {
        _toggle(row.item.id);
      } else if (row.parentId != null) {
        _focusRow(row.parentId!);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (row.item.canContain) {
        _toggle(row.item.id);
      } else {
        _select(row.item.id);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      setState(() => _renamingId = row.item.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu ||
        (HardwareKeyboard.instance.isShiftPressed &&
            key == LogicalKeyboardKey.f10)) {
      setState(() => _menuOpenId = row.item.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final flat = _flat;

    // Keep focus on a live row.
    if (_focusedId != null &&
        flat.every((r) => r.item.id != _focusedId) &&
        flat.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _focusedId = flat.first.item.id);
      });
    }
    final focusedId =
        _focusedId ?? _selectedId ?? (flat.isEmpty ? null : flat.first.item.id);

    final tree = Column(
      key: beuiAiSidebarKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (flat.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _basePadLeft,
              vertical: 12,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 13,
                height: 18 / 13,
                letterSpacing: 0,
                color: colors.mutedForeground,
              ),
              child: widget.emptyPlaceholder ?? const Text('No resources yet'),
            ),
          ),
        for (final row in flat)
          _ResourceRow(
            key: beuiAiSidebarRowKey(row.item.id),
            row: row,
            colors: colors,
            active: _selectedId == row.item.id,
            expanded: _expanded.contains(row.item.id),
            focused: focusedId == row.item.id,
            menuOpen: _menuOpenId == row.item.id,
            renaming: _renamingId == row.item.id,
            focusNode: _focusFor(row.item.id),
            iconBuilder: widget.iconBuilder,
            menuBuilder: widget.menuBuilder,
            onFocus: () => setState(() => _focusedId = row.item.id),
            onSelect: () {
              if (row.item.disabled) return;
              if (row.item.canContain) {
                _toggle(row.item.id);
              } else {
                _select(row.item.id);
              }
            },
            onToggle: () {
              if (!row.item.disabled && row.item.canContain) {
                _toggle(row.item.id);
              }
            },
            onKey: (e) => _onRowKey(e, row),
            onRenameStart: () => setState(() => _renamingId = row.item.id),
            onRenameCancel: () => setState(() => _renamingId = null),
            onRenameCommit: (label) => unawaited(_commitRename(row, label)),
            onMenuOpenChange: (open) {
              setState(() => _menuOpenId = open ? row.item.id : null);
              if (!open) _focusRow(row.item.id);
            },
          ),
        // Live region for move / rename announcements (a11y).
        ExcludeSemantics(
          excluding: false,
          child: Semantics(
            liveRegion: true,
            label: _announcement,
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: widget.maxHeight == null
          ? tree
          : _CappedTree(
              maxHeight: widget.maxHeight!,
              surface: colors.background,
              child: tree,
            ),
    );
  }
}

/// The opt-in viewport: caps the tree at a height and fades the clipped edge.
class _CappedTree extends StatelessWidget {
  const _CappedTree({
    required this.maxHeight,
    required this.surface,
    required this.child,
  });

  final double maxHeight;
  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Stack(
        children: [
          SingleChildScrollView(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [surface, surface.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resource row
// ---------------------------------------------------------------------------

class _ResourceRow extends StatefulWidget {
  const _ResourceRow({
    required this.row,
    required this.colors,
    required this.active,
    required this.expanded,
    required this.focused,
    required this.menuOpen,
    required this.renaming,
    required this.focusNode,
    required this.onFocus,
    required this.onSelect,
    required this.onToggle,
    required this.onKey,
    required this.onRenameStart,
    required this.onRenameCancel,
    required this.onRenameCommit,
    required this.onMenuOpenChange,
    this.iconBuilder,
    this.menuBuilder,
    super.key,
  });

  final _FlatResource row;
  final BeuiColors colors;
  final bool active;
  final bool expanded;
  final bool focused;
  final bool menuOpen;
  final bool renaming;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onSelect;
  final VoidCallback onToggle;
  final KeyEventResult Function(KeyEvent event) onKey;
  final VoidCallback onRenameStart;
  final VoidCallback onRenameCancel;
  final ValueChanged<String> onRenameCommit;
  final ValueChanged<bool> onMenuOpenChange;
  final Widget Function(BeuiSidebarResource item, {required bool expanded})?
  iconBuilder;
  final Widget Function(
    BeuiSidebarResource item,
    BeuiSidebarResourceMenuControls controls,
  )?
  menuBuilder;

  @override
  State<_ResourceRow> createState() => _ResourceRowState();
}

class _ResourceRowState extends State<_ResourceRow> {
  bool _hovered = false;
  bool _pressed = false;
  late final TextEditingController _renameCtrl;
  final FocusNode _renameFocus = FocusNode(debugLabel: 'ai-sidebar-rename');
  bool _skipRenameBlur = false;

  @override
  void initState() {
    super.initState();
    _renameCtrl = TextEditingController(text: widget.row.item.label);
  }

  @override
  void didUpdateWidget(_ResourceRow old) {
    super.didUpdateWidget(old);
    if (widget.renaming && !old.renaming) {
      _skipRenameBlur = false;
      _renameCtrl.text = widget.row.item.label;
      _renameCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _renameCtrl.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _renameFocus.requestFocus();
      });
    }
    if (!widget.renaming && old.renaming) {
      _renameCtrl.text = widget.row.item.label;
    }
  }

  @override
  void dispose() {
    _renameCtrl.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  /// True on a platform whose primary pointer cannot hover.
  ///
  /// Read from the ambient theme rather than `defaultTargetPlatform` so a test
  /// (or a consumer targeting a tablet build) can drive it.
  bool get _touchFirst {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS ||
        platform == TargetPlatform.android ||
        platform == TargetPlatform.fuchsia;
  }

  Widget _defaultIcon() {
    final item = widget.row.item;
    final icons = BeuiAgentTheme.of(context).icons;
    final IconData data;
    if (item.canContain) {
      data = widget.expanded ? icons.folderOpen : icons.folder;
    } else if (item.kind == BeuiSidebarResourceKind.bookmark) {
      data = icons.bookmark;
    } else {
      data = icons.document;
    }
    return Icon(
      data,
      size: 16,
      color: item.disabled
          ? widget.colors.mutedForeground.withValues(alpha: _disabledAlpha)
          : widget.active || _hovered || widget.menuOpen
          ? widget.colors.foreground
          : widget.colors.mutedForeground,
    );
  }

  Widget _defaultMenu(BeuiSidebarResourceMenuControls controls) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          controls.close();
          controls.rename();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                BeuiAgentTheme.of(context).icons.edit,
                size: 14,
                color: widget.colors.foreground,
              ),
              const SizedBox(width: 8),
              Text(
                'Rename',
                style: TextStyle(fontSize: 12, color: widget.colors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.row.item;
    final acceptsChildren = item.canContain;
    final colors = widget.colors;
    final selected = !acceptsChildren && widget.active;

    final fg = item.disabled
        ? colors.mutedForeground.withValues(alpha: _disabledAlpha)
        : selected || _hovered || widget.menuOpen
        ? colors.foreground
        : colors.mutedForeground;

    // Two distinct steps, not one shared `muted`. Selection used to be painted
    // in exactly the hover fill, so moving the pointer over the tree made the
    // current row indistinguishable from whatever the pointer happened to be
    // near — the selection literally disappeared under the cursor.
    final Color? bg = item.disabled
        ? null
        : selected
        ? colors.muted
        : (_hovered || widget.menuOpen)
        ? colors.foreground.withValues(alpha: 0.04)
        : null;

    final padLeft = _basePadLeft + widget.row.depth * _indentPerDepth;

    final controls = BeuiSidebarResourceMenuControls(
      close: () => widget.onMenuOpenChange(false),
      rename: () {
        widget.onMenuOpenChange(false);
        widget.onRenameStart();
      },
    );

    final menuBody =
        widget.menuBuilder?.call(item, controls) ?? _defaultMenu(controls);

    Widget label;
    if (widget.renaming) {
      label = Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 28,
            child: TextField(
              key: beuiAiSidebarRenameKey(item.id),
              controller: _renameCtrl,
              focusNode: _renameFocus,
              style: TextStyle(fontSize: 14, color: colors.foreground),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  // focusRing, not ring: `ring` is the 6-12% hairline token
                  // for borders and composites to 1.3:1.
                  borderSide: BorderSide(color: colors.focusRing, width: 1.5),
                ),
              ),
              onSubmitted: (v) {
                _skipRenameBlur = true;
                widget.onRenameCommit(v);
              },
              onTapOutside: (_) {
                if (!_skipRenameBlur) widget.onRenameCommit(_renameCtrl.text);
              },
              onEditingComplete: () {},
            ),
          ),
        ),
      );
    } else {
      label = Expanded(
        child: _MarqueeLabel(
          active: _hovered || widget.menuOpen,
          text: item.label,
          style: TextStyle(fontSize: 14, color: fg, height: 1.2),
        ),
      );
    }

    // Revealed by hover on a pointer device; held at a low but visible opacity
    // on touch, where "hover" never happens and the control was previously an
    // invisible-yet-tappable box at the end of every single row.
    final menuOpacity = (_hovered || widget.menuOpen)
        ? 1.0
        : (_touchFirst ? 0.45 : 0.0);

    final menuButton = !widget.renaming && !item.disabled
        ? BeuiMorphPopover(
            open: widget.menuOpen,
            onOpenChange: widget.onMenuOpenChange,
            side: BeuiMorphPopoverSide.bottom,
            align: BeuiMorphPopoverAlign.end,
            sideOffset: 8,
            radius: 12,
            content: Material(
              color: colors.popover,
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
              shadowColor: colors.foreground.withValues(alpha: 0.12),
              child: Container(
                width: 160,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: menuBody,
              ),
            ),
            // Outermost, so the 44px slop clears the 28px paint. The semantics
            // node sits inside it but outside the IgnorePointer, so the action
            // stays available to assistive technology even in the frame where
            // the glyph is invisible to a pointer.
            child: BeuiMinHitTarget(
              child: Semantics(
                container: true,
                button: true,
                label: 'Actions for ${item.label}',
                onTap: () => widget.onMenuOpenChange(true),
                child: IgnorePointer(
                  ignoring: menuOpacity == 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: menuOpacity,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: Icon(
                            BeuiAgentTheme.of(context).icons.more,
                            size: 16,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox(width: 28, height: 28);

    final icon =
        widget.iconBuilder?.call(item, expanded: widget.expanded) ??
        _defaultIcon();

    final rowBody = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: beuiEaseOut,
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      padding: EdgeInsets.only(left: padLeft - _selectionBarWidth, right: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // The second selection channel: a fill that a hover state can imitate
          // is not, on its own, a "you are here".
          SizedBox(
            width: _selectionBarWidth,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected && !item.disabled
                    ? colors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: _selectionBarWidth),
          SizedBox(width: 20, height: 20, child: Center(child: icon)),
          const SizedBox(width: 10),
          label,
          menuButton,
        ],
      ),
    );

    Widget interactive = Focus(
      focusNode: widget.focusNode,
      onFocusChange: (has) {
        if (has) widget.onFocus();
      },
      onKeyEvent: (node, event) {
        // Let the text field own keys while renaming.
        if (widget.renaming) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _skipRenameBlur = true;
            widget.onRenameCancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        return widget.onKey(event);
      },
      child: MouseRegion(
        cursor: item.disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: item.disabled || widget.renaming
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: item.disabled || widget.renaming
              ? null
              : (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: item.disabled || widget.renaming
              ? null
              : () {
                  widget.focusNode.requestFocus();
                  widget.onFocus();
                  if (acceptsChildren) {
                    widget.onToggle();
                  } else {
                    widget.onSelect();
                  }
                },
          onDoubleTap: item.disabled || acceptsChildren || widget.renaming
              ? null
              : () {
                  widget.focusNode.requestFocus();
                  widget.onRenameStart();
                },
          // Touch's answer to right-click. Rename had no touch entry point at
          // all: double-tap is the desktop gesture, and Shift+F10 is not a
          // thing on a phone.
          onLongPress: item.disabled || widget.renaming
              ? null
              : () {
                  widget.focusNode.requestFocus();
                  widget.onFocus();
                  widget.onMenuOpenChange(true);
                },
          // The row's focus ring — `focused` was threaded all the way down here
          // and then never rendered, so the whole keyboard tree model was
          // invisible to the person using it.
          child: BeuiFocusRing(
            focused: widget.focused && !widget.renaming,
            borderRadius: BorderRadius.circular(12),
            child: rowBody,
          ),
        ),
      ),
    );

    interactive = Semantics(
      enabled: !item.disabled,
      selected: acceptsChildren ? null : widget.active,
      expanded: acceptsChildren ? widget.expanded : null,
      label: item.label,
      child: interactive,
    );

    // Press scale on SPRING_PRESS (source press feedback ~100–160ms).
    final pressMotion = motionFor(context, beuiSpringPress, isMovement: true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SingleMotionBuilder(
        value: _pressed ? 0.98 : 1.0,
        motion: pressMotion,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: child,
        ),
        child: interactive,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overflow marquee label (source MarqueeLabel)
// ---------------------------------------------------------------------------

class _MarqueeLabel extends StatefulWidget {
  const _MarqueeLabel({
    required this.active,
    required this.text,
    required this.style,
  });

  final bool active;
  final String text;
  final TextStyle style;

  @override
  State<_MarqueeLabel> createState() => _MarqueeLabelState();
}

/// Delay before an overflowing label starts to travel.
///
/// The tree's rows are the highest-frequency hover target in the whole
/// component; without a delay, brushing the pointer down the list set every
/// long label in motion. 400ms is the same "did you mean it?" threshold a
/// tooltip uses.
const _marqueeDelay = Duration(milliseconds: 400);

/// The gap between the label and its repeat, in logical pixels.
const _marqueeGap = 24.0;

class _MarqueeLabelState extends State<_MarqueeLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _startTimer;
  bool _reduce = false;

  /// Memoised intrinsic width. Measuring used to happen in a post-frame
  /// callback scheduled from *every* build, i.e. once per frame per row for the
  /// whole life of the tree; the inputs only change when the text, the style,
  /// or the available width does.
  String? _measuredText;
  TextStyle? _measuredStyle;
  double _intrinsicWidth = 0;
  double _intrinsicHeight = 0;

  /// Whether a pass is actually under way.
  ///
  /// Separate from `widget.active`: the delay has to gate what is *rendered*,
  /// not just when the controller starts. Gating only the controller left the
  /// duplicated marquee track on screen from the first hover frame, which is
  /// the flicker the delay exists to prevent.
  bool _passing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        // One pass, then back to the static ellipsised label.
        if (mounted) setState(() => _passing = false);
        _controller.value = 0;
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(_MarqueeLabel old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) _arm();
    if (old.active && !widget.active) _stop();
    if (old.text != widget.text) {
      _stop();
      if (widget.active) _arm();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _stop() {
    _startTimer?.cancel();
    _startTimer = null;
    _controller
      ..stop()
      ..value = 0;
    if (_passing && mounted) setState(() => _passing = false);
  }

  /// Schedules one pass, after [_marqueeDelay].
  void _arm() {
    _startTimer?.cancel();
    _startTimer = Timer(_marqueeDelay, () {
      if (!mounted || !widget.active || _reduce) return;
      final distance = _distance;
      if (distance <= 0) return;
      // One pass, then stop. The source looped forever with a 2s pause; a label
      // that never settles is a label you cannot finish reading, and the row is
      // already fully announced to assistive technology.
      _controller.duration = Duration(
        milliseconds: (math.max(2.4, distance / 34) * 1000).round(),
      );
      setState(() => _passing = true);
      _controller.forward(from: 0);
    });
  }

  double _viewportWidth = 0;

  double get _distance =>
      _intrinsicWidth > _viewportWidth ? _intrinsicWidth + _marqueeGap : 0.0;

  /// Measures the label directly rather than probing render objects, so the
  /// answer is available during layout instead of a frame later.
  void _measure(double viewportWidth) {
    if (_measuredText == widget.text &&
        _measuredStyle == widget.style &&
        _viewportWidth == viewportWidth) {
      return;
    }
    _measuredText = widget.text;
    _measuredStyle = widget.style;
    _viewportWidth = viewportWidth;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    _intrinsicWidth = painter.width;
    _intrinsicHeight = painter.height;
    painter.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0);
        final distance = _distance;
        final canRun = _passing && distance > 0 && !_reduce;

        // Static path: ellipsis clip — no overflow, matches collapsed
        // hover-off, and the resting state of a settled marquee.
        if (!canRun) {
          return SizedBox(
            width: double.infinity,
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          );
        }

        // Marquee path: unconstrained track clipped to the viewport.
        //
        // The height is pinned to the measured line: the row's Column hands
        // children an unbounded height, and an OverflowBox under an unbounded
        // constraint tries to be infinitely tall.
        return SizedBox(
          width: double.infinity,
          height: _intrinsicHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final dx = -distance * _controller.value;
                return OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: widget.style,
                        ),
                        const SizedBox(width: _marqueeGap),
                        Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: widget.style,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
