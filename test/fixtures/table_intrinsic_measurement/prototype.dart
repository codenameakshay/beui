import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../table_intrinsic_layout/resolver.dart';

/// A passive copy of a sampled cell, or an explicit outer-width contract.
/// Never pass a live editor or reuse a GlobalKey from the visible cell.
class CellSample {
  const CellSample(this.column, this.widget) : widths = null;
  const CellSample.explicit(this.column, this.widths) : widget = null;
  final String column;
  final Widget? widget;
  final ({double minimum, double maximum})? widths;
}

class MeasurementResult {
  MeasurementResult(this.columns, this.viewport, this.error);
  final List<IntrinsicColumn> columns;
  final double viewport;
  final String? error;
  bool get supported => error == null;
}

class MeasurementTrace {
  int layouts = 0;
  int intrinsicQueries = 0;
  int mountedSamples = 0;
  final List<String> events = [];
}

// Exact types deliberately exclude custom subclasses and opaque builders. This
// is a small test contract, not a general widget-tree safety inspector.
String? _reject(Widget widget) {
  if (widget.key is GlobalKey) return 'GlobalKey cannot be duplicated';
  final type = widget.runtimeType;
  if (type == Text) {
    final text = widget as Text;
    if (text.textSpan != null) return 'Rich spans require an explicit contract';
    return null;
  }
  if (type == Padding || type == SizedBox || type == DecoratedBox) {
    final child = (widget as SingleChildRenderObjectWidget).child;
    return child == null ? null : _reject(child);
  }
  if (type == Expanded || type == Flexible) {
    return _reject((widget as Flexible).child);
  }
  if (type == Row || type == Column || type == Flex) {
    for (final child in (widget as Flex).children) {
      final error = _reject(child);
      if (error != null) return error;
    }
    return null;
  }
  return '$type has no passive intrinsic contract; provide explicit widths';
}

class IntrinsicMeasurement extends StatelessWidget {
  const IntrinsicMeasurement({
    super.key,
    required this.columns,
    required this.samples,
    required this.builder,
    required this.trace,
    this.sampleLimit = 96,
    this.revision,
  });
  final List<String> columns;
  final List<CellSample> samples;
  final int sampleLimit;

  /// Change for external font loads or other caller-owned metric changes.
  final Object? revision;
  final MeasurementTrace trace;
  final Widget Function(BuildContext, MeasurementResult) builder;

  @override
  Widget build(BuildContext context) {
    // Track environmental changes even when the caller reuses sample widgets.
    MediaQuery.maybeOf(context);
    DefaultTextStyle.of(context);
    Directionality.of(context);
    String? error;
    if (columns.isEmpty || columns.toSet().length != columns.length) {
      error = 'Require nonempty unique columns';
    } else if (sampleLimit < 1 || samples.length > sampleLimit) {
      error = 'Sample budget exceeded: ${samples.length}/$sampleLimit';
    } else {
      for (final sample in samples) {
        if (!columns.contains(sample.column)) {
          error = 'Unknown column ${sample.column}';
          break;
        }
        if (sample.widget != null) error = _reject(sample.widget!);
        if (sample.widget == null && sample.widths == null) {
          error = 'Missing explicit widths';
        }
        if (error != null) break;
      }
    }
    final holder = _Holder();
    final accepted = error == null ? samples : <CellSample>[];
    trace.mountedSamples = accepted.where((s) => s.widget != null).length;
    return _Measure(
      columns: columns,
      samples: accepted,
      error: error,
      holder: holder,
      trace: trace,
      children: [
        for (final sample in accepted)
          if (sample.widget != null) ExcludeFocus(child: sample.widget!),
        _ContentBuilder(
          holder: holder,
          builder: (context, info) {
            trace.events.add('build-content');
            return builder(context, info.$2);
          },
        ),
      ],
    );
  }
}

class _Holder {
  late MeasurementResult result;
}

class _Measure extends MultiChildRenderObjectWidget {
  const _Measure({
    required this.columns,
    required this.samples,
    required this.error,
    required this.holder,
    required this.trace,
    required super.children,
  });
  final List<String> columns;
  final List<CellSample> samples;
  final String? error;
  final _Holder holder;
  final MeasurementTrace trace;
  @override
  _RenderMeasure createRenderObject(BuildContext context) =>
      _RenderMeasure(this);
  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _SampleParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMeasure extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderMeasure(this.config);
  _Measure config;
  @override
  void setupParentData(RenderBox child) {
    child.parentData = _SampleParentData();
  }

  @override
  void performLayout() {
    final trace = config.trace;
    trace.layouts++;
    trace.events.add('measure');
    String? error = config.error;
    if (!constraints.hasBoundedWidth) error = 'A bounded viewport is required';
    final widths = <String, ({double minimum, double maximum})>{};
    RenderBox? probe = firstChild;
    for (final sample in config.samples) {
      var pair = sample.widths;
      if (sample.widget != null) {
        trace.intrinsicQueries += 2;
        pair = (
          minimum: probe!.getMinIntrinsicWidth(double.infinity),
          maximum: probe.getMaxIntrinsicWidth(double.infinity),
        );
        // Clear layout dirtiness so subsequent text/font changes propagate.
        probe.layout(
          BoxConstraints(
            maxWidth: pair.maximum.isFinite ? math.max(0, pair.maximum) : 0,
          ),
          parentUsesSize: true,
        );
        probe = childAfter(probe);
      }
      if (pair == null ||
          !pair.minimum.isFinite ||
          !pair.maximum.isFinite ||
          pair.minimum < 0 ||
          pair.maximum < pair.minimum) {
        error = 'Invalid intrinsic widths for ${sample.column}';
        continue;
      }
      final old = widths[sample.column];
      widths[sample.column] = (
        minimum: math.max(old?.minimum ?? 0, pair.minimum),
        maximum: math.max(old?.maximum ?? 0, pair.maximum),
      );
    }
    for (final column in config.columns) {
      if (!widths.containsKey(column)) error ??= 'No sample for $column';
    }
    // Resolver accepts 1/64 px. Round outward so text is never undermeasured.
    double quantize(double value) => (value * 64).ceil() / 64;
    config.holder.result = MeasurementResult(
      List.unmodifiable([
        if (error == null)
          for (final column in config.columns)
            IntrinsicColumn(
              key: column,
              minimum: quantize(widths[column]!.minimum),
              maximum: quantize(widths[column]!.maximum),
            ),
      ]),
      constraints.maxWidth,
      error,
    );
    final content = lastChild!;
    // A stock LayoutBuilder skips its callback at identical constraints. Our
    // layout-info includes the new result identity, including font-only changes.
    invokeLayoutCallback<BoxConstraints>((_) => content.markNeedsLayout());
    trace.events.add('layout-content');
    content.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(content.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(lastChild!, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      lastChild!.hitTest(result, position: position);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(lastChild!);
}

typedef _Info = (BoxConstraints, MeasurementResult);

class _ContentBuilder extends AbstractLayoutBuilder<_Info> {
  const _ContentBuilder({required this.holder, required this.builder});
  final _Holder holder;
  @override
  final Widget Function(BuildContext, _Info) builder;
  @override
  _RenderContent createRenderObject(BuildContext context) =>
      _RenderContent(holder);
  @override
  void updateRenderObject(BuildContext context, _RenderContent renderObject) {
    renderObject.holder = holder;
  }
}

class _RenderContent extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<_Info, RenderBox> {
  _RenderContent(this.holder);
  _Holder holder;
  @override
  _Info get layoutInfo => (constraints, holder.result);
  @override
  void performLayout() {
    runLayoutCallback();
    child!.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child!.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(child!, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child!.hitTest(result, position: position);
}
