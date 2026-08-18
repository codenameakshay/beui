import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<BeuiTodoItem> _sample({
  BeuiTodoItemStatus a = BeuiTodoItemStatus.pending,
  BeuiTodoItemStatus b = BeuiTodoItemStatus.pending,
  BeuiTodoItemStatus c = BeuiTodoItemStatus.pending,
  double? aProgress,
}) {
  return [
    BeuiTodoItem(
      id: 'a',
      title: const Text('Inspect the current data flow'),
      status: a,
      progress: aProgress,
      detail: aProgress != null ? Text('${aProgress.round()}%') : null,
    ),
    BeuiTodoItem(
      id: 'b',
      title: const Text('Update the response schema'),
      status: b,
    ),
    BeuiTodoItem(
      id: 'c',
      title: const Text('Add coverage for edge cases'),
      status: c,
    ),
  ];
}

Widget _host({
  required List<BeuiTodoItem> items,
  Widget? title,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  bool collapseOnComplete = true,
  bool reduce = false,
  bool dark = false,
  String? emptyLabel,
  String? emptyDescription,
  Widget? emptyState,
  List<ThemeExtension<dynamic>>? extensions,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 360,
      child: BeuiTodoList(
        items: items,
        title: title,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        collapseOnComplete: collapseOnComplete,
        emptyLabel: emptyLabel,
        emptyDescription: emptyDescription,
        emptyState: emptyState,
      ),
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  final base = dark ? ThemeData.dark() : ThemeData.light();
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      base.copyWith(
        extensions:
            extensions ?? [dark ? BeuiColors.dark() : BeuiColors.light()],
      ),
    ),
    home: Scaffold(body: child),
  );
}

List<BeuiTodoItem> _allDone() => _sample(
  a: BeuiTodoItemStatus.completed,
  b: BeuiTodoItemStatus.completed,
  c: BeuiTodoItemStatus.completed,
);

void main() {
  group('BeuiTodoList', () {
    testWidgets('renders title, count, and task rows', (tester) async {
      await tester.pumpWidget(
        _host(
          items: _sample(a: BeuiTodoItemStatus.completed),
          title: const Text('Implementation plan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Implementation plan'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // completed numerator
      expect(find.text('/3'), findsOneWidget);
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      expect(find.text('Update the response schema'), findsOneWidget);
      expect(find.text('Add coverage for edge cases'), findsOneWidget);
    });

    testWidgets('empty state shows "No tasks yet"', (tester) async {
      await tester.pumpWidget(_host(items: const []));
      await tester.pumpAndSettle();
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.text('/0'), findsOneWidget);
    });

    testWidgets('tapping header toggles open state (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(items: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      // Collapsed disclosure clips content out of hit-test / visibility.
      expect(find.text('Inspect the current data flow'), findsNothing);

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);
    });

    testWidgets('controlled open reports onOpenChange', (tester) async {
      var open = true;
      final calls = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              items: _sample(),
              open: open,
              onOpenChange: (v) {
                calls.add(v);
                setState(() => open = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      expect(find.text('Inspect the current data flow'), findsNothing);

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      expect(calls, [false, true]);
    });

    testWidgets('collapseOnComplete auto-collapses when all done', (
      tester,
    ) async {
      // Determinate progress avoids an infinite spin (which hangs pumpAndSettle).
      var items = const [
        BeuiTodoItem(
          id: 'a',
          title: Text('Inspect the current data flow'),
          status: BeuiTodoItemStatus.completed,
        ),
        BeuiTodoItem(
          id: 'b',
          title: Text('Update the response schema'),
          status: BeuiTodoItemStatus.completed,
        ),
        BeuiTodoItem(
          id: 'c',
          title: Text('Add coverage for edge cases'),
          status: BeuiTodoItemStatus.inProgress,
          progress: 75,
        ),
      ];

      await tester.pumpWidget(_host(items: items, collapseOnComplete: true));
      await tester.pumpAndSettle();
      expect(find.text('Add coverage for edge cases'), findsOneWidget);

      // Complete the last task — list should auto-collapse.
      items = _sample(
        a: BeuiTodoItemStatus.completed,
        b: BeuiTodoItemStatus.completed,
        c: BeuiTodoItemStatus.completed,
      );
      await tester.pumpWidget(_host(items: items, collapseOnComplete: true));
      await tester.pumpAndSettle();
      expect(find.text('Add coverage for edge cases'), findsNothing);
    });

    testWidgets('collapseOnComplete: false keeps panel open when done', (
      tester,
    ) async {
      final items = _sample(
        a: BeuiTodoItemStatus.completed,
        b: BeuiTodoItemStatus.completed,
        c: BeuiTodoItemStatus.completed,
      );
      await tester.pumpWidget(
        _host(items: items, collapseOnComplete: false, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);
    });

    testWidgets('completion count updates as status changes', (tester) async {
      var items = _sample();
      await tester.pumpWidget(
        StatefulBuilder(builder: (context, setState) => _host(items: items)),
      );
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('/3'), findsOneWidget);

      items = _sample(
        a: BeuiTodoItemStatus.completed,
        b: BeuiTodoItemStatus.completed,
      );
      await tester.pumpWidget(_host(items: items));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('/3'), findsOneWidget);
    });

    testWidgets('in-progress detail metadata is shown', (tester) async {
      await tester.pumpWidget(
        _host(items: _sample(a: BeuiTodoItemStatus.inProgress, aProgress: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });

    // A16. This used to assert the *bug*: the private disclosure hard-cut
    // under reduced motion, so one pump after the tap the rows were simply
    // gone. The shared disclosure keeps the opacity channel — reduced motion
    // drops movement, not fades — so the panel now cross-fades out over
    // ~120ms and only then unmounts.
    testWidgets('reduced motion cross-fades the panel instead of cutting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(items: _sample(), reduce: true, defaultOpen: true),
      );
      await tester.pump();
      expect(find.text('Inspect the current data flow'), findsOneWidget);

      await tester.tap(find.text('To-dos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Mid-fade: still mounted, still painting, at a partial opacity.
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Inspect the current data flow'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold<double>(1, (a, b) => a * b);
      expect(opacity, greaterThan(0.0));
      expect(opacity, lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Inspect the current data flow'), findsNothing);
    });

    testWidgets('keyboard ActivateIntent toggles the header', (tester) async {
      await tester.pumpWidget(_host(items: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsNothing);
    });

    testWidgets('status morph keeps the same row identity', (tester) async {
      var items = _sample(a: BeuiTodoItemStatus.pending);
      await tester.pumpWidget(_host(items: items));
      await tester.pumpAndSettle();

      items = _sample(a: BeuiTodoItemStatus.inProgress, aProgress: 25);
      await tester.pumpWidget(_host(items: items));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);

      items = _sample(a: BeuiTodoItemStatus.completed);
      await tester.pumpWidget(_host(items: items));
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('cancelled status is accepted without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          items: [
            const BeuiTodoItem(
              id: 'x',
              title: Text('Skipped task'),
              status: BeuiTodoItemStatus.cancelled,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skipped task'), findsOneWidget);
    });

    testWidgets('the completion strike spans the title, not the whole row', (
      tester,
    ) async {
      // A deliberately short title: the test font is far wider than Geist, so
      // a realistic sentence would fill the row and ellipsize, making the
      // strike legitimately full-width and the assertion meaningless.
      await tester.pumpWidget(
        _host(
          items: const [
            BeuiTodoItem(
              id: 'a',
              title: Text('Done'),
              status: BeuiTodoItemStatus.completed,
            ),
          ],
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();

      // The rule is drawn with `Positioned.fill` over the title's Stack, so
      // that Stack must shrink-wrap the glyphs. Under a bare Expanded the
      // Stack was handed a tight full-row width and the rule ran well past the
      // end of the text; beui.dev strikes only the title.
      final strike = tester
          .getSize(
            find
                .ancestor(of: find.text('Done'), matching: find.byType(Stack))
                .first,
          )
          .width;
      final row = tester.getSize(find.byType(BeuiTodoList)).width;

      expect(strike, lessThan(row / 2));
    });
  });

  // A40 — a published package must not crash on a consumer's theme.
  group('BeuiTodoList theme resilience', () {
    testWidgets('renders with no BeuiColors extension installed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: BeuiTodoList(items: _sample()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('To-dos'), findsOneWidget);
      expect(find.text('Inspect the current data flow'), findsOneWidget);
    });

    testWidgets('falls back at the ambient brightness, not a fixed palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: BeuiTodoList(items: _allDone()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text('/3')).style!.color,
        BeuiAgentStatusColors.dark.success.foreground,
      );
    });
  });

  // A36 — status colors come from the role set, in both brightnesses.
  group('BeuiTodoList status colors', () {
    testWidgets('light mode completion count takes the success 700 tier', (
      tester,
    ) async {
      await tester.pumpWidget(_host(items: _allDone()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('/3')).style!.color,
        BeuiAgentStatusColors.light.success.foreground,
      );
    });

    testWidgets('dark mode completion count takes the success 400 tier', (
      tester,
    ) async {
      await tester.pumpWidget(_host(items: _allDone(), dark: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('/3')).style!.color,
        BeuiAgentStatusColors.dark.success.foreground,
      );
      expect(
        BeuiAgentStatusColors.dark.success.foreground,
        isNot(BeuiAgentStatusColors.light.success.foreground),
      );
    });

    testWidgets('an incomplete list stays muted, not tinted', (tester) async {
      await tester.pumpWidget(_host(items: _sample()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('/3')).style!.color,
        BeuiColors.light().mutedForeground,
      );
    });

    testWidgets('a retinted success tier moves the count', (tester) async {
      const teal = Color(0xFF0F766E);
      await tester.pumpWidget(
        _host(
          items: _allDone(),
          extensions: [
            BeuiColors.light(),
            BeuiAgentTheme(
              statusLight: BeuiAgentStatusColors.light.copyWith(
                success: BeuiAgentStatusColors.light.success.copyWith(
                  foreground: teal,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('/3')).style!.color, teal);
    });
  });

  // A27 — the copy is a theme surface, not English baked into the widget.
  group('BeuiTodoList strings', () {
    testWidgets('a themed BeuiAgentStrings re-spells title, count, and empty', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          items: const [],
          extensions: [
            BeuiColors.light(),
            const BeuiAgentTheme(
              strings: BeuiAgentStrings(
                todoListTitle: 'À faire',
                todoEmpty: 'Aucune tâche',
                todoListLabel: 'Liste de tâches',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('À faire'), findsOneWidget);
      expect(find.text('Aucune tâche'), findsOneWidget);
      expect(find.bySemanticsLabel('Liste de tâches'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('per-instance overrides beat the theme string', (tester) async {
      await tester.pumpWidget(
        _host(items: const [], emptyLabel: 'Nothing planned'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing planned'), findsOneWidget);
      expect(find.text('No tasks yet'), findsNothing);
    });

    testWidgets('a themed BeuiAgentStrings re-spells the empty description', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          items: const [],
          extensions: [
            BeuiColors.light(),
            const BeuiAgentTheme(
              strings: BeuiAgentStrings(
                todoEmptyDescription: 'Le plan apparaîtra ici.',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Le plan apparaîtra ici.'), findsOneWidget);
    });

    testWidgets(
      'explicit emptyDescription beats the theme string, which beats nothing',
      (tester) async {
        // Explicit widget param wins over the theme string.
        await tester.pumpWidget(
          _host(
            items: const [],
            emptyDescription: 'Widget wins',
            extensions: [
              BeuiColors.light(),
              const BeuiAgentTheme(
                strings: BeuiAgentStrings(todoEmptyDescription: 'Theme loses'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Widget wins'), findsOneWidget);
        expect(find.text('Theme loses'), findsNothing);

        // With nothing supplied at all, the theme string (default English
        // copy here, since no theme is installed) still renders — the empty
        // state is never bare.
        await tester.pumpWidget(_host(items: const []));
        await tester.pumpAndSettle();
        expect(
          find.text('Tasks will appear here as the agent plans its work.'),
          findsOneWidget,
        );
      },
    );
  });

  // A28 — the empty state orients instead of shrugging.
  group('BeuiTodoList empty state', () {
    testWidgets('renders an orienting description under the headline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          items: const [],
          emptyDescription:
              'The agent will list its plan here before it '
              'starts work.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tasks yet'), findsOneWidget);
      expect(
        find.text('The agent will list its plan here before it starts work.'),
        findsOneWidget,
      );
    });

    testWidgets('emptyState replaces the whole panel', (tester) async {
      await tester.pumpWidget(
        _host(
          items: const [],
          emptyLabel: 'ignored',
          emptyState: const Text('Waiting for the plan'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiting for the plan'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    });
  });

  group('BeuiTodoList accessibility', () {
    testWidgets('the header is a labelled, expandable button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(items: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();

      // The header node merges the title and the n/N counter in after its own
      // sentence, so match on the sentence rather than the whole label.
      final sentence = const BeuiAgentStrings().todoHeaderLabel(0, 3, true);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp(sentence))),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );

      // And the card keeps its own name instead of having it swallowed into
      // that button label.
      expect(find.bySemanticsLabel('Agent task list'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('rows announce their status before their title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(items: _sample(a: BeuiTodoItemStatus.completed)),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Completed: ')), findsWidgets);
      handle.dispose();
    });

    testWidgets('meets the iOS tap-target and labelled-target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(items: _sample()));
      await tester.pumpAndSettle();

      // The header is 44px in *layout*, so unlike the activity summary it can
      // be measured by the semantics-rect guidelines. 44 is the library's
      // floor (Apple HIG / WCAG 2.5.8 AAA / kMinInteractiveDimension);
      // androidTapTargetGuideline asks for Material's 48 and is not the
      // standard this port targets.
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('BeuiTodoList keyboard', () {
    Future<List<bool>> activate(
      WidgetTester tester,
      LogicalKeyboardKey key,
    ) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        _host(items: _sample(), defaultOpen: true, onOpenChange: calls.add),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('Tab then Enter collapses', (tester) async {
      expect(await activate(tester, LogicalKeyboardKey.enter), [false]);
    });

    testWidgets('Tab then Space collapses', (tester) async {
      expect(await activate(tester, LogicalKeyboardKey.space), [false]);
    });
  });

  // A38 — `useGlassSurfaces` was dead across this whole cluster.
  group('BeuiTodoList structure tokens', () {
    testWidgets('off by default: no backdrop blur, no muted fill', (
      tester,
    ) async {
      await tester.pumpWidget(_host(items: _sample()));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('useGlassSurfaces gives the card a real glass surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          items: _sample(),
          extensions: [
            BeuiColors.light(),
            const BeuiAgentTheme(
              structure: BeuiAgentStructure(useGlassSurfaces: true),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the focus ring is drawn at the emphasis width', (
      tester,
    ) async {
      await tester.pumpWidget(_host(items: _sample()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Painted outside layout, so the header keeps its exact 44px box —
      // focusing must not resize or shift anything.
      expect(tester.getSize(find.byType(BeuiTodoList)).width, 360);
      final ring = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border?.top.color == BeuiColors.light().focusRing);
      expect(ring, hasLength(1));
      expect(
        ring.single.border!.top.width,
        const BeuiAgentStructure().emphasisBorderWidth,
      );
    });
  });

  // A18 — each row used to build a five-deep animation tree.
  testWidgets('a row builds a shallow animation tree', (tester) async {
    await tester.pumpWidget(
      _host(items: _sample(a: BeuiTodoItemStatus.inProgress, aProgress: 40)),
    );
    await tester.pumpAndSettle();

    final builders = tester
        .elementList(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString().contains('MotionBuilder'),
          ),
        )
        .length;

    // Three rows × 3 (the status mark is 2 — a `Rect` carrying four
    // per-dimension motions, plus the ring's own opacity — and the strike is
    // 1), plus the header's rolling counter. The mark alone used to be 5 per
    // row, so the rows contributed 18 where they now contribute 9.
    expect(builders, lessThanOrEqualTo(13));
  });

  testWidgets('golden — in-flight plan with all four row states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(child: RepaintBoundary(child: _TodoGolden())),
        ),
      ),
    );
    // Two fixed advances, never pumpAndSettle: the in-progress ring is an
    // indefinite ticker. The first pump lets the row entrances start (they are
    // armed in a post-frame callback, so a ticker started there takes the
    // following frame as its zero); the second settles them.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(_TodoGolden),
      matchesGoldenFile('goldens/beui_todo_list.png'),
    );
  });

  // F4/F5. Both channels below are gated on `NoMotion` under reduced motion,
  // and NoMotion holds its seeded value forever rather than snapping to the
  // target (see `_no_motion_semantics_test.dart`). Mounting straight into the
  // end state hides the bug — the controller's initial value IS the target —
  // so both tests mount in the start state and then TRANSITION, which is the
  // only thing that exercises the frozen channel.
  group('BeuiTodoList reduced-motion status channels', () {
    testWidgets('F4: pending -> inProgress draws the ring arc', (tester) async {
      await tester.pumpWidget(
        _host(items: _sample(a: BeuiTodoItemStatus.pending), reduce: true),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(
          items: _sample(a: BeuiTodoItemStatus.inProgress, aProgress: 50),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      // `dashed: pending` is false for an in-progress row, so its dashed
      // circle is not drawn and the progress ring is the only `drawArc` in the
      // subtree. 50% => a half-turn sweep.
      expect(
        find.byType(BeuiTodoList),
        paints..arc(startAngle: 0.0, sweepAngle: math.pi),
        reason:
            'the in-progress ring must reach its target under reduced motion, '
            'not stay frozen at 0 (which draws no arc at all)',
      );
    });

    testWidgets('F5: completing a visible row strikes its title', (
      tester,
    ) async {
      int strikes() => find
          .descendant(
            of: find.byType(BeuiTodoList),
            matching: find.byType(FractionallySizedBox),
          )
          .evaluate()
          .length;

      await tester.pumpWidget(
        _host(items: _sample(a: BeuiTodoItemStatus.pending), reduce: true),
      );
      await tester.pumpAndSettle();
      final before = strikes();

      await tester.pumpWidget(
        _host(items: _sample(a: BeuiTodoItemStatus.completed), reduce: true),
      );
      await tester.pumpAndSettle();
      // Well past the strike's draw-on delay in either mode.
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        strikes(),
        greaterThan(before),
        reason:
            'the strikethrough renders nothing while its width factor is 0; '
            'completing a row that was already on screen must draw it',
      );

      final drawn = tester
          .widgetList<FractionallySizedBox>(
            find.descendant(
              of: find.byType(BeuiTodoList),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .map((w) => w.widthFactor)
          .toList();
      expect(
        drawn,
        contains(1.0),
        reason: 'under reduced motion the strike snaps to full width',
      );
    });
  });
}

/// The golden subject: one list showing every row state at once.
class _TodoGolden extends StatelessWidget {
  const _TodoGolden();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 380,
      child: BeuiTodoList(
        title: Text('Implementation plan'),
        collapseOnComplete: false,
        items: [
          BeuiTodoItem(
            id: 'a',
            title: Text('Inspect the data flow'),
            status: BeuiTodoItemStatus.completed,
          ),
          BeuiTodoItem(
            id: 'b',
            title: Text('Update the schema'),
            status: BeuiTodoItemStatus.inProgress,
            progress: 40,
            detail: Text('40%'),
          ),
          BeuiTodoItem(
            id: 'c',
            title: Text('Add edge-case coverage'),
            status: BeuiTodoItemStatus.pending,
          ),
          BeuiTodoItem(
            id: 'd',
            title: Text('Backfill the old rows'),
            status: BeuiTodoItemStatus.cancelled,
          ),
        ],
      ),
    );
  }
}
