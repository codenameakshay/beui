import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A named Sankey node. Repeated ids keep the first node.
@immutable
class BeuiSankeyNode {
  /// Creates a node, optionally overriding its palette color.
  const BeuiSankeyNode({
    required this.id,
    required this.label,
    this.color,
    this.description,
  });

  /// Stable graph identity.
  final String id;

  /// Display name.
  final String label;

  /// Native Flutter color, replacing the source CSS color.
  final Color? color;

  /// Extra accessible and tooltip description.
  final String? description;
}

/// Weighted directed flow between node ids.
@immutable
class BeuiSankeyLink {
  /// Non-positive, non-finite, self, unknown and loop-closing links are omitted.
  const BeuiSankeyLink({
    required this.source,
    required this.target,
    required this.value,
    this.id,
  });

  /// Optional explicit identity. Repeated explicit ids keep the first.
  final String? id;

  /// Source node id.
  final String source;

  /// Destination node id.
  final String target;

  /// Positive flow weight. Unnamed repeated pairs are summed.
  final double value;

  /// Effective source identity.
  String get effectiveId => id ?? '$source:$target';
}

/// Cleaned, acyclic graph, independent of plot measurement.
@immutable
class BeuiSankeyData {
  /// Creates a cleaned graph and its omitted-link diagnostics.
  const BeuiSankeyData({
    required this.nodes,
    required this.links,
    required this.invalid,
    required this.cycles,
  });

  /// First node for each identity, in input order.
  final List<BeuiSankeyNode> nodes;

  /// Drawable links, in input order.
  final List<BeuiSankeyLink> links;

  /// Invalid or conflicting input links.
  final List<BeuiSankeyLink> invalid;

  /// Depth-first back edges removed to break cycles.
  final List<BeuiSankeyLink> cycles;
}

/// Cleans the graph with the pinned source's iterative depth-first cycle rule.
BeuiSankeyData beuiCleanSankey(
  List<BeuiSankeyNode> nodes,
  List<BeuiSankeyLink> links,
) {
  final byId = <String, BeuiSankeyNode>{};
  for (final n in nodes) {
    byId.putIfAbsent(n.id, () => n);
  }
  final merged = <String, BeuiSankeyLink>{};
  final invalid = <BeuiSankeyLink>[];
  for (final l in links) {
    if (!byId.containsKey(l.source) ||
        !byId.containsKey(l.target) ||
        l.source == l.target ||
        !l.value.isFinite ||
        l.value <= 0) {
      invalid.add(l);
      continue;
    }
    final old = merged[l.effectiveId];
    if (old == null) {
      merged[l.effectiveId] = BeuiSankeyLink(
        id: l.effectiveId,
        source: l.source,
        target: l.target,
        value: l.value,
      );
    } else if (l.id == null &&
        old.source == l.source &&
        old.target == l.target) {
      merged[l.effectiveId] = BeuiSankeyLink(
        id: old.id,
        source: old.source,
        target: old.target,
        value: old.value + l.value,
      );
    } else {
      invalid.add(l);
    }
  }
  final outgoing = <String, List<BeuiSankeyLink>>{};
  for (final l in merged.values) {
    (outgoing[l.source] ??= []).add(l);
  }
  final state = <String, bool>{};
  final back = <BeuiSankeyLink>{};
  for (final root in byId.values) {
    if (state.containsKey(root.id)) continue;
    final stack = <({String id, int next})>[(id: root.id, next: 0)];
    state[root.id] = false;
    while (stack.isNotEmpty) {
      final f = stack.last;
      final edges = outgoing[f.id] ?? [];
      if (f.next >= edges.length) {
        state[f.id] = true;
        stack.removeLast();
        continue;
      }
      stack[stack.length - 1] = (id: f.id, next: f.next + 1);
      final l = edges[f.next];
      if (state[l.target] == false) {
        back.add(l);
      } else if (!state.containsKey(l.target)) {
        state[l.target] = false;
        stack.add((id: l.target, next: 0));
      }
    }
  }
  return BeuiSankeyData(
    nodes: List.unmodifiable(byId.values),
    links: List.unmodifiable(merged.values.where((l) => !back.contains(l))),
    invalid: List.unmodifiable(invalid),
    cycles: List.unmodifiable(merged.values.where(back.contains)),
  );
}

/// Node after value scaling, column assignment and six relaxation passes.
@immutable
class BeuiSankeyPlacedNode {
  /// Creates a placed node.
  const BeuiSankeyPlacedNode({
    required this.node,
    required this.color,
    required this.value,
    required this.inValue,
    required this.outValue,
    required this.depth,
    required this.rect,
  });

  /// Original node.
  final BeuiSankeyNode node;

  /// Stable identity.
  String get id => node.id;

  /// Display name.
  String get label => node.label;

  /// Extra description.
  String? get description => node.description;

  /// Resolved fill.
  final Color color;

  /// Larger of incoming and outgoing totals.
  final double value;

  /// Total incoming value.
  final double inValue;

  /// Total outgoing value.
  final double outValue;

  /// Column counted from sources.
  final int depth;

  /// Bar geometry in plot coordinates.
  final Rect rect;
}

/// Flow geometry. Stroke [path] at [width], with a source-to-target gradient.
@immutable
class BeuiSankeyPlacedLink {
  /// Creates a placed flow.
  const BeuiSankeyPlacedLink({
    required this.id,
    required this.source,
    required this.target,
    required this.value,
    required this.share,
    required this.width,
    required this.start,
    required this.end,
  });

  /// Effective link id.
  final String id;

  /// Source node.
  final BeuiSankeyPlacedNode source;

  /// Destination node.
  final BeuiSankeyPlacedNode target;

  /// Original weight.
  final double value;

  /// Share of the larger incoming/outgoing source total.
  final double share;

  /// Band thickness.
  final double width;

  /// Centerline leaving the source.
  final Offset start;

  /// Centerline arriving at the target.
  final Offset end;

  /// Exact midpoint-control cubic, not a generic alluvial approximation.
  Path get path => Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(
      (start.dx + end.dx) / 2,
      start.dy,
      (start.dx + end.dx) / 2,
      end.dy,
      end.dx,
      end.dy,
    );
}

/// Measured Sankey layout in keyboard reading order.
@immutable
class BeuiSankeyLayout {
  /// Creates a layout.
  const BeuiSankeyLayout({
    required this.nodes,
    required this.links,
    required this.columns,
    required this.step,
  });

  /// Nodes in column and original input order.
  final List<BeuiSankeyPlacedNode> nodes;

  /// Links in cleaned input order.
  final List<BeuiSankeyPlacedLink> links;

  /// Number of columns.
  final int columns;

  /// Horizontal distance between column starts.
  final double step;
}

class _Node {
  _Node(
    this.node,
    this.color,
    this.inValue,
    this.outValue,
    this.depth,
    this.x,
    this.width,
  );
  final BeuiSankeyNode node;
  final Color color;
  final double inValue, outValue, x, width;
  final int depth;
  double y0 = 0, y1 = 0;
  double get value => math.max(inValue, outValue);
  double get center => (y0 + y1) / 2;
  BeuiSankeyPlacedNode placed() => BeuiSankeyPlacedNode(
    node: node,
    color: color,
    value: value,
    inValue: inValue,
    outValue: outValue,
    depth: depth,
    rect: Rect.fromLTRB(x, y0, x + width, y1),
  );
}

/// Source layout algorithm, including fixed node order, sink alignment and link stacking.
BeuiSankeyLayout beuiLayoutSankey(
  BeuiSankeyData data, {
  required Size size,
  double nodeWidth = 12,
  double nodePadding = 16,
  List<Color> colors = const [
    Color(0xff1d4ed8),
    Color(0xff7c3aed),
    Color(0xff0f766e),
    Color(0xffb45309),
    Color(0xffbe123c),
    Color(0xff475569),
  ],
}) {
  if (colors.isEmpty) {
    throw ArgumentError.value(colors, 'colors', 'Must not be empty');
  }
  final incoming = <String, double>{}, outgoing = <String, double>{};
  final indegree = <String, int>{}, depth = <String, int>{};
  for (final l in data.links) {
    outgoing.update(l.source, (v) => v + l.value, ifAbsent: () => l.value);
    incoming.update(l.target, (v) => v + l.value, ifAbsent: () => l.value);
    indegree.update(l.target, (v) => v + 1, ifAbsent: () => 1);
  }
  final queue = data.nodes
      .where((n) => (indegree[n.id] ?? 0) == 0)
      .map((n) => n.id)
      .toList();
  for (final id in queue) {
    depth[id] = 0;
  }
  for (var i = 0; i < queue.length; i++) {
    final id = queue[i];
    for (final l in data.links.where((l) => l.source == id)) {
      depth[l.target] = math.max(depth[l.target] ?? 0, (depth[id] ?? 0) + 1);
      indegree[l.target] = indegree[l.target]! - 1;
      if (indegree[l.target] == 0) queue.add(l.target);
    }
  }
  final linked = data.nodes
      .where((n) => incoming.containsKey(n.id) || outgoing.containsKey(n.id))
      .toList();
  if (linked.isEmpty || size.width <= 0 || size.height <= 0) {
    return const BeuiSankeyLayout(nodes: [], links: [], columns: 0, step: 0);
  }
  final maxDepth = linked.map((n) => depth[n.id] ?? 0).reduce(math.max);
  final columns = maxDepth + 1;
  final step = columns > 1 ? (size.width - nodeWidth) / (columns - 1) : 0.0;
  final placed = [
    for (final n in linked)
      _Node(
        n,
        n.color ?? colors[data.nodes.indexOf(n) % colors.length],
        incoming[n.id] ?? 0,
        outgoing[n.id] ?? 0,
        outgoing.containsKey(n.id) ? depth[n.id] ?? 0 : maxDepth,
        (outgoing.containsKey(n.id) ? depth[n.id] ?? 0 : maxDepth) * step,
        nodeWidth,
      ),
  ];
  final byId = {for (final n in placed) n.node.id: n};
  final byColumn = [
    for (var d = 0; d < columns; d++)
      placed.where((n) => n.depth == d).toList(),
  ];
  var padding = nodePadding;
  for (final col in byColumn) {
    if (col.length > 1) {
      padding = math.min(padding, size.height * .5 / (col.length - 1));
    }
  }
  final ky = byColumn
      .where((c) => c.isNotEmpty)
      .map(
        (c) =>
            (size.height - (c.length - 1) * padding) /
            c.fold<double>(0, (s, n) => s + n.value),
      )
      .reduce(math.min);
  for (final col in byColumn) {
    var y = 0.0;
    for (final n in col) {
      n.y0 = y;
      n.y1 = y + n.value * ky;
      y = n.y1 + padding;
    }
    final offset = (size.height - (y - padding)) / 2;
    for (final n in col) {
      n.y0 += offset;
      n.y1 += offset;
    }
  }
  void resolve(List<_Node> col) {
    var y = 0.0;
    for (final n in col) {
      final dy = y - n.y0;
      if (dy > 0) {
        n.y0 += dy;
        n.y1 += dy;
      }
      y = n.y1 + padding;
    }
    y = size.height;
    for (final n in col.reversed) {
      final dy = n.y1 - y;
      if (dy > 0) {
        n.y0 -= dy;
        n.y1 -= dy;
      }
      y = n.y0 - padding;
    }
  }

  void relax(List<_Node> col, double alpha, bool source) {
    for (final n in col) {
      var weighted = 0.0, total = 0.0;
      for (final l in data.links) {
        if ((source ? l.target : l.source) != n.node.id) continue;
        final other = byId[source ? l.source : l.target]!;
        weighted += other.center * l.value;
        total += l.value;
      }
      if (total == 0) continue;
      final dy = (weighted / total - n.center) * alpha;
      n.y0 += dy;
      n.y1 += dy;
    }
    resolve(col);
  }

  for (var i = 0; i < 6; i++) {
    final alpha = math.pow(.99, i).toDouble();
    for (var d = 1; d < columns; d++) {
      relax(byColumn[d], alpha, true);
    }
    for (var d = columns - 2; d >= 0; d--) {
      relax(byColumn[d], alpha, false);
    }
  }
  final immutable = {for (final n in placed) n.node.id: n.placed()};
  final sy = <String, double>{}, ty = <String, double>{};
  for (final n in placed) {
    var y = n.y0;
    final out = data.links.where((l) => l.source == n.node.id).toList()
      ..sort((a, b) => byId[a.target]!.y0.compareTo(byId[b.target]!.y0));
    for (final l in out) {
      sy[l.effectiveId] = y;
      y += l.value * ky;
    }
    y = n.y0;
    final inc = data.links.where((l) => l.target == n.node.id).toList()
      ..sort((a, b) => byId[a.source]!.y0.compareTo(byId[b.source]!.y0));
    for (final l in inc) {
      ty[l.effectiveId] = y;
      y += l.value * ky;
    }
  }
  return BeuiSankeyLayout(
    nodes: List.unmodifiable(
      byColumn.expand((c) => c.map((n) => immutable[n.node.id]!)),
    ),
    links: List.unmodifiable([
      for (final l in data.links)
        BeuiSankeyPlacedLink(
          id: l.effectiveId,
          source: immutable[l.source]!,
          target: immutable[l.target]!,
          value: l.value,
          share: l.value / immutable[l.source]!.value,
          width: l.value * ky,
          start: Offset(
            immutable[l.source]!.rect.right,
            sy[l.effectiveId]! + l.value * ky / 2,
          ),
          end: Offset(
            immutable[l.target]!.rect.left,
            ty[l.effectiveId]! + l.value * ky / 2,
          ),
        ),
    ]),
    columns: columns,
    step: step,
  );
}
