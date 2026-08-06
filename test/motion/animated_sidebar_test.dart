import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _groups = [
  BeuiAnimatedSidebarGroup(
    items: const [
      BeuiAnimatedSidebarItem(
        id: 'search',
        label: 'Search',
        icon: Icons.search,
      ),
      BeuiAnimatedSidebarItem(
        id: 'inbox',
        label: 'Inbox',
        icon: Icons.inbox,
        badge: '4',
      ),
    ],
  ),
  BeuiAnimatedSidebarGroup(
    label: 'Workspaces',
    items: const [
      BeuiAnimatedSidebarItem(
        id: 'people',
        label: 'People',
        icon: Icons.people,
        children: [
          BeuiAnimatedSidebarItem(id: 'all-people', label: 'All people'),
          BeuiAnimatedSidebarItem(id: 'segments', label: 'Segments'),
        ],
      ),
      BeuiAnimatedSidebarItem(
        id: 'tasks',
        label: 'Tasks',
        icon: Icons.checklist,
      ),
    ],
  ),
];

Widget _wrap(
  Widget child, {
  bool reduce = false,
  Size size = const Size(1024, 800),
}) {
  Widget body = MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: reduce),
    child: child,
  );
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

/// The desktop panel's chrome decoration — background, border, radius, shadow.
BoxDecoration _chrome(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(find.byKey(beuiAnimatedSidebarChromeKey))
            .decoration
        as BoxDecoration;

void main() {
  group('BeuiAnimatedSidebar', () {
    testWidgets('renders items and group labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            child: const Text('Main'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('WORKSPACES'), findsOneWidget);
      expect(find.text('Main'), findsOneWidget);
      expect(find.byKey(beuiAnimatedSidebarPanelKey), findsOneWidget);
    });

    testWidgets('selection callback fires for leaf items', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            onSelected: (id) => selected = id,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(selected, 'search');

      await tester.tap(find.text('Inbox'));
      await tester.pump();
      expect(selected, 'inbox');
    });

    testWidgets('parent with children toggles submenu, not selection', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            onSelected: (id) => selected = id,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nested children hidden until section opens.
      expect(find.text('All people'), findsNothing);

      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      // Parent toggle should not select.
      expect(selected, isNull);
      expect(find.text('All people'), findsOneWidget);
      expect(find.text('Segments'), findsOneWidget);

      await tester.tap(find.text('All people'));
      await tester.pump();
      expect(selected, 'all-people');
    });

    testWidgets('expand/collapse toggles via trigger and callback', (
      tester,
    ) async {
      var expanded = true;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return BeuiAnimatedSidebar(
                groups: _groups,
                expanded: expanded,
                onExpandedChange: (v) => setState(() => expanded = v),
                defaultSelectedId: 'tasks',
                child: const Column(
                  children: [
                    BeuiAnimatedSidebarTrigger(),
                    Expanded(child: SizedBox.expand()),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(expanded, isTrue);

      await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
      await tester.pumpAndSettle();
      expect(expanded, isFalse);

      await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
      await tester.pumpAndSettle();
      expect(expanded, isTrue);
    });

    testWidgets('collapsed icon rail keeps panel mounted at icon width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiAnimatedSidebar(
            groups: [
              BeuiAnimatedSidebarGroup(
                items: [
                  BeuiAnimatedSidebarItem(
                    id: 'a',
                    label: 'Alpha',
                    icon: Icons.home,
                  ),
                ],
              ),
            ],
            defaultExpanded: false,
            defaultSelectedId: 'a',
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = tester.getSize(find.byKey(beuiAnimatedSidebarPanelKey));
      // Panel is inside a width-constrained rail; collapsed ≈ icon width.
      expect(panel.width, lessThan(kBeuiAnimatedSidebarWidth));
      expect(panel.width, closeTo(kBeuiAnimatedSidebarIconWidth, 8));
    });

    testWidgets('reduced motion still renders and selects', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            onSelected: (id) => selected = id,
            child: const SizedBox.expand(),
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(selected, 'search');
    });

    testWidgets('mobile mode opens sheet from trigger', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            child: const Column(
              children: [
                BeuiAnimatedSidebarTrigger(),
                Expanded(child: Text('Mobile main')),
              ],
            ),
          ),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop panel rail is not in the row layout on mobile — main is shown.
      expect(find.text('Mobile main'), findsOneWidget);
      // Sheet closed: nav labels not visible in main tree the same way —
      // open via trigger.
      await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsOneWidget);
      expect(find.text('Search'), findsWidgets);
    });

    testWidgets('controlled selectedId updates highlight path', (tester) async {
      var selected = 'tasks';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return BeuiAnimatedSidebar(
                groups: _groups,
                selectedId: selected,
                onSelected: (id) => setState(() => selected = id),
                child: Text('sel:$selected'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sel:tasks'), findsOneWidget);

      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('sel:inbox'), findsOneWidget);
    });
  });

  group('BeuiAnimatedSidebar variant', () {
    testWidgets('sidebar (default) is flush: inner-edge border, no radius, '
        'no shadow, no inset chrome', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chrome = _chrome(tester);
      // Left side → border on the RIGHT edge only.
      final border = chrome.border! as Border;
      expect(border.right.style, BorderStyle.solid);
      expect(border.left.style, BorderStyle.none);
      expect(chrome.borderRadius, BorderRadius.zero);
      expect(chrome.boxShadow, isNull);

      // Flush panel fills the whole rail width — no `m-2`.
      expect(
        tester.getSize(find.byKey(beuiAnimatedSidebarChromeKey)).width,
        closeTo(kBeuiAnimatedSidebarWidth, 0.5),
      );
      // The content area stays plain for this variant.
      expect(find.byKey(beuiAnimatedSidebarInsetKey), findsNothing);
    });

    testWidgets('sidebar on the right borders its LEFT (inner) edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            side: BeuiAnimatedSidebarSide.right,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final border = _chrome(tester).border! as Border;
      expect(border.left.style, BorderStyle.solid);
      expect(border.right.style, BorderStyle.none);
    });

    testWidgets('floating is a detached card: m-2 inset, 1rem radius, border '
        'all round, shadow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            variant: BeuiAnimatedSidebarVariant.floating,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chrome = _chrome(tester);
      expect(chrome.borderRadius, BorderRadius.circular(16));
      expect(chrome.boxShadow, isNotNull);
      expect(chrome.boxShadow, isNotEmpty);
      final border = chrome.border! as Border;
      for (final side in [
        border.top,
        border.bottom,
        border.left,
        border.right,
      ]) {
        expect(side.style, BorderStyle.solid);
      }

      // m-2 on every edge: 16 narrower and 16 shorter than the flush panel,
      // while the rail still reserves the full sidebar width in the row.
      final shell = tester.getRect(find.byType(BeuiAnimatedSidebar));
      final rect = tester.getRect(find.byKey(beuiAnimatedSidebarChromeKey));
      expect(rect.width, closeTo(kBeuiAnimatedSidebarWidth - 16, 0.5));
      expect(rect.height, closeTo(shell.height - 16, 0.5));
      expect(rect.left, closeTo(shell.left + 8, 0.5));
      expect(rect.top, closeTo(shell.top + 8, 0.5));

      // Floating leaves the content area alone.
      expect(find.byKey(beuiAnimatedSidebarInsetKey), findsNothing);
    });

    testWidgets('inset: panel is detached but bare, and the CONTENT area '
        'becomes the card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            variant: BeuiAnimatedSidebarVariant.inset,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Panel: same detached geometry as floating, but no border and no shadow.
      final chrome = _chrome(tester);
      expect(chrome.borderRadius, BorderRadius.circular(16));
      expect(chrome.border, isNull);
      expect(chrome.boxShadow, isNull);
      final panelRect = tester.getRect(
        find.byKey(beuiAnimatedSidebarChromeKey),
      );
      expect(panelRect.width, closeTo(kBeuiAnimatedSidebarWidth - 16, 0.5));

      // Content: gains margin, radius and shadow.
      final insetFinder = find.byKey(beuiAnimatedSidebarInsetKey);
      expect(insetFinder, findsOneWidget);
      final inset =
          tester.widget<DecoratedBox>(insetFinder).decoration as BoxDecoration;
      expect(inset.borderRadius, BorderRadius.circular(16));
      expect(inset.boxShadow, isNotEmpty);

      // Margin is dropped on the edge the sidebar already spaced (source
      // `ml-0`), kept on the other three.
      final shell = tester.getRect(find.byType(BeuiAnimatedSidebar));
      final insetRect = tester.getRect(insetFinder);
      expect(
        insetRect.left,
        closeTo(shell.left + kBeuiAnimatedSidebarWidth, 0.5),
      );
      expect(insetRect.top, closeTo(shell.top + 8, 0.5));
      expect(insetRect.bottom, closeTo(shell.bottom - 8, 0.5));
      expect(insetRect.right, closeTo(shell.right - 8, 0.5));
    });

    testWidgets('inset on the right drops the margin on its right edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            variant: BeuiAnimatedSidebarVariant.inset,
            side: BeuiAnimatedSidebarSide.right,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shell = tester.getRect(find.byType(BeuiAnimatedSidebar));
      final rect = tester.getRect(find.byKey(beuiAnimatedSidebarInsetKey));
      expect(rect.left, closeTo(shell.left + 8, 0.5));
      expect(rect.right, closeTo(shell.right - kBeuiAnimatedSidebarWidth, 0.5));
    });

    testWidgets('variant chrome survives a collapse to the icon rail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            variant: BeuiAnimatedSidebarVariant.floating,
            defaultExpanded: false,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chrome = _chrome(tester);
      expect(chrome.borderRadius, BorderRadius.circular(16));
      // Card is still inset by m-2 inside the narrower icon rail.
      expect(
        tester.getSize(find.byKey(beuiAnimatedSidebarChromeKey)).width,
        closeTo(kBeuiAnimatedSidebarIconWidth - 16, 1),
      );
    });

    testWidgets('mobile ignores the variant — the sheet keeps its own chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            variant: BeuiAnimatedSidebarVariant.inset,
            defaultOpenMobile: true,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsOneWidget);
      expect(find.byKey(beuiAnimatedSidebarChromeKey), findsNothing);
      expect(find.byKey(beuiAnimatedSidebarInsetKey), findsNothing);
    });

    testWidgets('reduced motion still renders the floating chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            variant: BeuiAnimatedSidebarVariant.floating,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();

      final chrome = _chrome(tester);
      expect(chrome.borderRadius, BorderRadius.circular(16));
      expect(chrome.boxShadow, isNotEmpty);
      expect(find.text('Tasks'), findsOneWidget);
    });
  });

  group('BeuiAnimatedSidebar mobile sheet state', () {
    testWidgets('defaultOpenMobile opens the sheet on first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultOpenMobile: true,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsOneWidget);
      expect(find.text('Search'), findsWidgets);
    });

    testWidgets('uncontrolled openMobile notifies onOpenMobileChange', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            onOpenMobileChange: changes.add,
            defaultSelectedId: 'tasks',
            child: const Column(
              children: [
                BeuiAnimatedSidebarTrigger(),
                Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
      await tester.pumpAndSettle();
      expect(changes, [true]);
      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsOneWidget);

      // Selecting a destination auto-closes the sheet (source `closeOnSelect`).
      await tester.tap(find.text('Search').first);
      await tester.pumpAndSettle();
      expect(changes, [true, false]);
    });

    testWidgets(
      'controlled openMobile does NOT self-open — the owner decides',
      (tester) async {
        final changes = <bool>[];
        await tester.pumpWidget(
          _wrap(
            BeuiAnimatedSidebar(
              groups: _groups,
              openMobile: false,
              onOpenMobileChange: changes.add,
              defaultSelectedId: 'tasks',
              child: const Column(
                children: [
                  BeuiAnimatedSidebarTrigger(),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
            size: const Size(400, 800),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
        await tester.pumpAndSettle();

        // Callback fired, but the pinned prop still wins.
        expect(changes, [true]);
        expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsNothing);
      },
    );

    testWidgets('controlled openMobile opens when the owner writes it back', (
      tester,
    ) async {
      var open = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => BeuiAnimatedSidebar(
              groups: _groups,
              openMobile: open,
              onOpenMobileChange: (v) => setState(() => open = v),
              defaultSelectedId: 'tasks',
              child: const Column(
                children: [
                  BeuiAnimatedSidebarTrigger(),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsNothing);

      await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
      await tester.pumpAndSettle();
      expect(open, isTrue);
      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsOneWidget);

      // The trigger is behind the sheet's barrier once open, so close the way
      // a user would: the sheet's own close button.
      await tester.tap(find.byTooltip('Close sidebar'));
      await tester.pumpAndSettle();
      expect(open, isFalse);
      expect(find.byKey(beuiAnimatedSidebarMobilePanelKey), findsNothing);
    });
  });

  group('BeuiAnimatedSidebar row geometry', () {
    // Source `AnimatedSidebarMenuButton` never re-centres its icon: the row
    // keeps `px-3` at every width and the closing rail lands the glyph
    // dead-centre by arithmetic — 8 (content `px-2`) + 4 (group `px-1`)
    // + 12 (row `px-3`) + 10 (half of the `size-5` cell) = 34 = 68 / 2.
    // Re-centring instead makes the icon jump to the middle of a still-wide
    // panel mid-morph.
    Future<double> iconCentre(WidgetTester tester) async {
      final panel = tester.getRect(find.byKey(beuiAnimatedSidebarChromeKey));
      final icon = tester.getRect(find.byIcon(Icons.search));
      return icon.center.dx - panel.left;
    }

    testWidgets(
      'icon keeps its px-3 anchor expanded, collapsed and mid-morph',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BeuiAnimatedSidebar(
              groups: _groups,
              defaultExpanded: true,
              defaultSelectedId: 'tasks',
              child: const Column(
                children: [
                  BeuiAnimatedSidebarTrigger(),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(await iconCentre(tester), closeTo(34, 0.5));

        // Collapse, and sample partway through the width spring.
        await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          await iconCentre(tester),
          closeTo(34, 0.5),
          reason: 'icon must not re-anchor while the rail is still wide',
        );

        await tester.pumpAndSettle();
        expect(await iconCentre(tester), closeTo(34, 0.5));
        // …which is the centre of the 68 icon rail.
        expect(
          tester.getSize(find.byKey(beuiAnimatedSidebarChromeKey)).width,
          closeTo(kBeuiAnimatedSidebarIconWidth, 0.5),
        );
      },
    );

    testWidgets('rows sit on the source 38 pitch (h-9 + gap-0.5)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: _groups,
            defaultSelectedId: 'tasks',
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final search = tester.getRect(find.text('Search'));
      final inbox = tester.getRect(find.text('Inbox'));
      expect(inbox.center.dy - search.center.dy, closeTo(38, 0.5));
    });
  });
}
