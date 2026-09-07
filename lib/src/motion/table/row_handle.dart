part of 'table.dart';

/// The hover-revealed row/column menu handle (source `row-handle.tsx` /
/// `table-header.tsx`'s `ColumnHandle`) — a short pill on the row's left
/// border or the column's top border that opens its insert / delete menu.
///
/// A row and a column handle are the same control turned 90°: same trigger,
/// same menu, same entry shape — only the dimensions, glyphs, alignment and
/// which callback pair they drive differ. [_TableHandle.row] and
/// [_TableHandle.column] pick those; the body is written once.
class _TableHandle<T> extends StatelessWidget {
  const _TableHandle.row({
    required this.state,
    required String this.rowId,
    required this.index,
    required this.colors,
  }) : column = null;

  const _TableHandle.column({
    required this.state,
    required BeuiTableColumn<T> this.column,
    required this.index,
    required this.colors,
  }) : rowId = null;

  final _BeuiTableState<T> state;
  final int index;
  final BeuiColors colors;

  /// Set for [_TableHandle.row]; null for [_TableHandle.column].
  final String? rowId;

  /// Set for [_TableHandle.column]; null for [_TableHandle.row].
  final BeuiTableColumn<T>? column;

  bool get _isRow => rowId != null;

  @override
  Widget build(BuildContext context) {
    final isRow = _isRow;
    return _TableMenu(
      colors: colors,
      width: isRow ? 8 : 24,
      height: isRow ? 24 : 8,
      icon: isRow ? LucideIcons.ellipsis_vertical : LucideIcons.ellipsis,
      align: isRow ? _TableMenuAlign.start : _TableMenuAlign.end,
      items: [
        if (isRow
            ? state.widget.onInsertRow != null
            : state.widget.onInsertColumn != null) ...[
          _TableMenuEntry(
            label: 'Insert before',
            icon: isRow
                ? LucideIcons.arrow_up_to_line
                : LucideIcons.arrow_left_to_line,
            onSelect: () => isRow
                ? state.widget.onInsertRow!(
                    index,
                    BeuiTableInsertPosition.before,
                  )
                : state.widget.onInsertColumn!(
                    index,
                    BeuiTableInsertPosition.before,
                  ),
          ),
          _TableMenuEntry(
            label: 'Insert after',
            icon: isRow
                ? LucideIcons.arrow_down_to_line
                : LucideIcons.arrow_right_to_line,
            onSelect: () => isRow
                ? state.widget.onInsertRow!(
                    index,
                    BeuiTableInsertPosition.after,
                  )
                : state.widget.onInsertColumn!(
                    index,
                    BeuiTableInsertPosition.after,
                  ),
          ),
        ],
        if (isRow
            ? state.widget.onDeleteRow != null
            : state.widget.onDeleteColumn != null)
          _TableMenuEntry(
            label: isRow ? 'Delete row' : 'Delete column',
            icon: LucideIcons.trash,
            destructive: true,
            onSelect: () => isRow
                ? state.widget.onDeleteRow!(rowId!, index)
                : state.widget.onDeleteColumn!(column!.key, index),
          ),
      ],
    );
  }
}
