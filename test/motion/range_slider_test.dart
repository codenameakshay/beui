import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _thumb = ValueKey<String>('beui_range_slider_thumb');
const _startThumb = ValueKey<String>('beui_range_slider_thumb_start');
const _endThumb = ValueKey<String>('beui_range_slider_thumb_end');

// ---------------------------------------------------------------------------
// Single-thumb host — drives a controlled [BeuiRangeSlider] like a real app:
// holds the value and feeds each onChanged back so the thumb tracks it.
// ---------------------------------------------------------------------------
class _SingleHost extends StatefulWidget {
  const _SingleHost({required this.initial, this.observe, this.reduce = false});

  final double initial;
  final ValueChanged<double>? observe;
  final bool reduce;

  @override
  State<_SingleHost> createState() => _SingleHostState();
}

class _SingleHostState extends State<_SingleHost> {
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    Widget child = Center(
      child: SizedBox(
        width: 200, // 200px wide track → easy fractions
        child: BeuiRangeSlider(
          value: _value,
          min: 0,
          max: 100,
          step: 5,
          onChanged: (v) {
            setState(() => _value = v);
            widget.observe?.call(v);
          },
        ),
      ),
    );
    if (widget.reduce) {
      final inner = child;
      child = Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: inner,
        ),
      );
    }
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(body: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Dual host — same pattern for the two-thumb [BeuiRangeSliderDual].
// ---------------------------------------------------------------------------
class _DualHost extends StatefulWidget {
  const _DualHost({required this.initial, this.observe, this.reduce = false});

  final RangeValues initial;
  final ValueChanged<RangeValues>? observe;
  final bool reduce;

  @override
  State<_DualHost> createState() => _DualHostState();
}

class _DualHostState extends State<_DualHost> {
  late RangeValues _values = widget.initial;

  @override
  Widget build(BuildContext context) {
    Widget child = Center(
      child: SizedBox(
        width: 200,
        child: BeuiRangeSliderDual(
          values: _values,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (v) {
            setState(() => _values = v);
            widget.observe?.call(v);
          },
        ),
      ),
    );
    if (widget.reduce) {
      final inner = child;
      child = Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: inner,
        ),
      );
    }
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(body: child),
    );
  }
}

double _thumbX(WidgetTester t) => t.getCenter(find.byKey(_thumb)).dx;
double _startX(WidgetTester t) => t.getCenter(find.byKey(_startThumb)).dx;
double _endX(WidgetTester t) => t.getCenter(find.byKey(_endThumb)).dx;

void main() {
  // =========================================================================
  // Single-thumb (the faithful source port)
  // =========================================================================
  group('BeuiRangeSlider (single thumb)', () {
    testWidgets('dragging the thumb changes its value', (tester) async {
      double? changed;
      await tester.pumpWidget(
        _SingleHost(initial: 20, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed, greaterThan(20));
    });

    testWidgets('value snaps to a step boundary', (tester) async {
      double? changed;
      await tester.pumpWidget(
        _SingleHost(initial: 20, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(13, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed! % 5, 0, reason: 'snapped to a step of 5');
    });

    testWidgets('the handle follows the finger exactly while dragging', (
      tester,
    ) async {
      await tester.pumpWidget(const _SingleHost(initial: 10));
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.byKey(_thumb));
      final g = await tester.startGesture(start);
      await g.moveBy(const Offset(50, 0));
      await g.moveBy(const Offset(50, 0)); // pointer now +100px from start
      await tester.pump(const Duration(milliseconds: 16)); // one frame
      // A glide (≈60ms time constant) would still be far behind after one frame.

      // The handle is AT the pointer (+100), not lagging at a glided position.
      final fingerX = start.dx + 100;
      expect(
        (_thumbX(tester) - fingerX).abs(),
        lessThan(8),
        reason: 'handle tracks the pointer directly, no glide lag',
      );

      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('arrow keys move the thumb by one step', (tester) async {
      double? changed;
      await tester.pumpWidget(
        _SingleHost(initial: 20, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      // Focus the slider via a small drag (also requests focus).
      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(2, 0));
      await tester.pumpAndSettle();

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changed, 25, reason: '20 + one 5-step');

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changed, 20, reason: 'back down one step');
    });

    testWidgets('Home/End jump to min/max', (tester) async {
      double? changed;
      await tester.pumpWidget(
        _SingleHost(initial: 40, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(2, 0));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changed, 100);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changed, 0);
    });

    testWidgets('reduced motion still updates values, snaps instantly', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        _SingleHost(initial: 20, reduce: true, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      final beforeX = _thumbX(tester);

      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 1));
      final immediateX = _thumbX(tester);
      await tester.pumpAndSettle();
      final settledX = _thumbX(tester);

      expect(changed, isNotNull);
      expect(changed, greaterThan(20));
      // Movement happened, and it was instant (no glide).
      expect(beforeX, lessThan(settledX));
      expect(immediateX, closeTo(settledX, 0.5));
    });

    testWidgets('thumb POSITION glides without overshoot under normal motion', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        _SingleHost(initial: 10, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      final beforeX = _thumbX(tester);

      // Jump well to the right, release, and sample the whole settle.
      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(70, 0));
      await tester.pump(const Duration(milliseconds: 1));

      var maxX = double.negativeInfinity;
      for (var i = 0; i < 60; i++) {
        maxX = maxX > _thumbX(tester) ? maxX : _thumbX(tester);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      final settledX = _thumbX(tester);

      expect(changed, greaterThan(10));
      expect(settledX, greaterThan(beforeX));
      // GLIDE = critically damped: the position never overshoots past where it
      // finally settles (no rebound past the target). A tiny float epsilon
      // covers rounding only.
      expect(
        maxX,
        lessThanOrEqualTo(settledX + 0.5),
        reason: 'glide must not overshoot the target position',
      );
    });
  });

  // =========================================================================
  // Dual (Flutter-only two-thumb extension)
  // =========================================================================
  group('BeuiRangeSliderDual (two thumbs)', () {
    testWidgets('dragging the start thumb changes its value', (tester) async {
      RangeValues? changed;
      await tester.pumpWidget(
        _DualHost(
          initial: const RangeValues(20, 80),
          observe: (v) => changed = v,
        ),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_startThumb));
      await tester.dragFrom(from, const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed!.start, greaterThan(20));
      expect(changed!.start, lessThan(80));
      expect(changed!.end, 80);
    });

    testWidgets('thumbs cannot cross', (tester) async {
      RangeValues? changed;
      await tester.pumpWidget(
        _DualHost(
          initial: const RangeValues(20, 40),
          observe: (v) => changed = v,
        ),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_startThumb));
      await tester.dragFrom(from, const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed!.start, lessThanOrEqualTo(changed!.end));
      expect(changed!.end, 40);
    });

    testWidgets('arrow keys move the focused thumb by one step', (
      tester,
    ) async {
      RangeValues? changed;
      await tester.pumpWidget(
        _DualHost(
          initial: const RangeValues(20, 60),
          observe: (v) => changed = v,
        ),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_startThumb));
      await tester.dragFrom(from, const Offset(2, 0));
      await tester.pumpAndSettle();

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changed!.start, 25, reason: '20 + one 5-step');
    });

    testWidgets('end thumb stays put when the start thumb moves', (
      tester,
    ) async {
      await tester.pumpWidget(const _DualHost(initial: RangeValues(20, 60)));
      await tester.pumpAndSettle();
      final endBefore = _endX(tester);

      final from = tester.getCenter(find.byKey(_startThumb));
      await tester.dragFrom(from, const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(_endX(tester), closeTo(endBefore, 0.5));
    });

    testWidgets('reduced motion still updates band values', (tester) async {
      RangeValues? changed;
      await tester.pumpWidget(
        _DualHost(
          initial: const RangeValues(20, 80),
          reduce: true,
          observe: (v) => changed = v,
        ),
      );
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_startThumb));
      await tester.dragFrom(from, const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed!.start, greaterThan(20));
    });

    testWidgets('start thumb POSITION glides without overshoot', (
      tester,
    ) async {
      await tester.pumpWidget(const _DualHost(initial: RangeValues(10, 90)));
      await tester.pumpAndSettle();
      final beforeX = _startX(tester);

      final from = tester.getCenter(find.byKey(_startThumb));
      await tester.dragFrom(from, const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 1));

      var maxX = double.negativeInfinity;
      for (var i = 0; i < 60; i++) {
        maxX = maxX > _startX(tester) ? maxX : _startX(tester);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      final settledX = _startX(tester);

      expect(settledX, greaterThan(beforeX));
      expect(
        maxX,
        lessThanOrEqualTo(settledX + 0.5),
        reason: 'glide must not overshoot the target position',
      );
    });
  });
}
