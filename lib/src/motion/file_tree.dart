import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show NoMotion, SingleMotionBuilder;
import 'shared_layout_bg.dart';

/// A declarative folder in a [BeuiFileTree]. It is rendered by its parent tree.
class BeuiFileTreeFolder extends StatelessWidget {
  /// Creates a folder with nested [children].
  const BeuiFileTreeFolder({
    required this.value,
    required this.name,
    this.icon,
    this.disabled = false,
    this.children = const [],
    super.key,
  });

  /// Unique identifier used for selection and expanded state.
  final String value;

  /// Visible folder name.
  final String name;

  /// Optional replacement for the default folder icon.
  final Widget? icon;

  /// Whether this row can be selected or expanded.
  final bool disabled;

  /// Nested file and folder declarations.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A declarative file in a [BeuiFileTree]. It is rendered by its parent tree.
class BeuiFileTreeFile extends StatelessWidget {
  /// Creates a file row.
  const BeuiFileTreeFile({
    required this.value,
    required this.name,
    this.icon,
    this.disabled = false,
    super.key,
  });

  /// Unique identifier used for selection.
  final String value;

  /// Visible file name.
  final String name;

  /// Optional replacement for the default file icon.
  final Widget? icon;

  /// Whether this row can be selected.
  final bool disabled;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FileTreeItem {
  const _FileTreeItem({
    required this.value,
    required this.name,
    required this.isFolder,
    required this.depth,
    required this.parentId,
    required this.position,
    required this.setSize,
    required this.icon,
    required this.disabled,
  });

  final String value;
  final String name;
  final bool isFolder;
  final int depth;
  final String? parentId;
  final int position;
  final int setSize;
  final Widget? icon;
  final bool disabled;
}

/// A nested, keyboard-navigable file explorer with animated folder branches.
///
/// Supply [value] and [onChanged] for controlled selection, or seed
/// [defaultValue] for internal selection state. Expansion follows the same
/// pattern with [expandedIds], [defaultExpandedIds], and [onExpandedChanged].
/// [indent] defaults to 18 logical pixels per depth level.
class BeuiFileTree extends StatefulWidget {
  /// Creates a tree from nested [BeuiFileTreeFolder] and [BeuiFileTreeFile]
  /// declarations.
  const BeuiFileTree({
    required this.children,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.expandedIds,
    this.defaultExpandedIds = const [],
    this.onExpandedChanged,
    this.ariaLabel = 'Files',
    this.indent = 18,
    super.key,
  });

  /// Root-level file and folder declarations.
  final List<Widget> children;

  /// Selected item identifier. A non-null value makes selection controlled.
  final String? value;

  /// Initial selection when [value] is null.
  final String? defaultValue;

  /// Called when an enabled item is selected.
  final ValueChanged<String>? onChanged;

  /// Identifiers of open folders. A non-null list makes expansion controlled.
  final List<String>? expandedIds;

  /// Initial open folders when [expandedIds] is null.
  final List<String> defaultExpandedIds;

  /// Called with the new open-folder identifiers.
  final ValueChanged<List<String>>? onExpandedChanged;

  /// Accessible name for the tree.
  final String ariaLabel;

  /// Horizontal indentation per nesting level, in logical pixels.
  final double indent;

  @override
  State<BeuiFileTree> createState() => _BeuiFileTreeState();
}

class _BeuiFileTreeState extends State<BeuiFileTree> {
  late String? _internalValue = widget.defaultValue;
  late List<String> _internalExpandedIds = List.of(widget.defaultExpandedIds);
  String? _focusedId;
  final Map<String, FocusNode> _focusNodes = {};

  String? get _selected => widget.value ?? _internalValue;
  List<String> get _expandedIds => widget.expandedIds ?? _internalExpandedIds;

  @override
  void didUpdateWidget(covariant BeuiFileTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultValue != widget.defaultValue &&
        oldWidget.value == null &&
        widget.value == null) {
      _internalValue = widget.defaultValue;
    }
    if (!identical(oldWidget.defaultExpandedIds, widget.defaultExpandedIds) &&
        oldWidget.expandedIds == null &&
        widget.expandedIds == null) {
      _internalExpandedIds = List.of(widget.defaultExpandedIds);
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<_FileTreeItem> _flatten(
    List<Widget> children,
    Set<String> expanded, {
    int depth = 0,
    String? parentId,
  }) {
    final result = <_FileTreeItem>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      late final _FileTreeItem item;
      List<Widget> descendants = const [];
      if (child is BeuiFileTreeFolder) {
        item = _FileTreeItem(
          value: child.value,
          name: child.name,
          isFolder: true,
          depth: depth,
          parentId: parentId,
          position: i + 1,
          setSize: children.length,
          icon: child.icon,
          disabled: child.disabled,
        );
        descendants = child.children;
      } else if (child is BeuiFileTreeFile) {
        item = _FileTreeItem(
          value: child.value,
          name: child.name,
          isFolder: false,
          depth: depth,
          parentId: parentId,
          position: i + 1,
          setSize: children.length,
          icon: child.icon,
          disabled: child.disabled,
        );
      } else {
        continue;
      }
      result.add(item);
      if (item.isFolder && expanded.contains(item.value)) {
        result.addAll(
          _flatten(
            descendants,
            expanded,
            depth: depth + 1,
            parentId: item.value,
          ),
        );
      }
    }
    return result;
  }

  void _focusRow(String id) {
    setState(() => _focusedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[id]?.requestFocus();
    });
  }

  void _select(_FileTreeItem item) {
    if (item.disabled) return;
    if (widget.value == null) setState(() => _internalValue = item.value);
    widget.onChanged?.call(item.value);
  }

  void _toggleFolder(_FileTreeItem item) {
    if (item.disabled) return;
    final next = List<String>.of(_expandedIds);
    if (!next.remove(item.value)) next.add(item.value);
    if (widget.expandedIds == null) setState(() => _internalExpandedIds = next);
    widget.onExpandedChanged?.call(next);
  }

  KeyEventResult _onKey(
    KeyEvent event,
    _FileTreeItem row,
    List<_FileTreeItem> rows,
    Set<String> expanded,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = rows.indexWhere((item) => item.value == row.value);
    final next = index >= 0 && index + 1 < rows.length ? rows[index + 1] : null;
    final previous = index > 0 ? rows[index - 1] : null;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (next != null) _focusRow(next.value);
      case LogicalKeyboardKey.arrowUp:
        if (previous != null) _focusRow(previous.value);
      case LogicalKeyboardKey.home:
        if (rows.isNotEmpty) _focusRow(rows.first.value);
      case LogicalKeyboardKey.end:
        if (rows.isNotEmpty) _focusRow(rows.last.value);
      case LogicalKeyboardKey.arrowRight:
        if (row.isFolder) {
          if (!expanded.contains(row.value) && !row.disabled) {
            _toggleFolder(row);
          } else if (next?.parentId == row.value) {
            _focusRow(next!.value);
          }
        }
      case LogicalKeyboardKey.arrowLeft:
        if (row.isFolder && expanded.contains(row.value) && !row.disabled) {
          _toggleFolder(row);
        } else if (row.parentId != null) {
          _focusRow(row.parentId!);
        }
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        if (!row.disabled) {
          _select(row);
          if (row.isFolder) _toggleFolder(row);
        }
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final expanded = _expandedIds.toSet();
    final rows = _flatten(widget.children, expanded);
    final focused = rows.any((row) => row.value == _focusedId)
        ? _focusedId
        : rows.firstOrNull?.value;
    if (_focusedId != focused) _focusedId = focused;

    final rowWidgets = <Widget>[];
    for (final row in rows) {
      final isOpen = row.isFolder && expanded.contains(row.value);
      final selected = _selected == row.value;
      final focusNode = _focusNodes.putIfAbsent(
        row.value,
        () => FocusNode(debugLabel: 'file tree ${row.name}'),
      );
      rowWidgets.add(
        Semantics(
          container: true,
          role: SemanticsRole.listItem,
          label: row.name,
          hint: 'Level ${row.depth + 1}, ${row.position} of ${row.setSize}',
          focusable: true,
          focused: focused == row.value,
          selected: selected,
          expanded: row.isFolder ? isOpen : null,
          // Keep traversal on the row: Flutter web does not focus disabled
          // semantics nodes. The child action carries the disabled state.
          child: Semantics(
            container: true,
            button: true,
            selected: selected,
            enabled: !row.disabled,
            child: Focus(
              focusNode: focusNode,
              skipTraversal: focused != row.value,
              onFocusChange: (hasFocus) {
                if (hasFocus && _focusedId != row.value) {
                  setState(() => _focusedId = row.value);
                }
              },
              onKeyEvent: (node, event) => _onKey(event, row, rows, expanded),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: row.disabled
                    ? null
                    : () {
                        focusNode.requestFocus();
                        _select(row);
                        if (row.isFolder) _toggleFolder(row);
                      },
                child: _FileTreeRow(
                  row: row,
                  isOpen: isOpen,
                  selected: selected,
                  indent: widget.indent,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Rows entering/leaving on folder toggles share a height spring. Under
    // reduced motion the branch snaps while color and opacity remain intact.
    // Implicit AnimatedSize is skipped: it looks up TickerMode during dispose.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.list,
      label: widget.ariaLabel,
      child: ClipRect(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 0),
          child: BeuiSharedLayoutBg(
            inset: 0,
            pillColor: colors.muted.withValues(alpha: 0.5),
            children: rowWidgets,
          ),
        ),
      ),
    );
  }
}

/// One tree row.
class _FileTreeRow extends StatefulWidget {
  const _FileTreeRow({
    required this.row,
    required this.isOpen,
    required this.selected,
    required this.indent,
    required this.colors,
  });

  final _FileTreeItem row;
  final bool isOpen;
  final bool selected;
  final double indent;
  final BeuiColors colors;

  @override
  State<_FileTreeRow> createState() => _FileTreeRowState();
}

class _FileTreeRowState extends State<_FileTreeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final colors = widget.colors;
    final isOpen = widget.isOpen;
    final selected = widget.selected;
    final emphasized = selected || _hovered;
    final motion = motionFor(context, beuiSpringSwap, isMovement: true);
    return Opacity(
      opacity: row.disabled ? 0.42 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          height: 36,
          padding: EdgeInsets.only(left: 8 + row.depth * widget.indent),
          decoration: BoxDecoration(
            color: selected ? colors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              if (row.depth > 0)
                Positioned(
                  left: 16 + (row.depth - 1) * widget.indent,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: colors.border.withValues(alpha: 0.7),
                    child: const SizedBox(width: 1),
                  ),
                ),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: row.isFolder
                        ? motion is NoMotion
                              ? Transform.rotate(
                                  angle: isOpen ? 1.5707963267948966 : 0,
                                  child: Icon(
                                    LucideIcons.chevron_right,
                                    size: 14,
                                    color: emphasized
                                        ? colors.foreground
                                        : colors.mutedForeground,
                                  ),
                                )
                              : SingleMotionBuilder(
                                  value: isOpen ? 1.0 : 0.0,
                                  motion: motion,
                                  builder: (context, progress, child) =>
                                      Transform.rotate(
                                        angle: progress * 1.5707963267948966,
                                        child: child,
                                      ),
                                  child: Icon(
                                    LucideIcons.chevron_right,
                                    size: 14,
                                    color: emphasized
                                        ? colors.foreground
                                        : colors.mutedForeground,
                                  ),
                                )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        row.icon ??
                        Icon(
                          row.isFolder
                              ? (isOpen
                                    ? LucideIcons.folder_open
                                    : LucideIcons.folder)
                              : LucideIcons.file,
                          size: 16,
                          color: emphasized || isOpen
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: emphasized
                            ? colors.foreground
                            : colors.mutedForeground,
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
