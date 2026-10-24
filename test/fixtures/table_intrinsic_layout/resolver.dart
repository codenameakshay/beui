import 'dart:math' as math;

// Test-only prototype. Inputs are measured OUTER column contributions, including
// padding/borders. This does not measure Flutter text, widgets, or CSS cells.
class IntrinsicColumn {
  const IntrinsicColumn({
    required this.key,
    required this.minimum,
    required this.maximum,
    this.declared,
    this.inputOnly = false,
  });

  final String key;
  final double minimum;
  final double maximum;
  final String? declared;
  final bool inputOnly;
}

// Deliberately narrow CSS subset. fr is invalid on a native table col, so the
// browser ignores it. Other CSS lengths need their own constraint derivation.
double? absolutePreference(String? css, {double rootFontSize = 16}) {
  if (css == null ||
      css == 'auto' ||
      RegExp(r'^\d+(\.\d+)?fr$').hasMatch(css)) {
    return null;
  }
  final match = RegExp(r'^(\d+(?:\.\d+)?)(px|rem)$').firstMatch(css);
  if (match == null) throw UnsupportedError('Unsupported column width: $css');
  final value =
      double.parse(match[1]!) * (match[2] == 'rem' ? rootFontSize : 1);
  if (!value.isFinite || value <= 0) {
    throw UnsupportedError('Only positive absolute preferences are supported');
  }
  return value;
}

bool allOverridden(
  List<IntrinsicColumn> columns,
  Map<String, double> overrides,
) => columns.isNotEmpty && columns.every((c) => overrides.containsKey(c.key));

// Source index.tsx: this is a TABLE floor, never a per-column minimum.
double sourceFloor(
  List<IntrinsicColumn> columns,
  Map<String, double> overrides, {
  bool selectable = false,
  double minColumnWidth = 64,
  double rootFontSize = 16,
}) {
  var total = selectable ? 48.0 : 0.0;
  for (final c in columns) {
    total +=
        overrides[c.key] ??
        absolutePreference(c.declared, rootFontSize: rootFontSize) ??
        (c.inputOnly ? math.max(minColumnWidth, 120) : minColumnWidth);
  }
  return total.roundToDouble();
}

// Source freezes current data columns only and retains existing overrides.
// Missing/zero measurements are intentionally unsupported here: the source's
// minColumnWidth fallback must not disguise an unmeasured prototype input.
Map<String, double> freezeMeasured(
  List<IntrinsicColumn> columns,
  Map<String, double> overrides,
  Map<String, double> measured,
) {
  final result = {...overrides};
  for (final c in columns) {
    if (result.containsKey(c.key)) continue;
    final width = measured[c.key];
    if (width == null || !width.isFinite || width <= 0) {
      throw UnsupportedError('No usable measured width for ${c.key}');
    }
    result[c.key] = width.roundToDouble();
  }
  return result;
}

class IntrinsicLayout {
  const IntrinsicLayout(this.widths, this.tableWidth);
  final List<double> widths;
  final double tableWidth;
}

// Chromium 155 DistributeInlineSizeToComputedInlineSizeAuto, absolute/auto
// subset. Fixed-layout CSS with auto/max-content table width reaches this
// intrinsic path. All columns must have cells (including the empty filler).
// LayoutUnit arithmetic truncates MulDiv to 1/64 px and gives the remainder
// to the last participating column. Reject unquantized contributions rather
// than guessing how a caller measured them.
IntrinsicLayout allocateIntrinsic(
  List<IntrinsicColumn> columns, {
  required double viewport,
  required double tableFloor,
  Map<String, double> overrides = const {},
  bool maxContentWidth = false,
  double rootFontSize = 16,
}) {
  int units(double value) {
    if (!value.isFinite || value < 0 || value * 64 != (value * 64).round()) {
      throw UnsupportedError(
        'Expected nonnegative finite 1/64 px input: $value',
      );
    }
    return (value * 64).round();
  }

  if (columns.isEmpty ||
      columns.map((c) => c.key).toSet().length != columns.length) {
    throw ArgumentError('Require nonempty, uniquely keyed columns');
  }
  final minimum = <int>[];
  final maximum = <int>[];
  final fixed = <bool>[];
  for (final c in columns) {
    final min = units(c.minimum);
    final max = units(c.maximum);
    if (max < min) throw ArgumentError('max-content is below min-content');
    final preference =
        overrides[c.key] ??
        absolutePreference(c.declared, rootFontSize: rootFontSize);
    if (preference != null && preference <= 0) {
      throw UnsupportedError('Zero/negative overrides are not supported');
    }
    minimum.add(min);
    maximum.add(preference == null ? max : math.max(min, units(preference)));
    fixed.add(preference != null);
  }
  int sum(List<int> values) => values.fold(0, (a, b) => a + b);
  final specified = [
    for (var i = 0; i < columns.length; i++) fixed[i] ? maximum[i] : minimum[i],
  ];
  final target = [
    units(viewport),
    units(tableFloor),
    sum(minimum),
    if (maxContentWidth) sum(maximum),
  ].reduce(math.max);

  List<int> interpolate(List<int> low, List<int> high, List<int> eligible) {
    final extra = target - sum(low);
    final weight = eligible.fold(0, (s, i) => s + high[i] - low[i]);
    final result = [...low];
    var remainder = extra;
    for (final i in eligible) {
      final delta = weight == 0
          ? extra ~/ eligible.length
          : extra * (high[i] - low[i]) ~/ weight;
      result[i] += delta;
      remainder -= delta;
    }
    result[eligible.last] += remainder;
    return result;
  }

  final fixedIndices = [
    for (var i = 0; i < columns.length; i++)
      if (fixed[i]) i,
  ];
  final autoIndices = [
    for (var i = 0; i < columns.length; i++)
      if (!fixed[i]) i,
  ];
  late List<int> result;
  if (target == sum(minimum)) {
    result = minimum;
  } else if (target <= sum(specified)) {
    result = interpolate(minimum, specified, fixedIndices);
  } else if (target < sum(maximum)) {
    result = interpolate(specified, maximum, autoIndices);
  } else if (target == sum(maximum)) {
    result = maximum;
  } else {
    // Auto columns receive surplus proportional to max-content. Empty autos
    // split equally only when their combined max-content is zero. If there
    // are no autos, this constrained table target grows fixed columns.
    final eligible = autoIndices.isNotEmpty ? autoIndices : fixedIndices;
    final weights = [...maximum];
    for (final i in eligible) {
      weights[i] += maximum[i];
    }
    result = interpolate(maximum, weights, eligible);
  }
  return IntrinsicLayout([for (final w in result) w / 64], target / 64);
}

// Prospective opt-in integration seam. The production flex path never calls
// this prototype. Checkbox content must be measured just like data content.
IntrinsicLayout resolveSourceTable({
  required List<IntrinsicColumn> dataColumns,
  required double viewport,
  Map<String, double> overrides = const {},
  IntrinsicColumn? checkboxContribution,
  double minColumnWidth = 64,
  double rootFontSize = 16,
}) {
  if (dataColumns.any((c) => c.key == '#checkbox' || c.key == '#filler')) {
    throw ArgumentError('Reserved prototype column key');
  }
  final currentOverrides = {
    for (final c in dataColumns)
      if (overrides.containsKey(c.key)) c.key: overrides[c.key]!,
  };
  return allocateIntrinsic(
    [
      if (checkboxContribution != null)
        IntrinsicColumn(
          key: '#checkbox',
          minimum: checkboxContribution.minimum,
          maximum: checkboxContribution.maximum,
          declared: '48px',
        ),
      ...dataColumns,
      const IntrinsicColumn(key: '#filler', minimum: 0, maximum: 0),
    ],
    viewport: viewport,
    tableFloor: sourceFloor(
      dataColumns,
      currentOverrides,
      selectable: checkboxContribution != null,
      minColumnWidth: minColumnWidth,
      rootFontSize: rootFontSize,
    ),
    overrides: currentOverrides,
    maxContentWidth: allOverridden(dataColumns, currentOverrides),
    rootFontSize: rootFontSize,
  );
}
