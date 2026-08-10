import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  VoidCallback? onRetry,
  bool reduce = false,
}) {
  Widget body = Center(
    child: SizedBox(
      width: 320,
      child: BeuiImageGeneration(
        status: status,
        label: label,
        prompt: prompt,
        resolution: resolution,
        aspectRatio: aspectRatio,
        size: size,
        interactive: interactive,
        statusText: statusText,
        showStatus: showStatus,
        onRetry: onRetry,
        child: child,
      ),
    ),
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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
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
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('hides retry when onRetry is null on error', (tester) async {
      await tester.pumpWidget(_host(status: BeuiImageGenerationStatus.error));
      await tester.pump();

      expect(find.text('Try again'), findsNothing);
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

    testWidgets('reduced motion still shows complete media', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiImageGenerationStatus.complete,
          reduce: true,
          child: const ColoredBox(
            color: Color(0xFFAABBCC),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Image ready'), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
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
}
