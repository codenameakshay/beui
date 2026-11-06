import 'dart:ui' as ui;

import 'package:beui/src/layout/measure_size.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reports the first and each changed local size after layout', (
    tester,
  ) async {
    final sizes = <Size>[];
    final phases = <SchedulerPhase>[];
    final sizeKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: BeuiMeasureSize(
            onChanged: (size) {
              sizes.add(size);
              phases.add(tester.binding.schedulerPhase);
            },
            child: SizedBox(key: sizeKey, width: 30, height: 20),
          ),
        ),
      ),
    );

    expect(sizes, const <Size>[Size(30, 20)]);
    expect(phases, const <SchedulerPhase>[SchedulerPhase.postFrameCallbacks]);

    final child = tester.renderObject<RenderConstrainedBox>(
      find.byKey(sizeKey),
    );
    child.additionalConstraints = BoxConstraints.tight(const Size(30, 20));
    tester.binding.rootPipelineOwner.flushLayout();
    await tester.pump();
    expect(sizes, const <Size>[Size(30, 20)]);

    child.additionalConstraints = BoxConstraints.tight(const Size(50, 35));
    tester.binding.rootPipelineOwner.flushLayout();
    await tester.pump();
    expect(sizes, const <Size>[Size(30, 20), Size(50, 35)]);
  });

  testWidgets('observes child-only relayout without rebuilding its parent', (
    tester,
  ) async {
    final sizes = <Size>[];
    var parentBuilds = 0;
    final requestedSize = ValueNotifier<Size>(const Size(20, 12));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: _BuildCounter(
            onBuild: () => parentBuilds++,
            child: BeuiMeasureSize(
              onChanged: sizes.add,
              child: ValueListenableBuilder<Size>(
                valueListenable: requestedSize,
                builder: (context, size, child) =>
                    SizedBox(width: size.width, height: size.height),
              ),
            ),
          ),
        ),
      ),
    );
    expect(sizes, const <Size>[Size(20, 12)]);
    final buildsBeforeChildChange = parentBuilds;

    requestedSize.value = const Size(44, 28);
    await tester.pump();

    expect(parentBuilds, buildsBeforeChildChange);
    expect(sizes, const <Size>[Size(20, 12), Size(44, 28)]);
    requestedSize.dispose();
  });

  testWidgets('coalesces layouts to the latest size and cancels a changeback', (
    tester,
  ) async {
    final sizes = <Size>[];
    final childKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: BeuiMeasureSize(
            onChanged: sizes.add,
            child: SizedBox(key: childKey, width: 10, height: 8),
          ),
        ),
      ),
    );
    expect(sizes, const <Size>[Size(10, 8)]);

    final child = tester.renderObject<RenderConstrainedBox>(
      find.byKey(childKey),
    );
    child.additionalConstraints = BoxConstraints.tight(const Size(20, 16));
    tester.binding.rootPipelineOwner.flushLayout();
    expect(sizes, const <Size>[Size(10, 8)]);
    child.additionalConstraints = BoxConstraints.tight(const Size(35, 24));
    tester.binding.rootPipelineOwner.flushLayout();
    await tester.pump();
    expect(sizes, const <Size>[Size(10, 8), Size(35, 24)]);

    child.additionalConstraints = BoxConstraints.tight(const Size(48, 30));
    tester.binding.rootPipelineOwner.flushLayout();
    child.additionalConstraints = BoxConstraints.tight(const Size(35, 24));
    tester.binding.rootPipelineOwner.flushLayout();
    await tester.pump();
    expect(sizes, const <Size>[Size(10, 8), Size(35, 24)]);

    child.additionalConstraints = BoxConstraints.tight(const Size(48, 30));
    tester.binding.rootPipelineOwner.flushLayout();
    child.additionalConstraints = BoxConstraints.tight(const Size(35, 24));
    tester.binding.rootPipelineOwner.flushLayout();
    child.additionalConstraints = BoxConstraints.tight(const Size(22, 17));
    tester.binding.rootPipelineOwner.flushLayout();
    expect(sizes, const <Size>[Size(10, 8), Size(35, 24)]);
    await tester.pump();
    expect(sizes, const <Size>[Size(10, 8), Size(35, 24), Size(22, 17)]);
  });

  testWidgets('uses a replacement callback for pending delivery only', (
    tester,
  ) async {
    final oldCalls = <Size>[];
    final newCalls = <Size>[];
    final childKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: BeuiMeasureSize(
            onChanged: oldCalls.add,
            child: SizedBox(key: childKey, width: 16, height: 9),
          ),
        ),
      ),
    );
    expect(oldCalls, const <Size>[Size(16, 9)]);

    final child = tester.renderObject<RenderConstrainedBox>(
      find.byKey(childKey),
    );
    child.additionalConstraints = BoxConstraints.tight(const Size(25, 14));
    tester.binding.rootPipelineOwner.flushLayout();
    expect(oldCalls, const <Size>[Size(16, 9)]);
    expect(newCalls, isEmpty);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: BeuiMeasureSize(
            onChanged: newCalls.add,
            child: SizedBox(key: childKey, width: 25, height: 14),
          ),
        ),
      ),
    );

    expect(oldCalls, const <Size>[Size(16, 9)]);
    expect(newCalls, const <Size>[Size(25, 14)]);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: BeuiMeasureSize(
            onChanged: oldCalls.add,
            child: const SizedBox(width: 25, height: 14),
          ),
        ),
      ),
    );
    expect(newCalls, const <Size>[Size(25, 14)]);
    expect(oldCalls, const <Size>[Size(16, 9)]);
  });

  testWidgets('a size callback can set state for the following frame', (
    tester,
  ) async {
    final sizes = <Size>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(child: _ResizeOnFirstMeasurement(sizes: sizes)),
      ),
    );

    expect(sizes, const <Size>[Size(18, 11)]);
    await tester.pump();
    expect(sizes, const <Size>[Size(18, 11), Size(32, 19)]);
  });

  testWidgets('reattachment observes size without replaying unchanged size', (
    tester,
  ) async {
    final sizes = <Size>[];
    final hostKey = GlobalKey<_ReparentingHostState>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _ReparentingHost(key: hostKey, sizes: sizes),
      ),
    );
    expect(sizes, const <Size>[Size(24, 16)]);

    hostKey.currentState!.moveObserver();
    await tester.pump();
    expect(sizes, const <Size>[Size(24, 16)]);

    final observer = tester.renderObject(find.byType(BeuiMeasureSize));
    hostKey.currentState!.moveObserver(size: const Size(41, 27));
    await tester.pump();
    expect(tester.renderObject(find.byType(BeuiMeasureSize)), same(observer));
    expect(sizes, const <Size>[Size(24, 16), Size(41, 27)]);
  });

  testWidgets('detach cancels a first delivery and isolates a new generation', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    );

    final sizes = <Size>[];
    final observer =
        BeuiMeasureSize(
              onChanged: sizes.add,
              child: const SizedBox(),
            ).createRenderObject(context)
            as RenderProxyBox;
    observer.child = RenderConstrainedBox(
      additionalConstraints: BoxConstraints.tight(const Size(19, 13)),
    );
    final owner = PipelineOwner();
    observer.attach(owner);
    observer.layout(BoxConstraints.loose(const Size(100, 100)));
    expect(sizes, isEmpty);
    observer.detach();
    (observer.child! as RenderConstrainedBox).additionalConstraints =
        BoxConstraints.tight(const Size(31, 23));
    observer.attach(owner);
    observer.layout(BoxConstraints.loose(const Size(100, 100)));
    expect(sizes, isEmpty);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(sizes, const <Size>[Size(31, 23)]);

    observer.detach();
    observer.dispose();
    owner.dispose();
  });

  testWidgets('does not deliver pending work after disposal', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    );

    final sizes = <Size>[];
    final observer =
        BeuiMeasureSize(
              onChanged: sizes.add,
              child: const SizedBox(),
            ).createRenderObject(context)
            as RenderProxyBox;
    observer.child = RenderConstrainedBox(
      additionalConstraints: BoxConstraints.tight(const Size(21, 15)),
    );
    final owner = PipelineOwner();
    observer.attach(owner);
    observer.layout(BoxConstraints.loose(const Size(100, 100)));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(sizes, const <Size>[Size(21, 15)]);
    (observer.child! as RenderConstrainedBox).additionalConstraints =
        BoxConstraints.tight(const Size(32, 26));
    observer.layout(BoxConstraints.loose(const Size(100, 100)));
    observer.detach();
    observer.dispose();
    owner.dispose();

    tester.binding.scheduleFrame();
    await tester.pump();
    expect(sizes, const <Size>[Size(21, 15)]);
  });

  testWidgets('reports constrained local size, not transformed screen bounds', (
    tester,
  ) async {
    final sizes = <Size>[];

    Widget fixture({required double offset, required double scale}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(offset, offset),
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 25,
                  height: 15,
                  child: BeuiMeasureSize(
                    onChanged: sizes.add,
                    child: const SizedBox(width: 80, height: 60),
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(fixture(offset: 0, scale: 1));
    expect(sizes, const <Size>[Size(25, 15)]);
    await tester.pumpWidget(fixture(offset: 100, scale: 2));
    expect(sizes, const <Size>[Size(25, 15)]);
    expect(tester.getSize(find.byType(BeuiMeasureSize)), const Size(25, 15));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(sizes, const <Size>[Size(25, 15)]);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'forwards layout, intrinsic, baseline, paint, hit, and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final outcomes = <_RenderOutcome>[];
      final paintCounts = <int>[];
      final pixels = <List<int>>[];
      var taps = 0;

      Future<void> pumpChild({required bool wrapped}) async {
        var paints = 0;
        double? baseline;
        final content = _comparisonChild(
          onPaint: () => paints++,
          onTap: () => taps++,
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: const ValueKey('raster'),
                child: _BaselineProbe(
                  onBaseline: (value) => baseline = value,
                  child: wrapped
                      ? BeuiMeasureSize(onChanged: (_) {}, child: content)
                      : content,
                ),
              ),
            ),
          ),
        );

        final probe = wrapped
            ? tester.renderObject<RenderBox>(find.byType(BeuiMeasureSize))
            : tester.renderObject<RenderBox>(find.byKey(const ValueKey('tap')));
        final child = wrapped ? (probe as RenderProxyBox).child! : probe;
        final constraints = const BoxConstraints(maxWidth: 100, maxHeight: 60);
        outcomes.add(
          _RenderOutcome(
            size: probe.size,
            constraints: probe.constraints,
            childConstraints: child.constraints,
            drySize: probe.getDryLayout(constraints),
            minWidth: probe.getMinIntrinsicWidth(60),
            maxWidth: probe.getMaxIntrinsicWidth(60),
            minHeight: probe.getMinIntrinsicHeight(100),
            maxHeight: probe.getMaxIntrinsicHeight(100),
            baseline: baseline,
            childSize: child.size,
          ),
        );
        expect(probe.getDryBaseline(constraints, TextBaseline.alphabetic), 18);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('raster')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            expect(image.width, 40);
            expect(image.height, 28);
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            pixels.add(data!.buffer.asUint8List().toList());
          } finally {
            image.dispose();
          }
        });
        paintCounts.add(paints);
        await tester.tap(find.byKey(const ValueKey('tap')));
        await tester.pump();
        expect(find.bySemanticsLabel('measurement child'), findsOneWidget);
        final node = tester.getSemantics(
          find.bySemanticsLabel('measurement child'),
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        probe.owner!.semanticsOwner!.performAction(
          node.id,
          ui.SemanticsAction.tap,
        );
        await tester.pump();
      }

      try {
        await pumpChild(wrapped: false);
        await pumpChild(wrapped: true);
        const expected = _RenderOutcome(
          size: Size(40, 28),
          constraints: BoxConstraints(maxWidth: 800, maxHeight: 600),
          childConstraints: BoxConstraints(maxWidth: 800, maxHeight: 600),
          drySize: Size(40, 28),
          minWidth: 40,
          maxWidth: 40,
          minHeight: 28,
          maxHeight: 28,
          baseline: 18,
          childSize: Size(40, 28),
        );
        expect(outcomes, const <_RenderOutcome>[expected, expected]);
        expect(
          pixels[0],
          List<int>.generate(
            40 * 28 * 4,
            (index) => const [0x12, 0x34, 0x56, 0xff][index % 4],
          ),
        );
        expect(pixels[1], pixels[0]);
        expect(paintCounts, const <int>[1, 1]);
        expect(taps, 4);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return widget.child;
  }
}

class _ResizeOnFirstMeasurement extends StatefulWidget {
  const _ResizeOnFirstMeasurement({required this.sizes});

  final List<Size> sizes;

  @override
  State<_ResizeOnFirstMeasurement> createState() =>
      _ResizeOnFirstMeasurementState();
}

class _ResizeOnFirstMeasurementState extends State<_ResizeOnFirstMeasurement> {
  Size _size = const Size(18, 11);

  @override
  Widget build(BuildContext context) => BeuiMeasureSize(
    onChanged: (size) {
      widget.sizes.add(size);
      if (size == const Size(18, 11)) {
        setState(() => _size = const Size(32, 19));
      }
    },
    child: SizedBox(width: _size.width, height: _size.height),
  );
}

class _ReparentingHost extends StatefulWidget {
  const _ReparentingHost({super.key, required this.sizes});

  final List<Size> sizes;

  @override
  State<_ReparentingHost> createState() => _ReparentingHostState();
}

class _ReparentingHostState extends State<_ReparentingHost> {
  final _observerKey = GlobalKey();
  bool _moved = false;
  Size _size = const Size(24, 16);

  void moveObserver({Size? size}) => setState(() {
    _moved = !_moved;
    if (size != null) _size = size;
  });

  Widget _observer() => BeuiMeasureSize(
    key: _observerKey,
    onChanged: widget.sizes.add,
    child: SizedBox(width: _size.width, height: _size.height),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      if (!_moved) Align(alignment: Alignment.topLeft, child: _observer()),
      if (_moved) Align(alignment: Alignment.bottomRight, child: _observer()),
    ],
  );
}

Widget _comparisonChild({
  required VoidCallback onPaint,
  required VoidCallback onTap,
}) => GestureDetector(
  key: const ValueKey('tap'),
  onTap: onTap,
  child: Semantics(
    label: 'measurement child',
    child: CustomPaint(
      key: const ValueKey('child'),
      painter: _CountingPainter(onPaint),
      child: const _FixedBaselineBox(),
    ),
  ),
);

class _BaselineProbe extends SingleChildRenderObjectWidget {
  const _BaselineProbe({required this.onBaseline, required super.child});

  final ValueChanged<double?> onBaseline;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBaselineProbe(onBaseline);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBaselineProbe renderObject,
  ) {
    renderObject.onBaseline = onBaseline;
  }
}

class _RenderBaselineProbe extends RenderProxyBox {
  _RenderBaselineProbe(this.onBaseline);

  ValueChanged<double?> onBaseline;

  @override
  void performLayout() {
    super.performLayout();
    onBaseline(child!.getDistanceToBaseline(TextBaseline.alphabetic));
  }
}

class _FixedBaselineBox extends LeafRenderObjectWidget {
  const _FixedBaselineBox();

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFixedBaselineBox();
}

class _RenderFixedBaselineBox extends RenderBox {
  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(const Size(40, 28));

  @override
  double computeMinIntrinsicWidth(double height) => 40;

  @override
  double computeMaxIntrinsicWidth(double height) => 40;

  @override
  double computeMinIntrinsicHeight(double width) => 28;

  @override
  double computeMaxIntrinsicHeight(double width) => 28;

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => 18;

  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => 18;
}

class _CountingPainter extends CustomPainter {
  const _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff123456),
    );
  }

  @override
  bool shouldRepaint(covariant _CountingPainter oldDelegate) => false;
}

class _RenderOutcome {
  const _RenderOutcome({
    required this.size,
    required this.constraints,
    required this.childConstraints,
    required this.drySize,
    required this.minWidth,
    required this.maxWidth,
    required this.minHeight,
    required this.maxHeight,
    required this.baseline,
    required this.childSize,
  });

  final Size size;
  final BoxConstraints constraints;
  final BoxConstraints childConstraints;
  final Size drySize;
  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
  final double? baseline;
  final Size childSize;

  @override
  bool operator ==(Object other) =>
      other is _RenderOutcome &&
      other.size == size &&
      other.constraints == constraints &&
      other.childConstraints == childConstraints &&
      other.drySize == drySize &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.minHeight == minHeight &&
      other.maxHeight == maxHeight &&
      other.baseline == baseline &&
      other.childSize == childSize;

  @override
  int get hashCode => Object.hash(
    size,
    constraints,
    childConstraints,
    drySize,
    minWidth,
    maxWidth,
    minHeight,
    maxHeight,
    baseline,
    childSize,
  );
}
