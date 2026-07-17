/// The Flutter port of beUI's `table` block — a virtualized data grid with
/// column resize, drag reorder, sortable headers, inline-editable cells, row /
/// column insert-delete menus, and async skeleton loading.
///
/// Mirrors the source's file split (`index.tsx` + `table-header.tsx` +
/// `editable-cell.tsx` + `row-handle.tsx` + `skeleton-rows.tsx` +
/// `table-menu.tsx` + the `use-column-*` hooks) via Dart `part`s: [BeuiTable]
/// and its public types live here, the sub-surfaces are library-private parts.
///
/// Only [BeuiTable], [BeuiTableColumn], [BeuiSortState], [BeuiSortDirection],
/// [BeuiTableAlign] and [BeuiTableInsertPosition] are exported through the
/// barrel; every `_`-prefixed helper below is internal.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../overlay/beui_overlay.dart';
import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import '../checkbox.dart';

part 'editable_cell.dart';
part 'row_handle.dart';
part 'skeleton_rows.dart';
part 'table_header.dart';
part 'table_menu.dart';

/// Sort direction for a column (source `SortDirection`).
enum BeuiSortDirection {
  /// Ascending.
  asc,

  /// Descending.
  desc,
}

/// The active sort — a column [key] and its [direction] (source `SortState`).
@immutable
class BeuiSortState {
  /// Creates a sort state.
  const BeuiSortState({required this.key, required this.direction});

  /// The [BeuiTableColumn.key] being sorted.
  final String key;

  /// Sort direction.
  final BeuiSortDirection direction;

  @override
  bool operator ==(Object other) =>
      other is BeuiSortState &&
      other.key == key &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(key, direction);
}

/// Where an inserted row / column lands relative to the target (source
/// `InsertPosition`).
enum BeuiTableInsertPosition {
  /// Before the target index.
  before,

  /// After the target index.
  after,
}

/// Cell / header horizontal alignment (source column `align`).
enum BeuiTableAlign {
  /// Left / start (default).
  left,

  /// Centered.
  center,

  /// Right / end.
  right,
}

/// A column definition — the Flutter port of the source `TableColumn<T>`.
///
/// Where the source reads `row[key]` generically off a JS object, Dart's static
/// typing needs an explicit accessor: supply [value] for the default cell text
/// and the string sort key, and [sortValue] for a typed (usually numeric) sort
/// key. A custom [cell] takes precedence over both for rendering.
@immutable
class BeuiTableColumn<T> {
  /// Creates a column. [key] is the stable identity (used for sort/resize/
  /// reorder/selection and as the default header edit target).
  const BeuiTableColumn({
    required this.key,
    required this.header,
    this.cell,
    this.value,
    this.sortValue,
    this.sortable = false,
    this.editable = false,
    this.align = BeuiTableAlign.left,
    this.width,
    this.flex = 1,
  });

  /// Stable key; also the default header text edit target and reorder identity.
  final String key;

  /// Header label. When the column is renameable (see
  /// [BeuiTable.onColumnRename]) this becomes the initial value of the header
  /// text field.
  final String header;

  /// Custom cell renderer. Falls back to a [Text] of [value] (or an inline
  /// editor when [editable]).
  final Widget Function(T row)? cell;

  /// Text accessor for the default cell + the string sort key (source's
  /// `row[key]`). Required for non-[cell] columns that display or sort by text.
  final String Function(T row)? value;

  /// Typed value used for sorting (source `sortValue`), e.g. a `num` for a
  /// numeric column (numbers compare numerically, everything else by string).
  /// Falls back to [value]. A `num`/`String` accessor satisfies this via Dart's
  /// covariant generics.
  final Comparable<Object?> Function(T row)? sortValue;

  /// Allow clicking the header to sort by this column.
  final bool sortable;

  /// Render an inline text editor for this column's cells (ignored when [cell]
  /// is set). Mirrors the source `editable`.
  final bool editable;

  /// Cell + header alignment.
  final BeuiTableAlign align;

  /// Fixed column width in logical pixels. Omit to share remaining space by
  /// [flex] (the source's fr-unit / auto columns).
  final double? width;

  /// Flexible share weight when [width] is null. Defaults to 1.
  final double flex;
}

/// A virtualized, interactive data table — the Flutter port of beUI's `table`.
///
/// Feature-complete against the source's three registry examples:
///
/// * **data** — [selectable] checkbox column with an indeterminate select-all,
///   [sortable] headers (arrow rotates on the 180ms `EASE_OUT` curve, source
///   `table-header.tsx`), [resizable] columns (drag the right edge; widths are
///   **measured** from the live header cells at drag start so only the dragged
///   column moves), and [reorderable] columns (drag the grip; the header cell
///   lifts on `SPRING_PRESS` — scale 1.04, opacity 0.5 — and a primary drop
///   indicator tracks the boundary).
/// * **editable** — inline [_EditableCell] text editors (via [onCellEdit]),
///   renameable headers ([onColumnRename]), and row / column insert-delete
///   menus ([onInsertRow]/[onDeleteRow]/[onInsertColumn]/[onDeleteColumn]) whose
///   popup springs open on `SPRING_PANEL`.
/// * **async** — [loading] shows pulsing [_SkeletonRows]; [onEndReached] fires
///   once per near-bottom dwell (paused while [loading]) for infinite scroll.
///
/// **Motion engine.** Springs run through `motor` (via `_engine.dart` +
/// `motion.dart` tokens): `SPRING_PRESS` for the reorder lift, `SPRING_PANEL`
/// for the menu, and the sort arrow's `EASE_OUT` curve. Resize tracks the
/// pointer 1:1 exactly like the source (no artificial spring lag on a resize
/// handle); the *measure-driven* part is the GlobalKey + RenderBox seeding of
/// column widths at drag start.
///
/// **Reduced motion.** The reorder lift drops its scale (opacity only), the
/// sort arrow snaps, the menu fades without slide, and skeletons stop pulsing —
/// movement is dropped, opacity/colour kept, per the library rule.
///
/// Selection and sort follow the source's controlled + uncontrolled pattern:
/// pass [selectedRowIds]/[onSelectionChange] (or [sort]/[onSortChange]) to
/// control, or seed [defaultSelectedRowIds]/[defaultSort] and let the table own
/// the state.
class BeuiTable<T> extends StatefulWidget {
  /// Creates a table over [data] with [columns].
  const BeuiTable({
    required this.data,
    required this.columns,
    this.getRowId,
    this.selectable = false,
    this.selectedRowIds,
    this.defaultSelectedRowIds,
    this.onSelectionChange,
    this.sort,
    this.defaultSort,
    this.onSortChange,
    this.resizable = false,
    this.minColumnWidth = 64,
    this.onColumnResize,
    this.reorderable = false,
    this.onColumnOrderChange,
    this.onCellEdit,
    this.onColumnRename,
    this.onInsertRow,
    this.onDeleteRow,
    this.onInsertColumn,
    this.onDeleteColumn,
    this.rowHeight = 48,
    this.height = 440,
    this.onEndReached,
    this.loading = false,
    this.skeletonRows = 3,
    this.emptyState,
    super.key,
  });

  /// The rows.
  final List<T> data;

  /// The column definitions.
  final List<BeuiTableColumn<T>> columns;

  /// Stable id per row (required for correct selection across sorts). Defaults
  /// to the row index.
  final String Function(T row, int index)? getRowId;

  /// Render a leading checkbox column with a select-all header.
  final bool selectable;

  /// Controlled selection (row ids). When null the table owns selection.
  final List<String>? selectedRowIds;

  /// Uncontrolled initial selection.
  final List<String>? defaultSelectedRowIds;

  /// Notified when the selection changes.
  final ValueChanged<List<String>>? onSelectionChange;

  /// Controlled sort. When null (and not `undefined`-equivalent), the table
  /// owns sort seeded from [defaultSort].
  final BeuiSortState? sort;

  /// Uncontrolled initial sort.
  final BeuiSortState? defaultSort;

  /// Notified when the sort changes (null clears it).
  final ValueChanged<BeuiSortState?>? onSortChange;

  /// Allow dragging a header's right edge to resize that column.
  final bool resizable;

  /// Minimum column width in px when resizing.
  final double minColumnWidth;

  /// Notified with the new width when a resize ends.
  final void Function(String key, double width)? onColumnResize;

  /// Allow dragging a header grip to reorder columns.
  final bool reorderable;

  /// Notified with the new key order after a reorder.
  final ValueChanged<List<String>>? onColumnOrderChange;

  /// Called when an [BeuiTableColumn.editable] cell changes.
  final void Function(String rowId, String columnKey, String value)? onCellEdit;

  /// When set, non-sortable headers become editable inputs for the column name.
  final void Function(String columnKey, String value)? onColumnRename;

  /// Enables the row menu's insert items (receives the target index).
  final void Function(int index, BeuiTableInsertPosition position)? onInsertRow;

  /// Enables the row menu's delete item.
  final void Function(String rowId, int index)? onDeleteRow;

  /// Enables the column menu's insert items (receives the target column index).
  final void Function(int index, BeuiTableInsertPosition position)?
  onInsertColumn;

  /// Enables the column menu's delete item.
  final void Function(String columnKey, int index)? onDeleteColumn;

  /// Fixed row height in px (required for virtualization).
  final double rowHeight;

  /// Total table height in px (header + scroll body).
  final double height;

  /// Fires when the body scrolls near the bottom — load the next page.
  final VoidCallback? onEndReached;

  /// Currently fetching — shows skeleton rows and pauses [onEndReached].
  final bool loading;

  /// How many skeleton rows to append while loading more (default 3).
  final int skeletonRows;

  /// Shown when there are no rows and not [loading]. Defaults to "No data".
  final Widget? emptyState;

  @override
  State<BeuiTable<T>> createState() => _BeuiTableState<T>();
}

/// A data row paired with its stable id (source `TableRow<T>`).
class _Entry<T> {
  const _Entry(this.row, this.id);
  final T row;
  final String id;
}

/// Leading checkbox column width (source `CHECKBOX_PX`).
const double _checkboxWidth = 48;

class _BeuiTableState<T> extends State<BeuiTable<T>> {
  // --- selection (controlled + uncontrolled, source use-row-selection) ------
  late Set<String> _internalSelected = {...?widget.defaultSelectedRowIds};

  // --- sort (controlled + uncontrolled, source use-column-sort) -------------
  late BeuiSortState? _internalSort = widget.defaultSort;

  // --- column order (source use-column-reorder) -----------------------------
  late List<String> _order = widget.columns.map((c) => c.key).toList();

  // --- resize (source use-column-resize) ------------------------------------
  final Map<String, double> _widths = {};

  // Per-column header cell keys — the measure seam for resize/reorder.
  final Map<String, GlobalKey> _headerKeys = {};

  // Active resize drag.
  String? _resizeKey;
  double _resizeStartX = 0;
  double _resizeStartWidth = 0;

  // Active reorder drag.
  String? _dragKey;
  int? _dropIndex;

  // Hover-activated menu handles.
  String? _activeColumn;
  String? _activeRowId;

  final ScrollController _vScroll = ScrollController();
  bool _endReachedFired = false;

  @override
  void initState() {
    super.initState();
    _vScroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(BeuiTable<T> old) {
    super.didUpdateWidget(old);
    // Infinite-scroll guard resets when a load completes (source effect).
    if (old.loading && !widget.loading) _endReachedFired = false;
  }

  @override
  void dispose() {
    _vScroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  GlobalKey _headerKey(String key) =>
      _headerKeys.putIfAbsent(key, GlobalKey.new);

  // Apply the current order, tolerating columns added/removed at runtime — an
  // inserted column lands after its left neighbour (source use-column-reorder).
  List<BeuiTableColumn<T>> get _orderedColumns {
    final byKey = {for (final c in widget.columns) c.key: c};
    final resultKeys = _order.where(byKey.containsKey).toList();
    final present = resultKeys.toSet();
    for (var i = 0; i < widget.columns.length; i++) {
      final column = widget.columns[i];
      if (present.contains(column.key)) continue;
      var at = resultKeys.length;
      if (i == 0) {
        at = 0;
      } else {
        final idx = resultKeys.indexOf(widget.columns[i - 1].key);
        at = idx == -1 ? i : idx + 1;
      }
      resultKeys.insert(math.min(at, resultKeys.length), column.key);
      present.add(column.key);
    }
    return [for (final k in resultKeys) byKey[k]!];
  }

  // Controlled when [BeuiTable.sort] is provided, else the internal state
  // (seeded from [BeuiTable.defaultSort]). Mirrors the selection pattern.
  BeuiSortState? get _sort => widget.sort ?? _internalSort;

  Set<String> get _selected =>
      widget.selectedRowIds != null
          ? {...widget.selectedRowIds!}
          : _internalSelected;

  // ---- selection ------------------------------------------------------------
  void _commitSelection(Set<String> next) {
    if (widget.selectedRowIds == null) setState(() => _internalSelected = next);
    widget.onSelectionChange?.call(next.toList());
  }

  void _toggleRow(String id) {
    final next = {..._selected};
    if (!next.remove(id)) next.add(id);
    _commitSelection(next);
  }

  void _toggleAll(List<_Entry<T>> rows) {
    final next = {..._selected};
    final all = rows.isNotEmpty && rows.every((r) => next.contains(r.id));
    if (all) {
      for (final r in rows) {
        next.remove(r.id);
      }
    } else {
      for (final r in rows) {
        next.add(r.id);
      }
    }
    _commitSelection(next);
  }

  // ---- sort -----------------------------------------------------------------
  void _commitSort(BeuiSortState? next) {
    if (widget.sort == null) setState(() => _internalSort = next);
    widget.onSortChange?.call(next);
  }

  void _toggleSort(String key) {
    final s = _sort;
    if (s == null || s.key != key) {
      _commitSort(BeuiSortState(key: key, direction: BeuiSortDirection.asc));
    } else if (s.direction == BeuiSortDirection.asc) {
      _commitSort(BeuiSortState(key: key, direction: BeuiSortDirection.desc));
    } else {
      _commitSort(null);
    }
  }

  List<_Entry<T>> _sortedRows(List<_Entry<T>> rows) {
    final s = _sort;
    if (s == null) return rows;
    final column =
        widget.columns.where((c) => c.key == s.key).firstOrNull;
    if (column == null) return rows;
    final copy = [...rows];
    copy.sort((a, b) {
      final av = _sortKey(column, a.row);
      final bv = _sortKey(column, b.row);
      int cmp;
      if (av is num && bv is num) {
        cmp = av.compareTo(bv);
      } else {
        cmp = av.toString().compareTo(bv.toString());
      }
      return s.direction == BeuiSortDirection.asc ? cmp : -cmp;
    });
    return copy;
  }

  Object _sortKey(BeuiTableColumn<T> column, T row) {
    if (column.sortValue != null) return column.sortValue!(row) as Object;
    return column.value?.call(row) ?? '';
  }

  // ---- reorder --------------------------------------------------------------
  void _startReorder(String key) {
    setState(() {
      _dragKey = key;
      _dropIndex = _orderedColumns.indexWhere((c) => c.key == key);
    });
  }

  void _moveReorder(double globalX) {
    if (_dragKey == null) return;
    final cols = _orderedColumns;
    var drop = cols.length;
    for (var i = 0; i < cols.length; i++) {
      final rect = _globalRectFor(cols[i].key);
      if (rect != null && globalX < rect.left + rect.width / 2) {
        drop = i;
        break;
      }
    }
    if (drop != _dropIndex) setState(() => _dropIndex = drop);
  }

  void _endReorder() {
    final drag = _dragKey;
    final drop = _dropIndex;
    if (drag != null && drop != null) {
      final keys = _orderedColumns.map((c) => c.key).toList();
      final from = keys.indexOf(drag);
      if (from != -1) {
        keys.removeAt(from);
        var to = drop;
        if (from < to) to--;
        keys.insert(math.min(to, keys.length), drag);
        _order = keys;
        widget.onColumnOrderChange?.call(keys);
      }
    }
    setState(() {
      _dragKey = null;
      _dropIndex = null;
    });
  }

  // ---- resize ---------------------------------------------------------------
  void _startResize(String key, double globalX) {
    // Freeze every column to its *measured* pixel width so resizing one only
    // grows the trailing spacer, never the neighbours (source use-column-resize).
    // This is the measure-driven seam: read each live header cell's RenderBox.
    final snapshot = <String, double>{..._widths};
    for (final column in _orderedColumns) {
      if (snapshot[column.key] == null) {
        final rect = _globalRectFor(column.key);
        snapshot[column.key] =
            rect != null
                ? rect.width.roundToDouble()
                : (column.width ?? widget.minColumnWidth);
      }
    }
    setState(() {
      _widths
        ..clear()
        ..addAll(snapshot);
      _resizeKey = key;
      _resizeStartX = globalX;
      _resizeStartWidth = snapshot[key]!;
    });
  }

  void _moveResize(double globalX) {
    final key = _resizeKey;
    if (key == null) return;
    final width = math.max(
      widget.minColumnWidth,
      _resizeStartWidth + (globalX - _resizeStartX),
    );
    setState(() => _widths[key] = width);
  }

  void _endResize() {
    final key = _resizeKey;
    _resizeKey = null;
    if (key != null) {
      widget.onColumnResize?.call(key, _widths[key] ?? _resizeStartWidth);
    }
  }

  Rect? _globalRectFor(String key) {
    final ctx = _headerKeys[key]?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ---- hover activation (menus) --------------------------------------------
  void _activateColumn(String key) {
    if (_activeColumn != key) setState(() => _activeColumn = key);
  }

  void _deactivateColumn(String key) {
    if (_activeColumn == key) setState(() => _activeColumn = null);
  }

  void _activateRow(String id, int index) {
    if (_activeRowId != id) setState(() => _activeRowId = id);
  }

  void _deactivateRow(String id) {
    if (_activeRowId == id) setState(() => _activeRowId = null);
  }

  // ---- infinite scroll ------------------------------------------------------
  void _onScroll() {
    if (widget.onEndReached == null || widget.loading || _endReachedFired) {
      return;
    }
    if (!_vScroll.hasClients) return;
    final position = _vScroll.position;
    if (position.maxScrollExtent - position.pixels < widget.rowHeight * 4) {
      _endReachedFired = true;
      widget.onEndReached!();
    }
  }

  // ---- width resolution -----------------------------------------------------
  //
  // Fixed columns keep their resize override / declared width; the rest share
  // the remaining viewport by flex. A trailing spacer owns any leftover (the
  // source's empty `<col/>` filler), so content stays fill-width until columns
  // out-grow the viewport, at which point the table scrolls horizontally.
  Map<String, double> _resolveWidths(
    List<BeuiTableColumn<T>> cols,
    double viewport,
  ) {
    final resolved = <String, double>{};
    var fixedSum = 0.0;
    var flexSum = 0.0;
    for (final c in cols) {
      final fixed = _widths[c.key] ?? c.width;
      if (fixed != null) {
        fixedSum += fixed;
      } else {
        flexSum += c.flex;
      }
    }
    final avail = viewport - (widget.selectable ? _checkboxWidth : 0);
    final remaining = math.max(0.0, avail - fixedSum);
    final perFlex = flexSum > 0 ? remaining / flexSum : 0.0;
    for (final c in cols) {
      final fixed = _widths[c.key] ?? c.width;
      resolved[c.key] =
          fixed ?? math.max(widget.minColumnWidth, perFlex * c.flex);
    }
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final rows = <_Entry<T>>[
      for (var i = 0; i < widget.data.length; i++)
        _Entry(
          widget.data[i],
          widget.getRowId?.call(widget.data[i], i) ?? '$i',
        ),
    ];
    final sortedRows = _sortedRows(rows);
    final cols = _orderedColumns;

    final hasRowMenu =
        widget.onInsertRow != null || widget.onDeleteRow != null;
    final hasColumnMenu =
        widget.onInsertColumn != null || widget.onDeleteColumn != null;

    final allSelected =
        sortedRows.isNotEmpty && sortedRows.every((r) => _selected.contains(r.id));
    final someSelected = sortedRows.any((r) => _selected.contains(r.id));

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.maxWidth;
            final resolved = _resolveWidths(cols, viewport);
            final columnsWidth =
                (widget.selectable ? _checkboxWidth : 0) +
                cols.fold<double>(0, (sum, c) => sum + resolved[c.key]!);
            final contentWidth = math.max(viewport, columnsWidth);
            final bodyHeight = math.max(0.0, widget.height - widget.rowHeight);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TableHeader<T>(
                      state: this,
                      columns: cols,
                      colors: colors,
                      reduce: reduce,
                      resolved: resolved,
                      allSelected: allSelected,
                      someSelected: someSelected,
                      onToggleAll: () => _toggleAll(sortedRows),
                      hasColumnMenu: hasColumnMenu,
                    ),
                    SizedBox(
                      height: bodyHeight,
                      child: _buildBody(
                        colors: colors,
                        reduce: reduce,
                        cols: cols,
                        resolved: resolved,
                        sortedRows: sortedRows,
                        bodyHeight: bodyHeight,
                        hasRowMenu: hasRowMenu,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody({
    required BeuiColors colors,
    required bool reduce,
    required List<BeuiTableColumn<T>> cols,
    required Map<String, double> resolved,
    required List<_Entry<T>> sortedRows,
    required double bodyHeight,
    required bool hasRowMenu,
  }) {
    if (sortedRows.isEmpty) {
      if (widget.loading) {
        final count = math.max(1, (bodyHeight / widget.rowHeight).ceil());
        return SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < count; i++)
                _SkeletonRow<T>(
                  columns: cols,
                  resolved: resolved,
                  colors: colors,
                  reduce: reduce,
                  rowHeight: widget.rowHeight,
                  selectable: widget.selectable,
                ),
            ],
          ),
        );
      }
      return Center(
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.mutedForeground, fontSize: 14),
          child: widget.emptyState ?? const Text('No data'),
        ),
      );
    }

    final skeletonCount = widget.loading ? widget.skeletonRows : 0;
    return ListView.builder(
      controller: _vScroll,
      itemExtent: widget.rowHeight,
      itemCount: sortedRows.length + skeletonCount,
      itemBuilder: (context, index) {
        if (index >= sortedRows.length) {
          return _SkeletonRow<T>(
            columns: cols,
            resolved: resolved,
            colors: colors,
            reduce: reduce,
            rowHeight: widget.rowHeight,
            selectable: widget.selectable,
          );
        }
        final entry = sortedRows[index];
        return _DataRow<T>(
          state: this,
          entry: entry,
          index: index,
          columns: cols,
          resolved: resolved,
          colors: colors,
          selected: _selected.contains(entry.id),
          hasRowMenu: hasRowMenu,
        );
      },
    );
  }
}

/// One body row — its cells, the leading checkbox, hover/selection background,
/// and (when enabled) the left-edge row menu handle.
class _DataRow<T> extends StatefulWidget {
  const _DataRow({
    required this.state,
    required this.entry,
    required this.index,
    required this.columns,
    required this.resolved,
    required this.colors,
    required this.selected,
    required this.hasRowMenu,
    super.key,
  });

  final _BeuiTableState<T> state;
  final _Entry<T> entry;
  final int index;
  final List<BeuiTableColumn<T>> columns;
  final Map<String, double> resolved;
  final BeuiColors colors;
  final bool selected;
  final bool hasRowMenu;

  @override
  State<_DataRow<T>> createState() => _DataRowState<T>();
}

class _DataRowState<T> extends State<_DataRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final colors = w.colors;

    final bg =
        w.selected
            ? colors.primary.withValues(alpha: 0.05)
            : _hovered
            ? colors.muted.withValues(alpha: 0.5)
            : Colors.transparent;

    Widget cells = Row(
      children: [
        if (w.state.widget.selectable)
          SizedBox(
            width: _checkboxWidth,
            child: Center(
              child: BeuiCheckbox(
                value: w.selected,
                onChanged: (_) => w.state._toggleRow(w.entry.id),
              ),
            ),
          ),
        for (final column in w.columns)
          SizedBox(
            width: w.resolved[column.key],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: _alignment(column.align),
                child: _cellChild(column),
              ),
            ),
          ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );

    Widget row = MouseRegion(
      onEnter:
          w.hasRowMenu
              ? (_) {
                setState(() => _hovered = true);
                w.state._activateRow(w.entry.id, w.index);
              }
              : (_) => setState(() => _hovered = true),
      onExit:
          w.hasRowMenu
              ? (_) {
                setState(() => _hovered = false);
                w.state._deactivateRow(w.entry.id);
              }
              : (_) => setState(() => _hovered = false),
      child: Container(
        height: w.state.widget.rowHeight,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
          ),
        ),
        child: cells,
      ),
    );

    if (!w.hasRowMenu) return row;

    // Left-edge row menu handle, revealed on hover (source RowHandle, rendered
    // in-tree via BeuiOverlay so the popup escapes the scroll clip).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        row,
        if (_hovered)
          Positioned(
            left: -4,
            top: 0,
            bottom: 0,
            child: Center(
              child: _RowHandle<T>(
                state: w.state,
                rowId: w.entry.id,
                index: w.index,
                colors: colors,
              ),
            ),
          ),
      ],
    );
  }

  Widget _cellChild(BeuiTableColumn<T> column) {
    final w = widget;
    if (column.cell != null) {
      return DefaultTextStyle.merge(
        style: TextStyle(color: w.colors.foreground, fontSize: 14),
        child: column.cell!(w.entry.row),
      );
    }
    if (column.editable) {
      return _EditableCell(
        value: column.value?.call(w.entry.row) ?? '',
        colors: w.colors,
        align: column.align,
        onChanged:
            (next) =>
                w.state.widget.onCellEdit?.call(w.entry.id, column.key, next),
      );
    }
    return Text(
      column.value?.call(w.entry.row) ?? '',
      overflow: TextOverflow.ellipsis,
      textAlign: _textAlign(column.align),
      style: TextStyle(color: w.colors.foreground, fontSize: 14),
    );
  }
}

Alignment _alignment(BeuiTableAlign align) => switch (align) {
  BeuiTableAlign.right => Alignment.centerRight,
  BeuiTableAlign.center => Alignment.center,
  BeuiTableAlign.left => Alignment.centerLeft,
};

TextAlign _textAlign(BeuiTableAlign align) => switch (align) {
  BeuiTableAlign.right => TextAlign.right,
  BeuiTableAlign.center => TextAlign.center,
  BeuiTableAlign.left => TextAlign.left,
};
