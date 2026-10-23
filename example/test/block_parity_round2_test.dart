import 'dart:io';
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:beui_example/demos/card_folder_demo.dart';
import 'package:beui_example/demos/feedback_widget_demo.dart';
import 'package:beui_example/demos/knockout_bracket_demo.dart';
import 'package:beui_example/demos/morphing_search_chips_demo.dart';
import 'package:beui_example/demos/number_demo.dart';
import 'package:beui_example/demos/prediction_market_demo.dart';
import 'package:beui_example/demos/prediction_market_card_demo.dart';
import 'package:beui_example/demos/text_animation_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget app(WidgetBuilder demo, {bool reduce = false, bool dark = true}) =>
    MaterialApp(
      theme: ThemeData(
        fontFamily: 'Geist',
        brightness: dark ? Brightness.dark : Brightness.light,
        extensions: [dark ? BeuiColors.dark() : BeuiColors.light()],
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: SingleChildScrollView(
              child: SizedBox(width: 592, child: Builder(builder: demo)),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'search backdrop fills both source rows and accepts a recent chip',
    (tester) async {
      await tester.pumpWidget(app(morphingSearchChipsDemo, reduce: true));
      await tester.pump(const Duration(seconds: 1));
      final cells = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient != null,
      );
      expect(cells, findsNWidgets(6));
      expect(tester.getSize(cells.first), const Size(178, 197));
      expect(
        tester.getRect(cells.at(3)).top - tester.getRect(cells.first).top,
        209,
      );
      expect(
        tester.getRect(cells.at(2)).left - tester.getRect(cells.first).left,
        380,
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('dashboards'), findsWidgets);
      await tester.tap(find.text('dashboards').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'dashboards'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'dark mode');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'dark mode'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rates artwork requests and natively decodes the real source SVG', (
    tester,
  ) async {
    final bytes = File('test/fixtures/federal_reserve.svg').readAsBytesSync();
    final requested = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          app(
            (_) => const SizedBox(
              width: 48,
              height: 48,
              child: MarketArtwork(
                url:
                    'https://upload.wikimedia.org/wikipedia/commons/7/73/Seal_of_the_United_States_Federal_Reserve_Board.svg',
                rates: true,
              ),
            ),
          ),
        );
        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        final info = await tester.runAsync(
          () => vg.loadPicture(picture.bytesLoader, null),
        );
        expect(
          requested,
          contains(
            'https://upload.wikimedia.org/wikipedia/commons/7/73/Seal_of_the_United_States_Federal_Reserve_Board.svg',
          ),
        );
        expect(info!.size, const Size(1, 1));
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(40);
        canvas.drawPicture(info.picture);
        final rendered = recorder.endRecording();
        final image = await tester.runAsync(() => rendered.toImage(40, 40));
        final rgba = (await tester.runAsync(
          () => image!.toByteData(),
        ))!.buffer.asUint8List();
        final opaque = <int>[
          for (var i = 3; i < rgba.length; i += 4)
            if (rgba[i] > 0) i,
        ];
        expect(opaque.length, inInclusiveRange(500, 1500));
        image!.dispose();
        rendered.dispose();
        info.picture.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        requested.add(request.url.toString());
        return http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'image/svg+xml'},
        );
      }),
    );
  });

  for (final reduce in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'card privacy and layers remain independent, dark=$dark reduce=$reduce',
        (tester) async {
          await tester.pumpWidget(
            app(cardFolderDemo, reduce: reduce, dark: dark),
          );
          await tester.tap(find.bySemanticsLabel('Show card details'));
          await tester.pumpAndSettle();
          final numbers = find.byWidgetPredicate(
            (w) => w is BeuiDigitSwap && w.value == '3745 6987 4096 0806',
          );
          expect(numbers, findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            expect(
              tester
                  .widgetList<Text>(
                    find.descendant(
                      of: numbers.at(i),
                      matching: find.byType(Text),
                    ),
                  )
                  .map((w) => w.data ?? '')
                  .join(),
              '3745698740960806',
            );
          }
          final cvvs = find.byWidgetPredicate(
            (w) => w is BeuiDigitSwap && w.value == '123',
          );
          expect(cvvs, findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            expect(
              tester
                  .widgetList<Text>(
                    find.descendant(
                      of: cvvs.at(i),
                      matching: find.byType(Text),
                    ),
                  )
                  .map((w) => w.data ?? '')
                  .join(),
              '123',
            );
          }
          expect(
            find.bySemanticsLabel(
              'Open Saurabh Chauhan, card ending in 0806, expires 08/29',
            ),
            findsOneWidget,
          );
          await tester.tap(find.bySemanticsLabel('Hide card details'));
          await tester.pumpAndSettle();
          final masked = find.byWidgetPredicate(
            (w) => w is BeuiDigitSwap && w.value == '•••• •••• •••• 0806',
          );
          expect(masked, findsNWidgets(2));
          expect(
            tester
                .widgetList<Text>(
                  find.descendant(
                    of: masked.first,
                    matching: find.byType(Text),
                  ),
                )
                .map((w) => w.data ?? '')
                .join(),
            '••••••••••••0806',
          );
          await tester.tap(find.byType(BeuiCardFolder));
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(
              'Close Saurabh Chauhan, card ending in 0806, expires 08/29',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'feedback matches source default and retries the rejected draft',
    (tester) async {
      await tester.pumpWidget(app(feedbackWidgetDemo));
      await tester.tap(find.byIcon(LucideIcons.message_square));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('How was your experience?'), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        'The native SVG is visible',
      );
      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 901));
      final expectedPreviewError = tester.takeException();
      expect(
        expectedPreviewError.toString(),
        contains('Preview submission failed'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'The native SVG is visible',
      );
      await tester.pump(const Duration(milliseconds: 901));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Thanks!'), findsOneWidget);
      expect(
        find.text('Last submission received: "The native SVG is visible"'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'secondary trade ticket uses controlled source order and quick amounts',
    (tester) async {
      await tester.pumpWidget(app(predictionMarketDemo));
      await tester.pump(const Duration(seconds: 1));
      var ticket = tester.widget<BeuiPredictionMarket>(
        find.byType(BeuiPredictionMarket),
      );
      expect(ticket.value!.amount, '115');
      expect(find.text('Yes 16.7¢'), findsOneWidget);
      await tester.tap(find.text('+\$10'));
      await tester.pump(const Duration(milliseconds: 400));
      ticket = tester.widget<BeuiPredictionMarket>(
        find.byType(BeuiPredictionMarket),
      );
      expect(ticket.value!.amount, '125');
      await tester.tap(find.text('Sell'));
      await tester.pump(const Duration(milliseconds: 400));
      ticket = tester.widget<BeuiPredictionMarket>(
        find.byType(BeuiPredictionMarket),
      );
      expect(ticket.value!.mode, BeuiPredictionMarketMode.sell);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'number secondary examples and all text examples mount with their source data',
    (tester) async {
      await tester.pumpWidget(app(numberDemo, reduce: true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BeuiNumberTicker), findsOneWidget);
      expect(find.bySemanticsLabel('48,273'), findsOneWidget);
      expect(find.text('\$129,480'), findsOneWidget);
      await tester.tap(find.text('Animate'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.bySemanticsLabel('4242 4242 4242 0806'), findsOneWidget);
      await tester.pumpWidget(app(textAnimationDemo, reduce: true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BeuiTextScramble), findsOneWidget);
      expect(find.byType(BeuiChromaticTextReveal), findsOneWidget);
      expect(find.byType(BeuiTextReveal), findsNWidgets(2));
      expect(find.byType(BeuiTextShimmer), findsNWidgets(2));
      expect(find.byType(BeuiTextCascade), findsOneWidget);
      await tester.tap(find.text('Next phrase'));
      await tester.pump();
      expect(find.text('Running the checks'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('fixtures include wheel and bracket compositions', (
    tester,
  ) async {
    await tester.pumpWidget(app(knockoutBracketDemo, reduce: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BeuiKnockoutWheel), findsOneWidget);
    expect(find.byType(BeuiKnockoutBracket), findsOneWidget);
    expect(find.text('Final'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
