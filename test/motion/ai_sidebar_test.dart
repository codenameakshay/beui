import 'package:beui/beui.dart';
// The focus ring is package-internal; these tests pin that the row finally
// renders the `focused` flag it has always been threaded.
import 'package:beui/src/motion/_focus_ring.dart' show BeuiFocusRing;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _sample = <BeuiSidebarResource>[
  const BeuiSidebarResource(
    id: 'platform',
    label: 'Platform',
    kind: BeuiSidebarResourceKind.project,
    children: [
      BeuiSidebarResource(
        id: 'api',
        label: 'API migration',
        kind: BeuiSidebarResourceKind.file,
      ),
      BeuiSidebarResource(
        id: 'docs',
        label: 'Read platform docs',
        kind: BeuiSidebarResourceKind.bookmark,
      ),
    ],
  ),
  const BeuiSidebarResource(
    id: 'notes',
    label: 'Release notes',
    kind: BeuiSidebarResourceKind.file,
  ),
  const BeuiSidebarResource(
    id: 'archive',
    label: 'Archive',
    kind: BeuiSidebarResourceKind.folder,
  ),
];

Widget _host({
  List<BeuiSidebarResource>? items,
  List<BeuiSidebarResource> defaultItems = const [],
  String? activeId,
  String? defaultActiveId,
  List<String> defaultExpandedIds = const [],
  ValueChanged<String>? onActiveChange,
  ValueChanged<List<BeuiSidebarResource>>? onItemsChange,
  Future<void> Function(BeuiSidebarResourceMove move)? onMove,
  Future<void> Function(BeuiSidebarResource item, String label)? onRename,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 320,
      height: 480,
      child: Material(
        child: BeuiAiSidebar(
          items: items,
          defaultItems: defaultItems.isEmpty ? _sample : defaultItems,
          activeId: activeId,
          defaultActiveId: defaultActiveId,
          defaultExpandedIds: defaultExpandedIds,
          onActiveChange: onActiveChange,
          onItemsChange: onItemsChange,
          onMove: onMove,
          onRename: onRename,
        ),
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
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('tree helpers', () {
    test('move before / after / inside', () {
      final after = beuiSidebarMove(
        _sample,
        const BeuiSidebarResourceMove(
          itemId: 'notes',
          targetId: 'platform',
          position: BeuiSidebarResourceDropPosition.before,
        ),
      )!;
      expect(after.map((r) => r.id).toList(), ['notes', 'platform', 'archive']);

      final inside = beuiSidebarMove(
        _sample,
        const BeuiSidebarResourceMove(
          itemId: 'notes',
          targetId: 'platform',
          position: BeuiSidebarResourceDropPosition.inside,
        ),
      )!;
      final platform = inside.firstWhere((r) => r.id == 'platform');
      expect(platform.children!.map((c) => c.id).toList(), [
        'api',
        'docs',
        'notes',
      ]);
    });

    test('move rejects nesting into self / non-container', () {
      expect(
        beuiSidebarMove(
          _sample,
          const BeuiSidebarResourceMove(
            itemId: 'platform',
            targetId: 'api',
            position: BeuiSidebarResourceDropPosition.inside,
          ),
        ),
        isNull,
      );
      expect(
        beuiSidebarMove(
          _sample,
          const BeuiSidebarResourceMove(
            itemId: 'docs',
            targetId: 'notes',
            position: BeuiSidebarResourceDropPosition.inside,
          ),
        ),
        isNull,
      );
    });

    test('rename updates label', () {
      final next = beuiSidebarRename(_sample, 'api', 'API v2');
      expect(beuiSidebarFind(next, 'api')!.label, 'API v2');
    });
  });

  group('BeuiAiSidebar', () {
    testWidgets('renders top-level resources', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAiSidebarKey), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      // Children hidden until expanded.
      expect(find.text('API migration'), findsNothing);
    });

    testWidgets('expands folder and shows children', (tester) async {
      await tester.pumpWidget(_host(defaultExpandedIds: const ['platform']));
      await tester.pumpAndSettle();

      expect(find.text('API migration'), findsOneWidget);
      expect(find.text('Read platform docs'), findsOneWidget);
    });

    testWidgets('tap folder toggles expand', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Platform'));
      await tester.pumpAndSettle();
      expect(find.text('API migration'), findsOneWidget);

      await tester.tap(find.text('Platform'));
      await tester.pumpAndSettle();
      expect(find.text('API migration'), findsNothing);
    });

    testWidgets('selects leaf and reports onActiveChange', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _host(
          defaultExpandedIds: const ['platform'],
          onActiveChange: (id) => selected = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      // GestureDetector delays onTap when onDoubleTap is set.
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(selected, 'api');
    });

    testWidgets('controlled activeId highlights leaf', (tester) async {
      await tester.pumpWidget(
        _host(defaultExpandedIds: const ['platform'], activeId: 'docs'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Read platform docs'), findsOneWidget);
    });

    testWidgets('inline rename via F2 commits on submit', (tester) async {
      List<BeuiSidebarResource>? items;
      String? renamedTo;

      await tester.pumpWidget(
        _host(
          defaultExpandedIds: const ['platform'],
          defaultActiveId: 'api',
          onItemsChange: (next) => items = next,
          onRename: (item, label) async {
            renamedTo = label;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Focus the row then press F2.
      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAiSidebarRenameKey('api')), findsOneWidget);

      await tester.enterText(
        find.byKey(beuiAiSidebarRenameKey('api')),
        'API v2',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(renamedTo, 'API v2');
      expect(beuiSidebarFind(items!, 'api')!.label, 'API v2');
      expect(find.text('API v2'), findsOneWidget);
    });

    testWidgets('double-tap leaf starts rename', (tester) async {
      await tester.pumpWidget(_host(defaultExpandedIds: const ['platform']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAiSidebarRenameKey('api')), findsOneWidget);
    });

    testWidgets('optimistic move rolls back on failure', (tester) async {
      final snapshots = <List<String>>[];

      await tester.pumpWidget(
        _host(
          onItemsChange: (next) =>
              snapshots.add(next.map((r) => r.id).toList()),
          onMove: (_) async {
            throw StateError('server rejected');
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('notes')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(); // optimistic apply
      await tester.pumpAndSettle(); // rollback completes

      expect(snapshots, isNotEmpty);
      // Final tree after rollback matches original order.
      expect(snapshots.last, ['platform', 'notes', 'archive']);
      // At least one intermediate snapshot reordered optimistically.
      expect(snapshots.any((s) => s.join() != 'platformnotesarchive'), isTrue);
    });

    testWidgets('keyboard move reorders optimistically', (tester) async {
      List<BeuiSidebarResource>? latest;

      await tester.pumpWidget(
        _host(onItemsChange: (next) => latest = next, onMove: (_) async {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('notes')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.map((r) => r.id).toList(), [
        'notes',
        'platform',
        'archive',
      ]);
    });

    testWidgets('reduced motion still renders', (tester) async {
      await tester.pumpWidget(
        _host(reduce: true, defaultExpandedIds: const ['platform']),
      );
      await tester.pumpAndSettle();
      expect(find.text('API migration'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // UX remediation — R4, R5, R6, R15, R23, R26, R29, R34
  // ---------------------------------------------------------------------

  Widget remediationHost({
    List<BeuiSidebarResource>? items,
    String? activeId,
    List<String> defaultExpandedIds = const [],
    double? maxHeight,
    Widget? emptyPlaceholder,
    TargetPlatform platform = TargetPlatform.macOS,
    double width = 320,
  }) {
    return MaterialApp(
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(
          platform: platform,
          extensions: [BeuiColors.light()],
        ),
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 480,
            child: Material(
              child: Align(
                alignment: Alignment.topCenter,
                child: BeuiAiSidebar(
                  items: items ?? _sample,
                  activeId: activeId,
                  defaultExpandedIds: defaultExpandedIds,
                  maxHeight: maxHeight,
                  emptyPlaceholder: emptyPlaceholder,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('BeuiAiSidebar keyboard focus is visible', () {
    testWidgets('the focused row renders a ring', (tester) async {
      await tester.pumpWidget(remediationHost());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // `focused` was threaded all the way to the row and then never rendered,
      // which made the whole tree keyboard model invisible to its user.
      final rings = tester
          .widgetList<BeuiFocusRing>(find.byType(BeuiFocusRing))
          .where((r) => r.focused);
      expect(rings, isNotEmpty);
    });

    testWidgets('the ring costs no layout', (tester) async {
      await tester.pumpWidget(remediationHost());
      await tester.pumpAndSettle();
      final before = tester.getRect(find.text('Release notes'));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Release notes')), before);
    });

    testWidgets('the rename field uses the focus role, not the hairline', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(beuiAiSidebarRowKey('notes')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      final border = field.decoration!.focusedBorder! as OutlineInputBorder;
      final colors = BeuiColors.light();
      expect(border.borderSide.color, colors.focusRing);
      expect(border.borderSide.color, isNot(colors.ring));
    });
  });

  group('BeuiAiSidebar selection vs hover', () {
    /// The row background painted behind [label].
    Color? fillBehind(WidgetTester tester, String label) {
      final container = tester
          .widgetList<AnimatedContainer>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .first;
      return (container.decoration! as BoxDecoration).color;
    }

    testWidgets('selection and hover are two different steps', (tester) async {
      await tester.pumpWidget(remediationHost(activeId: 'notes'));
      await tester.pumpAndSettle();

      final selected = fillBehind(tester, 'Release notes');
      expect(selected, isNotNull);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Archive')));
      await tester.pumpAndSettle();

      final hovered = fillBehind(tester, 'Archive');
      expect(hovered, isNotNull);
      // They used to be the same `muted`, so selection vanished under the
      // pointer.
      expect(hovered, isNot(selected));
      expect(hovered!.a, closeTo(0.04, 0.005));
    });

    testWidgets('the selected row carries a leading accent bar too', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost(activeId: 'notes'));
      await tester.pumpAndSettle();
      final colors = BeuiColors.light();
      final bars = tester
          .widgetList<DecoratedBox>(
            find
                    .ancestor(
                      of: find.text('Release notes'),
                      matching: find.byType(Row),
                    )
                    .evaluate()
                    .isEmpty
                ? find.byType(DecoratedBox)
                : find.descendant(
                    of: find
                        .ancestor(
                          of: find.text('Release notes'),
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                    matching: find.byType(DecoratedBox),
                  ),
          )
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();
      // A fill a hover state can imitate is not, on its own, a "you are here".
      expect(bars, contains(colors.primary));
    });
  });

  group('BeuiAiSidebar disabled rows', () {
    testWidgets('one dimming mechanism, not two compounded', (tester) async {
      await tester.pumpWidget(
        remediationHost(
          items: const [
            BeuiSidebarResource(
              id: 'off',
              label: 'Archived notes',
              kind: BeuiSidebarResourceKind.file,
              disabled: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The row-wide Opacity(0.45) is gone; only the colour dims.
      final opacities = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Archived notes'),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity < 0.99);
      expect(opacities, isEmpty);

      final style = tester.widget<Text>(find.text('Archived notes')).style!;
      // 0.7, not 0.55 x 0.45 — "disabled" should read as unavailable, not
      // invisible (it measured about 1.42:1).
      expect(style.color!.a, closeTo(0.7, 0.01));
    });

    testWidgets('and it is still announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        remediationHost(
          items: const [
            BeuiSidebarResource(
              id: 'off',
              label: 'Archived notes',
              kind: BeuiSidebarResourceKind.file,
              disabled: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(beuiAiSidebarRowKey('off'))),
        // The tree merges into one node, so assert the flags rather than a
        // label that arrives concatenated with its siblings'.
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });
  });

  group('BeuiAiSidebar row actions on touch', () {
    double menuOpacity(WidgetTester tester, String label) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedContainer),
      );
      return tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: row.first,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
    }

    testWidgets('on a pointer platform it stays hidden until hover', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost());
      await tester.pumpAndSettle();
      expect(menuOpacity(tester, 'Release notes'), 0);
    });

    testWidgets('on touch it is visible without a hover that never comes', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();
      // Previously Opacity(0) yet hit-testable: a permanently invisible button
      // at the end of every row.
      expect(menuOpacity(tester, 'Release notes'), closeTo(0.45, 0.001));
    });

    testWidgets('an invisible control takes no pointers', (tester) async {
      await tester.pumpWidget(remediationHost());
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('Release notes'),
        matching: find.byType(AnimatedContainer),
      );
      final ignoring = tester.widget<IgnorePointer>(
        find.descendant(of: row.first, matching: find.byType(IgnorePointer)),
      );
      expect(ignoring.ignoring, isTrue);
    });

    testWidgets('long press opens the row menu — touch has no right-click', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);

      await tester.longPress(find.text('Release notes'));
      await tester.pumpAndSettle();
      // Rename previously had no touch entry point at all: double-tap is the
      // desktop gesture and Shift+F10 is not a thing on a phone.
      expect(find.text('Rename'), findsOneWidget);
    });
  });

  group('BeuiAiSidebar marquee restraint', () {
    const longLabel =
        'Review resource sidebar interaction details across every surface';
    final wide = <BeuiSidebarResource>[
      const BeuiSidebarResource(
        id: 'long',
        label: longLabel,
        kind: BeuiSidebarResourceKind.file,
      ),
    ];

    Future<void> hoverRow(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text(longLabel).first));
      await tester.pump();
    }

    testWidgets('a brushed-past row does not start travelling', (tester) async {
      await tester.pumpWidget(remediationHost(items: wide, width: 200));
      await tester.pumpAndSettle();
      await hoverRow(tester);
      await tester.pump(const Duration(milliseconds: 200));
      // Still the single static ellipsised label: the 400ms intent threshold
      // has not elapsed.
      expect(find.text(longLabel), findsOneWidget);
    });

    testWidgets('a deliberate hover starts one pass, and only one', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost(items: wide, width: 200));
      await tester.pumpAndSettle();
      await hoverRow(tester);

      await tester.pump(const Duration(milliseconds: 500));
      // The marquee track duplicates the label so the scroll reads as a loop.
      expect(find.text(longLabel), findsNWidgets(2));

      // One pass, then it settles back to the static label — the source looped
      // forever, so the label could never be finished.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text(longLabel), findsOneWidget);
    });

    testWidgets('reduced motion never starts it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 200,
                    child: Material(child: BeuiAiSidebar(items: wide)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await hoverRow(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(longLabel), findsOneWidget);
    });
  });

  group('BeuiAiSidebar empty state and viewport', () {
    testWidgets('an empty tree is a state, not a zero-height box', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost(items: const []));
      await tester.pumpAndSettle();
      expect(find.text('No resources yet'), findsOneWidget);
    });

    testWidgets('the placeholder is overridable', (tester) async {
      await tester.pumpWidget(
        remediationHost(
          items: const [],
          emptyPlaceholder: const Text('Nothing shared with you'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing shared with you'), findsOneWidget);
    });

    testWidgets('maxHeight caps and scrolls the tree', (tester) async {
      final many = <BeuiSidebarResource>[
        for (var i = 0; i < 40; i++)
          BeuiSidebarResource(
            id: '$i',
            label: 'Resource $i',
            kind: BeuiSidebarResourceKind.file,
          ),
      ];
      await tester.pumpWidget(remediationHost(items: many, maxHeight: 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(BeuiAiSidebar)).height,
        lessThanOrEqualTo(200),
      );
      expect(
        find.descendant(
          of: find.byType(BeuiAiSidebar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without maxHeight the consumer still owns the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(remediationHost());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BeuiAiSidebar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    });
  });
}
