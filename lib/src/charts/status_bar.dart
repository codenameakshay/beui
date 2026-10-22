/// Animated status history with an accessible period inspector.
library;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
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
    this.barHeight = 28,
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
            label: '${active.label}, ${statusMap[active.status]!.label}',
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Semantics(
                    container: true,
                    slider: true,
                    label: 'Status history period',
                    value:
                        '${active.label}, ${statusMap[active.status]!.label}',
                    increasedValue:
                        '${data[(activeIndex + 1).clamp(0, data.length - 1)].label}, ${statusMap[data[(activeIndex + 1).clamp(0, data.length - 1)].status]!.label}',
                    decreasedValue:
                        '${data[(activeIndex - 1).clamp(0, data.length - 1)].label}, ${statusMap[data[(activeIndex - 1).clamp(0, data.length - 1)].status]!.label}',
                    onIncrease: () => state.setActiveId(
                      data[(activeIndex + 1).clamp(0, data.length - 1)].id,
                    ),
                    onDecrease: () => state.setActiveId(
                      data[(activeIndex - 1).clamp(0, data.length - 1)].id,
                    ),
                    child: Opacity(
                      opacity: 0,
                      alwaysIncludeSemantics: true,
                      child: Slider(
                        value: activeIndex.toDouble(),
                        min: 0,
                        max: (data.length - 1).toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        divisions: data.length > 1 ? data.length - 1 : null,
                        semanticFormatterCallback: (_) =>
                            '${active.label}, ${statusMap[active.status]!.label}',
                        onChanged: data.length < 2
                            ? null
                            : (value) =>
                                  state.setActiveId(data[value.round()].id),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < data.length; i++)
                        Expanded(
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
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  state._inspectorFocusNode.requestFocus();
                                  state.setActiveId(data[i].id);
                                },
                                child: Semantics(
                                  button: true,
                                  selected: data[i].id == state.activeId,
                                  label:
                                      '${data[i].label}, ${statusMap[data[i].status]!.label}${data[i].description == null ? '' : ', ${data[i].description}'}',
                                  child: Center(
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey(data[i].id),
                                      tween: Tween(begin: 0.72, end: 1),
                                      duration: Duration(
                                        milliseconds: 180 + i * 8,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, t, _) =>
                                          Transform.translate(
                                            offset: Offset(0, 3 * (1 - t)),
                                            child: BeuiChartFade(
                                              opacity: t,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                curve: Curves.easeOut,
                                                height: barHeight,
                                                decoration: BoxDecoration(
                                                  color: beuiChartColor(
                                                    statusMap[data[i].status]!
                                                        .color,
                                                    colors,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                  border:
                                                      data[i].id ==
                                                          state.activeId
                                                      ? Border.all(
                                                          color:
                                                              colors.foreground,
                                                          width: 1.5,
                                                        )
                                                      : null,
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
    if (!state._tooltipOpen) return const SizedBox.shrink();
    final datum = state.widget.data
        .where((item) => item.id == state.activeId)
        .firstOrNull;
    if (datum == null) return const SizedBox.shrink();
    final status = state.widget.statuses.firstWhere(
      (item) => item.id == datum.status,
    );
    return BeuiChartTooltipCard(
      title: datum.label,
      lines: [
        status.label,
        if (datum.duration != null)
          'Duration: ${datum.duration!.inMinutes} minutes',
        if (datum.description != null) datum.description!,
      ],
      swatch: beuiChartColor(status.color, BeuiColors.resolve(context)),
    );
  }
}
