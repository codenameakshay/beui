import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/table/intrinsic_layout.dart';

const _fixture = 'test/fixtures/table_intrinsic_layout';

IntrinsicColumn _column(
  String key, {
  String? declared,
  bool inputOnly = false,
}) => IntrinsicColumn(
  key: key,
  minimum: 20,
  maximum: 40,
  declared: declared,
  inputOnly: inputOnly,
);

void main() {
  final oracle =
      jsonDecode(File('$_fixture/oracle.json').readAsStringSync())
          as Map<String, dynamic>;
  test(
    'source adapter recomputes lifecycle with measured checkbox content',
    () {
      const data = IntrinsicColumn(key: 'data', minimum: 20, maximum: 200);
      const inserted = IntrinsicColumn(key: 'new', minimum: 20, maximum: 200);
      const checkbox = IntrinsicColumn(
        key: 'measured-checkbox',
        minimum: 19,
        maximum: 19,
      );
      expect(resolveSourceTable(dataColumns: [data], viewport: 80).widths, [
        80,
        0,
      ]);
      expect(
        resolveSourceTable(
          dataColumns: [data],
          viewport: 80,
          overrides: {'data': 80},
        ).widths,
        [80, 0],
      );
      expect(
        resolveSourceTable(
          dataColumns: [data, inserted],
          viewport: 80,
          overrides: {'data': 80},
        ).widths,
        [80, 64, 0],
      );
      expect(
        resolveSourceTable(
          dataColumns: [data],
          viewport: 80,
          overrides: {'data': 80, 'new': 500},
          checkboxContribution: checkbox,
        ).widths,
        [48, 80, 0],
      );
      expect(
        resolveSourceTable(
          dataColumns: [],
          viewport: 80,
          overrides: {'stale': 900},
        ).widths,
        [80],
      );
    },
  );

  group('native Chrome absolute/auto allocation oracle', () {
    for (final raw in oracle['results'] as List<dynamic>) {
      final c = raw as Map<String, dynamic>;
      test(c['name'] as String, () {
        final columns = [
          for (final x in c['columns'] as List<dynamic>)
            IntrinsicColumn(
              key: x['key'] as String,
              minimum: (x['minimum'] as num).toDouble(),
              maximum: (x['maximum'] as num).toDouble(),
              declared: x['declared'] as String?,
            ),
        ];
        final result = allocateIntrinsic(
          columns,
          viewport: (c['viewport'] as num).toDouble(),
          tableFloor: (c['floor'] as num).toDouble(),
          maxContentWidth: c['maxContentWidth'] as bool,
        );
        // Exact LayoutUnit results, not a tolerance broad enough to hide
        // an incorrect proportional-growth or last-column remainder rule.
        expect(result.widths, c['widths']);
        expect(result.tableWidth, c['tableWidth']);
        expect(result.widths.reduce((a, b) => a + b), result.tableWidth);
        for (var i = 0; i < columns.length; i++) {
          expect(result.widths[i], greaterThanOrEqualTo(columns[i].minimum));
        }
      });
    }
  });

  test('source floor uses overrides, then absolute widths, then fallback', () {
    final columns = [
      _column('px', declared: '80px'),
      _column('rem', declared: '2rem'),
      _column('fr', declared: '1.4fr'),
      _column('input', inputOnly: true),
    ];
    expect(sourceFloor(columns, {}, selectable: true), 48 + 80 + 32 + 64 + 120);
    expect(
      sourceFloor(columns, {'px': 81.5}, rootFontSize: 20),
      82 + 40 + 64 + 120,
    );
    expect(
      sourceFloor([_column('i', inputOnly: true)], {}, minColumnWidth: 150),
      150,
    );
    // The source floor is not clamped to the default resize minimum per col.
    expect(sourceFloor([_column('a', declared: '12px')], {}), 12);
    expect(sourceFloor([_column('a', inputOnly: true)], {'a': 31}), 31);
  });

  test(
    'all CURRENT data columns need overrides, not declarations or stale keys',
    () {
      final a = _column('a', declared: '100px');
      final b = _column('b', declared: '200px');
      expect(allOverridden([], {'stale': 10}), isFalse);
      expect(allOverridden([a, b], {}), isFalse);
      expect(allOverridden([a, b], {'a': 100, 'stale': 200}), isFalse);
      final frozen = freezeMeasured([a, b], {}, {'a': 80.25, 'b': 125.75});
      expect(allOverridden([a, b], frozen), isTrue);
      expect(allOverridden([b, a], frozen), isTrue);
      expect(allOverridden([a, b, _column('inserted')], frozen), isFalse);
      expect(allOverridden([b], frozen), isTrue);
      expect(allOverridden([_column('replacement')], frozen), isFalse);
    },
  );

  test(
    'freeze preferences retain rendered minimum without offset compensation',
    () {
      const name = IntrinsicColumn(
        key: 'name',
        minimum: 112.453125,
        maximum: 112.453125,
        declared: '1.4fr',
      );
      const filler = IntrinsicColumn(key: 'filler', minimum: 0, maximum: 0);
      final frozen = freezeMeasured([name], {}, {'name': 112.453125});
      expect(frozen, {'name': 112});
      final down = allocateIntrinsic(
        [name, filler],
        viewport: 100,
        tableFloor: sourceFloor([name], frozen),
        overrides: frozen,
        maxContentWidth: allOverridden([name], frozen),
      );
      expect(down.widths, [112.453125, 0]);
      final moved = {...frozen, 'name': frozen['name']! + 50};
      expect(
        allocateIntrinsic(
          [name, filler],
          viewport: 100,
          tableFloor: sourceFloor([name], moved),
          overrides: moved,
          maxContentWidth: allOverridden([name], moved),
        ).widths,
        [162, 0],
      );
      expect(freezeMeasured([name], moved, {'name': 200}), moved);
      expect(freezeMeasured([_column('fraction')], {}, {'fraction': 37.5}), {
        'fraction': 38,
      });
    },
  );

  test('minimum overflow and filler derive from supplied contributions', () {
    final columns = [
      const IntrinsicColumn(
        key: 'check',
        minimum: 19,
        maximum: 19,
        declared: '48px',
      ),
      const IntrinsicColumn(key: 'data', minimum: 81, maximum: 81),
      const IntrinsicColumn(key: 'filler', minimum: 0, maximum: 0),
    ];
    expect(allocateIntrinsic(columns, viewport: 50, tableFloor: 0).widths, [
      19,
      81,
      0,
    ]);
    expect(allocateIntrinsic(columns, viewport: 129, tableFloor: 0).widths, [
      48,
      81,
      0,
    ]);
    expect(
      allocateIntrinsic(
        columns,
        viewport: 200,
        tableFloor: 0,
        overrides: {'data': 81},
      ).widths,
      [48, 81, 71],
    );
  });

  test('unsupported CSS or missing measurements fail explicitly', () {
    for (final css in [
      '25%',
      'calc(100% - 2px)',
      'min-content',
      '3em',
      '0px',
      '-1px',
    ]) {
      expect(() => absolutePreference(css), throwsUnsupportedError);
    }
    expect(absolutePreference('1.4fr'), isNull);
    expect(absolutePreference('1.8fr'), isNull);
    expect(
      () => freezeMeasured([_column('a')], {}, {}),
      throwsUnsupportedError,
    );
    expect(
      () => allocateIntrinsic(
        [_column('a')],
        viewport: double.infinity,
        tableFloor: 0,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => allocateIntrinsic(
        [const IntrinsicColumn(key: 'unknown', minimum: 1.001, maximum: 2)],
        viewport: 100,
        tableFloor: 0,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => allocateIntrinsic(
        [const IntrinsicColumn(key: 'bad', minimum: 10, maximum: 2)],
        viewport: 100,
        tableFloor: 0,
      ),
      throwsArgumentError,
    );
  });

  test('real source content measurements predict all resize phases', () {
    final capture =
        jsonDecode(
              File(
                '$_fixture/beui-table-content-metrics-final.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final measured = capture['measured'] as List<dynamic>;
    const keys = ['name', 'email', 'role', 'status', 'mrr'];
    const declarations = [null, null, '120px', '130px', '110px'];
    final columns = [
      for (var i = 0; i < keys.length; i++)
        IntrinsicColumn(
          key: keys[i],
          minimum: (measured[i + 1]['min-content'] as num).toDouble(),
          maximum: (measured[i + 1]['max-content'] as num).toDouble(),
          declared: declarations[i],
        ),
    ];
    final checkbox = IntrinsicColumn(
      key: 'selection',
      minimum: (measured[0]['min-content'] as num).toDouble(),
      maximum: (measured[0]['max-content'] as num).toDouble(),
    );
    var overrides = <String, double>{};
    for (final phase in capture['phases'] as List<dynamic>) {
      if (phase['phase'] == 'freeze') {
        overrides = freezeMeasured(columns, overrides, {
          for (var i = 0; i < keys.length; i++)
            keys[i]: (measured[i + 1]['rendered'] as num).toDouble(),
        });
      } else if (phase['phase'] == 'drag50') {
        overrides = {...overrides, 'name': overrides['name']! + 50};
      }
      final layout = resolveSourceTable(
        dataColumns: columns,
        viewport: (capture['viewport'] as num).toDouble(),
        checkboxContribution: checkbox,
        overrides: overrides,
      );
      expect(
        layout.widths,
        (phase['cols'] as List<dynamic>)
            .map((dynamic c) => c['width'])
            .toList(),
        reason: phase['phase'] as String,
      );
      expect(layout.tableWidth, phase['width']);
    }
  });

  test(
    'original resize observations remain exact and distinct from oracle',
    () {
      final phases =
          jsonDecode(
                File(
                  '$_fixture/original-resize-phases.json',
                ).readAsStringSync(),
              )
              as List<dynamic>;
      expect(phases.map((dynamic p) => p['checkboxWidth']), [24, 48, 48]);
      expect(phases.map((dynamic p) => p['nameWidth']), [
        112.453125,
        112.453125,
        162,
      ]);
      expect(phases.map((dynamic p) => p['handleX']), [
        491.453125,
        515.453125,
        565,
      ]);
      // These are observations, not intrinsic contributions fed into a fit of
      // the original full table. The native fixtures above derive their inputs
      // independently from explicit inline boxes and break opportunities.
    },
  );
}
