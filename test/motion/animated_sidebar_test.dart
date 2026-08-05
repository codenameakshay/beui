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
}
