part of 'table.dart';

/// The hover-revealed row menu handle (source `row-handle.tsx`) — a short
/// vertical pill on the row's left border that opens the insert / delete menu.
class _RowHandle<T> extends StatelessWidget {
  const _RowHandle({
    required this.state,
    required this.rowId,
    required this.index,
    required this.colors,
  });

  final _BeuiTableState<T> state;
  final String rowId;
  final int index;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return _TableMenu(
      colors: colors,
      width: 8,
      height: 24,
      icon: LucideIcons.ellipsis_vertical,
      align: _TableMenuAlign.start,
      items: [
        if (state.widget.onInsertRow != null) ...[
          _TableMenuEntry(
            label: 'Insert before',
            icon: LucideIcons.arrow_up_to_line,
            onSelect: () => state.widget.onInsertRow!(
              index,
              BeuiTableInsertPosition.before,
            ),
          ),
          _TableMenuEntry(
            label: 'Insert after',
            icon: LucideIcons.arrow_down_to_line,
            onSelect: () =>
                state.widget.onInsertRow!(index, BeuiTableInsertPosition.after),
          ),
        ],
        if (state.widget.onDeleteRow != null)
          _TableMenuEntry(
            label: 'Delete row',
            icon: LucideIcons.trash,
            destructive: true,
            onSelect: () => state.widget.onDeleteRow!(rowId, index),
          ),
      ],
    );
  }
}
