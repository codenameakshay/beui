import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:beui/src/motion/_engine.dart'
    show SingleMotionBuilder, SpringMotion;
import 'package:beui/src/motion/voice_orb.dart'
    show beuiVoiceOrbCanvasKey, beuiVoiceOrbErrorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _RecordingAnalyser implements BeuiVoiceAnalyser {
  _RecordingAnalyser(this.fftSize, [this.bytes = const []]);

  @override
  int fftSize;
  List<int> bytes;
  int calls = 0;

  @override
  void getByteTimeDomainData(Uint8List destination) {
    calls++;
    for (var i = 0; i < destination.length; i++) {
      destination[i] = bytes.isEmpty ? 128 : bytes[i % bytes.length];
    }
  }
}

class _ThrowingCanvas implements ui.Canvas {
  _ThrowingCanvas(this.error);

  final Object error;

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

bool _orbSettled(WidgetTester tester) {
  if (find.byKey(beuiVoiceOrbErrorKey).evaluate().isNotEmpty) return true;
  final canvas = find.byKey(beuiVoiceOrbCanvasKey);
  if (canvas.evaluate().isEmpty) return false;
  return tester.widget<CustomPaint>(canvas).painter != null;
}

/// FragmentProgram.fromAsset is real asynchronous work in widget tests.
Future<void> _settleOrb(WidgetTester tester) async {
  await tester.pump();
  if (_orbSettled(tester)) return;
  await tester.runAsync(() async {
    for (var k = 0; k < 40; k++) {
      await tester.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 8));
      if (_orbSettled(tester)) return;
    }
  });
  await tester.pump();
}

void _expectLoaded(WidgetTester tester) {
  expect(find.byKey(beuiVoiceOrbErrorKey), findsNothing);
  final canvas = tester.widget<CustomPaint>(find.byKey(beuiVoiceOrbCanvasKey));
  expect(canvas.painter, isNotNull, reason: 'fragment shader loaded');
}

double _shaderTime(WidgetTester tester) {
  final dynamic painter = tester
      .widget<CustomPaint>(find.byKey(beuiVoiceOrbCanvasKey))
      .painter;
  return (painter.time.value as double);
}

double _motionTarget(WidgetTester tester) =>
    tester.widget<SingleMotionBuilder>(find.byType(SingleMotionBuilder)).value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('label replaces child semantics with an image name', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiVoiceOrb(semanticLabel: 'Voice visualization')),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(BeuiVoiceOrb)),
      matchesSemantics(label: 'Voice visualization', isImage: true),
    );
  });

  testWidgets('activity inputs clamp and the glide target is exact', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 4)));
    await tester.pump();
    expect(_motionTarget(tester), 1);
    final motion =
        tester
                .widget<SingleMotionBuilder>(find.byType(SingleMotionBuilder))
                .motion!
            as SpringMotion;
    expect(motion.description.mass, 0.5);
    expect(motion.description.stiffness, 700);
    expect(motion.description.damping, 50);

    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: -2)));
    await tester.pump();
    expect(_motionTarget(tester), 0);
    await tester.pumpWidget(
      beuiTestApp(const BeuiVoiceOrb(activity: double.nan)),
    );
    await tester.pump();
    expect(_motionTarget(tester), 0);
  });

  testWidgets('ValueListenable updates target without rebuilding its owner', (
    tester,
  ) async {
    final activity = ValueNotifier<double>(0.2);
    addTearDown(activity.dispose);
    await tester.pumpWidget(
      beuiTestApp(BeuiVoiceOrb(activityListenable: activity)),
    );
    await tester.pump();
    expect(_motionTarget(tester), 0.2);
    activity.value = 0.8;
    await tester.pump();
    expect(_motionTarget(tester), 0.8);
  });

  testWidgets('analyser RMS maps [128, 160] to the exact spring target', (
    tester,
  ) async {
    final analyser = _RecordingAnalyser(2, [128, 160]);
    await tester.pumpWidget(beuiTestApp(BeuiVoiceOrb(analyser: analyser)));
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(analyser.calls, greaterThan(0));
    expect(_motionTarget(tester), closeTo(0.5303300859, 1e-9));
  });

  testWidgets(
    'analyser RMS silence is zero and full-range input clamps to one',
    (tester) async {
      final analyser = _RecordingAnalyser(2);
      await tester.pumpWidget(beuiTestApp(BeuiVoiceOrb(analyser: analyser)));
      await _settleOrb(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_motionTarget(tester), 0);
      analyser.bytes = [0, 255];
      await tester.pump(const Duration(milliseconds: 16));
      expect(_motionTarget(tester), 1);
    },
  );

  testWidgets('empty analyser has a zero target', (tester) async {
    final analyser = _RecordingAnalyser(0);
    await tester.pumpWidget(beuiTestApp(BeuiVoiceOrb(analyser: analyser)));
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 32));
    expect(_motionTarget(tester), 0);
  });

  testWidgets('analyser replacement, resize, and removal update sampling', (
    tester,
  ) async {
    final first = _RecordingAnalyser(2, [0, 255]);
    final replacement = _RecordingAnalyser(4, [128]);
    await tester.pumpWidget(beuiTestApp(BeuiVoiceOrb(analyser: first)));
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_motionTarget(tester), 1);

    await tester.pumpWidget(beuiTestApp(BeuiVoiceOrb(analyser: replacement)));
    final firstCalls = first.calls;
    await tester.pump(const Duration(milliseconds: 16));
    expect(first.calls, firstCalls);
    expect(replacement.calls, greaterThan(0));
    expect(_motionTarget(tester), 0);
    final replacementCalls = replacement.calls;

    replacement.fftSize = 1;
    replacement.bytes = [0];
    await tester.pump(const Duration(milliseconds: 16));
    expect(replacement.calls, greaterThan(replacementCalls));
    expect(_motionTarget(tester), 1);

    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 0.25)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(first.calls, firstCalls);
    expect(_motionTarget(tester), 0.25);
  });

  testWidgets('scroll clipping pauses analyser and shader time, then resumes', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final analyser = _RecordingAnalyser(8, [0, 255]);
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      beuiTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 300),
            child: SizedBox(
              width: 300,
              height: 300,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    BeuiVoiceOrb(analyser: analyser),
                    const SizedBox(height: 512),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    expect(analyser.calls, greaterThan(0));

    controller.jumpTo(300);
    await tester.pump();
    final pausedCalls = analyser.calls;
    final pausedTime = _shaderTime(tester);
    final orbRect = tester.getRect(find.byType(BeuiVoiceOrb));
    expect(orbRect.overlaps(Offset.zero & const Size(800, 800)), isTrue);
    expect(orbRect, const Rect.fromLTWH(22, 0, 256, 256));
    expect(orbRect.overlaps(const Rect.fromLTWH(0, 300, 300, 300)), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(analyser.calls, pausedCalls);
    expect(_shaderTime(tester), pausedTime);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 16));
    expect(analyser.calls, greaterThan(pausedCalls));
    expect(_shaderTime(tester), greaterThan(pausedTime));
  });

  testWidgets('active false freezes clock without catch-up and restarts', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 0.5)));
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    final beforePause = _shaderTime(tester);
    await tester.pumpWidget(
      beuiTestApp(const BeuiVoiceOrb(activity: 0.5, active: false)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(_shaderTime(tester), beforePause);
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 0.5)));
    await tester.pump(const Duration(milliseconds: 16));
    final firstFrame = _shaderTime(tester);
    expect(firstFrame, beforePause);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_shaderTime(tester) - firstFrame, lessThan(0.05));
  });

  testWidgets('reduced motion disables and re-enabling restarts shader clock', (
    tester,
  ) async {
    Widget app(bool reduce) => beuiTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: const BeuiVoiceOrb(activity: 1),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    await tester.pump(const Duration(milliseconds: 16));
    final beforeReduce = _shaderTime(tester);
    expect(beforeReduce, greaterThan(0));

    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SingleMotionBuilder), findsNothing);
    expect(_shaderTime(tester), beforeReduce);
    expect(
      find.descendant(
        of: find.byType(BeuiVoiceOrb),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );

    await tester.pumpWidget(app(false));
    await tester.pump(const Duration(milliseconds: 32));
    expect(_motionTarget(tester), 1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_shaderTime(tester), greaterThan(beforeReduce));
    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(BeuiVoiceOrb),
        matching: find.byType(Transform),
      ),
    );
    expect(transforms.last.transform.entry(0, 0), greaterThan(1));
  });

  testWidgets('lifecycle paused, hidden, and detached freeze then resume', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 0.5)));
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    for (final state in [
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      final before = _shaderTime(tester);
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shaderTime(tester), before, reason: '$state freezes time');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_shaderTime(tester), before, reason: 'no catch-up on resume');
      await tester.pump(const Duration(milliseconds: 16));
      expect(_shaderTime(tester), greaterThan(before));
    }
  });

  testWidgets('TickerMode pauses and resumes the shader clock', (tester) async {
    var enabled = true;
    Widget app() => beuiTestApp(
      StatefulBuilder(
        builder: (context, setState) => TickerMode(
          enabled: enabled,
          child: Column(
            children: [
              Switch(
                value: enabled,
                onChanged: (value) => setState(() => enabled = value),
              ),
              const BeuiVoiceOrb(activity: 0.5),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    final before = _shaderTime(tester);
    enabled = false;
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    expect(_shaderTime(tester), before);
    enabled = true;
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 16));
    expect(_shaderTime(tester), before);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_shaderTime(tester), greaterThan(before));
  });

  testWidgets('outer nested-scroll clipping pauses the inner orb', (
    tester,
  ) async {
    final outer = ScrollController();
    final inner = ScrollController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    final analyser = _RecordingAnalyser(8, [0, 255]);
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      beuiTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 300),
            child: SizedBox(
              width: 300,
              height: 300,
              child: SingleChildScrollView(
                controller: outer,
                child: Column(
                  children: [
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: SingleChildScrollView(
                        controller: inner,
                        child: Column(
                          children: [
                            BeuiVoiceOrb(analyser: analyser),
                            const SizedBox(height: 512),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 512),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    expect(analyser.calls, greaterThan(0));
    outer.jumpTo(300);
    await tester.pump();
    final pausedCalls = analyser.calls;
    final pausedTime = _shaderTime(tester);
    final rect = tester.getRect(find.byType(BeuiVoiceOrb));
    expect(rect, const Rect.fromLTWH(22, 0, 256, 256));
    expect(rect.overlaps(const Rect.fromLTWH(0, 300, 300, 300)), isFalse);
    expect(rect.overlaps(Offset.zero & const Size(800, 800)), isTrue);
    await tester.pump(const Duration(milliseconds: 80));
    expect(analyser.calls, pausedCalls);
    expect(_shaderTime(tester), pausedTime);
  });

  testWidgets('replacing scroll physics reattaches visibility listener', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final analyser = _RecordingAnalyser(8, [0, 255]);
    final orb = BeuiVoiceOrb(key: ValueKey('stable-orb'), analyser: analyser);
    ScrollPhysics physics = const ClampingScrollPhysics();
    Widget app() => beuiTestApp(
      StatefulBuilder(
        builder: (context, setState) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 300),
            child: SizedBox(
              width: 300,
              height: 300,
              child: SingleChildScrollView(
                controller: controller,
                physics: physics,
                child: Column(children: [orb, const SizedBox(height: 512)]),
              ),
            ),
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 48));
    expect(analyser.calls, greaterThan(0));

    physics = const BouncingScrollPhysics();
    await tester.pumpWidget(app());
    controller.jumpTo(300);
    await tester.pump();
    final pausedCalls = analyser.calls;
    final pausedTime = _shaderTime(tester);
    expect(
      tester.getRect(find.byKey(const ValueKey('stable-orb'))),
      const Rect.fromLTWH(22, 0, 256, 256),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(analyser.calls, pausedCalls);
    expect(_shaderTime(tester), pausedTime);
  });

  testWidgets('overflow remains animated through a Clip.none ancestor', (
    tester,
  ) async {
    final analyser = _RecordingAnalyser(8, [0, 255]);
    await tester.pumpWidget(
      beuiTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: BeuiVoiceOrb(analyser: analyser),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _settleOrb(tester);
    await tester.pump(const Duration(milliseconds: 32));
    final calls = analyser.calls;
    expect(calls, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 32));
    expect(analyser.calls, greaterThan(calls));
  });

  testWidgets('shader edge pixels are premultiplied by fractional alpha', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb()));
    await _settleOrb(tester);
    _expectLoaded(tester);
    final painter = tester
        .widget<CustomPaint>(find.byKey(beuiVoiceOrbCanvasKey))
        .painter!;
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), const Size(256, 256));
    final picture = recorder.endRecording();
    final channels = await tester.runAsync(() async {
      final image = await picture.toImage(256, 256);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return <int>[];
      return List<int>.generate(data.lengthInBytes, data.getUint8);
    });
    picture.dispose();
    expect(channels, isNotNull);
    var sawFractionalAlpha = false;
    for (var i = 0; i < channels!.length; i += 4) {
      final alpha = channels[i + 3];
      if (alpha == 0 || alpha == 255) continue;
      sawFractionalAlpha = true;
      expect(channels[i], lessThanOrEqualTo(alpha));
      expect(channels[i + 1], lessThanOrEqualTo(alpha));
      expect(channels[i + 2], lessThanOrEqualTo(alpha));
    }
    expect(sawFractionalAlpha, isTrue);
  });

  testWidgets(
    'paint exceptions report once, replace surface, and stop sampling',
    (tester) async {
      final analyser = _RecordingAnalyser(4, [128]);
      final errors = <Object>[];
      await tester.pumpWidget(
        beuiTestApp(BeuiVoiceOrb(analyser: analyser, onError: errors.add)),
      );
      await _settleOrb(tester);
      final painter = tester
          .widget<CustomPaint>(find.byKey(beuiVoiceOrbCanvasKey))
          .painter!;
      final paintError = StateError('paint failed');
      expect(
        () => (painter as dynamic).paint(
          _ThrowingCanvas(paintError),
          const Size(256, 256),
        ),
        returnsNormally,
      );
      expect(
        () => (painter as dynamic).paint(
          _ThrowingCanvas(paintError),
          const Size(256, 256),
        ),
        returnsNormally,
      );
      await tester.pump();
      await tester.pump();
      expect(errors, hasLength(1));
      expect(errors.single, same(paintError));
      expect(find.byKey(beuiVoiceOrbErrorKey), findsOneWidget);
      final calls = analyser.calls;
      await tester.pump(const Duration(milliseconds: 48));
      expect(analyser.calls, calls);
    },
  );

  testWidgets('load failure shows themed fallback and reports its cause', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    BeuiVoiceOrb.debugLoadError = Exception('no gpu');
    addTearDown(() => BeuiVoiceOrb.debugLoadError = null);
    Object? reported;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVoiceOrb(
          semanticLabel: 'Voice orb unavailable',
          onError: (e) => reported = e,
        ),
        extensions: const [
          BeuiAgentTheme(
            strings: BeuiAgentStrings(orbUnavailable: 'SENTINEL orb'),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('SENTINEL orb'), findsOneWidget);
    expect(find.byKey(beuiVoiceOrbErrorKey), findsOneWidget);
    expect(reported, isA<Exception>());
    expect(
      tester.getSemantics(find.byType(BeuiVoiceOrb)),
      matchesSemantics(label: 'Voice orb unavailable', isImage: true),
    );

    await tester.pumpWidget(
      beuiTestApp(
        const BeuiVoiceOrb(),
        extensions: const [
          BeuiAgentTheme(
            strings: BeuiAgentStrings(orbUnavailable: 'SENTINEL orb'),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('SENTINEL orb'), findsOneWidget);
    expect(find.bySemanticsLabel('SENTINEL orb'), findsNothing);
    semantics.dispose();
  });

  testWidgets('size defaults to 256 and override resizes the same widget', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb()));
    await tester.pump();
    expect(kBeuiVoiceOrbSize, 256);
    expect(
      tester.getSize(find.byKey(beuiVoiceOrbCanvasKey)),
      const Size(256, 256),
    );

    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(size: 288)));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(beuiVoiceOrbCanvasKey)),
      const Size(288, 288),
    );

    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(size: 192)));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(beuiVoiceOrbCanvasKey)),
      const Size(192, 192),
    );
  });

  testWidgets('zero, negative, NaN, and infinite sizes fall back to 256', (
    tester,
  ) async {
    for (final size in <double>[
      0,
      -1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      await tester.pumpWidget(beuiTestApp(BeuiVoiceOrb(size: size)));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(beuiVoiceOrbCanvasKey)),
        const Size(256, 256),
        reason: 'size $size should use the default',
      );
    }
  });

  testWidgets('rest-state golden loads the real shader (reduced motion, t=0)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiVoiceOrb(semanticLabel: 'Voice visualization'),
        reduce: true,
        dark: true,
      ),
    );
    await _settleOrb(tester);
    _expectLoaded(tester);
    expect(tester.getSize(find.byType(BeuiVoiceOrb)), const Size(256, 256));
    expect(
      tester.getSize(find.byKey(beuiVoiceOrbCanvasKey)),
      const Size(256, 256),
    );
    await expectLater(
      find.byType(BeuiVoiceOrb),
      matchesGoldenFile('goldens/beui_voice_orb.png'),
    );
    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pumpWidget(
      beuiTestApp(const BeuiVoiceOrb(semanticLabel: 'Warm cache remount')),
    );
    await _settleOrb(tester);
    _expectLoaded(tester);
    expect(tester.takeException(), isNull);
  });
}
