import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('BeuiThinkingShimmer public constructors', () {
    testWidgets('keeps the const string API and its default values', (
      tester,
    ) async {
      const BeuiThinkingShimmer widget = BeuiThinkingShimmer();
      final String publicText = widget.text;

      expect(publicText, 'Thinking…');
      expect(widget.duration, const Duration(milliseconds: 1800));
      expect(widget.style, isNull);

      await tester.pumpWidget(beuiTestApp(widget));
      expect(find.text('Thinking…'), findsOneWidget);
    });

    testWidgets('keeps legacy ambient style selection and forced medium', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          DefaultTextStyle(
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w300),
            textAlign: TextAlign.right,
            child: const BeuiThinkingShimmer(text: 'Reviewing'),
          ),
        ),
      );

      final shimmer = tester.widget<BeuiTextShimmer>(
        find.byType(BeuiTextShimmer),
      );
      expect(shimmer.text, 'Reviewing');
      expect(shimmer.duration, const Duration(milliseconds: 1800));
      expect(shimmer.style?.fontSize, 19);
      expect(shimmer.style?.fontWeight, FontWeight.w500);
      expect(find.text('Reviewing'), findsOneWidget);
    });

    testWidgets('retains explicit legacy duration, style, and wrapper key', (
      tester,
    ) async {
      const key = ValueKey('legacy-thinking');
      const style = TextStyle(fontSize: 23, fontWeight: FontWeight.w700);
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer(
            text: 'Planning',
            duration: Duration(seconds: 3),
            style: style,
            key: key,
          ),
        ),
      );

      final shimmer = tester.widget<BeuiTextShimmer>(
        find.byType(BeuiTextShimmer),
      );
      expect(tester.widget<BeuiThinkingShimmer>(find.byKey(key)).key, key);
      expect(shimmer.duration, const Duration(seconds: 3));
      expect(shimmer.style?.fontSize, 23);
      expect(shimmer.style?.fontWeight, FontWeight.w500);
      expect(shimmer.text, 'Planning');
    });

    testWidgets('child constructor has empty compatibility text and defaults', (
      tester,
    ) async {
      const widget = BeuiThinkingShimmer.child(Text('Thinking richly'));
      expect(widget.text, '');
      expect(widget.duration, const Duration(milliseconds: 1800));
      expect(widget.style, isNull);

      await tester.pumpWidget(beuiTestApp(widget));
      expect(find.text('Thinking richly'), findsOneWidget);
      expect(find.text(''), findsNothing);
      expect(
        tester.widget<BeuiTextShimmer>(find.byType(BeuiTextShimmer)).duration,
        const Duration(milliseconds: 1800),
      );
    });

    testWidgets('child constructor forwards custom duration, style, and key', (
      tester,
    ) async {
      const key = ValueKey('child-thinking');
      const style = TextStyle(fontSize: 21, letterSpacing: 1.5);
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer.child(
            Text('Custom child'),
            duration: Duration(milliseconds: 900),
            style: style,
            key: key,
          ),
        ),
      );

      final shimmer = tester.widget<BeuiTextShimmer>(
        find.byType(BeuiTextShimmer),
      );
      expect(tester.widget<BeuiThinkingShimmer>(find.byKey(key)).key, key);
      expect(shimmer.duration, const Duration(milliseconds: 900));
      expect(shimmer.style?.fontSize, 21);
      expect(shimmer.style?.letterSpacing, 1.5);
      expect(shimmer.style?.fontWeight, FontWeight.w500);
      expect(find.text('Custom child'), findsOneWidget);
    });

    testWidgets('rich spans render their literal content', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer.child(
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Working '),
                  TextSpan(
                    text: 'carefully',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' now'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Working carefully now'), findsOneWidget);
      final rich = tester.widget<RichText>(find.byType(RichText).last);
      expect(rich.text.toPlainText(), 'Working carefully now');
    });

    testWidgets('adds no second mask or repaint boundary around delegation', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiThinkingShimmer.child(Text('One engine'))),
      );

      final thinking = find.byType(BeuiThinkingShimmer);
      expect(
        find.descendant(of: thinking, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: thinking, matching: find.byType(RepaintBoundary)),
        findsOneWidget,
      );
    });

    testWidgets('child inherits medium style and ambient alignment', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          DefaultTextStyle(
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
            textAlign: TextAlign.center,
            child: const BeuiThinkingShimmer.child(Text('Inherited')),
          ),
        ),
      );

      final textContext = tester.element(find.text('Inherited'));
      final inherited = DefaultTextStyle.of(textContext);
      expect(inherited.style.fontSize, 18);
      expect(inherited.style.fontWeight, FontWeight.w500);
      expect(inherited.textAlign, TextAlign.center);
    });

    testWidgets('explicit descendant style keeps normal precedence', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer.child(
            Text('Explicit', style: TextStyle(fontWeight: FontWeight.w700)),
            style: TextStyle(fontSize: 20),
          ),
        ),
      );

      final textContext = tester.element(find.text('Explicit'));
      final inherited = DefaultTextStyle.of(textContext);
      final rendered = tester.widget<RichText>(find.byType(RichText).last);
      expect(inherited.style.fontWeight, FontWeight.w500);
      expect(inherited.style.fontSize, 20);
      expect(rendered.text.style?.fontWeight, FontWeight.w700);
      expect(rendered.text.style?.fontSize, 20);
    });

    testWidgets('explicit wrapper child weight overrides the medium default', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer.child(
            Text('Custom weight'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
      final rendered = tester.widget<RichText>(find.byType(RichText).last);
      expect(rendered.text.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('long RTL text stays inside narrow bounds', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: const SizedBox(
                width: 96,
                child: BeuiThinkingShimmer.child(
                  Text('جارٍ تحليل الطلب والاستعداد للإجابة'),
                  style: TextStyle(fontSize: 28),
                ),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(BeuiThinkingShimmer));
      expect(size.width, 96);
      expect(size.height, greaterThan(28));
      expect(find.text('جارٍ تحليل الطلب والاستعداد للإجابة'), findsOneWidget);
      final rendered = tester.widget<RichText>(find.byType(RichText).last);
      expect(
        tester
            .renderObject<RenderParagraph>(find.byType(RichText).last)
            .textDirection,
        TextDirection.rtl,
      );
      expect(rendered.textScaler.scale(28), 42);
    });

    testWidgets('child retains one semantics label and button action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var activations = 0;
        await tester.pumpWidget(
          beuiTestApp(
            BeuiThinkingShimmer.child(
              TextButton(
                onPressed: () => activations++,
                child: const Text('Open details'),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Open details'), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        final node = tester.getSemantics(find.bySemanticsLabel('Open details'));
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        expect(activations, 1);
        await tester.tap(find.text('Open details'));
        expect(activations, 2);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('real Tab focus, Enter, and pointer activation reach child', (
      tester,
    ) async {
      var activations = 0;
      final focus = FocusNode(debugLabel: 'Thinking child activation');
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          BeuiThinkingShimmer.child(
            TextButton(
              focusNode: focus,
              onPressed: () => activations++,
              child: const Text('Activate'),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activations, 1);
      await tester.tap(find.text('Activate'));
      expect(activations, 2);
    });

    testWidgets('same-key replacement and string-child-string updates render', (
      tester,
    ) async {
      const key = ValueKey('replaceable-thinking');
      Widget string(String value) => BeuiThinkingShimmer(text: value, key: key);
      Widget child(String value) =>
          BeuiThinkingShimmer.child(Text(value), key: key);

      await tester.pumpWidget(beuiTestApp(string('String one')));
      expect(find.text('String one'), findsOneWidget);
      await tester.pumpWidget(beuiTestApp(child('Child one')));
      expect(find.text('String one'), findsNothing);
      expect(find.text('Child one'), findsOneWidget);
      await tester.pumpWidget(beuiTestApp(child('Child two')));
      expect(find.text('Child one'), findsNothing);
      expect(find.text('Child two'), findsOneWidget);
      await tester.pumpWidget(beuiTestApp(string('String two')));
      expect(find.text('Child two'), findsNothing);
      expect(find.text('String two'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keyed child reuse, replacement, and removal retain lifecycle',
      (tester) async {
        final mounted = <String>[];
        final disposed = <String>[];
        Widget host(String label, Key childKey) => beuiTestApp(
          BeuiThinkingShimmer.child(
            _LifecycleChild(
              key: childKey,
              label: label,
              onMount: mounted.add,
              onDispose: disposed.add,
            ),
            key: const ValueKey('lifecycle-thinking'),
          ),
        );

        await tester.pumpWidget(host('First', const ValueKey('first-child')));
        await tester.pumpWidget(host('Updated', const ValueKey('first-child')));
        expect(mounted, ['First']);
        expect(disposed, isEmpty);
        expect(find.text('Updated'), findsOneWidget);
        await tester.pumpWidget(host('Second', const ValueKey('second-child')));
        expect(mounted, ['First', 'Second']);
        expect(disposed, ['Updated']);
        expect(find.text('Updated'), findsNothing);
        expect(find.text('Second'), findsOneWidget);
        await tester.pumpWidget(
          beuiTestApp(
            const BeuiThinkingShimmer(
              text: 'String again',
              key: ValueKey('lifecycle-thinking'),
            ),
          ),
        );
        expect(disposed, ['Updated', 'Second']);
        expect(find.text('Second'), findsNothing);
        expect(find.text('String again'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(disposed, ['Updated', 'Second']);
      },
    );

    testWidgets('duration update is forwarded and reduced motion can change', (
      tester,
    ) async {
      Widget build(Duration duration, {required bool reduce}) => beuiTestApp(
        BeuiThinkingShimmer.child(const Text('Updating'), duration: duration),
        reduce: reduce,
      );

      await tester.pumpWidget(build(const Duration(seconds: 2), reduce: false));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(build(const Duration(seconds: 4), reduce: false));
      expect(
        tester.widget<BeuiTextShimmer>(find.byType(BeuiTextShimmer)).duration,
        const Duration(seconds: 4),
      );
      await tester.pumpWidget(build(const Duration(seconds: 4), reduce: true));
      await tester.pump();
      expect(find.text('Updating'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(build(const Duration(seconds: 4), reduce: false));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(find.text('Updating'), findsOneWidget);
    });

    testWidgets('unmount during a sweep disposes without ticker errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiThinkingShimmer.child(Text('Unmount'))),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Unmount'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'delegated shader matches direct shared child at fixed samples',
      (tester) async {
        Future<List<int>> capture(Widget widget) async {
          await tester.pumpWidget(
            beuiTestApp(
              widget,
              extensions: [
                BeuiColors.light().copyWith(
                  mutedForeground: Colors.black,
                  foreground: Colors.white,
                ),
              ],
            ),
          );
          await tester.pump();
          // 450ms is one quarter of the 1800ms ThinkingShimmer period.
          await tester.pump(const Duration(milliseconds: 450));
          const bounds = Rect.fromLTWH(0, 0, 200, 24);
          final shader = tester
              .widget<ShaderMask>(find.byType(ShaderMask))
              .shaderCallback(bounds);
          late List<int> row;
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            Canvas(recorder, bounds).drawRect(bounds, Paint()..shader = shader);
            final image = await recorder.endRecording().toImage(200, 24);
            final bytes = (await image.toByteData())!;
            row = [
              for (final x in [0, 40, 80, 100])
                bytes.getUint8(((12 * 200) + x) * 4),
            ];
            image.dispose();
          });
          await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
          return row;
        }

        const child = Text('Loading', style: TextStyle(fontSize: 16));
        final wrapperSamples = await capture(
          const BeuiThinkingShimmer.child(
            child,
            style: TextStyle(fontSize: 16),
            duration: Duration(milliseconds: 1800),
          ),
        );
        final directSamples = await capture(
          const BeuiTextShimmer.child(
            child,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            duration: Duration(milliseconds: 1800),
          ),
        );

        expect(wrapperSamples[0], closeTo(253, 2));
        expect(wrapperSamples[1], closeTo(133, 3));
        expect(wrapperSamples[2], closeTo(13, 3));
        expect(wrapperSamples[3], 0);
        expect(wrapperSamples, directSamples);
      },
    );
  });
}

class _LifecycleChild extends StatefulWidget {
  const _LifecycleChild({
    required this.label,
    required this.onMount,
    required this.onDispose,
    super.key,
  });

  final String label;
  final ValueChanged<String> onMount;
  final ValueChanged<String> onDispose;

  @override
  State<_LifecycleChild> createState() => _LifecycleChildState();
}

class _LifecycleChildState extends State<_LifecycleChild> {
  @override
  void initState() {
    super.initState();
    widget.onMount(widget.label);
  }

  @override
  void dispose() {
    widget.onDispose(widget.label);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
