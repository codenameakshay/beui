import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiTable] — a 1:1 port of the source preview
/// (`components/previews/motion/table.preview.tsx`): one virtualized 10,000-row
/// grid with sortable headers, row selection, column resize and reorder, above
/// a muted row-count / selection-count caption.
Widget tableDemo(BuildContext context, {String? example}) =>
    _TableDemo(example: example ?? Uri.base.queryParameters['example']);

class _Person {
  const _Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.mrr,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String status; // active | invited | suspended
  final int mrr;
}

const _first = [
  'Ava',
  'Leo',
  'Mia',
  'Kai',
  'Zoe',
  'Eli',
  'Noa',
  'Ren',
  'Ivy',
  'Jude',
];
const _last = [
  'Cole',
  'Frost',
  'Vale',
  'Reyes',
  'Okafor',
  'Sato',
  'Lund',
  'Marsh',
  'Bose',
  'Quinn',
];
const _roles = ['Owner', 'Admin', 'Member', 'Viewer'];
const _statuses = ['active', 'invited', 'suspended'];

/// Deterministic, so the gallery and the golden tests render the same rows.
List<_Person> _buildPeople(int count) => [
  for (var i = 0; i < count; i++)
    _Person(
      id: '$i',
      name: '${_first[i % _first.length]} ${_last[(i * 7) % _last.length]}',
      email:
          '${_first[i % _first.length].toLowerCase()}.'
          '${_last[(i * 7) % _last.length].toLowerCase()}$i@beui.dev',
      role: _roles[(i * 3) % _roles.length],
      status: _statuses[(i * 5) % _statuses.length],
      mrr: 12 + ((i * 37) % 488),
    ),
];

class _TableDemo extends StatefulWidget {
  const _TableDemo({this.example});

  final String? example;

  @override
  State<_TableDemo> createState() => _TableDemoState();
}

class _EditRow {
  _EditRow(this.id, this.fields);
  final String id;
  final Map<String, String> fields;
}

class _TableDemoState extends State<_TableDemo> {
  final List<_Person> _data = _buildPeople(10000);
  List<String> _selected = const [];

  final List<_EditRow> _editRows = [
    _EditRow('r1', {'name': 'Ava Cole', 'role': 'Owner', 'team': 'Design'}),
    _EditRow('r2', {'name': 'Leo Frost', 'role': 'Admin', 'team': 'Growth'}),
    _EditRow('r3', {'name': 'Mia Vale', 'role': 'Member', 'team': 'Design'}),
    _EditRow('r4', {'name': 'Kai Reyes', 'role': 'Member', 'team': 'Platform'}),
  ];
  List<String> _editKeys = ['name', 'role', 'team'];
  final Map<String, String> _editLabels = {
    'name': 'Name',
    'role': 'Role',
    'team': 'Team',
  };
  int _nextRow = 5;
  int _nextCol = 1;
  bool _editable = true;

  List<_Person> _asyncRows = const [];
  bool _asyncLoading = true;
  int _asyncPage = 0;
  bool _asyncLoadingLock = false;
  static const int _pageSize = 20;
  static const int _maxPages = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMoreAsync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget statusBadge(String status) {
      final tint = switch (status) {
        'active' => colors.success,
        'invited' => colors.warning,
        _ => colors.destructive,
      };
      return Container(
        // rounded-full px-2 py-0.5 font-medium text-xs capitalize
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status[0].toUpperCase() + status.substring(1),
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: tint,
          ),
        ),
      );
    }

    final columns = <BeuiTableColumn<_Person>>[
      BeuiTableColumn(
        key: 'name',
        header: 'Name',
        sortable: true,
        flex: 1.4,
        value: (r) => r.name,
        cell: (r) => Text(
          r.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      BeuiTableColumn(
        key: 'email',
        header: 'Email',
        flex: 1.8,
        value: (r) => r.email,
      ),
      BeuiTableColumn(
        key: 'role',
        header: 'Role',
        sortable: true,
        width: 120,
        value: (r) => r.role,
      ),
      BeuiTableColumn(
        key: 'status',
        header: 'Status',
        width: 130,
        value: (r) => r.status,
        cell: (r) => statusBadge(r.status),
      ),
      BeuiTableColumn(
        key: 'mrr',
        header: 'MRR',
        sortable: true,
        align: BeuiTableAlign.right,
        width: 110,
        value: (r) => '\$${groupThousands(r.mrr)}',
        sortValue: (r) => r.mrr,
        cell: (r) => Text(
          '\$${groupThousands(r.mrr)}',
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    ];

    final captionStyle = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      color: colors.mutedForeground,
    );

    // flex w-full justify-center p-4  >  flex w-full flex-col gap-2
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.example == null || widget.example == 'data') ...[
            Padding(
              // px-1
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${groupThousands(_data.length)} rows',
                    style: captionStyle,
                  ),
                  if (_selected.isNotEmpty)
                    Text(
                      '${groupThousands(_selected.length)} selected',
                      style: captionStyle,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8), // gap-2
            BeuiTable<_Person>(
              data: _data,
              columns: columns,
              getRowId: (r, _) => r.id,
              selectable: true,
              resizable: true,
              reorderable: true,
              selectedRowIds: _selected,
              onSelectionChange: (ids) => setState(() => _selected = ids),
              defaultSort: const BeuiSortState(
                key: 'mrr',
                direction: BeuiSortDirection.desc,
              ),
              height: 420,
              rowHeight: 52,
            ),
          ],
          if (widget.example == null ||
              widget.example == 'editable' ||
              widget.example == 'editable-recovery') ...[
            if (widget.example == 'editable-recovery') ...[
              _sectionLabel(colors, 'Editable recovery example'),
              const SizedBox(height: 8),
            ],
            if (widget.example == null) ...[
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Editable Table'),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _editable
                        ? 'Click a cell to edit. Use the column and row handles to insert or delete.'
                        : 'Read-only.',
                    style: captionStyle,
                  ),
                ),
                BeuiSwitch(
                  value: _editable,
                  onChanged: (v) => setState(() => _editable = v),
                  label: 'Editable',
                ),
              ],
            ),
            const SizedBox(height: 12),
            BeuiTable<_EditRow>(
              data: _editRows,
              columns: [
                for (var i = 0; i < _editKeys.length; i++)
                  BeuiTableColumn<_EditRow>(
                    key: _editKeys[i],
                    header: _editLabels[_editKeys[i]] ?? _editKeys[i],
                    editable: _editable,
                    width: i == 0 ? null : 180,
                    value: (r) => r.fields[_editKeys[i]] ?? '',
                  ),
              ],
              getRowId: (r, _) => r.id,
              rowHeight: 48,
              height: widget.example == 'editable-recovery'
                  ? (_editRows.length + 1).clamp(5, 7) * 48
                  : _editRows.length.clamp(1, 6) * 48,
              borderRadius: BorderRadius.zero,
              onCellEdit: _editable
                  ? (rowId, key, value) {
                      setState(() {
                        for (final row in _editRows) {
                          if (row.id == rowId) row.fields[key] = value;
                        }
                      });
                    }
                  : null,
              onColumnRename: _editable
                  ? (key, value) => setState(() => _editLabels[key] = value)
                  : null,
              onInsertRow: _editable ? _insertEditRow : null,
              onDeleteRow: _editable
                  ? (rowId, _) => setState(
                      () => _editRows.removeWhere((r) => r.id == rowId),
                    )
                  : null,
              onInsertColumn: _editable ? _insertEditColumn : null,
              onDeleteColumn: _editable
                  ? (key, _) => setState(() {
                      _editKeys = _editKeys.where((k) => k != key).toList();
                      for (final row in _editRows) {
                        row.fields.remove(key);
                      }
                    })
                  : null,
              emptyState: TextButton(
                onPressed: () =>
                    _insertEditRow(0, BeuiTableInsertPosition.before),
                child: const Text('Insert first row'),
              ),
            ),
          ],
          if (widget.example == null || widget.example == 'async') ...[
            if (widget.example == null) ...[
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Async Table'),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${groupThousands(_asyncRows.length)} loaded',
                    style: captionStyle,
                  ),
                  Text(
                    _asyncLoading
                        ? 'Loading…'
                        : _asyncPage >= _maxPages
                        ? 'All loaded'
                        : 'Scroll for more',
                    style: captionStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            BeuiTable<_Person>(
              data: _asyncRows,
              columns: [
                BeuiTableColumn(
                  key: 'name',
                  header: 'Name',
                  value: (r) => r.name,
                  cell: (r) => Text(
                    r.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                BeuiTableColumn(
                  key: 'email',
                  header: 'Email',
                  width: 220,
                  value: (r) => r.email,
                ),
                BeuiTableColumn(
                  key: 'role',
                  header: 'Role',
                  width: 110,
                  value: (r) => r.role,
                ),
                BeuiTableColumn(
                  key: 'status',
                  header: 'Status',
                  width: 120,
                  value: (r) => r.status,
                  cell: (r) => statusBadge(r.status),
                ),
                BeuiTableColumn(
                  key: 'mrr',
                  header: 'MRR',
                  width: 100,
                  align: BeuiTableAlign.right,
                  value: (r) => '\$${r.mrr}',
                ),
              ],
              getRowId: (r, _) => r.id,
              height: 420,
              rowHeight: 52,
              onEndReached: _loadMoreAsync,
              loading: _asyncLoading,
            ),
          ],
        ],
      ),
    );
  }

  void _insertEditRow(int index, BeuiTableInsertPosition position) {
    final at = position == BeuiTableInsertPosition.after ? index + 1 : index;
    setState(() {
      _editRows.insert(at, _EditRow('r$_nextRow', {}));
      _nextRow += 1;
    });
  }

  void _insertEditColumn(int index, BeuiTableInsertPosition position) {
    final key = 'field$_nextCol';
    final at = position == BeuiTableInsertPosition.after ? index + 1 : index;
    setState(() {
      _editLabels[key] = 'Field $_nextCol';
      _editKeys = [..._editKeys]..insert(at, key);
      for (final row in _editRows) {
        row.fields[key] = '';
      }
      _nextCol += 1;
    });
  }

  void _loadMoreAsync() {
    if (_asyncLoadingLock || _asyncPage >= _maxPages) return;
    _asyncLoadingLock = true;
    setState(() => _asyncLoading = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final page = _asyncPage;
      final start = page * _pageSize;
      final slice = _buildPeople(start + _pageSize).sublist(start);
      setState(() {
        _asyncRows = [..._asyncRows, ...slice];
        _asyncPage = page + 1;
        _asyncLoadingLock = false;
        _asyncLoading = false;
      });
    });
  }

  Widget _sectionLabel(BeuiColors colors, String title) => Text(
    title.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.5,
      color: colors.mutedForeground,
    ),
  );
}
