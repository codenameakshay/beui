/// Animated status history with an accessible period inspector.
library;

import 'package:flutter/material.dart';

import '../motion/_scroll_geometry.dart';
import '../motion/tooltip.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// A period in a status history.
@immutable
class BeuiStatusBarDatum {
  /// Creates a period.
  const BeuiStatusBarDatum({
    required this.id,
    required this.label,
    required this.status,
    this.duration,
    this.description,
  });

  /// Stable identity for updates.
  final String id;

  /// Human-readable period label.
  final String label;

  /// Status key matching [BeuiStatusBarStatus.id].
  final String status;

  /// Optional duration represented by this period.
  final Duration? duration;

  /// Additional status detail.
  final String? description;
}

/// A status key, label, and color.
@immutable
class BeuiStatusBarStatus {
  /// Creates a status definition.
  const BeuiStatusBarStatus({
    required this.id,
    required this.label,
    required this.color,
  });

  /// Status key.
  final String id;

  /// Display label.
  final String label;

  /// CSS-like color string (hex or supported `var(--...)` token).
  final String color;
}

/// Default status palette.
// ignore: constant_identifier_names
const STATUS_BAR_STATUSES = <BeuiStatusBarStatus>[
  BeuiStatusBarStatus(
    id: 'operational',
    label: 'Operational',
    color: '#059669',
  ),
  BeuiStatusBarStatus(id: 'degraded', label: 'Degraded', color: '#d97706'),
  BeuiStatusBarStatus(id: 'outage', label: 'Outage', color: '#e11d48'),
  BeuiStatusBarStatus(
    id: 'maintenance',
    label: 'Maintenance',
    color: '#2563eb',
  ),
  BeuiStatusBarStatus(
    id: 'unknown',
    label: 'No data',
    color: 'var(--muted-foreground)',
  ),
];

/// Dart-idiomatic alias for [STATUS_BAR_STATUSES].
const beuiStatusBarStatuses = STATUS_BAR_STATUSES;

/// Complete animated status history, or a scope for custom chart parts.
class BeuiStatusBar extends StatefulWidget {
  /// Creates a status history.
  const BeuiStatusBar({
    required this.data,
    super.key,
    this.statuses = STATUS_BAR_STATUSES,
    this.label = 'Status history',
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.child,
  });

  /// Observations in display order.
  final List<BeuiStatusBarDatum> data;

  /// Status definitions, including every key used by [data].
  final List<BeuiStatusBarStatus> statuses;

  /// Accessible name.
  final String label;

  /// Controlled highlighted period.
  final String? activeId;

  /// Initial highlighted period when uncontrolled.
  final String? defaultActiveId;

  /// Called when the highlighted period changes.
  final ValueChanged<String?>? onActiveChange;

  /// Custom composition. Defaults to plot, tooltip, and legend.
  final Widget? child;

  @override
  State<BeuiStatusBar> createState() => _BeuiStatusBarState();
}

class _BeuiStatusBarState extends State<BeuiStatusBar>
    with BeuiChartActiveState<BeuiStatusBar>, BeuiChartInspectorKeys {
  final FocusNode _inspectorFocusNode = FocusNode();
  bool _tooltipOpen = false;
  final _tooltipAnchor = GlobalKey();
  final _tooltipLink = LayerLink();

  @override
  String? get widgetActiveId => widget.activeId;
  @override
  String? get widgetDefaultActiveId => widget.defaultActiveId;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => null;
  @override
  Iterable<String> get knownIds => widget.data.map((datum) => datum.id);
  @override
  List<String> get inspectableIds =>
      widget.data.map((datum) => datum.id).toList();

  @override
  void initState() {
    super.initState();
    initActive();
  }

  @override
  void dispose() {
    _inspectorFocusNode.dispose();
    super.dispose();
  }

  @override
  void setActiveId(String? id) {
    final previous = activeId;
    super.setActiveId(id);
    if (previous != id) widget.onActiveChange?.call(id);
  }

  void setTooltipOpen(bool open) {
    if (_tooltipOpen != open) setState(() => _tooltipOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final ids = <String>{};
    final statusMap = {for (final status in widget.statuses) status.id: status};
    if (statusMap.length != widget.statuses.length) {
      throw ArgumentError('BeuiStatusBar.statuses must have unique ids.');
    }
    for (final datum in widget.data) {
      if (!ids.add(datum.id)) {
        throw ArgumentError('BeuiStatusBar.data must have unique ids.');
      }
      if (!statusMap.containsKey(datum.status)) {
        throw ArgumentError('BeuiStatusBar: define status "${datum.status}".');
      }
    }
    return _StatusScope(
      state: this,
      child: BeuiChartFrame(
        label: widget.label,
        child:
            widget.child ??
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BeuiStatusBarPlot(),
                SizedBox(height: 8),
                BeuiStatusBarTooltip(),
                SizedBox(height: 12),
                BeuiStatusBarLegend(),
              ],
            ),
      ),
    );
  }
}

class _StatusScope extends InheritedWidget {
  const _StatusScope({required this.state, required super.child});
  final _BeuiStatusBarState state;

  static _BeuiStatusBarState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_StatusScope>();
    assert(scope != null, 'Status bar parts must be inside BeuiStatusBar.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_StatusScope old) => true;
}

/// Rounded, staggered status segments with a range-based inspector.
class BeuiStatusBarPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiStatusBarPlot({
    super.key,
    this.showLabels = true,
    this.barHeight = 32,
  });

  /// Whether to show the first and last period labels.
  final bool showLabels;

  /// Visual segment height; the range hit area remains at least 44 pixels.
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final state = _StatusScope.of(context);
    final data = state.widget.data;
    final colors = BeuiColors.resolve(context);
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No status data'),
      );
    }
    final index = data.indexWhere((item) => item.id == state.activeId);
    final activeIndex = index < 0 ? 0 : index;
    final active = data[activeIndex];
    final statusMap = {
      for (final status in state.widget.statuses) status.id: status,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          focusNode: state._inspectorFocusNode,
          onFocusChange: state.setTooltipOpen,
          onKeyEvent: (node, event) {
            return state.handleInspectorKey(event)
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          },
          child: Semantics(
            container: true,
            slider: true,
            label: '${state.widget.label}: inspect period',
            value:
                '${active.label}. ${statusMap[active.status]!.label}${active.description == null ? '' : '. ${active.description}'}',
            increasedValue:
                data[(activeIndex + 1).clamp(0, data.length - 1)].label,
            decreasedValue:
                data[(activeIndex - 1).clamp(0, data.length - 1)].label,
            onIncrease: () => state.setActiveId(
              data[(activeIndex + 1).clamp(0, data.length - 1)].id,
            ),
            onDecrease: () => state.setActiveId(
              data[(activeIndex - 1).clamp(0, data.length - 1)].id,
            ),
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            Positioned(
                              left:
                                  (activeIndex + .5) /
                                  data.length *
                                  constraints.maxWidth,
                              top: 4.4,
                              child: CompositedTransformTarget(
                                key: state._tooltipAnchor,
                                link: state._tooltipLink,
                                child: const SizedBox(width: 1, height: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < data.length; i++)
                        Expanded(
                          key: ValueKey(data[i].id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1.5,
                            ),
                            child: MouseRegion(
                              onEnter: (_) {
                                state.setActiveId(data[i].id);
                                state.setTooltipOpen(true);
                              },
                              onExit: (_) => state.setTooltipOpen(false),
                              child: GestureDetector(
                                excludeFromSemantics: true,
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  state._inspectorFocusNode.requestFocus();
                                  state.setActiveId(data[i].id);
                                },
                                child: ExcludeSemantics(
                                  child: Center(
                                    child: _StatusEntrance(
                                      height: barHeight,
                                      child: BeuiChartTween(
                                        key: ValueKey(data[i].id),
                                        from: 0,
                                        value: 1,
                                        duration: Duration(
                                          milliseconds:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              )
                                              ? 150
                                              : 240,
                                        ),
                                        delay: Duration(
                                          microseconds:
                                              (180000 *
                                                      i /
                                                      (data.length > 1
                                                          ? data.length - 1
                                                          : 1))
                                                  .round(),
                                        ),
                                        builder: (context, opacity) => Opacity(
                                          opacity: opacity.clamp(0, 1),
                                          child: BeuiChartTween(
                                            from: 0,
                                            value: 1,
                                            duration: const Duration(
                                              milliseconds: 240,
                                            ),
                                            delay: Duration(
                                              microseconds:
                                                  (180000 *
                                                          i /
                                                          (data.length > 1
                                                              ? data.length - 1
                                                              : 1))
                                                      .round(),
                                            ),
                                            motion: beuiSpringPress,
                                            isMovement: true,
                                            builder: (context, t) => Transform.translate(
                                              offset: Offset(0, 4 * (1 - t)),
                                              child: Transform.scale(
                                                scaleY: .9 + .1 * t,
                                                child: SizedBox(
                                                  height: barHeight,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      AnimatedSwitcher(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 160,
                                                            ),
                                                        reverseDuration:
                                                            const Duration(
                                                              milliseconds: 120,
                                                            ),
                                                        switchInCurve:
                                                            beuiEaseOut,
                                                        switchOutCurve:
                                                            beuiEaseOut,
                                                        child: DecoratedBox(
                                                          key: ValueKey(
                                                            '${data[i].status}:${statusMap[data[i].status]!.color}',
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: beuiChartColor(
                                                              statusMap[data[i]
                                                                      .status]!
                                                                  .color,
                                                              colors,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  99,
                                                                ),
                                                          ),
                                                          child:
                                                              const SizedBox.expand(),
                                                        ),
                                                      ),
                                                      AnimatedOpacity(
                                                        opacity:
                                                            state._tooltipOpen &&
                                                                data[i].id ==
                                                                    state
                                                                        .activeId
                                                            ? 1
                                                            : 0,
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 100,
                                                            ),
                                                        curve: beuiEaseOut,
                                                        child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  99,
                                                                ),
                                                            border: Border.all(
                                                              color: colors
                                                                  .foreground
                                                                  .withValues(
                                                                    alpha: .6,
                                                                  ),
                                                            ),
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
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showLabels)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.first.label,
                style: TextStyle(color: colors.mutedForeground, fontSize: 11),
              ),
              Text(
                data.last.label,
                style: TextStyle(color: colors.mutedForeground, fontSize: 11),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatusEntrance extends StatefulWidget {
  const _StatusEntrance({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  State<_StatusEntrance> createState() => _StatusEntranceState();
}

class _StatusEntranceState extends State<_StatusEntrance>
    with ScrollGeometryMixin {
  bool _shown = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_shown) setState(() => _shown = true);
      });
    }
  }

  @override
  void onScrollGeometryChanged() {
    if (!_shown && (visibleFraction ?? 0) > 0) setState(() => _shown = true);
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: widget.height, child: _shown ? widget.child : null);
}

/// Legend for statuses present in the configured status set.
class BeuiStatusBarLegend extends StatelessWidget {
  /// Creates a legend.
  const BeuiStatusBarLegend({super.key, this.showCounts = false});

  /// Whether each status count is shown.
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    final state = _StatusScope.of(context);
    final colors = BeuiColors.resolve(context);
    return BeuiChartLegend(
      children: [
        for (final status in state.widget.statuses)
          BeuiChartLegendItem(
            color: beuiChartColor(status.color, colors),
            label: status.label,
            value: showCounts
                ? '${state.widget.data.where((item) => item.status == status.id).length}'
                : null,
          ),
      ],
    );
  }
}

/// Tooltip slot; period detail is also available from each period's semantics.
class BeuiStatusBarTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiStatusBarTooltip({super.key, this.side = BeuiChartTooltipSide.top});

  /// Preferred tooltip side.
  final BeuiChartTooltipSide side;

  @override
  Widget build(BuildContext context) {
    final state = _StatusScope.of(context);
    final active = state.widget.data
        .where((item) => item.id == state.activeId)
        .firstOrNull;
    final datum = active ?? state.widget.data.firstOrNull;
    if (datum == null) return const SizedBox.shrink();
    final status = state.widget.statuses.firstWhere(
      (item) => item.id == datum.status,
    );
    final colors = BeuiColors.resolve(context);
    return BeuiTooltip(
      open: state._tooltipOpen && active != null,
      onOpenChange: state.setTooltipOpen,
      externalAnchor: state._tooltipAnchor,
      anchorLink: state._tooltipLink,
      side: beuiChartToTooltipSide(side),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 256),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(datum.label, style: TextStyle(color: colors.mutedForeground)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiChartSwatch(color: beuiChartColor(status.color, colors)),
                const SizedBox(width: 8),
                Text(
                  status.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (datum.description != null) ...[
              const SizedBox(height: 4),
              Text(
                datum.description!,
                style: TextStyle(color: colors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
