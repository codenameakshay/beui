import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The components' own `@visibleForTesting` keys, mirrored here — they are
// deliberately not part of the barrel's public surface.
const _thumb = ValueKey<String>('beui_range_slider_thumb');
const _ticks = ValueKey<String>('beui_range_slider_ticks');
const _fluidTrack = ValueKey<String>('beui_fluid_slider_track');
const _fluidFill = ValueKey<String>('beui_fluid_slider_fill');
const _waveTrack = ValueKey<String>('beui_wave_slider_track');
ValueKey<String> _waveBar(int i) => ValueKey<String>('beui_wave_slider_bar_$i');
const _bubbleTrack = ValueKey<String>('beui_bubble_slider_track');
const _bubbleThumb = ValueKey<String>('beui_bubble_slider_thumb');
const _bubble = ValueKey<String>('beui_bubble_slider_bubble');
const _rulerReadout = ValueKey<String>('beui_ruler_slider_readout');
const _rulerNeedle = ValueKey<String>('beui_ruler_slider_needle');

/// Wraps a slider in a themed app at a known width, optionally with reduced
/// motion switched on.
Widget _app({required Widget child, bool reduce = false, double width = 200}) {
  Widget body = Center(
    child: SizedBox(width: width, child: child),
  );
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

/// Drives a **controlled** slider the way a real app does: holds the value and
/// feeds every `onChanged` straight back, so the handle tracks the parent.
class _Controlled extends StatefulWidget {
  const _Controlled({
    required this.initial,
    required this.build,
    this.observe,
    this.reduce = false,
    this.width = 200,
    super.key,
  });

  final double initial;
  final Widget Function(double value, ValueChanged<double> onChanged) build;
  final ValueChanged<double>? observe;
  final bool reduce;
  final double width;

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) => _app(
    reduce: widget.reduce,
    width: widget.width,
    child: widget.build(_value, (v) {
      setState(() => _value = v);
      widget.observe?.call(v);
    }),
  );
}

double _thumbX(WidgetTester t) => t.getCenter(find.byKey(_thumb)).dx;
double _fillWidth(WidgetTester t) => t.getSize(find.byKey(_fluidFill)).width;
double _bubbleThumbX(WidgetTester t) =>
    t.getCenter(find.byKey(_bubbleThumb)).dx;

/// The rendered `scaleY` of wave bar [i] (`Transform.scale(scaleY: …)` writes it
/// into row 1, column 1 of the matrix).
double _barScale(WidgetTester t, int i) {
  final transform = t.widget<Transform>(
    find
        .descendant(
          of: find.byKey(_waveBar(i)),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.entry(1, 1);
}

String _readoutText(WidgetTester t) =>
    t.widget<Text>(find.byKey(_rulerReadout)).data!;

void main() {
  // =========================================================================
  // BeuiRangeSlider — ticked track, vertical-bar thumb
  // =========================================================================
  group('BeuiRangeSlider', () {
    Widget host({
      double initial = 20,
      ValueChanged<double>? observe,
      bool reduce = false,
    }) => _Controlled(
      initial: initial,
      observe: observe,
      reduce: reduce,
      build: (value, onChanged) => BeuiRangeSlider(
        value: value,
        min: 0,
        max: 100,
        step: 5,
        onChanged: onChanged,
      ),
    );

    // The source insets the tick layer by `inset-x-[3px]` — half the thumb's
    // width, which is exactly the span the thumb's own centre travels. That is
    // what makes a dot sit precisely where the thumb lands. Any other inset
    // leaves the dots agreeing with the thumb only at the midpoint and walking
    // off it towards both ends.
    testWidgets('a tick dot sits exactly where the thumb lands', (
      tester,
    ) async {
      final dots = find.descendant(
        of: find.byKey(_ticks),
        matching: find.byType(Container),
      );

      for (final probe in const [(0.0, 0), (50.0, 10), (100.0, 20)]) {
        // A fresh key per probe: `_Controlled` seeds its value in a field
        // initialiser, so re-pumping the same widget type would reuse the old
        // State and leave the thumb where the previous probe left it.
        await tester.pumpWidget(
          _Controlled(
            key: ValueKey<double>(probe.$1),
            initial: probe.$1,
            build: (value, onChanged) => BeuiRangeSlider(
              value: value,
              min: 0,
              max: 100,
              step: 5,
              onChanged: onChanged,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(dots, findsNWidgets(21), reason: '0..100 by 5 is 21 dots');
        expect(
          tester.getCenter(dots.at(probe.$2)).dx,
          moreOrLessEquals(_thumbX(tester), epsilon: 0.5),
          reason: 'the dot for value ${probe.$1} is under the thumb',
        );
      }
    });

    testWidgets('dragging the thumb changes its value', (tester) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed, greaterThan(20));
    });

    testWidgets('value snaps to a step boundary', (tester) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.byKey(_thumb));
      await tester.dragFrom(from, const Offset(13, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed! % 5, 0, reason: 'snapped to a step of 5');
    });

    testWidgets('the thumb glides to the snapped step during a drag', (
      tester,
    ) async {
      await tester.pumpWidget(host(initial: 10));
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.byKey(_thumb));
      final g = await tester.startGesture(start);
      await g.moveBy(const Offset(50, 0));
      await g.moveBy(const Offset(50, 0)); // pointer now +100px from start
      await tester.pump(const Duration(milliseconds: 16)); // one frame
      // A glide (≈60ms time constant) is still far behind after one frame.

      // Source drives the thumb off the SNAPPED value through SPRING_GLIDE, so a
      // frame after the pointer jumps the handle is still gliding toward the
      // step — it LAGS the finger (detents live) rather than raw-tracking it.
      final fingerX = start.dx + 100;
      expect(
        (_thumbX(tester) - fingerX).abs(),
        greaterThan(8),
        reason:
            'handle glides to the snapped step, not bound to the raw pointer',
      );

      // It settles onto a snapped step to the right of where it began.
      await tester.pumpAndSettle();
      expect(_thumbX(tester), greaterThan(start.dx));

      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('arrow keys move the thumb by one step', (tester) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
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
      await tester.pumpWidget(host(initial: 40, observe: (v) => changed = v));
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
      await tester.pumpWidget(host(reduce: true, observe: (v) => changed = v));
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
      await tester.pumpWidget(host(initial: 10, observe: (v) => changed = v));
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
  // BeuiFluidSlider — thumbless pill, liquid cap, inverted label
  // =========================================================================
  group('BeuiFluidSlider', () {
    Widget host({
      double initial = 40,
      ValueChanged<double>? observe,
      bool reduce = false,
    }) => _Controlled(
      initial: initial,
      observe: observe,
      reduce: reduce,
      build: (value, onChanged) => BeuiFluidSlider(
        value: value,
        min: 0,
        max: 100,
        step: 5,
        labelText: 'Brightness',
        label: 'Brightness',
        onChanged: onChanged,
      ),
    );

    testWidgets('dragging the pill changes the value and grows the fill', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();
      expect(_fillWidth(tester), closeTo(80, 0.5), reason: '40% of 200px');

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(2, 24), const Offset(98, 0));
      await tester.pumpAndSettle();

      expect(changed, 50, reason: 'pointer landed at 100/200px → 50');
      expect(_fillWidth(tester), closeTo(100, 0.5));
    });

    testWidgets('the label is drawn twice so it inverts under the fill', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      // One copy on the muted track, one inside the clipped fill — the pair is
      // what makes the copy flip colour exactly where the cap crosses it.
      expect(find.text('Brightness'), findsNWidgets(2));
      expect(find.text('40%'), findsNWidgets(2));
    });

    testWidgets('uncontrolled: holds its own value from defaultValue', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        _app(
          child: BeuiFluidSlider(
            defaultValue: 20,
            min: 0,
            max: 100,
            step: 5,
            onChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_fillWidth(tester), closeTo(40, 0.5));

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(2, 24), const Offset(148, 0));
      await tester.pumpAndSettle();

      // No parent fed the value back, yet the fill moved: internal state.
      expect(changed, 75);
      expect(_fillWidth(tester), closeTo(150, 0.5));
    });

    testWidgets('controlled: a parent that refuses the change pins the fill', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        _app(
          child: BeuiFluidSlider(
            value: 40,
            min: 0,
            max: 100,
            step: 5,
            onChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(2, 24), const Offset(148, 0));
      await tester.pumpAndSettle();

      expect(changed, 75, reason: 'it still reports the intent');
      expect(
        _fillWidth(tester),
        closeTo(80, 0.5),
        reason: 'but the parent owns the value, so nothing moved',
      );
    });

    testWidgets('arrow keys step, Home/End jump', (tester) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(80, 24), const Offset(2, 0));
      await tester.pumpAndSettle();

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changed, 45, reason: '40 + one 5-step');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changed, 40, reason: 'back down one step');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changed, 100);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changed, 0);
    });

    testWidgets('the fill glides under normal motion', (tester) async {
      await tester.pumpWidget(host(initial: 10));
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(2, 24), const Offset(158, 0));
      await tester.pump(const Duration(milliseconds: 16));

      // One frame in, the fill is still well short of its 160px target.
      expect(_fillWidth(tester), lessThan(140));
      await tester.pumpAndSettle();
      expect(_fillWidth(tester), closeTo(160, 0.5));
    });

    testWidgets('reduced motion places the fill with no glide', (tester) async {
      double? changed;
      await tester.pumpWidget(
        host(initial: 10, reduce: true, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(2, 24), const Offset(158, 0));
      await tester.pump(const Duration(milliseconds: 1));
      final immediate = _fillWidth(tester);
      await tester.pumpAndSettle();
      final settled = _fillWidth(tester);

      expect(changed, 80, reason: 'the value still changes');
      expect(settled, closeTo(160, 0.5));
      expect(
        immediate,
        closeTo(settled, 0.5),
        reason: 'no intermediate frames — it snaps',
      );
    });

    testWidgets('disabled ignores drags and keys', (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _app(
          child: BeuiFluidSlider(
            defaultValue: 40,
            enabled: false,
            onChanged: (_) => changes++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_fluidTrack));
      await tester.dragFrom(origin + const Offset(2, 24), const Offset(148, 0));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(changes, 0);
      expect(_fillWidth(tester), closeTo(80, 0.5));
    });
  });

  // =========================================================================
  // BeuiWaveSlider — equalizer bars with a travelling Gaussian crest
  // =========================================================================
  group('BeuiWaveSlider', () {
    Widget host({
      double initial = 50,
      int bars = 32,
      ValueChanged<double>? observe,
      bool reduce = false,
    }) => _Controlled(
      initial: initial,
      observe: observe,
      reduce: reduce,
      build: (value, onChanged) => BeuiWaveSlider(
        value: value,
        min: 0,
        max: 100,
        step: 5,
        bars: bars,
        onChanged: onChanged,
      ),
    );

    testWidgets('dragging changes the value', (tester) async {
      double? changed;
      await tester.pumpWidget(host(initial: 20, observe: (v) => changed = v));
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_waveTrack));
      await tester.dragFrom(origin + const Offset(2, 40), const Offset(148, 0));
      await tester.pumpAndSettle();

      expect(changed, 75);
    });

    testWidgets('the crest peaks on the bar under the value', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // value 50 of 0–100 over 32 bars → head at index 15.5.
      final peak = _barScale(tester, 16);
      final edge = _barScale(tester, 0);
      final far = _barScale(tester, 31);

      expect(peak, greaterThan(edge + 0.4), reason: 'a crest, not a flat row');
      expect(peak, greaterThan(far + 0.4));
      // Off the crest the bars sit at the 0.22 floor.
      expect(edge, closeTo(0.22, 0.02));
    });

    testWidgets('the crest travels with the value', (tester) async {
      await tester.pumpWidget(host(initial: 10));
      await tester.pumpAndSettle();
      final leftPeakBefore = _barScale(tester, 3);
      final rightPeakBefore = _barScale(tester, 28);
      expect(leftPeakBefore, greaterThan(rightPeakBefore));

      final origin = tester.getTopLeft(find.byKey(_waveTrack));
      await tester.dragFrom(origin + const Offset(2, 40), const Offset(178, 0));
      // The per-bar stagger is a `Timer` (`min(distance × 12ms, 120ms)`), and
      // `pumpAndSettle` only waits on transient callbacks — never on pending
      // timers. Advance past the longest stagger explicitly so every bar has
      // actually been handed its new target, then settle the springs.
      await tester.pump(const Duration(milliseconds: 130));
      await tester.pumpAndSettle();

      // The crest has moved to the right-hand bars and the left has fallen back.
      expect(_barScale(tester, 28), greaterThan(rightPeakBefore + 0.4));
      expect(_barScale(tester, 3), lessThan(leftPeakBefore));
    });

    testWidgets('bar count is configurable', (tester) async {
      await tester.pumpWidget(host(bars: 8));
      await tester.pumpAndSettle();
      expect(find.byKey(_waveBar(7)), findsOneWidget);
      expect(find.byKey(_waveBar(8)), findsNothing);
    });

    testWidgets('reduced motion flattens every bar to a uniform 0.4', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        host(initial: 20, reduce: true, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      for (final i in [0, 8, 16, 31]) {
        expect(
          _barScale(tester, i),
          closeTo(0.4, 0.001),
          reason: 'bar $i is flat under reduced motion',
        );
      }

      // The control still works — only the crest is gone.
      final origin = tester.getTopLeft(find.byKey(_waveTrack));
      await tester.dragFrom(origin + const Offset(2, 40), const Offset(148, 0));
      await tester.pumpAndSettle();
      expect(changed, 75);
      expect(_barScale(tester, 16), closeTo(0.4, 0.001));
    });

    testWidgets('arrow keys step the value', (tester) async {
      double? changed;
      await tester.pumpWidget(host(initial: 50, observe: (v) => changed = v));
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_waveTrack));
      await tester.dragFrom(origin + const Offset(100, 40), const Offset(2, 0));
      await tester.pumpAndSettle();

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changed, 55);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changed, 50);
    });

    testWidgets('uncontrolled: the crest follows its own internal value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const BeuiWaveSlider(defaultValue: 0, min: 0, max: 100)),
      );
      await tester.pumpAndSettle();
      final before = _barScale(tester, 31);

      final origin = tester.getTopLeft(find.byKey(_waveTrack));
      await tester.dragFrom(origin + const Offset(2, 40), const Offset(198, 0));
      await tester.pumpAndSettle();

      expect(_barScale(tester, 31), greaterThan(before + 0.4));
    });
  });

  // =========================================================================
  // BeuiBubbleSlider — velocity-reactive value bubble
  // =========================================================================
  group('BeuiBubbleSlider', () {
    Widget host({
      double initial = 20,
      ValueChanged<double>? observe,
      bool reduce = false,
    }) => _Controlled(
      initial: initial,
      observe: observe,
      reduce: reduce,
      build: (value, onChanged) => BeuiBubbleSlider(
        value: value,
        min: 0,
        max: 100,
        step: 5,
        onChanged: onChanged,
      ),
    );

    testWidgets('dragging moves the thumb and changes the value', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();
      final before = _bubbleThumbX(tester);

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      // The track is inset by the wrapper's 20px padding; the hit area is the
      // 48px band around it, so aim at the track's own vertical centre.
      await tester.dragFrom(origin + const Offset(22, 56), const Offset(78, 0));
      await tester.pumpAndSettle();

      expect(
        changed,
        50,
        reason: '80px along a 160px track (20px inset each side)',
      );
      expect(_bubbleThumbX(tester), greaterThan(before));
    });

    testWidgets('the bubble pops out on grab and leaves on release', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.byKey(_bubble), findsNothing, reason: 'idle: no bubble');

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      final g = await tester.startGesture(origin + const Offset(22, 56));
      await g.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_bubble), findsOneWidget, reason: 'grabbed: bubble in');

      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_bubble), findsNothing, reason: 'released: bubble out');
    });

    testWidgets('the bubble reads the formatted value', (tester) async {
      await tester.pumpWidget(
        _Controlled(
          initial: 20,
          build: (value, onChanged) => BeuiBubbleSlider(
            value: value,
            min: 0,
            max: 100,
            step: 5,
            format: (v) => '${v.round()} kg',
            onChanged: onChanged,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      final g = await tester.startGesture(origin + const Offset(22, 56));
      await g.moveBy(const Offset(78, 0));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('50 kg'), findsOneWidget);

      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the thumb glides under normal motion', (tester) async {
      await tester.pumpWidget(host(initial: 0));
      await tester.pumpAndSettle();
      final before = _bubbleThumbX(tester);

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      await tester.dragFrom(
        origin + const Offset(22, 56),
        const Offset(138, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final oneFrame = _bubbleThumbX(tester);
      await tester.pumpAndSettle();
      final settled = _bubbleThumbX(tester);

      expect(settled, greaterThan(before));
      expect(
        oneFrame,
        lessThan(settled - 8),
        reason: 'a frame in, the thumb is still gliding toward the step',
      );
    });

    testWidgets('reduced motion snaps the thumb and drops the bubble scale', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        host(initial: 0, reduce: true, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      await tester.dragFrom(
        origin + const Offset(22, 56),
        const Offset(138, 0),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final immediate = _bubbleThumbX(tester);
      await tester.pumpAndSettle();
      final settled = _bubbleThumbX(tester);

      expect(changed, isNotNull);
      expect(changed, greaterThan(0));
      expect(
        immediate,
        closeTo(settled, 0.5),
        reason: 'no intermediate frames — it snaps',
      );
    });

    testWidgets('arrow keys step, Home/End jump', (tester) async {
      double? changed;
      await tester.pumpWidget(host(initial: 20, observe: (v) => changed = v));
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      await tester.dragFrom(origin + const Offset(54, 56), const Offset(2, 0));
      await tester.pumpAndSettle();

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final afterUp = changed!;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(changed, afterUp - 5);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changed, 100);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changed, 0);
    });

    testWidgets('uncontrolled: the thumb moves without a parent', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        _app(
          child: BeuiBubbleSlider(
            defaultValue: 0,
            min: 0,
            max: 100,
            step: 5,
            onChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = _bubbleThumbX(tester);

      final origin = tester.getTopLeft(find.byKey(_bubbleTrack));
      await tester.dragFrom(
        origin + const Offset(22, 56),
        const Offset(138, 0),
      );
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(_bubbleThumbX(tester), greaterThan(before + 100));
    });
  });

  // =========================================================================
  // BeuiRulerSlider — the scale scrolls under a fixed needle
  // =========================================================================
  group('BeuiRulerSlider', () {
    Widget host({
      double initial = 50,
      ValueChanged<double>? observe,
      bool reduce = false,
      Key? key,
    }) => _Controlled(
      key: key,
      initial: initial,
      observe: observe,
      reduce: reduce,
      // A ruler wants room for its scale; the drag maths is gap-based, not
      // width-based, so the wider host does not change any expectation.
      width: 300,
      build: (value, onChanged) => BeuiRulerSlider(
        value: value,
        min: 0,
        max: 100,
        step: 1,
        gap: 14,
        onChanged: onChanged,
      ),
    );

    testWidgets('the needle stays put while the scale scrolls', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final needle = tester.getCenter(find.byKey(_rulerNeedle));

      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(-70, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(tester.getCenter(find.byKey(_rulerNeedle)), needle);
      expect(_readoutText(tester), isNot('50'));
    });

    testWidgets('dragging right lowers the value, left raises it', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(70, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(
        changed,
        lessThan(50),
        reason: 'pulling right brings back smaller',
      );
      final afterRight = changed!;

      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(-70, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(changed, greaterThan(afterRight));
    });

    testWidgets('the scale settles on a whole tick', (tester) async {
      double? changed;
      await tester.pumpWidget(host(observe: (v) => changed = v));
      await tester.pumpAndSettle();

      // 47px is 3.36 steps at gap 14 — deliberately not a whole tick.
      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(-47, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed! % 1, 0, reason: 'landed on a tick, not between two');
    });

    testWidgets('a flick carries momentum past where it was released', (
      tester,
    ) async {
      double? coasted;
      // Distinct keys: without them the second pumpWidget would UPDATE the same
      // element and inherit the first run's value instead of starting fresh.
      await tester.pumpWidget(
        host(
          key: const ValueKey('coast'),
          initial: 0,
          observe: (v) => coasted = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(BeuiRulerSlider),
        const Offset(-120, 0),
        1200,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      double? stopped;
      await tester.pumpWidget(
        host(
          key: const ValueKey('stop'),
          initial: 0,
          reduce: true,
          observe: (v) => stopped = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(BeuiRulerSlider),
        const Offset(-120, 0),
        1200,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(coasted, isNotNull);
      expect(stopped, isNotNull);
      // Reduced motion lands on the tick under the finger at release; normal
      // motion projects the flick's momentum and coasts well past it.
      expect(
        coasted,
        greaterThan(stopped! + 5),
        reason: 'momentum carries the scale past the release point',
      );
    });

    testWidgets('reduced motion lands on the release tick with no coast', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(
        host(initial: 0, reduce: true, observe: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(-70, 0),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 1));
      final immediate = _readoutText(tester);
      await tester.pumpAndSettle();

      expect(changed, 5, reason: '70px / 14px per step');
      expect(
        immediate,
        _readoutText(tester),
        reason: 'no settle frames — it is already on the tick',
      );
    });

    testWidgets('arrow keys step, Home/End jump', (tester) async {
      double? changed;
      await tester.pumpWidget(host(initial: 50, observe: (v) => changed = v));
      await tester.pumpAndSettle();

      // Focus it with a nudge too small to move the value off its tick.
      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(2, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      changed = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changed, 51);
      expect(_readoutText(tester), '51');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changed, 50);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changed, 100);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changed, 0);
    });

    testWidgets('a key press takes the scale back from momentum', (
      tester,
    ) async {
      double? changed;
      await tester.pumpWidget(host(initial: 50, observe: (v) => changed = v));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(BeuiRulerSlider),
        const Offset(-120, 0),
        1200,
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 16));
      final midFlight = changed!;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // The coast was cancelled at the key press, so the value is exactly one
      // step past wherever it had reached — not wherever momentum would have
      // carried it.
      expect(
        changed,
        lessThan(midFlight + 20),
        reason: 'the coasting strip did not swallow the key press',
      );
      expect(changed! % 1, 0);
    });

    testWidgets('the readout carries the precision the step implies', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          width: 300,
          child: const BeuiRulerSlider(
            value: 72.5,
            min: 40,
            max: 120,
            step: 0.5,
            gap: 12,
            majorEvery: 10,
            unit: 'kg',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_readoutText(tester), '72.5');
      expect(find.text('kg'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          width: 300,
          child: const BeuiRulerSlider(value: 72, min: 40, max: 120),
        ),
      );
      await tester.pumpAndSettle();
      expect(_readoutText(tester), '72', reason: 'a whole step drops the ".0"');
    });

    testWidgets('uncontrolled: the readout tracks its own internal value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const BeuiRulerSlider(defaultValue: 50, min: 0, max: 100)),
      );
      await tester.pumpAndSettle();
      expect(_readoutText(tester), '50');

      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(-70, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(_readoutText(tester), '55');
    });

    testWidgets('disabled ignores drags and keys', (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _app(
          child: BeuiRulerSlider(
            defaultValue: 50,
            enabled: false,
            onChanged: (_) => changes++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(BeuiRulerSlider),
        const Offset(-70, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(changes, 0);
      expect(_readoutText(tester), '50');
    });
  });
}
