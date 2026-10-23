/// Weighted flows, ported from source a76e57c9.
library;

import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show SemanticsRole;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../motion/_engine.dart';
import '../motion/_scroll_geometry.dart';
import '../motion/tooltip.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';
import 'sankey_chart/model.dart';
import 'sankey_chart/hover_stub.dart'
    if (dart.library.js_interop) 'sankey_chart/hover_web.dart';
export 'sankey_chart/model.dart';

/// A highlighted node or flow. Only one of [node] and [link] is populated.
sealed class BeuiSankeyActive {
  const BeuiSankeyActive();

  /// Node selection, if this is a node.
  BeuiSankeyPlacedNode? get node;

  /// Flow selection, if this is a flow.
  BeuiSankeyPlacedLink? get link;
}

/// A node inspection.
class BeuiSankeyActiveNode extends BeuiSankeyActive {
  /// Selects [node].
  const BeuiSankeyActiveNode(this.node);
  @override
  final BeuiSankeyPlacedNode node;
  @override
  BeuiSankeyPlacedLink? get link => null;
}

/// A flow inspection.
class BeuiSankeyActiveLink extends BeuiSankeyActive {
  /// Selects [link].
  const BeuiSankeyActiveLink(this.link);
  @override
  final BeuiSankeyPlacedLink link;
  @override
  BeuiSankeyPlacedNode? get node => null;
}

/// Weighted flows laid out in columns from sources to outcomes.
///
/// Omit [child] for Plot and Tooltip, or compose those public parts. The
/// optional [controlled] flag distinguishes a controlled null selection from
/// an omitted selection, which Dart's nullable [activeId] cannot represent.
class BeuiSankeyChart extends StatefulWidget {
  /// Reads the chart model for custom composed parts, like source useSankeyChart.
  static BeuiSankeyChartModel of(BuildContext context) =>
      BeuiSankeyChartModel._(_SankeyScope.of(context));

  /// Creates a Sankey chart.
  const BeuiSankeyChart({
    required this.nodes,
    required this.links,
    super.key,
    this.label = 'Sankey chart',
    this.formatValue,
    this.colors = beuiChartPalette,
    this.nodeWidth = 12,
    this.nodePadding = 16,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.controlled = false,
    this.child,
  });

  /// Nodes, in stable within-column order.
  final List<BeuiSankeyNode> nodes;

  /// Directed positive flows. Invalid and cycle-closing edges are omitted.
  final List<BeuiSankeyLink> links;

  /// Accessible chart name.
  final String label;

  /// Value formatter, defaulting to en-US grouping with at most two decimals.
  final String Function(double)? formatValue;

  /// Palette for nodes without an explicit color.
  final List<Color> colors;

  /// Bar width in logical pixels.
  final double nodeWidth;

  /// Gap between nodes in a column.
  final double nodePadding;

  /// Controlled node or flow id. Nodes win an identity collision.
  final String? activeId;

  /// Initial uncontrolled selection. Highlight alone does not open a tooltip.
  final String? defaultActiveId;

  /// Selection requests, emitted only when the requested id changes.
  final ValueChanged<String?>? onActiveChange;

  /// Keep selection controlled even when [activeId] is null.
  final bool controlled;

  /// Custom composition of Plot and Tooltip.
  final Widget? child;
  @override
  State<BeuiSankeyChart> createState() => _SankeyState();
}

/// Chart context for custom composed parts. Read it during build.
class BeuiSankeyChartModel {
  BeuiSankeyChartModel._(this._state);
  final _SankeyState _state;

  /// Current measured layout.
  BeuiSankeyLayout get layout => _state.layout;

  /// Cleaned input and omitted-link diagnostics.
  BeuiSankeyData get data => _state.data;

  /// Resolved selection, or null for a missing identity.
  BeuiSankeyActive? get active => _state.active;

  /// Current tooltip inspection visibility.
  bool get tooltipOpen => _state.tooltipOpen;

  /// Accessible chart name.
  String get label => _state.widget.label;

  /// Formats a value with the consumer's formatter.
  String formatValue(double value) => _state.format(value);

  /// Requests selection without opening inspection.
  void setActive(String? id) => _state.select(id);

  /// Opens or closes inspection without clearing selection.
  void setTooltipOpen(bool open) => _state.setOpen(open);
}

class _SankeyScope extends InheritedWidget {
  const _SankeyScope({required this.state, required super.child});
  final _SankeyState state;
  static _SankeyState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SankeyScope>();
    if (scope == null) {
      throw FlutterError(
        'Sankey chart parts must be rendered inside BeuiSankeyChart.',
      );
    }
    return scope.state;
  }

  @override
  bool updateShouldNotify(_SankeyScope old) => true;
}

class _SankeyState extends State<BeuiSankeyChart> {
  late BeuiSankeyData data;
  late BeuiSankeyLayout layout;
  Size size = const Size(640, 320);
  late String? internal = widget.defaultActiveId;
  String? cursor, focused;
  bool tooltipOpen = false;
  bool pointerFocus = false;
  Offset? pointer;
  final anchor = GlobalKey();
  final anchorLink = LayerLink();
  final plotFocus = FocusNode(debugLabel: 'Sankey plot');
  final focus = <String, FocusNode>{};
  bool get controlled => widget.controlled || widget.activeId != null;
  String? get requested => controlled ? widget.activeId : internal;
  BeuiSankeyActive? get active {
    for (final n in layout.nodes) {
      if (n.id == requested) return BeuiSankeyActiveNode(n);
    }
    for (final l in layout.links) {
      if (l.id == requested) return BeuiSankeyActiveLink(l);
    }
    return null;
  }

  String format(double v) {
    if (widget.formatValue != null) return widget.formatValue!(v);
    return beuiChartFormatNumber(
      v,
      maximumFractionDigits: 2,
    ).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    _clean();
  }

  void _clean() {
    data = beuiCleanSankey(widget.nodes, widget.links);
    measure(size);
  }

  void measure(Size s) {
    size = s;
    layout = beuiLayoutSankey(
      data,
      size: s,
      nodeWidth: widget.nodeWidth,
      nodePadding: widget.nodePadding,
      colors: widget.colors,
    );
    if (!controlled && internal != null && active == null) internal = null;
    if (cursor != null && !layout.nodes.any((node) => node.id == cursor)) {
      cursor = null;
    }
  }

  @override
  void didUpdateWidget(BeuiSankeyChart old) {
    super.didUpdateWidget(old);
    _clean();
    if (focused != null && !layout.nodes.any((n) => n.id == focused)) {
      focused = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (layout.nodes.isEmpty) {
          plotFocus.requestFocus();
        } else {
          focusNode(tabStop!).requestFocus();
        }
      });
    }
  }

  FocusNode focusNode(String id) =>
      focus.putIfAbsent(id, () => FocusNode(debugLabel: 'Sankey $id'));
  String? get tabStop => layout.nodes.any((n) => n.id == cursor)
      ? cursor
      : layout.nodes.firstOrNull?.id;
  void select(String? id, {bool? open, Offset? point, bool keyboard = false}) {
    final previous = requested;
    setState(() {
      if (!controlled) internal = id;
      if (open != null) tooltipOpen = open;
      if (keyboard) {
        pointer = null;
      } else if (point != null) {
        pointer = point;
      }
    });
    if (previous != id) widget.onActiveChange?.call(id);
  }

  void dismiss({bool clear = true}) {
    if (clear) {
      select(null, open: false);
    } else {
      setState(() => tooltipOpen = false);
    }
  }

  void setOpen(bool open) => setState(() => tooltipOpen = open);

  @override
  void dispose() {
    plotFocus.dispose();
    for (final n in focus.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SankeyScope(
    state: this,
    child: FocusTraversalGroup(
      child: BeuiChartFrame(
        label: widget.label,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child ??
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [BeuiSankeyChartPlot(), BeuiSankeyChartTooltip()],
                ),
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: _SankeyDataTable(state: this),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SankeyDataTable extends StatelessWidget {
  const _SankeyDataTable({required this.state});
  final _SankeyState state;
  @override
  Widget build(BuildContext context) {
    final s = state;
    Widget row(List<String> cells, {bool heading = false}) => Expanded(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.row,
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                child: Semantics(
                  container: true,
                  role: heading
                      ? SemanticsRole.columnHeader
                      : SemanticsRole.cell,
                  header: heading || i == 0,
                  label: cells[i],
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.table,
      label: '${s.widget.label} data',
      child: Column(
        children: [
          row(['Flow', 'Value', 'Share of source'], heading: true),
          for (final l in s.data.links)
            row([
              '${s.data.nodes.firstWhere((n) => n.id == l.source).label} to ${s.data.nodes.firstWhere((n) => n.id == l.target).label}',
              s.format(l.value),
              beuiChartPercent(
                l.value /
                    math.max(
                      s.data.links
                          .where((x) => x.source == l.source)
                          .fold<double>(0, (v, x) => v + x.value),
                      s.data.links
                          .where((x) => x.target == l.source)
                          .fold<double>(0, (v, x) => v + x.value),
                    ),
              ),
            ]),
        ],
      ),
    );
  }
}

/// A measured, horizontally scrollable Sankey plot with native focus targets.
class BeuiSankeyChartPlot extends StatefulWidget {
  /// Creates the plot. Its minimum content width is 512 logical pixels.
  const BeuiSankeyChartPlot({
    super.key,
    this.height = 320,
    this.showValues = true,
  });

  /// Plot height, replacing the source's height class.
  final double height;

  /// Show values below names when the bar and label room permit.
  final bool showValues;
  @override
  State<BeuiSankeyChartPlot> createState() => _PlotState();
}

class _PlotState extends State<BeuiSankeyChartPlot> with ScrollGeometryMixin {
  bool shown = false;
  bool entered = false;
  Timer? entrance;
  String? touchTarget;
  final plotKey = GlobalKey();
  bool get reduce =>
      motionFor(context, beuiSpringLayout, isMovement: true) is NoMotion;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
  }

  @override
  void dispose() {
    entrance?.cancel();
    super.dispose();
  }

  @override
  void onScrollGeometryChanged() => _checkVisible();
  void _checkVisible() {
    if (!mounted || shown) return;
    var fraction = visibleFraction;
    if (fraction == null) {
      final box = plotKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final r = box.localToGlobal(Offset.zero) & box.size;
      fraction =
          r
              .intersect(Offset.zero & MediaQuery.sizeOf(context))
              .height
              .clamp(0, r.height) /
          r.height;
    }
    if (fraction >= .3) {
      setState(() => shown = true);
      entrance = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => entered = true);
      });
    }
  }

  String? hit(BeuiSankeyLayout layout, Offset point) {
    for (final n in layout.nodes.reversed) {
      final h = math.max(1.0, n.rect.height), target = math.max(24.0, h + 8);
      if (Rect.fromLTWH(
        n.rect.left - 4,
        n.rect.top + h / 2 - target / 2,
        n.rect.width + 8,
        target,
      ).contains(point)) {
        return n.id;
      }
    }
    final links = [...layout.links]..sort((a, b) => a.width.compareTo(b.width));
    for (final l in links) {
      final metric = l.path.computeMetrics().first;
      // Distance to the exact cubic centerline, with source's static 8px floor.
      final count = math.max(24, (metric.length / 2).ceil());
      for (var i = 0; i <= count; i++) {
        if ((metric.getTangentForOffset(metric.length * i / count)!.position -
                    point)
                .distance <=
            math.max(8, l.width) / 2) {
          return l.id;
        }
      }
    }
    return null;
  }

  KeyEventResult key(_SankeyState s, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    s.pointer = null;
    s.pointerFocus = false;
    final current = s.layout.nodes
        .where((n) => s.focus[n.id]?.hasFocus ?? false)
        .firstOrNull;
    if (current == null) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (!s.tooltipOpen) return KeyEventResult.ignored;
      s.dismiss(clear: false);
      return KeyEventResult.handled;
    }
    BeuiSankeyPlacedNode? next;
    final nodes = s.layout.nodes;
    if (k == LogicalKeyboardKey.home) {
      next = nodes.first;
    } else if (k == LogicalKeyboardKey.end) {
      next = nodes.last;
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown) {
      final same = nodes.where((n) => n.depth == current.depth).toList();
      final index =
          same.indexOf(current) + (k == LogicalKeyboardKey.arrowUp ? -1 : 1);
      if (index >= 0 && index < same.length) next = same[index];
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      final dir = k == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      for (
        var d = current.depth + dir;
        d >= 0 && d < s.layout.columns && next == null;
        d += dir
      ) {
        for (final n in nodes.where((n) => n.depth == d)) {
          if (next == null ||
              (n.rect.center.dy - current.rect.center.dy).abs() <
                  (next.rect.center.dy - current.rect.center.dy).abs()) {
            next = n;
          }
        }
      }
    } else {
      return KeyEventResult.ignored;
    }
    if (next != null && next != current) {
      s.focusNode(next.id).requestFocus();
    } else {
      s.select(current.id, open: true, keyboard: true);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final s = _SankeyScope.of(context);
    final colors = BeuiColors.resolve(context);
    final visible = reduce || shown;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(512.0, constraints.maxWidth);
        s.measure(Size(width, widget.height));
        final l = s.layout, active = s.active;
        bool linkLit(BeuiSankeyPlacedLink link) =>
            active == null ||
            active.link?.id == link.id ||
            active.node?.id == link.source.id ||
            active.node?.id == link.target.id;
        bool nodeLit(BeuiSankeyPlacedNode n) =>
            active == null ||
            active.node?.id == n.id ||
            active.link?.source.id == n.id ||
            active.link?.target.id == n.id ||
            (active.node != null &&
                l.links.any(
                  (f) =>
                      (f.source.id == active.node!.id && f.target.id == n.id) ||
                      (f.target.id == active.node!.id && f.source.id == n.id),
                ));
        final anchor =
            s.pointer ??
            (active?.node != null
                ? Offset(active!.node!.rect.center.dx, active.node!.rect.top)
                : active?.link != null
                ? (active!.link!.start + active.link!.end) / 2
                : Offset(width / 2, widget.height / 2));
        return SizedBox(
          height: widget.height,
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: constraints.maxWidth + 16,
            maxWidth: constraints.maxWidth + 16,
            minHeight: widget.height + 16,
            maxHeight: widget.height + 16,
            child: TapRegion(
              onTapOutside: (_) {
                if (s.tooltipOpen) s.dismiss();
              },
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Focus(
                    focusNode: s.plotFocus,
                    includeSemantics: false,
                    skipTraversal: true,
                    onKeyEvent: (_, e) => key(s, e),
                    onFocusChange: (focused) {
                      if (!focused) {
                        s.focused = null;
                        s.dismiss();
                      }
                    },
                    child: MouseRegion(
                      onExit: (e) {
                        if (e.kind != PointerDeviceKind.touch) {
                          s.dismiss();
                        }
                      },
                      onHover: (e) {
                        if (e.kind == PointerDeviceKind.touch ||
                            !sankeyHoverCapable) {
                          return;
                        }
                        final id = hit(l, e.localPosition);
                        if (visible && id != null) {
                          s.select(id, open: true, point: e.localPosition);
                        } else if (s.tooltipOpen) {
                          s.select(s.requested, point: e.localPosition);
                        }
                      },
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          final touch = e.kind == PointerDeviceKind.touch;
                          final id = hit(l, e.localPosition);
                          if (touch) touchTarget = id;
                          if (visible && id != null) {
                            s.select(id, open: true, point: e.localPosition);
                            if (!touch && s.focus.containsKey(id)) {
                              s.pointerFocus = true;
                              s.focusNode(id).requestFocus();
                            }
                          }
                        },
                        onPointerMove: (e) {
                          if (e.kind != PointerDeviceKind.touch &&
                              !sankeyHoverCapable) {
                            return;
                          }
                          if (e.kind == PointerDeviceKind.touch &&
                              e.buttons != 1) {
                            return;
                          }
                          final id = e.kind == PointerDeviceKind.touch
                              ? touchTarget
                              : hit(l, e.localPosition);
                          if (visible && id != null) {
                            s.select(id, open: true, point: e.localPosition);
                          } else if (s.tooltipOpen) {
                            s.select(s.requested, point: e.localPosition);
                          }
                        },
                        onPointerUp: (e) {
                          if (e.kind == PointerDeviceKind.touch) {
                            touchTarget = null;
                          }
                        },
                        onPointerCancel: (e) {
                          if (e.kind == PointerDeviceKind.touch) {
                            touchTarget = null;
                          }
                        },
                        child: SizedBox(
                          key: plotKey,
                          width: width,
                          height: widget.height,
                          child: Semantics(
                            container: true,
                            label: '${s.widget.label} nodes',
                            explicitChildNodes: true,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (visible) ...[
                                  for (final link in l.links)
                                    Positioned.fill(
                                      key: ValueKey('flow:${link.id}'),
                                      child: IgnorePointer(
                                        child: _LinkPaint(
                                          key: ValueKey('link:${link.id}'),
                                          link: link,
                                          entered: entered,
                                          size: s.size,
                                          opacity: active == null
                                              ? 0.32
                                              : linkLit(link)
                                              ? 0.6
                                              : 0.08,
                                        ),
                                      ),
                                    ),
                                  for (final node in l.nodes)
                                    Positioned.fill(
                                      key: ValueKey('bar:${node.id}'),
                                      child: IgnorePointer(
                                        child: _NodePaint(
                                          key: ValueKey('node:${node.id}'),
                                          node: node,
                                          entered: entered,
                                          size: s.size,
                                          columns: l.columns,
                                          step: l.step,
                                          lit: nodeLit(node),
                                          showValues: widget.showValues,
                                          format: s.format,
                                          colors: colors,
                                        ),
                                      ),
                                    ),
                                ],
                                for (final n in l.nodes)
                                  Positioned.fromRect(
                                    key: ValueKey('target:${n.id}'),
                                    rect: Rect.fromCenter(
                                      center: n.rect.center,
                                      width: n.rect.width + 8,
                                      height: math.max(
                                        24,
                                        math.max(1, n.rect.height) + 8,
                                      ),
                                    ),
                                    child: _NodeTarget(
                                      key: ValueKey('sankey-target:${n.id}'),
                                      node: n,
                                      state: s,
                                      enabled: visible,
                                    ),
                                  ),
                                Positioned(
                                  left: anchor.dx,
                                  top: anchor.dy,
                                  width: 1,
                                  height: 1,
                                  child: IgnorePointer(
                                    child: CompositedTransformTarget(
                                      key: s.anchor,
                                      link: s.anchorLink,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                                if (dataEmpty(s))
                                  Center(
                                    child: Text(
                                      s.widget.nodes.isEmpty
                                          ? 'No sankey data'
                                          : 'No flows to show',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.mutedForeground,
                                      ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  bool dataEmpty(_SankeyState s) => s.data.links.isEmpty;
}

class _NodeTarget extends StatefulWidget {
  const _NodeTarget({
    super.key,
    required this.node,
    required this.state,
    required this.enabled,
  });
  final BeuiSankeyPlacedNode node;
  final _SankeyState state;
  final bool enabled;
  @override
  State<_NodeTarget> createState() => _NodeTargetState();
}

class _NodeTargetState extends State<_NodeTarget> {
  bool ring = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.state, n = widget.node;
    final label = [
      n.label,
      s.format(n.value),
      if (n.inValue != 0 && n.outValue != 0)
        'in ${s.format(n.inValue)}, out ${s.format(n.outValue)}',
      if (n.description != null) n.description!,
    ].join('. ');
    final focus = s.focusNode(n.id)..skipTraversal = s.tabStop != n.id;
    return FocusableActionDetector(
      focusNode: focus,
      includeFocusSemantics: false,
      onShowFocusHighlight: (v) => setState(() => ring = v),
      onFocusChange: (v) {
        if (v) {
          s.cursor = n.id;
          s.focused = n.id;
          s.select(n.id, open: true, keyboard: !s.pointerFocus);
          s.pointerFocus = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !focus.hasFocus) return;
            Scrollable.ensureVisible(
              context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
            );
            Scrollable.ensureVisible(
              context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          });
        }
      },
      child: Focus(
        includeSemantics: false,
        skipTraversal: s.tabStop != n.id,
        canRequestFocus: false,
        child: Semantics(
          key: ValueKey(s.tabStop == n.id),
          button: true,
          focusable: s.tabStop == n.id,
          focused: s.tabStop == n.id ? focus.hasFocus : null,
          onFocus: focus.requestFocus,
          label: label,
          excludeSemantics: true,
          onTap: widget.enabled
              ? () {
                  s.pointerFocus = s.pointer != null;
                  focus.requestFocus();
                  s.select(n.id, open: true, keyboard: s.pointer == null);
                }
              : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              boxShadow: ring
                  ? [
                      BoxShadow(
                        color: BeuiColors.resolve(context).ring,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: BeuiColors.resolve(context).background,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _LinkPaint extends StatelessWidget {
  const _LinkPaint({
    super.key,
    required this.link,
    required this.size,
    required this.opacity,
    required this.entered,
  });
  final BeuiSankeyPlacedLink link;
  final Size size;
  final double opacity;
  final bool entered;
  @override
  Widget build(BuildContext context) {
    final r = Rect.fromLTRB(
      link.start.dx,
      link.start.dy,
      link.end.dx,
      link.end.dy,
    );
    return BeuiChartTween(
      value: 1,
      from: 0,
      duration: const Duration(milliseconds: 700),
      delay: Duration(milliseconds: entered ? 0 : link.source.depth * 120),
      isMovement: true,
      builder: (context, progress) => BeuiChartTween(
        value: opacity,
        from: .32,
        duration: const Duration(milliseconds: 160),
        snapWhenReduced: true,
        builder: (context, alpha) => _GeometryRect(
          size: size,
          value: r,
          builder: (r) =>
              CustomPaint(painter: _FlowPainter(link, r, progress, alpha)),
        ),
      ),
    );
  }
}

class _GeometryRect extends StatelessWidget {
  const _GeometryRect({
    required this.size,
    required this.value,
    required this.builder,
  });
  final Size size;
  final Rect value;
  final Widget Function(Rect) builder;
  @override
  Widget build(BuildContext context) {
    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    if (motion is NoMotion) return builder(value);
    return MotionBuilder<Rect>(
      key: ValueKey(size),
      value: value,
      motion: motion,
      converter: const RectMotionConverter(),
      builder: (context, r, _) => builder(r),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.link, this.geometry, this.progress, this.alpha);
  final BeuiSankeyPlacedLink link;
  final Rect geometry;
  final double progress, alpha;
  @override
  void paint(Canvas canvas, Size size) {
    final r = geometry;
    final path = Path()
      ..moveTo(r.left, r.top)
      ..cubicTo(r.center.dx, r.top, r.center.dx, r.bottom, r.right, r.bottom);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, link.width)
      ..shader = LinearGradient(
        colors: [
          link.source.color.withValues(alpha: alpha),
          link.target.color.withValues(alpha: alpha),
        ],
      ).createShader(Rect.fromLTRB(link.start.dx, 0, link.end.dx, 1));
    canvas.drawPath(
      progress >= 1
          ? path
          : metric.extractPath(0, metric.length * progress.clamp(0, 1)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}

class _NodePaint extends StatelessWidget {
  const _NodePaint({
    super.key,
    required this.node,
    required this.size,
    required this.columns,
    required this.step,
    required this.lit,
    required this.showValues,
    required this.format,
    required this.colors,
    required this.entered,
  });
  final BeuiSankeyPlacedNode node;
  final Size size;
  final int columns;
  final double step;
  final bool lit, showValues;
  final String Function(double) format;
  final BeuiColors colors;
  final bool entered;
  @override
  Widget build(BuildContext context) {
    return BeuiChartTween(
      value: lit ? 1 : .3,
      from: 0,
      duration: Duration(milliseconds: entered ? 160 : 300),
      delay: Duration(milliseconds: entered ? 0 : 100 + node.depth * 120),
      snapWhenReduced: true,
      builder: (context, alpha) => BeuiChartTween(
        value: lit ? 1 : .35,
        from: 0,
        duration: const Duration(milliseconds: 200),
        delay: Duration(milliseconds: entered ? 0 : 200 + node.depth * 120),
        snapWhenReduced: true,
        builder: (context, labelAlpha) => _GeometryRect(
          size: size,
          value: node.rect,
          builder: (r) => CustomPaint(
            painter: _BarPainter(
              node,
              Rect.fromLTWH(node.rect.left, r.top, node.rect.width, r.height),
              alpha,
              labelAlpha,
              columns,
              step,
              size,
              showValues,
              format,
              colors,
              DefaultTextStyle.of(context).style.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(
    this.node,
    this.rect,
    this.alpha,
    this.labelAlpha,
    this.columns,
    this.step,
    this.plotSize,
    this.showValues,
    this.format,
    this.colors,
    this.fontFamily,
  );
  final BeuiSankeyPlacedNode node;
  final Rect rect;
  final double alpha, labelAlpha, step;
  final int columns;
  final Size plotSize;
  final bool showValues;
  final String Function(double) format;
  final BeuiColors colors;
  final String? fontFamily;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width,
          math.max(1, rect.height),
        ),
        const Radius.circular(2),
      ),
      Paint()..color = node.color.withValues(alpha: alpha.clamp(0, 1)),
    );
    if (node.rect.height < 12) return;
    final room = columns > 1 ? step - node.rect.width - 16 : plotSize.width;
    final chars = (room / 6.6).floor();
    if (chars < 4 && chars < node.label.length) return;
    final text = chars >= node.label.length
        ? node.label
        : '${node.label.substring(0, chars - 1).trimRight()}…';
    final value = format(node.value);
    final two =
        showValues && node.rect.height >= 28.8 && value.length * 6.6 <= room;
    final last = columns > 1 && node.depth == columns - 1;
    final x = last ? rect.left - 8 : rect.right + 8;
    void line(String text, double cy, Color color, FontWeight weight) {
      TextPainter painter(Paint paint) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1,
            fontWeight: weight,
            foreground: paint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final stroke = painter(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = colors.background.withValues(alpha: labelAlpha.clamp(0, 1)),
      );
      final offset = Offset(
        last ? x - stroke.width : x,
        cy - stroke.height / 2,
      );
      stroke.paint(canvas, offset);
      painter(
        Paint()..color = color.withValues(alpha: labelAlpha.clamp(0, 1)),
      ).paint(canvas, offset);
    }

    line(
      text,
      rect.center.dy - (two ? 7.2 : 0),
      colors.foreground,
      FontWeight.w500,
    );
    if (two) {
      line(
        value,
        rect.center.dy + 7.2,
        colors.mutedForeground,
        FontWeight.w400,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}

/// Cursor-following readout for the highlighted node or flow.
class BeuiSankeyChartTooltip extends StatelessWidget {
  /// Creates the readout, with optional static or active-dependent content.
  const BeuiSankeyChartTooltip({
    super.key,
    this.side = BeuiChartTooltipSide.top,
    this.child,
    this.builder,
  });

  /// Preferred placement, subject to viewport collision handling.
  final BeuiChartTooltipSide side;

  /// Static replacement content.
  final Widget? child;

  /// Dynamic replacement content. Takes precedence over [child].
  final Widget Function(BuildContext, BeuiSankeyActive)? builder;
  @override
  Widget build(BuildContext context) {
    final s = _SankeyScope.of(context), a = _SankeyScope.of(context).active;
    return ExcludeFocus(
      child: BeuiTooltip(
        externalAnchor: s.anchor,
        anchorLink: s.anchorLink,
        open: s.tooltipOpen && a != null,
        onOpenChange: (open) {
          if (!open) s.dismiss(clear: false);
        },
        delay: Duration.zero,
        sideOffset: s.pointer == null ? 8 : 12,
        side: beuiChartToTooltipSide(side),
        semanticLabel:
            a?.node?.label ??
            (a?.link == null
                ? null
                : '${a!.link!.source.label} to ${a.link!.target.label}'),
        content: a == null
            ? const SizedBox.shrink()
            : builder?.call(context, a) ??
                  child ??
                  _TooltipBody(state: s, active: a),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _TooltipBody extends StatelessWidget {
  const _TooltipBody({required this.state, required this.active});
  final _SankeyState state;
  final BeuiSankeyActive active;
  @override
  Widget build(BuildContext context) {
    final s = state,
        a = active,
        n = a.node,
        l = a.link,
        colors = BeuiColors.resolve(context);
    final muted = TextStyle(
      color: colors.mutedForeground,
      fontSize: 12,
      height: 16 / 12,
    );
    Widget ticker(double v, String Function(double) f, {Color? color}) =>
        BeuiChartTicker(
          value: v,
          format: (v) => f(v.toDouble()),
          style: TextStyle(
            color: color,
            fontFamily: 'Geist Mono',
            fontSize: 12,
            height: 16 / 12,
          ),
        );
    Widget flows(bool incoming) {
      final own =
          s.layout.links
              .where(
                (l) => incoming ? l.target.id == n!.id : l.source.id == n!.id,
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      if (own.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(incoming ? 'From' : 'To', style: muted),
          for (final f in own.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      incoming ? f.source.label : f.target.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    s.format(f.value),
                    style: muted.copyWith(fontFamily: 'Geist Mono'),
                  ),
                ],
              ),
            ),
          if (own.length > 4) Text('${own.length - 4} more', style: muted),
        ],
      );
    }

    final rows = <Widget>[
      if (n != null) ...[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiChartSwatch(color: n.color, size: 8),
            const SizedBox(width: 8),
            Text(n.label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        ticker(n.value, s.format),
        if (n.inValue != 0 && n.outValue != 0)
          Text(
            'In ${s.format(n.inValue)} · Out ${s.format(n.outValue)}',
            style: muted.copyWith(fontFamily: 'Geist Mono'),
          ),
        if (s.layout.links.any((l) => l.target.id == n.id)) flows(true),
        if (s.layout.links.any((l) => l.source.id == n.id)) flows(false),
        if (n.description != null) Text(n.description!, style: muted),
      ] else if (l != null) ...[
        Text(
          '${l.source.label} → ${l.target.label}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ticker(l.value, s.format),
            const SizedBox(width: 8),
            Text('·', style: muted.copyWith(fontFamily: 'Geist Mono')),
            const SizedBox(width: 8),
            ticker(
              l.share,
              (v) => '${(v * 100).toStringAsFixed(1)}%',
              color: colors.mutedForeground,
            ),
            Text(
              ' of ${l.source.label}',
              style: muted.copyWith(fontFamily: 'Geist Mono'),
            ),
          ],
        ),
      ],
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 256),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12, height: 16 / 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: rows[i],
              ),
          ],
        ),
      ),
    );
  }
}
