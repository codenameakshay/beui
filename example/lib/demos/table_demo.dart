import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTable] — the virtualized data grid with resize,
/// reorder, sort, selection, inline editing, row/column menus and async
/// skeleton loading. Mirrors the source's three registry examples (data,
/// editable, async).
Widget tableDemo(BuildContext context) => const _TableDemo();

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

const _first = ['Ava', 'Leo', 'Mia', 'Kai', 'Zoe', 'Eli', 'Noa', 'Ren', 'Ivy', 'Jude'];
const _last = ['Cole', 'Frost', 'Vale', 'Reyes', 'Okafor', 'Sato', 'Lund', 'Marsh', 'Bose', 'Quinn'];
const _roles = ['Owner', 'Admin', 'Member', 'Viewer'];
const _statuses = ['active', 'invited', 'suspended'];

_Person _person(int n) {
  final first = _first[n % _first.length];
  final last = _last[(n * 7) % _last.length];
  return _Person(
    id: '$n',
    name: '$first $last',
    email: '${first.toLowerCase()}.${last.toLowerCase()}$n@beui.dev',
    role: _roles[(n * 3) % _roles.length],
    status: _statuses[(n * 5) % _statuses.length],
    mrr: 12 + ((n * 37) % 488),
  );
}

class _TableDemo extends StatefulWidget {
  const _TableDemo();

  @override
  State<_TableDemo> createState() => _TableDemoState();
}

class _TableDemoState extends State<_TableDemo> {
  // --- data variant ----------------------------------------------------------
  final List<_Person> _people = [for (var i = 0; i < 12; i++) _person(i)];
  List<String> _selected = const [];

  // --- editable variant ------------------------------------------------------
  final List<Map<String, String>> _rows = [
    {'id': 'r1', 'name': 'Ava Cole', 'role': 'Owner', 'team': 'Design'},
    {'id': 'r2', 'name': 'Leo Frost', 'role': 'Admin', 'team': 'Growth'},
    {'id': 'r3', 'name': 'Mia Vale', 'role': 'Member', 'team': 'Design'},
    {'id': 'r4', 'name': 'Kai Reyes', 'role': 'Member', 'team': 'Platform'},
  ];
  List<String> _keys = ['name', 'role', 'team'];
  final Map<String, String> _labels = {
    'name': 'Name',
    'role': 'Role',
    'team': 'Team',
  };
  int _nextRow = 5;
  int _nextCol = 1;

  // --- async variant ---------------------------------------------------------
  final List<_Person> _asyncRows = [];
  bool _asyncLoading = true;
  int _page = 0;
  static const _pageSize = 20;
  static const _maxPages = 6;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  void _loadMore() {
    if (_asyncLoading && _asyncRows.isNotEmpty) return;
    if (_page >= _maxPages) return;
    setState(() => _asyncLoading = true);
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        for (var n = _page * _pageSize; n < (_page + 1) * _pageSize; n++) {
          _asyncRows.add(_person(n));
        }
        _page += 1;
        _asyncLoading = false;
      });
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status[0].toUpperCase() + status.substring(1),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tint),
        ),
      );
    }

    final peopleColumns = <BeuiTableColumn<_Person>>[
      BeuiTableColumn(
        key: 'name',
        header: 'Name',
        sortable: true,
        flex: 1.4,
        value: (r) => r.name,
        cell: (r) => Text(
          r.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      BeuiTableColumn(key: 'email', header: 'Email', flex: 1.8, value: (r) => r.email),
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
        value: (r) => '\$${r.mrr}',
        sortValue: (r) => r.mrr,
        cell: (r) => Text(
          '\$${r.mrr}',
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    ];

    final editableColumns = <BeuiTableColumn<Map<String, String>>>[];
    for (var i = 0; i < _keys.length; i++) {
      final key = _keys[i]; // capture per-iteration for the closures below
      editableColumns.add(
        BeuiTableColumn(
          key: key,
          header: _labels[key] ?? key,
          editable: true,
          width: i == 0 ? null : 180,
          value: (r) => r[key] ?? '',
        ),
      );
    }

    final asyncColumns = <BeuiTableColumn<_Person>>[
      BeuiTableColumn(
        key: 'name',
        header: 'Name',
        value: (r) => r.name,
        cell: (r) => Text(
          r.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      BeuiTableColumn(key: 'email', header: 'Email', width: 220, value: (r) => r.email),
      BeuiTableColumn(key: 'role', header: 'Role', width: 110, value: (r) => r.role),
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
        align: BeuiTableAlign.right,
        width: 100,
        value: (r) => '\$${r.mrr}',
        cell: (r) => Text(
          '\$${r.mrr}',
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    ];

    final asyncDone = _page >= _maxPages;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(colors, 'Data', '${_people.length} rows'
                  '${_selected.isEmpty ? '' : ' · ${_selected.length} selected'}'),
              const SizedBox(height: 8),
              BeuiTable<_Person>(
                data: _people,
                columns: peopleColumns,
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
                height: 340,
                rowHeight: 52,
              ),

              const SizedBox(height: 32),
              _section(colors, 'Editable',
                  'Click a cell to edit. Hover the row/column edges for insert & delete.'),
              const SizedBox(height: 8),
              BeuiTable<Map<String, String>>(
                data: _rows,
                columns: editableColumns,
                getRowId: (r, _) => r['id'] ?? '',
                rowHeight: 48,
                height:
                    ((_rows.isEmpty ? 1 : _rows.length.clamp(1, 6)) * 48 + 48)
                        .toDouble(),
                onCellEdit: (rowId, key, value) => setState(() {
                  final row = _rows.firstWhere((r) => r['id'] == rowId);
                  row[key] = value;
                }),
                onColumnRename: (key, value) =>
                    setState(() => _labels[key] = value),
                onInsertRow: (index, position) => setState(() {
                  final at = position == BeuiTableInsertPosition.after
                      ? index + 1
                      : index;
                  _rows.insert(at, {'id': 'r$_nextRow'});
                  _nextRow++;
                }),
                onDeleteRow: (rowId, _) =>
                    setState(() => _rows.removeWhere((r) => r['id'] == rowId)),
                onInsertColumn: (index, position) => setState(() {
                  final key = 'field$_nextCol';
                  final at = position == BeuiTableInsertPosition.after
                      ? index + 1
                      : index;
                  _labels[key] = 'Field $_nextCol';
                  _keys = [..._keys]..insert(at, key);
                  for (final r in _rows) {
                    r[key] = '';
                  }
                  _nextCol++;
                }),
                onDeleteColumn: (key, _) => setState(() {
                  _keys = [..._keys]..remove(key);
                  for (final r in _rows) {
                    r.remove(key);
                  }
                }),
                emptyState: TextButton(
                  onPressed: () => setState(() {
                    _rows.insert(0, {'id': 'r$_nextRow'});
                    _nextRow++;
                  }),
                  child: const Text('Insert first row'),
                ),
              ),

              const SizedBox(height: 32),
              _section(colors, 'Async',
                  '${_asyncRows.length} loaded · '
                  '${_asyncLoading ? 'Loading…' : asyncDone ? 'All loaded' : 'Scroll for more'}'),
              const SizedBox(height: 8),
              BeuiTable<_Person>(
                data: _asyncRows,
                columns: asyncColumns,
                getRowId: (r, _) => r.id,
                height: 340,
                rowHeight: 52,
                loading: _asyncLoading,
                onEndReached: _loadMore,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BeuiColors colors, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.mutedForeground),
      ),
    ],
  );
}
