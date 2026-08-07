import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTable] — a 1:1 port of the source preview
/// (`components/previews/motion/table.preview.tsx`): one virtualized 10,000-row
/// grid with sortable headers, row selection, column resize and reorder, above
/// a muted row-count / selection-count caption.
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

/// `Number.prototype.toLocaleString()` for the en-US grouping the source uses.
String _grouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _TableDemo extends StatefulWidget {
  const _TableDemo();

  @override
  State<_TableDemo> createState() => _TableDemoState();
}

class _TableDemoState extends State<_TableDemo> {
  final List<_Person> _data = _buildPeople(10000);
  List<String> _selected = const [];

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
        value: (r) => '\$${_grouped(r.mrr)}',
        sortValue: (r) => r.mrr,
        cell: (r) => Text(
          '\$${_grouped(r.mrr)}',
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
          Padding(
            // px-1
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_grouped(_data.length)} rows', style: captionStyle),
                if (_selected.isNotEmpty)
                  Text(
                    '${_grouped(_selected.length)} selected',
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
      ),
    );
  }
}
