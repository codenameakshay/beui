part of 'table.dart';

/// The header/body rule under `border-collapse: collapse`.
///
/// A collapsed border is painted on the grid line *between* the two cells, over
/// the table's own background — the header's `bg-muted` fill does not extend
/// under it. Compositing the semi-transparent `--border` token over
/// `--background` (rather than over `--muted`) reproduces that exactly.
Color _collapsedRule(BeuiColors colors) =>
    Color.alphaBlend(colors.border, colors.background);

/// The sticky header row — the Flutter port of `table-header.tsx`.
///
/// Each header cell hosts (in source order) an optional reorder grip, the sort
/// button / rename input / plain label, and an optional right-edge resize
/// handle. The whole cell lifts on `SPRING_PRESS` (scale 1.04, opacity 0.5)
/// while its column is being dragged, and a primary drop indicator tracks the
/// reorder boundary.
class _TableHeader<T> extends StatelessWidget {
  const _TableHeader({
    required this.state,
    required this.columns,
    required this.colors,
    required this.reduce,
    required this.resolved,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleAll,
    required this.hasColumnMenu,
  });

  final _BeuiTableState<T> state;
  final List<BeuiTableColumn<T>> columns;
  final BeuiColors colors;
  final bool reduce;
  final Map<String, double> resolved;
  final bool allSelected;
  final bool someSelected;
  final VoidCallback onToggleAll;
  final bool hasColumnMenu;

  @override
  Widget build(BuildContext context) {
    final dragKey = state._dragKey;
    final dropIndex = state._dropIndex;

    // Reorder drop indicator x: left edge of the target column (or the right
    // edge of the last column when dropping at the end).
    double? indicatorX;
    if (dragKey != null && dropIndex != null) {
      var x = state.widget.selectable ? _checkboxWidth : 0.0;
      final clamped = dropIndex.clamp(0, columns.length);
      for (var i = 0; i < clamped; i++) {
        x += resolved[columns[i].key]!;
      }
      indicatorX = x;
    }

    final headerRow = Row(
      children: [
        if (state.widget.selectable)
          Container(
            width: _checkboxWidth,
            height: state.widget.rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.muted,
              border: Border(bottom: BorderSide(color: _collapsedRule(colors))),
            ),
            child: BeuiCheckbox(
              value: allSelected,
              indeterminate: !allSelected && someSelected,
              onChanged: (_) => onToggleAll(),
            ),
          ),
        for (var i = 0; i < columns.length; i++)
          _HeaderCell<T>(
            key: state._headerKey(columns[i].key),
            state: state,
            column: columns[i],
            index: i,
            colors: colors,
            reduce: reduce,
            width: resolved[columns[i].key]!,
            isDragging: dragKey == columns[i].key,
            hasColumnMenu: hasColumnMenu,
          ),
        // Trailing spacer header (source's empty filler `<th aria-hidden />`).
        Expanded(
          child: Container(
            height: state.widget.rowHeight,
            decoration: BoxDecoration(
              color: colors.muted,
              border: Border(bottom: BorderSide(color: _collapsedRule(colors))),
            ),
          ),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        headerRow,
        if (indicatorX != null)
          Positioned(
            left: indicatorX - 1,
            top: 0,
            bottom: 0,
            width: 2,
            child: IgnorePointer(child: ColoredBox(color: colors.primary)),
          ),
      ],
    );
  }
}

/// A single header cell.
class _HeaderCell<T> extends StatefulWidget {
  const _HeaderCell({
    required this.state,
    required this.column,
    required this.index,
    required this.colors,
    required this.reduce,
    required this.width,
    required this.isDragging,
    required this.hasColumnMenu,
    super.key,
  });

  final _BeuiTableState<T> state;
  final BeuiTableColumn<T> column;
  final int index;
  final BeuiColors colors;
  final bool reduce;
  final double width;
  final bool isDragging;
  final bool hasColumnMenu;

  @override
  State<_HeaderCell<T>> createState() => _HeaderCellState<T>();
}

class _HeaderCellState<T> extends State<_HeaderCell<T>> {
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final colors = w.colors;
    final column = w.column;
    final state = w.state;
    final sort = state._sort;
    final active = sort?.key == column.key;
    final isActive = state._activeColumn == column.key;

    // SPRING_PRESS lift while dragging: scale 1.04 (dropped under reduced
    // motion), opacity 0.5 either way.
    final scaleTarget = w.isDragging && !w.reduce ? 1.04 : 1.0;

    Widget content = Row(
      children: [
        if (state.widget.reorderable)
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => state._startReorder(column.key),
              onHorizontalDragUpdate: (d) =>
                  state._moveReorder(d.globalPosition.dx),
              onHorizontalDragEnd: (_) => state._endReorder(),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  LucideIcons.grip_vertical,
                  size: 14,
                  color: colors.mutedForeground.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        Expanded(child: _label(context, active: active)),
      ],
    );

    content = SingleMotionBuilder(
      value: scaleTarget,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AnimatedOpacity(
        opacity: w.isDragging ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: content,
      ),
    );

    Widget cell = Container(
      width: w.width,
      height: state.widget.rowHeight,
      decoration: BoxDecoration(
        color: colors.muted,
        border: Border(
          bottom: BorderSide(color: _collapsedRule(colors)),
          top: isActive ? BorderSide(color: colors.primary) : BorderSide.none,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: content),
          // Right-edge resize handle.
          if (state.widget.resizable)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 6,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) =>
                      state._startResize(column.key, d.globalPosition.dx),
                  onHorizontalDragUpdate: (d) =>
                      state._moveResize(d.globalPosition.dx),
                  onHorizontalDragEnd: (_) => state._endResize(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          // Hover-revealed column menu handle straddling the top border. Its own
          // opaque MouseRegion re-activates the column on enter (cancelling the
          // 100ms deactivate grace) and re-arms it on exit, so the pointer can
          // cross from the header cell onto the handle without it unmounting —
          // mirroring the source ColumnHandle onPointerEnter / onPointerLeave.
          if (w.hasColumnMenu && isActive)
            Positioned(
              top: -1,
              left: 0,
              right: 0,
              child: Center(
                child: MouseRegion(
                  onEnter: (_) => state._activateColumn(column.key),
                  onExit: (_) => state._deactivateColumn(column.key),
                  child: _ColumnHandle<T>(
                    state: state,
                    column: column,
                    index: w.index,
                    colors: colors,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!w.hasColumnMenu) return cell;
    return MouseRegion(
      onEnter: (_) => state._activateColumn(column.key),
      onExit: (_) => state._deactivateColumn(column.key),
      child: cell,
    );
  }

  Widget _label(BuildContext context, {required bool active}) {
    final w = widget;
    final column = w.column;
    final state = w.state;
    final colors = w.colors;

    if (column.sortable) {
      final sort = state._sort;
      final desc = active && sort?.direction == BeuiSortDirection.desc;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => state._toggleSort(column.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: _rowAlign(column.align),
              children: [
                Flexible(
                  child: Text(
                    column.header,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: active
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedOpacity(
                  opacity: active ? 1 : 0.35,
                  duration: w.reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: AnimatedRotation(
                    turns: desc ? 0.5 : 0,
                    duration: w.reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: beuiEaseOut,
                    child: Icon(
                      LucideIcons.chevron_up,
                      size: 14,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.widget.onColumnRename != null) {
      return _HeaderRenameField(
        key: ValueKey('rename_${column.key}'),
        value: column.header,
        colors: colors,
        align: column.align,
        onChanged: (v) => state.widget.onColumnRename!(column.key, v),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: _alignment(column.align),
        child: Text(
          column.header,
          overflow: TextOverflow.ellipsis,
          textAlign: _textAlign(column.align),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

MainAxisAlignment _rowAlign(BeuiTableAlign align) => switch (align) {
  BeuiTableAlign.right => MainAxisAlignment.end,
  BeuiTableAlign.center => MainAxisAlignment.center,
  BeuiTableAlign.left => MainAxisAlignment.start,
};

/// Inline header rename input (source: non-sortable header becomes an input
/// when `onColumnRename` is set).
class _HeaderRenameField extends StatefulWidget {
  const _HeaderRenameField({
    required this.value,
    required this.colors,
    required this.align,
    required this.onChanged,
    super.key,
  });

  final String value;
  final BeuiColors colors;
  final BeuiTableAlign align;
  final ValueChanged<String> onChanged;

  @override
  State<_HeaderRenameField> createState() => _HeaderRenameFieldState();
}

class _HeaderRenameFieldState extends State<_HeaderRenameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void didUpdateWidget(_HeaderRenameField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text && !_focused) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          textAlign: _textAlign(widget.align),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _focused ? colors.foreground : colors.mutedForeground,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: _focused,
            fillColor: colors.muted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hover-revealed column menu handle (source `ColumnHandle`) — a short pill
/// on the header's top border that opens the insert / delete menu.
class _ColumnHandle<T> extends StatelessWidget {
  const _ColumnHandle({
    required this.state,
    required this.column,
    required this.index,
    required this.colors,
  });

  final _BeuiTableState<T> state;
  final BeuiTableColumn<T> column;
  final int index;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return _TableMenu(
      colors: colors,
      width: 24,
      height: 8,
      icon: LucideIcons.ellipsis,
      items: [
        if (state.widget.onInsertColumn != null) ...[
          _TableMenuEntry(
            label: 'Insert before',
            icon: LucideIcons.arrow_left_to_line,
            onSelect: () => state.widget.onInsertColumn!(
              index,
              BeuiTableInsertPosition.before,
            ),
          ),
          _TableMenuEntry(
            label: 'Insert after',
            icon: LucideIcons.arrow_right_to_line,
            onSelect: () => state.widget.onInsertColumn!(
              index,
              BeuiTableInsertPosition.after,
            ),
          ),
        ],
        if (state.widget.onDeleteColumn != null)
          _TableMenuEntry(
            label: 'Delete column',
            icon: LucideIcons.trash_2,
            destructive: true,
            onSelect: () => state.widget.onDeleteColumn!(column.key, index),
          ),
      ],
    );
  }
}
