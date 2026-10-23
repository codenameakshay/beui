/// Animated treemap — Flutter port of beUI `treemap`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/_focus_ring.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// A treemap node: a leaf with a value, or a group of children.
@immutable
class BeuiTreemapNode {
  /// Creates a leaf.
  const BeuiTreemapNode.leaf({
    required this.id,
    required this.label,
    required this.value,
    this.color,
    this.textColor,
    this.description,
  }) : children = null;

  /// Creates a group. Weight is the sum of descendants.
  const BeuiTreemapNode.group({
    required this.id,
    required this.label,
    required this.children,
    this.color,
    this.textColor,
    this.description,
  }) : value = null;

  /// Unique across the tree. Retain IDs when updating values.
  final String id;

  /// Display label.
  final String label;

  /// Leaf weight. Null on groups.
  final double? value;

  /// Nested nodes. Null on leaves.
  final List<BeuiTreemapNode>? children;

  /// Optional fill override.
  final String? color;

  /// Optional label color override.
  final String? textColor;

  /// Extra accessible description.
  final String? description;

  /// Whether this is a group.
  bool get isGroup => children != null;
}

/// A laid-out leaf tile.
@immutable
class BeuiTreemapTile {
  /// Creates a tile.
  const BeuiTreemapTile({
    required this.id,
    required this.label,
    required this.value,
    required this.share,
    required this.path,
    required this.color,
    required this.textColor,
    required this.rect,
    this.description,
  });

  /// Node id.
  final String id;

  /// Leaf label.
  final String label;

  /// Leaf value.
  final double value;

  /// Share of the tree total, 0–1.
  final double share;

  /// Path labels from the root.
  final List<String> path;

  /// Fill.
  final Color color;

  /// Label color.
  final Color textColor;

  /// Layout rect in plot coordinates.
  final Rect rect;

  /// Optional description.
  final String? description;
}

class _Resolved {
  const _Resolved({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
    required this.children,
    this.item,
  });

  final String id;
  final String label;
  final double value;
  final Color color;
  final Color textColor;
  final List<_Resolved> children;
  final BeuiTreemapTile? item;
}

/// Proportional tiles that morph with the data, with value and share tooltips.
///
/// Compose [BeuiTreemapPlot], [BeuiTreemapTooltip] and [BeuiTreemapLegend],
/// or omit children for the default layout.
class BeuiTreemap extends StatefulWidget {
  /// Creates a treemap.
  const BeuiTreemap({
    required this.data,
    super.key,
    this.label = 'Treemap',
    this.formatValue,
    this.colors,
    this.textColor,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.child,
  });

  /// Flat leaves or nested groups.
  final List<BeuiTreemapNode> data;

  /// Accessible name.
  final String label;

  /// Value formatter. Defaults to a grouped integer.
  final String Function(double value)? formatValue;

  /// Top-level palette; nodes can override.
  final List<Color>? colors;

  /// Default tile text color.
  final Color? textColor;

  /// Controlled active tile.
  final String? activeId;

  /// Uncontrolled seed.
  final String? defaultActiveId;

  /// Active-id callback.
  final ValueChanged<String?>? onActiveChange;

  /// Custom composition. Null renders plot + tooltip + legend.
  final Widget? child;

  @override
  State<BeuiTreemap> createState() => _BeuiTreemapState();
}

class _BeuiTreemapState extends State<BeuiTreemap>
    with BeuiChartActiveState<BeuiTreemap> {
  final _focus = <String, FocusNode>{};
  String? _focusedTile;
  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusTile(String id) {
    _focusedTile = id;
    _focus[id]?.requestFocus();
    setActiveId(id);
  }

  @override
  String? get widgetActiveId => widget.activeId;
  @override
  String? get widgetDefaultActiveId => widget.defaultActiveId;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => widget.onActiveChange;

  late _Layout _layout;

  @override
  Iterable<String> get knownIds => _layout.tiles.map((t) => t.id);

  String Function(double) get _format =>
      widget.formatValue ?? (v) => beuiChartFormatNumber(v);

  @override
  void initState() {
    super.initState();
    initActive();
    _layout = _Layout.empty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuild();
  }

  @override
  void didUpdateWidget(BeuiTreemap old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data ||
        old.colors != widget.colors ||
        old.textColor != widget.textColor) {
      _rebuild();
    }
  }

  void _rebuild() {
    final colors = BeuiColors.resolve(context);
    _layout = _build(
      widget.data,
      widget.colors ?? beuiChartPalette,
      widget.textColor ?? const Color(0xFFFFFFFF),
      colors,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TreemapScope(
      state: this,
      child: BeuiChartFrame(
        label: widget.label,
        child:
            widget.child ??
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BeuiTreemapPlot(),
                SizedBox(height: 16),
                BeuiTreemapTooltip(),
                SizedBox(height: 12),
                BeuiTreemapLegend(),
              ],
            ),
      ),
    );
  }
}

class _Layout {
  const _Layout({
    required this.nodes,
    required this.tiles,
    required this.total,
  });
  static const empty = _Layout(nodes: [], tiles: [], total: 0);
  final List<_Resolved> nodes;
  final List<BeuiTreemapTile> tiles;
  final double total;
}

_Layout _build(
  List<BeuiTreemapNode> data,
  List<Color> palette,
  Color textColor,
  BeuiColors colors,
) {
  if (palette.isEmpty) {
    throw ArgumentError('BeuiTreemap.colors must contain at least one color.');
  }
  final ids = <String>{};
  final items = <BeuiTreemapTile>[];
  _Resolved resolve(
    BeuiTreemapNode node,
    List<String> path,
    Color inheritedColor,
    Color inheritedText,
  ) {
    if (!ids.add(node.id)) {
      throw ArgumentError('BeuiTreemap: duplicate node ID "${node.id}".');
    }
    final color = node.color == null
        ? inheritedColor
        : beuiChartColor(node.color, colors, fallback: inheritedColor);
    final fg = node.textColor == null
        ? inheritedText
        : beuiChartColor(node.textColor, colors, fallback: inheritedText);
    final nextPath = [...path, node.label];
    if (node.isGroup) {
      final children = [
        for (final child in node.children!) resolve(child, nextPath, color, fg),
      ];
      final value = children.fold<double>(0, (s, c) => s + c.value);
      if (!value.isFinite) {
        throw ArgumentError('BeuiTreemap: group totals must remain finite.');
      }
      return _Resolved(
        id: node.id,
        label: node.label,
        value: value,
        color: color,
        textColor: fg,
        children: children,
      );
    }
    final value = node.value!;
    if (!value.isFinite || value < 0) {
      throw ArgumentError(
        'BeuiTreemap: leaf values must be finite and nonnegative.',
      );
    }
    final item = BeuiTreemapTile(
      id: node.id,
      label: node.label,
      value: value,
      share: 0,
      path: nextPath,
      color: color,
      textColor: fg,
      rect: Rect.zero,
      description: node.description,
    );
    items.add(item);
    return _Resolved(
      id: node.id,
      label: node.label,
      value: value,
      color: color,
      textColor: fg,
      children: const [],
      item: item,
    );
  }

  final nodes = [
    for (var i = 0; i < data.length; i++)
      resolve(data[i], const [], palette[i % palette.length], textColor),
  ];
  final total = nodes.fold<double>(0, (s, n) => s + n.value);
  if (!total.isFinite) {
    throw ArgumentError('BeuiTreemap: the total must remain finite.');
  }
  final withShare = [
    for (final item in items)
      BeuiTreemapTile(
        id: item.id,
        label: item.label,
        value: item.value,
        share: total == 0 ? 0 : item.value / total,
        path: item.path,
        color: item.color,
        textColor: item.textColor,
        rect: item.rect,
        description: item.description,
      ),
  ];
  // Rebuild resolved tree to point at share-updated items.
  BeuiTreemapTile? byId(String id) {
    for (final t in withShare) {
      if (t.id == id) return t;
    }
    return null;
  }

  _Resolved relink(_Resolved n) => _Resolved(
    id: n.id,
    label: n.label,
    value: n.value,
    color: n.color,
    textColor: n.textColor,
    children: [for (final c in n.children) relink(c)],
    item: n.item == null ? null : byId(n.item!.id),
  );
  return _Layout(
    nodes: [for (final n in nodes) relink(n)],
    tiles: withShare,
    total: total,
  );
}

List<BeuiTreemapTile> _layoutTiles(List<_Resolved> nodes, Size size) {
  final out = <BeuiTreemapTile>[];
  void partition(List<_Resolved> siblings, Rect box) {
    final positive = [
      for (final n in siblings)
        if (n.value > 0) n,
    ];
    if (positive.isEmpty) return;
    if (positive.length == 1) {
      final node = positive.first;
      if (node.item != null) {
        out.add(
          BeuiTreemapTile(
            id: node.item!.id,
            label: node.item!.label,
            value: node.item!.value,
            share: node.item!.share,
            path: node.item!.path,
            color: node.item!.color,
            textColor: node.item!.textColor,
            rect: box,
            description: node.item!.description,
          ),
        );
      } else {
        partition(node.children, box);
      }
      return;
    }
    final total = positive.fold<double>(0, (s, n) => s + n.value);
    var cut = 1;
    var subtotal = positive.first.value;
    for (var i = 1; i < positive.length - 1; i++) {
      final next = subtotal + positive[i].value;
      if ((next - total / 2).abs() > (subtotal - total / 2).abs()) break;
      cut = i + 1;
      subtotal = next;
    }
    final fraction = subtotal / total;
    if (box.width >= box.height) {
      final split = box.width * fraction;
      partition(
        positive.sublist(0, cut),
        Rect.fromLTWH(box.left, box.top, split, box.height),
      );
      partition(
        positive.sublist(cut),
        Rect.fromLTWH(box.left + split, box.top, box.width - split, box.height),
      );
    } else {
      final split = box.height * fraction;
      partition(
        positive.sublist(0, cut),
        Rect.fromLTWH(box.left, box.top, box.width, split),
      );
      partition(
        positive.sublist(cut),
        Rect.fromLTWH(box.left, box.top + split, box.width, box.height - split),
      );
    }
  }

  partition(nodes, Offset.zero & size);
  return [
    for (final t in out)
      if (t.rect.width > 0 && t.rect.height > 0) t,
  ];
}

class _TreemapScope extends InheritedWidget {
  const _TreemapScope({required this.state, required super.child});
  final _BeuiTreemapState state;

  static _BeuiTreemapState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TreemapScope>();
    assert(scope != null, 'Treemap parts must be rendered inside BeuiTreemap.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_TreemapScope old) => true;
}

/// Plot of morphing tiles. Default height is 20rem (320).
class BeuiTreemapPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiTreemapPlot({super.key, this.height = 320, this.renderTile});

  /// Plot height.
  final double height;

  /// Custom tile body. The tile already owns its button and name.
  final Widget Function(BeuiTreemapTile tile)? renderTile;

  @override
  Widget build(BuildContext context) {
    final state = _TreemapScope.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          final tiles = _layoutTiles(state._layout.nodes, size);
          for (final id
              in state._focus.keys
                  .where((id) => !tiles.any((tile) => tile.id == id))
                  .toList()) {
            state._focus.remove(id)!.dispose();
          }
          for (final tile in tiles) {
            state._focus.putIfAbsent(tile.id, FocusNode.new);
            state._focus[tile.id]!.skipTraversal =
                tile.id != (state._focusedTile ?? tiles.first.id);
          }
          if (!tiles.any((tile) => tile.id == state._focusedTile)) {
            state._focusedTile = tiles.firstOrNull?.id;
          }
          for (final tile in tiles) {
            state._focus[tile.id]!.skipTraversal =
                tile.id != state._focusedTile;
          }
          return Focus(
            canRequestFocus: false,
            onKeyEvent: (node, event) {
              if (_handleTileKeys(state, tiles, event)) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              children: [
                for (final tile in tiles)
                  BeuiChartSpringRect(
                    key: ValueKey(tile.id),
                    value: tile.rect,
                    builder: (context, rect) {
                      return Positioned(
                        left: rect.left,
                        top: rect.top,
                        width: math.max(0, rect.width),
                        height: math.max(0, rect.height),
                        child: _Tile(
                          tile: tile,
                          size: Size(
                            math.max(0, rect.width),
                            math.max(0, rect.height),
                          ),
                          format: state._format,
                          active: state.activeId == tile.id,
                          onActive: (id) {
                            if (id != null || state.activeId == tile.id) {
                              state.setActiveId(id);
                            }
                          },
                          focusNode: state._focus[tile.id]!,
                          onFocus: () => state._focusedTile = tile.id,
                          renderTile: renderTile,
                        ),
                      );
                    },
                  ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: 0,
                  height: 0,
                  child: OverflowBox(
                    maxWidth: 1,
                    maxHeight: 1,
                    child: ExcludeSemantics(
                      excluding: false,
                      child: Column(
                        children: [
                          for (final tile in tiles)
                            Semantics(
                              label:
                                  '${tile.path.join(' / ')}, ${state._format(tile.value)}, ${beuiChartPercent(tile.share)}',
                              child: const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

bool _handleTileKeys(
  _BeuiTreemapState state,
  List<BeuiTreemapTile> tiles,
  KeyEvent event,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
  if (tiles.isEmpty) return false;
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.escape) {
    if (state.activeId == null) return false;
    state.setActiveId(null);
    return true;
  }
  if (key == LogicalKeyboardKey.home) {
    state._focusTile(tiles.first.id);
    return true;
  }
  if (key == LogicalKeyboardKey.end) {
    state._focusTile(tiles.last.id);
    return true;
  }
  final dir = switch (key) {
    LogicalKeyboardKey.arrowRight => Offset(1, 0),
    LogicalKeyboardKey.arrowLeft => Offset(-1, 0),
    LogicalKeyboardKey.arrowDown => Offset(0, 1),
    LogicalKeyboardKey.arrowUp => Offset(0, -1),
    _ => Offset.zero,
  };
  if (dir == Offset.zero) return false;
  final current = tiles.cast<BeuiTreemapTile?>().firstWhere(
    (t) => t!.id == (state._focusedTile ?? state.activeId),
    orElse: () => tiles.first,
  )!;
  BeuiTreemapTile? best;
  var bestScore = double.infinity;
  final origin = current.rect.center;
  for (final tile in tiles) {
    if (tile.id == current.id) continue;
    final delta = tile.rect.center - origin;
    final along = delta.dx * dir.dx + delta.dy * dir.dy;
    if (along <= .01) continue;
    final across = (delta.dx * dir.dy - delta.dy * dir.dx).abs();
    final score = along + across * 2;
    if (score < bestScore) {
      bestScore = score;
      best = tile;
    }
  }
  state._focusTile((best ?? current).id);
  return true;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tile,
    required this.size,
    required this.format,
    required this.active,
    required this.onActive,
    required this.focusNode,
    required this.onFocus,
    this.renderTile,
  });

  final BeuiTreemapTile tile;
  final Size size;
  final String Function(double) format;
  final bool active;
  final ValueChanged<String?> onActive;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final Widget Function(BeuiTreemapTile tile)? renderTile;

  @override
  Widget build(BuildContext context) {
    final name =
        '${tile.path.join(' / ')}, ${format(tile.value)}, ${beuiChartPercent(tile.share)}'
        '${tile.description == null ? '' : ', ${tile.description}'}';
    final showLabel = size.width >= 52 && size.height >= 32;
    final showValue = size.width >= 70 && size.height >= 56;
    final body =
        renderTile?.call(tile) ??
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: showLabel
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tile.textColor,
                      ),
                    ),
                    if (showValue) ...[
                      const SizedBox(height: 4),
                      Text(
                        format(tile.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: tile.textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        );
    return BeuiChartTooltip(
      open: active,
      onOpenChange: (open) {
        if (!open) onActive(null);
      },
      followCursor: true,
      content: BeuiChartTooltipCard(
        title: tile.label,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tile.path.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  tile.path.sublist(0, tile.path.length - 1).join(' / '),
                  style: TextStyle(
                    color: BeuiColors.resolve(context).mutedForeground,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            Text(tile.label),
          ],
        ),
        details: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiChartTicker(
                value: tile.value,
                format: (v) => format(v.toDouble()),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('·'),
              ),
              BeuiChartTicker(
                value: tile.share * 100,
                format: (v) => '${v.toStringAsFixed(1)}%',
              ),
            ],
          ),
          if (tile.description != null) Text(tile.description!),
        ],
      ),
      child: BeuiFocusRing(
        focused: active,
        borderRadius: BorderRadius.circular(6),
        child: Semantics(
          button: true,
          label: name,
          child: MouseRegion(
            onEnter: (_) => onActive(tile.id),
            onExit: (_) => onActive(null),
            child: InkWell(
              focusNode: focusNode,
              onFocusChange: (focused) {
                if (focused) onFocus();
                onActive(focused ? tile.id : null);
              },
              onTap: () {
                focusNode.requestFocus();
                onActive(tile.id);
              },
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: tile.color, child: body),
                      IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: active ? 1 : 0,
                          duration: const Duration(milliseconds: 100),
                          curve: beuiEaseOut,
                          child: const ColoredBox(color: Color(0x1AFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tooltip host. Content is shown from the active tile; this part is a no-op
/// slot matching the source composition API.
class BeuiTreemapTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiTreemapTooltip({super.key, this.side = BeuiChartTooltipSide.top});

  /// Preferred side. Honored by the per-tile tooltip.
  final BeuiChartTooltipSide side;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Color legend of top-level groups.
class BeuiTreemapLegend extends StatelessWidget {
  /// Creates the legend.
  const BeuiTreemapLegend({super.key, this.showValues = false});

  /// When true, show each group's formatted total.
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final state = _TreemapScope.of(context);
    final colors = BeuiColors.resolve(context);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final node in state._layout.nodes)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiChartSwatch(color: node.color),
              const SizedBox(width: 6),
              Text(
                showValues
                    ? '${node.label} ${state._format(node.value)}'
                    : node.label,
                style: TextStyle(fontSize: 12, color: colors.mutedForeground),
              ),
            ],
          ),
      ],
    );
  }
}
