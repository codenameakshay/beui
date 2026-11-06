import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadMinesTestFonts);

  group('Mines payout', () {
    test('matches source odds and multiplier formatting', () {
      expect(beuiMinesMultiplier(25, 3, 1), 1.1363636363636365);
      expect(beuiMinesMultiplier(25, 3, 2), 1.2987012987012987);
      expect(beuiMinesMultiplier(9, 2, 1), 1.2857142857142858);
      expect(beuiMinesMultiplier(25, 3, 100), closeTo(2300, 1e-9));
      expect(beuiMinesMultiplier(4, 1, 3), 4);
      expect(beuiMinesMultiplier(4, 10, 4), 4);
      expect(beuiMinesMultiplier(25, 0, 24), 1);
      expect(beuiFormatMinesMultiplier(2.5), '2.50×');
      expect(beuiFormatMinesMultiplier(10000), '10K×');
      expect(beuiFormatMinesMultiplier(999999), '1M×');
      expect(beuiFormatMinesMultiplier(1.3e18), '1.3E18×');
    });
  });

  group('MinesRound', () {
    test(
      'places a fixed number of mines at start and reports one bust once',
      () {
        final round = MinesRound(size: 3, mineCount: 2);
        expect(round.phase, BeuiMinesPhase.idle);
        expect(round.mines, isEmpty);

        round.start(Random(8));
        final board = round.mines;
        expect(board.length, 2);
        expect(round.phase, BeuiMinesPhase.playing);

        final hit = round.reveal(board.first)!;
        expect(hit.tile, board.first);
        expect(hit.result, BeuiMinesTile.mine);
        expect(hit.multiplier, 0);
        expect(hit.completedRound, isTrue);
        expect(round.phase, BeuiMinesPhase.busted);
        expect(round.mines, board);
        expect(round.reveal(board.first), isNull);
        expect(round.cashOut(), isNull);
      },
    );

    test('safe picks calculate odds and cash out only after a gem', () {
      final round = MinesRound(size: 3, mineCount: 2)..start(Random(4));
      expect(round.cashOut(), isNull);

      final safeTile = List<int>.generate(
        9,
        (index) => index,
      ).firstWhere((tile) => !round.mines.contains(tile));
      final pick = round.reveal(safeTile)!;
      expect(pick.result, BeuiMinesTile.gem);
      expect(pick.multiplier, 1.2857142857142858);
      expect(pick.gems, 1);
      expect(round.reveal(safeTile), isNull);

      final payout = round.cashOut()!;
      expect(payout.multiplier, 1.2857142857142858);
      expect(payout.gems, 1);
      expect(round.phase, BeuiMinesPhase.cashed);
    });

    test('reveal callbacks retain pick order through a later bust', () {
      final round = MinesRound(size: 3, mineCount: 1)..start(Random(11));
      final safe = List<int>.generate(
        9,
        (index) => index,
      ).firstWhere((tile) => !round.mines.contains(tile));
      final mine = round.mines.single;
      final callbacks = <(int, BeuiMinesTile, double)>[];

      final first = round.reveal(safe)!;
      callbacks.add((first.tile, first.result, first.multiplier));
      final second = round.reveal(mine)!;
      callbacks.add((second.tile, second.result, second.multiplier));

      expect(callbacks, [
        (safe, BeuiMinesTile.gem, 1.125),
        (mine, BeuiMinesTile.mine, 0),
      ]);
      expect(round.reveal(mine), isNull);
    });

    test('finding every safe tile automatically completes the round', () {
      final round = MinesRound(size: 2, mineCount: 3)..start(Random(2));
      final safeTile = List<int>.generate(
        4,
        (index) => index,
      ).firstWhere((tile) => !round.mines.contains(tile));

      final pick = round.reveal(safeTile)!;
      expect(pick.result, BeuiMinesTile.gem);
      expect(pick.multiplier, 4);
      expect(pick.completedRound, isTrue);
      expect(round.phase, BeuiMinesPhase.cashed);
      expect(round.cashOut(), isNull);
    });
  });

  group('BeuiMines', () {
    testWidgets(
      'public composition keeps source mine-count and ticker values',
      (tester) async {
        await _pumpMines(tester);

        final stepper = tester.widget<BeuiAdaptiveStepper>(
          find.byType(BeuiAdaptiveStepper),
        );
        final value = stepper.children
            .whereType<BeuiAdaptiveStepperValue>()
            .single;
        expect(value.builder, isNotNull);

        final valueContent = find.descendant(
          of: find.byType(BeuiAdaptiveStepperValue),
          matching: find.byType(Row),
        );
        final customValue = tester.widget<Row>(valueContent);
        expect(customValue.mainAxisSize, MainAxisSize.min);
        expect(customValue.children, hasLength(3));
        final mineGlyph = customValue.children[0] as CustomPaint;
        expect(mineGlyph.size, const Size(16, 16));
        expect(mineGlyph.painter, isA<CustomPainter>());
        expect((customValue.children[1] as SizedBox).width, 6);
        expect((customValue.children[2] as Text).data, '3');
        final glyph = find.descendant(
          of: valueContent,
          matching: find.byType(CustomPaint),
        );
        final numeral = find.descendant(
          of: valueContent,
          matching: find.text('3'),
        );
        expect(tester.getSize(glyph), const Size(16, 16));
        expect(tester.getTopLeft(numeral).dx - tester.getTopRight(glyph).dx, 6);

        final ticker = tester.widget<BeuiNumberTicker>(
          find.byType(BeuiNumberTicker),
        );
        expect(ticker.value, 1);
        expect(ticker.decimals, 2);
        expect(ticker.format, isNull);
        expect(ticker.formatNumber, isNotNull);
        expect(ticker.duration, const Duration(milliseconds: 350));
        expect(ticker.suffix, '×');

        await tester.tap(find.bySemanticsLabel('Increase value'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BeuiAdaptiveStepperValue),
            matching: find.text('4'),
          ),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Mine count')).value,
          '4 mines',
        );
      },
    );

    testWidgets('tile focus moves with arrows and Home/End within a row', (
      tester,
    ) async {
      await _pumpMines(tester);
      final first = tester.widget<Focus>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Focus && widget.focusNode?.debugLabel == 'Mines tile 1',
        ),
      );
      first.focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Mines tile 2');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Mines tile 5');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Mines tile 1');
    });

    testWidgets('Enter reveals the focused tile and reports one callback', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();

      final first = tester.widget<Focus>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Focus && widget.focusNode?.debugLabel == 'Mines tile 1',
        ),
      );
      first.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(reveals, hasLength(1));
      expect(reveals.single.$1, 0);
      expect(reveals.single.$2, anyOf(BeuiMinesTile.gem, BeuiMinesTile.mine));
    });

    testWidgets('touch activation reports one pick and ignores its duplicate', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      final tile = find.byKey(const ValueKey('mines-tile-0'));
      await tester.tap(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();

      expect(reveals, hasLength(1));
      expect(reveals.single.$1, 0);
      expect(reveals.single.$2, anyOf(BeuiMinesTile.gem, BeuiMinesTile.mine));
      if (reveals.single.$2 == BeuiMinesTile.mine) {
        expect(reveals.single.$3, 0);
      } else {
        expect(reveals.single.$3, 1.1363636363636365);
      }
    });

    testWidgets('sound preference calls back without claiming playback', (
      tester,
    ) async {
      final changes = <bool>[];
      await _pumpMines(tester, widget: BeuiMines(onSoundChange: changes.add));

      await tester.tap(find.byKey(const ValueKey('mines-sound')));
      await tester.pump();
      expect(changes, [true]);
      expect(find.bySemanticsLabel('Sound'), findsOneWidget);
    });

    testWidgets(
      'result delays until reveal settles, disables the board, and closes on Escape',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpMines(tester);
        await tester.tap(find.text('Start'));
        await tester.pump();

        for (var tile = 0; tile < 25; tile++) {
          if (find.text('Play again').evaluate().isNotEmpty) break;
          await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(find.text('Play again'), findsOneWidget);
        expect(find.bySemanticsLabel('Round result'), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Row [1-5], column [1-5], gem, not picked'),
          ),
          findsWidgets,
        );

        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(const ValueKey('mines-result-card')), findsOneWidget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.bySemanticsLabel('Round result'), findsOneWidget);
        final boardLabels = <String>[];
        void collectLabels(SemanticsNode node) {
          boardLabels.add(node.label);
          node.visitChildren((child) {
            collectLabels(child);
            return true;
          });
        }

        collectLabels(
          tester.getSemantics(find.byKey(const ValueKey('mines-board'))),
        );
        expect(
          boardLabels.where(
            (label) => RegExp('Row [1-5], column').hasMatch(label),
          ),
          isEmpty,
        );
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'Mines main action',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.bySemanticsLabel('Round result'), findsNothing);
        expect(find.text('Play again'), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets(
      'outside input passes through while the in-board cover dismisses',
      (tester) async {
        tester.view.physicalSize = const Size(260, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        var outsideTaps = 0;
        final outsideFocus = FocusNode(debugLabel: 'Outside page action');
        addTearDown(outsideFocus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: _minesTestTheme(),
            home: Scaffold(
              body: Stack(
                children: [
                  Center(child: const BeuiMines()),
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: TextButton(
                      key: const ValueKey('outside-page-action'),
                      focusNode: outsideFocus,
                      onPressed: () => outsideTaps++,
                      child: const Text('Outside action'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('mines-board'))).width,
          260,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Start'));
        await tester.pump();
        for (var tile = 0; tile < 25; tile++) {
          if (find.text('Play again').evaluate().isNotEmpty) break;
          await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
          await tester.pump(const Duration(milliseconds: 1));
        }
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(const ValueKey('mines-result-card')), findsOneWidget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.bySemanticsLabel('Round result'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('outside-page-action')));
        await tester.pump();
        expect(outsideTaps, 1);
        outsideFocus.requestFocus();
        await tester.pump();
        expect(outsideFocus.hasFocus, isTrue);
        expect(find.bySemanticsLabel('Round result'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Hide result and show the board'),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(find.bySemanticsLabel('Round result'), findsOneWidget);
        expect(outsideFocus.hasFocus, isTrue);

        final board = tester.getRect(find.byKey(const ValueKey('mines-board')));
        await tester.tapAt(board.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.bySemanticsLabel('Round result'), findsNothing);
        expect(outsideTaps, 1);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'Mines main action',
        );
        await tester.tap(find.text('Play again'));
        await tester.pump();
        expect(find.text('Cash out 1.00×'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('size changes reset the round and rebuild the roving board', (
      tester,
    ) async {
      _useRoomyViewport(tester);
      final key = GlobalKey();
      Widget app(int size) => MaterialApp(
        theme: _minesTestTheme(),
        home: Scaffold(
          body: Center(
            child: BeuiMines(key: key, size: size),
          ),
        ),
      );

      await tester.pumpWidget(app(5));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Cash out 1.00×'), findsOneWidget);
      expect(find.byKey(const ValueKey('mines-tile-24')), findsOneWidget);

      await tester.pumpWidget(app(3));
      expect(find.byKey(const ValueKey('mines-tile-8')), findsOneWidget);
      expect(find.byKey(const ValueKey('mines-tile-9')), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning results off cancels a pending ticket entrance', (
      tester,
    ) async {
      _useRoomyViewport(tester);
      final key = GlobalKey();
      Widget app(bool showResult) => MaterialApp(
        theme: _minesTestTheme(),
        home: Scaffold(
          body: Center(
            child: BeuiMines(key: key, showResult: showResult),
          ),
        ),
      );

      await tester.pumpWidget(app(true));
      await tester.tap(find.text('Start'));
      await tester.pump();
      for (var tile = 0; tile < 25; tile++) {
        if (find.text('Play again').evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(find.text('Play again'), findsOneWidget);

      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 2));
      expect(find.bySemanticsLabel('Round result'), findsNothing);

      await tester.pumpWidget(app(true));
      expect(find.bySemanticsLabel('Round result'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('mines-result-card')), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.bySemanticsLabel('Round result'), findsOneWidget);
    });

    testWidgets('an interrupted entrance keeps its result card element', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      await _startNextRound(tester);
      for (var tile = 0; tile < 25; tile++) {
        if (find.text('Play again').evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      final pickedTiles = reveals.map((pick) => pick.$1).toSet();
      var outerRing = 0;
      for (var tile = 0; tile < 25; tile++) {
        if (pickedTiles.contains(tile)) continue;
        final ring = math.max(
          (tile ~/ 5 - reveals.last.$1 ~/ 5).abs(),
          (tile % 5 - reveals.last.$1 % 5).abs(),
        );
        outerRing = math.max(outerRing, ring);
      }
      final rippleMilliseconds = outerRing * 25 + 300;
      final pulseMilliseconds = reveals.last.$2 == BeuiMinesTile.gem
          ? (reveals.length - 1) * 40 + 350
          : 0;
      final closingMilliseconds = math.max(
        rippleMilliseconds,
        pulseMilliseconds,
      );
      expect(find.bySemanticsLabel('Round result'), findsNothing);
      await tester.pump(Duration(milliseconds: closingMilliseconds - 2));
      expect(find.byKey(const ValueKey('mines-result-card')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('mines-result-card')), findsOneWidget);
      await tester.pump();
      final cardElement = tester.element(
        find.byKey(const ValueKey('mines-result-card')),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        0,
      );
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('mines-result-enter-transform')),
            )
            .transform
            .getTranslation()
            .y,
        16,
      );
      expect(
        _maxXYScale(
          tester.widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-scale')),
          ),
        ),
        0.96,
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.bySemanticsLabel('Round result'), findsOneWidget);
      final enteringOpacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('mines-result-enter-opacity')),
          )
          .opacity;
      expect(enteringOpacity, closeTo(0.3190023051, 0.001));
      final enteringY = tester
          .widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-transform')),
          )
          .transform
          .getTranslation()
          .y;
      final enteringScale = _maxXYScale(
        tester.widget<Transform>(
          find.byKey(const ValueKey('mines-result-enter-scale')),
        ),
      );
      expect(enteringY, closeTo(10.8959631184, 0.001));
      expect(enteringScale, closeTo(0.9727600922, 0.001));
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('mines-board'))).center,
      );
      await tester.pump();

      expect(
        identical(
          cardElement,
          tester.element(find.byKey(const ValueKey('mines-result-card'))),
        ),
        isTrue,
      );
      final interruptedOpacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('mines-result-enter-opacity')),
          )
          .opacity;
      final interruptedY = tester
          .widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-transform')),
          )
          .transform
          .getTranslation()
          .y;
      final interruptedScale = _maxXYScale(
        tester.widget<Transform>(
          find.byKey(const ValueKey('mines-result-enter-scale')),
        ),
      );
      expect(interruptedOpacity, enteringOpacity);
      expect(interruptedY, enteringY);
      expect(interruptedScale, enteringScale);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const ValueKey('mines-result-card')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a controlled mine count takes effect on the next board', (
      tester,
    ) async {
      _useRoomyViewport(tester);
      final key = GlobalKey();
      Widget app(int mines) => MaterialApp(
        theme: _minesTestTheme(),
        home: Scaffold(
          body: Center(
            child: BeuiMines(key: key, mines: mines),
          ),
        ),
      );

      await tester.pumpWidget(app(3));
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pumpWidget(app(8));
      expect(find.text('88% safe · next 1.14×'), findsOneWidget);

      for (var tile = 0; tile < 25; tile++) {
        if (find.text('Play again').evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      await tester.tap(find.text('Play again'));
      await tester.pump();
      expect(find.text('68% safe · next 1.47×'), findsOneWidget);
    });

    testWidgets(
      'a bust reports zero while showing the earned multiplier lost',
      (tester) async {
        final reveals = <(int, BeuiMinesTile, double)>[];
        await _pumpMines(
          tester,
          widget: BeuiMines(
            onReveal: (tile, result, value) {
              reveals.add((tile, result, value));
            },
          ),
        );

        var foundBustAfterGem = false;
        for (var attempt = 0; attempt < 64 && !foundBustAfterGem; attempt++) {
          await _startNextRound(tester);
          await tester.pump();
          final before = reveals.length;
          for (var tile = 0; tile < 25; tile++) {
            if (find.text('Play again').evaluate().isNotEmpty) break;
            await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
            await tester.pump(const Duration(milliseconds: 1));
          }
          final roundReveals = reveals.skip(before).toList();
          final mine = roundReveals.where(
            (pick) => pick.$2 == BeuiMinesTile.mine,
          );
          final gems = roundReveals.where(
            (pick) => pick.$2 == BeuiMinesTile.gem,
          );
          if (mine.isNotEmpty && gems.isNotEmpty) {
            final earned = gems.last.$3;
            expect(mine.single.$3, 0);
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    widget.data == beuiFormatMinesMultiplier(earned) &&
                    widget.style?.decoration == TextDecoration.lineThrough,
              ),
              findsOneWidget,
            );
            foundBustAfterGem = true;
          }
        }
        expect(
          foundBustAfterGem,
          isTrue,
          reason: 'No gem-then-mine outcome appeared in 64 rounds.',
        );
      },
    );

    testWidgets('reduced motion keeps tiles at their resting scale', (
      tester,
    ) async {
      await _pumpMines(tester, reduceMotion: true);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 250));

      final tileScale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byKey(const ValueKey('mines-tile-0')),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(tileScale.scale, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion keeps the closing wait and fades the ticket', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        reduceMotion: true,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      for (var tile = 0; tile < 25; tile++) {
        if (find.text('Play again').evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      final lastPick = reveals.last.$1;
      final pickedTiles = reveals.map((pick) => pick.$1).toSet();
      var outerRing = 0;
      for (var tile = 0; tile < 25; tile++) {
        if (pickedTiles.contains(tile)) continue;
        final ring = math.max(
          (tile ~/ 5 - lastPick ~/ 5).abs(),
          (tile % 5 - lastPick % 5).abs(),
        );
        outerRing = math.max(outerRing, ring);
      }
      final closingMilliseconds = outerRing * 25 + 300;
      expect(find.bySemanticsLabel('Round result'), findsNothing);
      await tester.pump(Duration(milliseconds: closingMilliseconds - 2));
      expect(find.byKey(const ValueKey('mines-result-card')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('mines-result-card')), findsOneWidget);
      await tester.pump();
      expect(find.bySemanticsLabel('Round result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.bySemanticsLabel('Round result'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        closeTo(0.3781381308, 0.001),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        closeTo(0.6846431874, 0.001),
      );
      final heading = _resultHeading();
      final stageOpacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
          )
          .opacity;
      expect(stageOpacity, closeTo(0.9397556031, 0.001));
      expect(
        _effectiveOpacity(tester, heading),
        closeTo(0.6846431874 * 0.9397556031, 0.001),
      );
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('mines-result-enter-transform')),
            )
            .transform
            .getTranslation()
            .y,
        0,
      );
      expect(
        _maxXYScale(
          tester.widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-scale')),
          ),
        ),
        1,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        closeTo(0.9065353493, 0.001),
      );
      expect(
        _effectiveOpacity(tester, heading),
        closeTo(0.9065353493 * 0.9879649117, 0.001),
      );
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('mines-board'))).center,
      );
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        closeTo(0.9065353493, 0.001),
      );
      await tester.pump(const Duration(microseconds: 37500));
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        closeTo(0.9065353493 * (1 - 0.8256223012), 0.001),
      );
    });

    testWidgets('an unpicked icon settles at source opacity and geometry', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      for (var tile = 0; tile < 25; tile++) {
        if (find.text('Play again').evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final unpicked = List<int>.generate(
        25,
        (tile) => tile,
      ).firstWhere((tile) => !reveals.any((pick) => pick.$1 == tile));
      final opacity = tester.widget<Opacity>(
        find.byKey(ValueKey('mines-icon-opacity-$unpicked')),
      );
      final scale = tester.widget<Transform>(
        find.byKey(ValueKey('mines-icon-scale-$unpicked')),
      );
      expect(opacity.opacity, 0.4);
      expect(_maxXYScale(scale), 1);
      expect(find.byKey(ValueKey('mines-icon-blur-$unpicked')), findsOneWidget);
    });

    testWidgets(
      'reduced icon reveal keeps opacity motion but removes geometry',
      (tester) async {
        final reveals = <(int, BeuiMinesTile, double)>[];
        await _pumpMines(
          tester,
          reduceMotion: true,
          widget: BeuiMines(
            onReveal: (tile, result, multiplier) =>
                reveals.add((tile, result, multiplier)),
          ),
        );
        await tester.tap(find.text('Start'));
        await tester.pump();
        for (var tile = 0; tile < 25; tile++) {
          if (find.text('Play again').evaluate().isNotEmpty) break;
          await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
          await tester.pump(const Duration(milliseconds: 1));
        }
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final unpicked = List<int>.generate(
          25,
          (tile) => tile,
        ).firstWhere((tile) => !reveals.any((pick) => pick.$1 == tile));
        expect(
          tester
              .widget<Opacity>(
                find.byKey(ValueKey('mines-icon-opacity-$unpicked')),
              )
              .opacity,
          0.4,
        );
        expect(
          find.byKey(ValueKey('mines-icon-scale-$unpicked')),
          findsNothing,
        );
        expect(find.byKey(ValueKey('mines-icon-blur-$unpicked')), findsNothing);
      },
    );

    testWidgets('a delayed start wave preserves a revealed icon element', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      var foundGem = false;
      for (var attempt = 0; attempt < 64 && !foundGem; attempt++) {
        await _startNextRound(tester);
        await tester.pump(Duration.zero);
        await tester.tap(find.byKey(const ValueKey('mines-tile-1')));
        await tester.pump();
        foundGem = reveals.last.$2 == BeuiMinesTile.gem;
      }
      expect(foundGem, isTrue, reason: 'No safe tile appeared in 64 rounds.');
      final icon = find.byKey(const ValueKey('mines-icon-opacity-1'));
      final beforeWave = tester.element(icon);
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.element(icon), same(beforeWave));
    });

    testWidgets('cash-out pulse reaches 1.2 at the source keyframe', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      int? gem;
      for (var attempt = 0; attempt < 64 && gem == null; attempt++) {
        await _startNextRound(tester);
        for (var tile = 0; tile < 25; tile++) {
          await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
          await tester.pump();
          final reveal = reveals.last;
          if (reveal.$2 == BeuiMinesTile.gem) {
            gem = reveal.$1;
            break;
          }
          if (find.text('Play again').evaluate().isNotEmpty) break;
        }
      }
      expect(gem, isNotNull, reason: 'No safe tile appeared in 64 rounds.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('mines-icon-opacity-$gem')))
            .opacity,
        1,
      );
      await tester.tap(find.textContaining('Cash out'));
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('mines-icon-opacity-$gem')))
            .opacity,
        greaterThan(0.99),
        reason: 'Cash-out must not restart the gem icon reveal.',
      );
      expect(
        tester
            .widget<Transform>(find.byKey(ValueKey('mines-icon-scale-$gem')))
            .transform
            .getMaxScaleOnAxis(),
        greaterThan(0.99),
      );
      await tester.pump(const Duration(milliseconds: 175));
      final pulse = tester.widget<Transform>(
        find.byKey(ValueKey('mines-cashout-pulse-scale-$gem')),
      );
      expect(pulse.transform.getMaxScaleOnAxis(), closeTo(1.2, 0.002));
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('mines-icon-opacity-$gem')))
            .opacity,
        1,
        reason: 'Cash-out must keep the already revealed gem mounted.',
      );
    });

    testWidgets('picked-gem order fades in after its source delay', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      int? gem;
      for (var attempt = 0; attempt < 64 && gem == null; attempt++) {
        await _startNextRound(tester);
        for (var tile = 0; tile < 25; tile++) {
          await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
          await tester.pump();
          if (reveals.last.$2 == BeuiMinesTile.gem) {
            gem = reveals.last.$1;
            break;
          }
          if (find.text('Play again').evaluate().isNotEmpty) break;
        }
      }
      expect(gem, isNotNull, reason: 'No safe tile appeared in 64 rounds.');
      // Build the delayed label target before advancing its 100ms timer.
      await tester.pump();
      final label = find.byKey(const ValueKey('mines-pick-order-opacity-1'));
      await tester.pump(const Duration(milliseconds: 99));
      expect(tester.widget<Opacity>(label).opacity, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.widget<Opacity>(label).opacity, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(tester.widget<Opacity>(label).opacity, greaterThan(0));
      expect(tester.widget<Opacity>(label).opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 75));
      expect(tester.widget<Opacity>(label).opacity, 1);
    });

    testWidgets('mine shake reaches its first per-segment keyframe', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      var hitMine = false;
      for (var attempt = 0; attempt < 64 && !hitMine; attempt++) {
        await _startNextRound(tester);
        final before = reveals.length;
        for (var tile = 0; tile < 25; tile++) {
          if (find.text('Play again').evaluate().isNotEmpty) break;
          await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
          await tester.pump(const Duration(milliseconds: 1));
          if (reveals.length > before &&
              reveals.last.$2 == BeuiMinesTile.mine) {
            hitMine = true;
            break;
          }
        }
      }
      expect(hitMine, isTrue, reason: 'No mine appeared in 64 rounds.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final shake = tester.widget<Transform>(
        find.byKey(const ValueKey('mines-shake-offset')),
      );
      expect(shake.transform.getTranslation().x, closeTo(-5, 0.05));
    });

    testWidgets('keeps ticket stages and map replay through result exit', (
      tester,
    ) async {
      final reveals = <(int, BeuiMinesTile, double)>[];
      await _pumpMines(
        tester,
        widget: BeuiMines(
          onReveal: (tile, result, multiplier) =>
              reveals.add((tile, result, multiplier)),
        ),
      );
      await _startNextRound(tester);
      for (var tile = 0; tile < 25; tile++) {
        if (find.text('Play again').evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(ValueKey('mines-tile-$tile')));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump();
      expect(find.text('Play again'), findsOneWidget);
      final pickedTiles = reveals.map((pick) => pick.$1).toSet();
      var outerRing = 0;
      for (var tile = 0; tile < 25; tile++) {
        if (pickedTiles.contains(tile)) continue;
        final ring = math.max(
          (tile ~/ 5 - reveals.last.$1 ~/ 5).abs(),
          (tile % 5 - reveals.last.$1 % 5).abs(),
        );
        outerRing = math.max(outerRing, ring);
      }
      final rippleMilliseconds = outerRing * 25 + 300;
      final pulseMilliseconds = reveals.last.$2 == BeuiMinesTile.gem
          ? (reveals.length - 1) * 40 + 350
          : 0;
      final closingMilliseconds = math.max(
        rippleMilliseconds,
        pulseMilliseconds,
      );
      await tester.pump(Duration(milliseconds: closingMilliseconds - 2));
      expect(find.byKey(const ValueKey('mines-result-card')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('mines-result-card')), findsOneWidget);
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('mines-mini-map'))).width,
        52,
      );

      final cardElement = tester.element(
        find.byKey(const ValueKey('mines-result-card')),
      );
      final stageChildElement = tester.element(find.text('Gems'));
      final mapElement = tester.element(
        find.byKey(const ValueKey('mines-mini-map')),
      );
      final firstPickOpacity = find.byKey(
        ValueKey('mines-map-cell-opacity-${reveals.first.$1}'),
      );
      final firstPickElement = tester.element(firstPickOpacity);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
            )
            .opacity,
        0,
      );
      expect(tester.widget<Opacity>(firstPickOpacity).opacity, 0);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
            )
            .opacity,
        0,
      );
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.bySemanticsLabel('Round result'), findsOneWidget);
      final cardOpacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('mines-result-enter-opacity')),
          )
          .opacity;
      expect(cardOpacity, greaterThan(0));
      expect(cardOpacity, lessThan(1));
      final entryY = tester
          .widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-transform')),
          )
          .transform
          .getTranslation()
          .y;
      expect(entryY, greaterThan(0));
      expect(entryY, closeTo(7.5094128922, 0.001));
      expect(cardOpacity, closeTo(0.5306616942, 0.001));
      expect(
        _maxXYScale(
          tester.widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-scale')),
          ),
        ),
        closeTo(0.9812264678, 0.001),
      );
      final heading = _resultHeading();
      final stageOpacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
          )
          .opacity;
      expect(stageOpacity, closeTo(0.4943906171, 0.001));
      expect(
        _effectiveOpacity(tester, heading),
        closeTo(0.5306616942 * 0.4943906171, 0.001),
      );
      expect(
        identical(
          cardElement,
          tester.element(find.byKey(const ValueKey('mines-result-card'))),
        ),
        isTrue,
      );
      expect(
        identical(stageChildElement, tester.element(find.text('Gems'))),
        isTrue,
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
            )
            .opacity,
        greaterThan(0),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
            )
            .opacity,
        lessThan(1),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-1-opacity')),
            )
            .opacity,
        0,
      );
      expect(tester.widget<Opacity>(firstPickOpacity).opacity, 0);

      await tester.pump(const Duration(milliseconds: 175));
      final overshootY = tester
          .widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-transform')),
          )
          .transform
          .getTranslation()
          .y;
      final overshootScale = _maxXYScale(
        tester.widget<Transform>(
          find.byKey(const ValueKey('mines-result-enter-scale')),
        ),
      );
      expect(overshootY, closeTo(-0.0813243576, 0.001));
      expect(overshootScale, closeTo(1.0002033109, 0.001));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.bySemanticsLabel('Round result'), findsOneWidget);
      expect(
        identical(
          mapElement,
          tester.element(find.byKey(const ValueKey('mines-mini-map'))),
        ),
        isTrue,
      );
      expect(
        identical(firstPickElement, tester.element(firstPickOpacity)),
        isTrue,
      );
      expect(
        identical(stageChildElement, tester.element(find.text('Gems'))),
        isTrue,
      );
      expect(tester.widget<Opacity>(firstPickOpacity).opacity, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      expect(find.bySemanticsLabel('Round result'), findsOneWidget);
      expect(tester.widget<Opacity>(firstPickOpacity).opacity, greaterThan(0));
      expect(tester.widget<Opacity>(firstPickOpacity).opacity, lessThan(1));

      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
            )
            .opacity,
        greaterThan(0.9),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        closeTo(1, 0.001),
      );
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('mines-result-enter-transform')),
            )
            .transform
            .getTranslation()
            .y,
        closeTo(0, 0.001),
      );
      expect(
        _maxXYScale(
          tester.widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-scale')),
          ),
        ),
        closeTo(1, 0.001),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(
                ValueKey('mines-map-cell-opacity-${reveals.first.$1}'),
              ),
            )
            .opacity,
        greaterThan(0.9),
      );

      final settledOpacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('mines-result-enter-opacity')),
          )
          .opacity;
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('mines-board'))).center,
      );
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        settledOpacity,
      );
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('mines-result-enter-transform')),
            )
            .transform
            .getTranslation()
            .y,
        0,
      );
      expect(
        _maxXYScale(
          tester.widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-scale')),
          ),
        ),
        1,
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        identical(
          cardElement,
          tester.element(find.byKey(const ValueKey('mines-result-card'))),
        ),
        isTrue,
        reason: 'Dismissal must preserve the result card element.',
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        greaterThan(0),
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-result-enter-opacity')),
            )
            .opacity,
        lessThan(1),
      );
      final exitY = tester
          .widget<Transform>(
            find.byKey(const ValueKey('mines-result-enter-transform')),
          )
          .transform
          .getTranslation()
          .y;
      expect(exitY, closeTo(8 * 0.7521260717, 0.001));
      final exitScale = _maxXYScale(
        tester.widget<Transform>(
          find.byKey(const ValueKey('mines-result-enter-scale')),
        ),
      );
      expect(exitScale, closeTo(1 - 0.02 * 0.7521260717, 0.001));
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('mines-ticket-stage-0-opacity')),
            )
            .opacity,
        greaterThan(0.9),
        reason: 'An already-visible ticket stage must not restart on exit.',
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(
                ValueKey('mines-map-cell-opacity-${reveals.first.$1}'),
              ),
            )
            .opacity,
        greaterThan(0.9),
        reason: 'A replay cell must retain its reveal state during exit.',
      );
      expect(
        identical(
          mapElement,
          tester.element(find.byKey(const ValueKey('mines-mini-map'))),
        ),
        isTrue,
      );
      expect(
        identical(firstPickElement, tester.element(firstPickOpacity)),
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const ValueKey('mines-result-card')), findsNothing);
      expect(find.byKey(const ValueKey('mines-mini-map')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _startNextRound(WidgetTester tester) async {
  if (find.textContaining('Cash out').evaluate().isNotEmpty) return;
  final action = find.text('Play again').evaluate().isNotEmpty
      ? find.text('Play again')
      : find.text('Start');
  await tester.tap(action);
  await tester.pump();
}

Future<void> _pumpMines(
  WidgetTester tester, {
  Widget? widget,
  bool reduceMotion = false,
}) async {
  _useRoomyViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: _minesTestTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: widget ?? const BeuiMines())),
      ),
    ),
  );
}

Future<void> _loadMinesTestFonts() async {
  final loader = FontLoader('Geist');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(
      File(
        'example/assets/fonts/Geist-$weight.ttf',
      ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
}

ThemeData _minesTestTheme() => ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Geist',
  extensions: [BeuiColors.dark()],
);

void _useRoomyViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _resultHeading() => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data == 'MINE HIT' || widget.data == 'CASHED OUT'),
);

double _maxXYScale(Transform transform) {
  final matrix = transform.transform.storage;
  final x = math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]);
  final y = math.sqrt(matrix[4] * matrix[4] + matrix[5] * matrix[5]);
  return math.max(x, y);
}

double _effectiveOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  RenderObject? renderObject = tester.renderObject<RenderObject>(finder);
  while (renderObject != null) {
    if (renderObject is RenderOpacity) {
      opacity *= renderObject.opacity;
    } else if (renderObject is RenderAnimatedOpacity) {
      opacity *= renderObject.opacity.value;
    }
    renderObject = renderObject.parent;
  }
  return opacity;
}
