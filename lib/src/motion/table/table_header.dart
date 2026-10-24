part of 'table.dart';

const _tableRuleWidth = 1.0;

// Paint shared rules once, after all row backgrounds. Splitting a rule across
// siblings introduces two antialiased edges at fractional row boundaries.
class _TableGridRules extends CustomPainter {
  _TableGridRules({
    required this.scroll,
    required this.rowHeight,
    required this.rowCount,
    required this.color,
    required this.headerColor,
  }) : super(repaint: scroll);

  final ScrollController scroll;
  final double rowHeight;
  final int rowCount;
  final Color color;
  final Color headerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final first = math.max(0, ((offset - _tableRuleWidth) / rowHeight).ceil());
    final last = math.min(
      rowCount,
      ((offset + size.height - rowHeight) / rowHeight).ceil(),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, rowHeight, size.width, size.height));
    final paint = Paint();
    for (var i = first; i <= last; i++) {
      paint.color = i == 0 ? headerColor : color;
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          rowHeight + i * rowHeight - offset,
          size.width,
          _tableRuleWidth,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TableGridRules old) =>
      old.scroll != scroll ||
      old.rowHeight != rowHeight ||
      old.rowCount != rowCount ||
      old.color != color ||
      old.headerColor != headerColor;
}

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
  final _ResolvedTableLayout resolved;
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
      var x = resolved.selectionWidth;
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
            width: resolved.selectionWidth,
            height: state.widget.rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.muted,
              border: state.widget.sizing == BeuiTableSizing.intrinsic
                  ? null
                  : Border(bottom: BorderSide(color: _collapsedRule(colors))),
            ),
            child: SizedBox(
              width: state.widget.sizing == BeuiTableSizing.intrinsic
                  ? 24
                  : null,
              height: state.widget.sizing == BeuiTableSizing.intrinsic
                  ? 24
                  : null,
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: BeuiCheckbox(
                  value: allSelected,
                  indeterminate: !allSelected && someSelected,
                  onChanged: (_) => onToggleAll(),
                ),
              ),
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
              border: state.widget.sizing == BeuiTableSizing.intrinsic
                  ? null
                  : Border(bottom: BorderSide(color: _collapsedRule(colors))),
            ),
          ),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (state.widget.sizing == BeuiTableSizing.intrinsic)
          SizedBox(
            height: state.widget.rowHeight + _tableRuleWidth / 2,
            child: Align(alignment: Alignment.topLeft, child: headerRow),
          )
        else
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
class _HeaderCell<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final w = this;
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
            child: Semantics(
              button: true,
              label: 'Reorder ${column.key} column',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onHorizontalDragDown: (_) => state._startReorder(column.key),
                onHorizontalDragUpdate: (d) =>
                    state._moveReorder(d.globalPosition.dx),
                onHorizontalDragEnd: (_) => state._endReorder(),
                onHorizontalDragCancel: state._endReorder,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: state.widget.sizing == BeuiTableSizing.intrinsic
                        ? 5
                        : 8,
                    right: state.widget.sizing == BeuiTableSizing.intrinsic
                        ? 5
                        : 0,
                  ),
                  child: Icon(
                    LucideIcons.grip_vertical,
                    size: 14,
                    color: colors.mutedForeground.withValues(alpha: 0.6),
                  ),
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
        border: state.widget.sizing == BeuiTableSizing.intrinsic
            ? null
            : Border(
                bottom: BorderSide(color: _collapsedRule(colors)),
                top: isActive
                    ? BorderSide(color: colors.primary)
                    : BorderSide.none,
              ),
      ),
      foregroundDecoration:
          state.widget.sizing == BeuiTableSizing.intrinsic && isActive
          ? BoxDecoration(
              border: Border(top: BorderSide(color: colors.primary)),
            )
          : null,
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
                child: Semantics(
                  button: true,
                  label: 'Resize ${column.key} column',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragDown: (d) =>
                        state._startResize(column.key, d.globalPosition.dx),
                    onHorizontalDragUpdate: (d) =>
                        state._moveResize(d.globalPosition.dx),
                    onHorizontalDragEnd: (_) => state._endResize(),
                    onHorizontalDragCancel: state._endResize,
                    child: const SizedBox.expand(),
                  ),
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
                  child: _TableHandle<T>.column(
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
    final w = this;
    final column = w.column;
    final state = w.state;
    final colors = w.colors;

    if (column.sortable) {
      final sort = state._sort;
      final desc = active && sort?.direction == BeuiSortDirection.desc;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              state._toggleSort(column.key);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Focus.of(context).requestFocus();
                state._toggleSort(column.key);
              },
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
          ),
        ),
      );
    }

    if (state.widget.onColumnRename != null) {
      return _InlineTextField.header(
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
