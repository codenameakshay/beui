import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'intrinsic_layout.dart';

/// A passive copy of a sampled cell, or an explicit outer-width contract.
/// Never pass a live editor or reuse a GlobalKey from the visible cell.
class BeuiTableIntrinsicSample {
  const BeuiTableIntrinsicSample(this.column, this.widget) : widths = null;
  const BeuiTableIntrinsicSample.explicit(this.column, this.widths)
    : widget = null;
  const BeuiTableIntrinsicSample.selection(Widget content)
    : column = '#checkbox',
      widget = content,
      widths = null;
  const BeuiTableIntrinsicSample.selectionWidths(double minimum, double maximum)
    : column = '#checkbox',
      widget = null,
      widths = (minimum: minimum, maximum: maximum);
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

// Exact types deliberately exclude custom subclasses and opaque builders. This
// is a narrow measurement contract, not a general widget-tree safety inspector.
// Probes have bounded width and unbounded height. Flex parent data is valid
// only directly inside a horizontal Flex; vertical flex needs a height contract.
const _maximumWidth = 33554431.0;

bool _validWidth(double value) =>
    value.isFinite && value >= 0 && value <= _maximumWidth;

String? _reject(
  Widget widget, {
  bool horizontalFlexChild = false,
  bool boundedWidth = true,
}) {
  if (widget.key is GlobalKey) return 'GlobalKey cannot be duplicated';
  final type = widget.runtimeType;
  if (type == Text) {
    final text = widget as Text;
    if (text.textSpan != null) return 'Rich spans require an explicit contract';
    return null;
  }
  if (type == SizedBox) {
    final box = widget as SizedBox;
    if ((box.width != null && !_validWidth(box.width!)) ||
        (box.height != null && !_validWidth(box.height!))) {
      return 'SizedBox needs finite representable dimensions; provide explicit widths';
    }
  }
  if (type == Padding || type == SizedBox || type == DecoratedBox) {
    final child = (widget as SingleChildRenderObjectWidget).child;
    return child == null
        ? null
        : _reject(
            child,
            boundedWidth: type == SizedBox && (widget as SizedBox).width != null
                ? true
                : boundedWidth,
          );
  }
  if (type == Expanded || type == Flexible) {
    if (!horizontalFlexChild || !boundedWidth) {
      return 'Flexible requires a direct horizontal Flex parent; provide explicit widths';
    }
    return _reject((widget as Flexible).child, boundedWidth: boundedWidth);
  }
  if (type == Row || type == Column || type == Flex) {
    final flex = widget as Flex;
    if (flex.direction == Axis.horizontal &&
        flex.crossAxisAlignment == CrossAxisAlignment.stretch) {
      return 'Horizontal stretch requires bounded height; provide explicit widths';
    }
    for (final child in flex.children) {
      final error = _reject(
        child,
        horizontalFlexChild: flex.direction == Axis.horizontal,
        boundedWidth: flex.direction == Axis.horizontal
            ? child is Flexible && boundedWidth
            : boundedWidth,
      );
      if (error != null) return error;
    }
    return null;
  }
  return '$type has no passive intrinsic contract; provide explicit widths';
}

class IntrinsicMeasurement extends StatefulWidget {
  const IntrinsicMeasurement({
    super.key,
    required this.columns,
    required this.samples,
    required this.builder,

    this.sampleLimit = 256,
    this.revision,
  });
  final List<String> columns;
  final List<BeuiTableIntrinsicSample> samples;
  final int sampleLimit;

  /// Change for external font loads or other caller-owned metric changes.
  final Object? revision;

  final Widget Function(BuildContext, MeasurementResult) builder;

  @override
  State<IntrinsicMeasurement> createState() => _IntrinsicMeasurementState();
}

class _IntrinsicMeasurementState extends State<IntrinsicMeasurement> {
  int _fontRevision = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _fontsChanged() => setState(() => _fontRevision++);

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    final samples = widget.samples;
    final sampleLimit = widget.sampleLimit;
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
    final accepted = error == null ? samples : <BeuiTableIntrinsicSample>[];
    return _Measure(
      columns: columns,
      samples: accepted,
      error: error,
      holder: holder,
      children: [
        for (var i = 0; i < accepted.length; i++)
          if (accepted[i].widget != null)
            // RenderParagraph retains a separate intrinsic TextPainter cache
            // across font loads. Recreate passive probes, keeping real content.
            KeyedSubtree(
              key: ValueKey((widget.revision, _fontRevision, i)),
              child: SelectionContainer.disabled(
                child: ExcludeFocus(child: accepted[i].widget!),
              ),
            ),
        _ContentBuilder(
          holder: holder,
          builder: (context, info) {
            return widget.builder(context, info.$2);
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

    required super.children,
  });
  final List<String> columns;
  final List<BeuiTableIntrinsicSample> samples;
  final String? error;
  final _Holder holder;

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
    String? error = config.error;
    if (!constraints.hasBoundedWidth) error = 'A bounded viewport is required';
    if (constraints.hasBoundedWidth && !_validWidth(constraints.maxWidth)) {
      error = 'Viewport exceeds representable measurement range';
    }
    final widths = <String, ({double minimum, double maximum})>{};
    RenderBox? probe = firstChild;
    for (final sample in config.samples) {
      var pair = sample.widths;
      if (sample.widget != null) {
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
          !_validWidth(pair.minimum) ||
          !_validWidth(pair.maximum) ||
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
      _validWidth(constraints.maxWidth)
          ? (constraints.maxWidth * 64).floor() / 64
          : 0,
      error,
    );
    final content = lastChild!;
    // A stock LayoutBuilder skips its callback at identical constraints. Our
    // layout-info includes the new result identity, including font-only changes.
    invokeLayoutCallback<BoxConstraints>((_) => content.markNeedsLayout());
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
