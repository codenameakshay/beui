import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

/// Hosts a [BeuiImageGeneration] in a 320px-wide, light-themed [MaterialApp].
Widget _host({
  Widget? child,
  BeuiImageGenerationStatus status = BeuiImageGenerationStatus.generating,
  String? label,
  String? prompt,
  String? resolution = '1024 × 1024',
  double aspectRatio = 1,
  BeuiImageGenerationSize size = BeuiImageGenerationSize.compact,
  bool interactive = true,
  String? statusText,
  bool showStatus = true,
  double? progress,
  VoidCallback? onCancel,
  VoidCallback? onRetry,
  bool reserveErrorSlot = true,
  bool reduce = false,
}) {
  final generation = BeuiImageGeneration(
    status: status,
    label: label,
    prompt: prompt,
    resolution: resolution,
    aspectRatio: aspectRatio,
    size: size,
    interactive: interactive,
    statusText: statusText,
    showStatus: showStatus,
    progress: progress,
    onCancel: onCancel,
    onRetry: onRetry,
    reserveErrorSlot: reserveErrorSlot,
    child: child,
  );
  return beuiTestApp(generation, width: 320, reduce: reduce);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeuiImageGeneration', () {
    testWidgets('renders default generating status text', (tester) async {
      await tester.pumpWidget(_host());
      // Continuous dither ticker — pump once, avoid pumpAndSettle.
      await tester.pump();

      expect(find.text('Generating image'), findsOneWidget);
      expect(find.text('1024 × 1024'), findsOneWidget);
    });

    testWidgets('maps each status to its default label', (tester) async {
      const expected = {
        BeuiImageGenerationStatus.queued: 'Waiting to generate',
        BeuiImageGenerationStatus.generating: 'Generating image',
        BeuiImageGenerationStatus.refining: 'Refining details',
        BeuiImageGenerationStatus.complete: 'Image ready',
        BeuiImageGenerationStatus.error: 'Generation failed',
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(_host(status: entry.key));
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('shows check icon when complete', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiImageGenerationStatus.complete),
      );
      await tester.pump();

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Image ready'), findsOneWidget);
    });

    testWidgets('shows alert icon and retry on error', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.error,
          onRetry: () => retried = true,
        ),
      );
      await tester.pump();

      expect(find.byIcon(LucideIcons.circle_alert), findsOneWidget);
      expect(find.text('Generation failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('hides retry when onRetry is null on error', (tester) async {
      await tester.pumpWidget(_host(status: BeuiImageGenerationStatus.error));
      await tester.pump();

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders prompt under status', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.complete,
          prompt: 'a quiet mountain landscape at sunset',
        ),
      );
      await tester.pump();

      expect(
        find.text('“a quiet mountain landscape at sunset”'),
        findsOneWidget,
      );
    });

    testWidgets('statusText overrides default label', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.generating,
          statusText: 'Cooking pixels',
        ),
      );
      await tester.pump();

      expect(find.text('Cooking pixels'), findsOneWidget);
      expect(find.text('Generating image'), findsNothing);
    });

    testWidgets('showStatus false hides status row but keeps prompt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.complete,
          showStatus: false,
          prompt: 'still visible',
        ),
      );
      await tester.pump();

      expect(find.text('Image ready'), findsNothing);
      expect(find.text('“still visible”'), findsOneWidget);
    });

    testWidgets('hides resolution badge when null', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiImageGenerationStatus.complete, resolution: null),
      );
      await tester.pump();

      expect(find.text('1024 × 1024'), findsNothing);
    });

    testWidgets('renders child media without layout shift across statuses', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.generating,
          child: ColoredBox(
            key: key,
            color: const Color(0xFF336699),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      final sizeWhileGenerating = tester.getSize(find.byKey(key).first);

      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.complete,
          child: ColoredBox(
            key: key,
            color: const Color(0xFF336699),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      final sizeWhenComplete = tester.getSize(find.byKey(key).first);

      expect(sizeWhileGenerating, equals(sizeWhenComplete));
      expect(sizeWhenComplete.width, greaterThan(0));
      expect(sizeWhenComplete.height, closeTo(sizeWhenComplete.width, 0.5));
    });

    testWidgets('compact size caps frame width at 208', (tester) async {
      const mediaKey = Key('media');
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.complete,
          size: BeuiImageGenerationSize.compact,
          child: const ColoredBox(
            key: mediaKey,
            color: Color(0xFF445566),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      final media = tester.getSize(find.byKey(mediaKey));
      expect(media.width, lessThanOrEqualTo(208 + 0.5));
      expect(media.height, closeTo(media.width, 0.5));
    });

    testWidgets('fluid size uses full parent width', (tester) async {
      const mediaKey = Key('media');
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.complete,
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(
            key: mediaKey,
            color: Color(0xFF112233),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      final media = tester.getSize(find.byKey(mediaKey));
      expect(media.width, closeTo(320, 1));
    });

    testWidgets('semantics expose image label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.generating,
          label: 'A quiet mountain landscape at sunset',
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('A quiet mountain landscape at sunset'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('BeuiImageGeneration progress', () {
    /// Fraction of the frame the determinate fill covers.
    double? fillFactor(WidgetTester tester) {
      final boxes = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      return boxes.isEmpty ? null : boxes.first.widthFactor;
    }

    testWidgets('an indeterminate run shows no hairline', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
        ),
      );
      await pumpFrames(tester, 30);
      expect(fillFactor(tester), isNull);
    });

    testWidgets('a determinate run shows one, sized to the fraction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          progress: 0.4,
        ),
      );
      await pumpFrames(tester, 30);
      expect(fillFactor(tester), moreOrLessEquals(0.4, epsilon: 0.01));
    });

    testWidgets('out-of-range values are clamped rather than overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          progress: 4,
        ),
      );
      await pumpFrames(tester, 30);
      expect(fillFactor(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hairline goes away once the work is done', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.complete,
          progress: 1,
        ),
      );
      await pumpFrames(tester, 30);
      expect(fillFactor(tester), isNull);
    });

    testWidgets('progress is spoken, not only drawn', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          progress: 0.42,
          prompt: 'a quiet mountain',
        ),
      );
      await pumpFrames(tester, 30);
      // Four words and a spinner across a 10-60s operation is the canonical
      // "is it frozen?" surface — for a screen reader most of all.
      expect(
        find.bySemanticsLabel('Generating image, 42%: a quiet mountain'),
        findsOneWidget,
      );
      expect(find.text('Generating image · 42%'), findsOneWidget);
      handle.dispose();
    });
  });

  group('BeuiImageGeneration cancel', () {
    testWidgets('no stop control without a handler', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
        ),
      );
      await pumpFrames(tester, 30);
      expect(find.byIcon(LucideIcons.square), findsNothing);
    });

    testWidgets('a stop control appears in-frame while active', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          onCancel: () {},
        ),
      );
      await pumpFrames(tester, 30);
      expect(find.byIcon(LucideIcons.square), findsOneWidget);
    });

    testWidgets('and goes away once there is nothing to stop', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.complete,
          onCancel: () {},
        ),
      );
      await pumpFrames(tester, 30);
      expect(find.byIcon(LucideIcons.square), findsNothing);
    });

    testWidgets('it fires, is labelled, and is keyboard-reachable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var cancels = 0;
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          onCancel: () => cancels++,
        ),
      );
      await pumpFrames(tester, 30);

      expect(find.bySemanticsLabel('Stop generating'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.square));
      await tester.pump();
      expect(cancels, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFrames(tester, 30);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(cancels, 2);
      handle.dispose();
    });

    testWidgets('the 24px control accepts a touch that misses it', (
      tester,
    ) async {
      var cancels = 0;
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          onCancel: () => cancels++,
        ),
      );
      await pumpFrames(tester, 30);
      final centre = tester.getCenter(find.byIcon(LucideIcons.square));
      await tester.tapAt(centre + const Offset(0, 18));
      await tester.pump();
      expect(cancels, 1);
    });
  });

  group('BeuiImageGeneration error costs no layout shift', () {
    testWidgets('the retry slot is held open on every status', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          onRetry: () {},
        ),
      );
      await pumpFrames(tester, 30);
      final generating = tester.getSize(find.byType(BeuiImageGeneration));

      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.error,
          onRetry: () {},
        ),
      );
      await pumpFrames(tester, 30);
      // The component reserves its media frame with AspectRatio; the error
      // branch was the one place it forgot, and appended 52px.
      expect(tester.getSize(find.byType(BeuiImageGeneration)), generating);
    });

    testWidgets('the reserved slot is inert until the failure arrives', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          onRetry: () => retries++,
        ),
      );
      await pumpFrames(tester, 30);
      await tester.tap(find.text('Retry'), warnIfMissed: false);
      await tester.pump();
      expect(retries, 0);
    });

    testWidgets('and live once it does', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.error,
          onRetry: () => retries++,
        ),
      );
      await pumpFrames(tester, 30);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('reserveErrorSlot: false gives the 52px back', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          onRetry: () {},
          reserveErrorSlot: false,
        ),
      );
      await pumpFrames(tester, 30);
      final generating = tester.getSize(find.byType(BeuiImageGeneration));

      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.error,
          onRetry: () {},
          reserveErrorSlot: false,
        ),
      );
      await pumpFrames(tester, 30);
      expect(
        tester.getSize(find.byType(BeuiImageGeneration)).height,
        greaterThan(generating.height),
      );
    });
  });

  group('BeuiImageGeneration failure legibility', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    testWidgets('the failure line clears AA against the light surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.error,
        ),
      );
      await pumpFrames(tester, 30);
      final style = tester.widget<Text>(find.text('Generation failed')).style!;
      final colors = BeuiColors.light();
      // `destructive` is tuned as a fill and measured 3.94:1 as body text.
      expect(contrast(style.color!, colors.background), greaterThan(4.5));
    });

    testWidgets('and it is still recognisably the destructive hue', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.error,
        ),
      );
      await pumpFrames(tester, 30);
      final style = tester.widget<Text>(find.text('Generation failed')).style!;
      final colors = BeuiColors.light();
      expect(
        HSLColor.fromColor(style.color!).hue,
        moreOrLessEquals(
          HSLColor.fromColor(colors.destructive).hue,
          epsilon: 2,
        ),
      );
    });

    testWidgets('dark mode is left alone — it already passed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.dark().copyWith(extensions: [BeuiColors.dark()]),
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: BeuiImageGeneration(
                  status: BeuiImageGenerationStatus.error,
                ),
              ),
            ),
          ),
        ),
      );
      await pumpFrames(tester, 30);
      final style = tester.widget<Text>(find.text('Generation failed')).style!;
      expect(style.color, BeuiColors.dark().destructive);
    });
  });

  group('BeuiImageGeneration reduced motion', () {
    testWidgets('the reveal keeps its opacity channel', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.generating,
          reduce: true,
        ),
      );
      await pumpFrames(tester, 5);
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.complete,
          reduce: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final mid = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .where((o) => o > 0 && o < 1);
      // Movement snaps; the fade survives. It used to hard-cut.
      expect(mid, isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('but drops the movement channel', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.generating,
          reduce: true,
        ),
      );
      await pumpFrames(tester, 5);
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
          status: BeuiImageGenerationStatus.complete,
          reduce: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiImageGeneration),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0]);
      // The 1.015 → 1 scale snaps rather than easing.
      expect(scales.every((s) => (s - 1).abs() < 0.001), isTrue);
    });
  });

  group('BeuiImageGeneration dither field cost', () {
    testWidgets('the painter repaints without rebuilding the widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
        ),
      );
      await tester.pump();

      CustomPaint field() => tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(BeuiImageGeneration),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      final first = field();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Identity, not equality: a setState per tick would build a new widget
      // every frame — about 2,700 circles' worth of rebuild at 500px square.
      expect(identical(field(), first), isTrue);
    });

    testWidgets('and it paints inside a RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        _host(
          size: BeuiImageGenerationSize.fluid,
          child: const ColoredBox(color: Color(0xFF335577)),
        ),
      );
      await tester.pump();
      expect(
        find.ancestor(
          of: find
              .descendant(
                of: find.byType(BeuiImageGeneration),
                matching: find.byType(CustomPaint),
              )
              .first,
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });
}
