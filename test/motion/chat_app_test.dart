import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: SizedBox(width: 900, height: 640, child: child));
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
  group('BeuiChatApp', () {
    testWidgets('lays out sidebar, header, body, and prompt', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiChatApp(
            sidebar: const ColoredBox(
              color: Colors.red,
              child: Center(child: Text('Sidebar')),
            ),
            header: const SizedBox(
              height: 48,
              child: Center(child: Text('Header')),
            ),
            body: const Center(child: Text('Body')),
            prompt: const SizedBox(
              height: 56,
              child: Center(child: Text('Prompt')),
            ),
          ),
        ),
      );

      expect(find.text('Sidebar'), findsOneWidget);
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Prompt'), findsOneWidget);
    });

    testWidgets('omits sidebar when null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiChatApp(
            header: SizedBox(height: 40, child: Text('Only header')),
            body: Center(child: Text('Only body')),
            prompt: SizedBox(height: 40, child: Text('Only prompt')),
          ),
        ),
      );

      expect(find.text('Sidebar'), findsNothing);
      expect(find.text('Only body'), findsOneWidget);
      expect(find.text('Only header'), findsOneWidget);
      expect(find.text('Only prompt'), findsOneWidget);
    });

    testWidgets('uses custom sidebar width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiChatApp(
            sidebarWidth: 200,
            sidebar: const ColoredBox(
              color: Colors.blue,
              child: Text('Wide sidebar'),
            ),
            body: const Center(child: Text('Main')),
          ),
        ),
      );

      final sized = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final sidebarBox = sized.where((s) => s.width == 200).toList();
      expect(sidebarBox, isNotEmpty);
      expect(find.text('Wide sidebar'), findsOneWidget);
    });

    testWidgets('exposes workspace semantics label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiChatApp(
            semanticLabel: 'Release workspace',
            body: Center(child: Text('Body')),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Release workspace'), findsOneWidget);
    });
  });

  group('BeuiChatApp collapsed sidebar drawer', () {
    Widget wrapNarrow(Widget child, {bool reduce = false}) {
      Widget body = Center(
        child: SizedBox(width: 400, height: 500, child: child),
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

    testWidgets('below the breakpoint the sidebar drawer opens and dismisses', (
      tester,
    ) async {
      var open = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => wrapNarrow(
            BeuiChatApp(
              sidebar: const Center(child: Text('Nav')),
              sidebarOpen: open,
              onSidebarDismiss: () => setState(() => open = false),
              body: const Center(child: Text('Body')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nav'), findsOneWidget);

      await tester.tapAt(
        const Offset(500, 60),
      ); // scrim, clear of the 272px-wide panel
      await tester.pumpAndSettle();
      expect(find.text('Nav'), findsNothing);
    });

    testWidgets('reduced motion still opens and dismisses the drawer', (
      tester,
    ) async {
      var open = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => wrapNarrow(
            BeuiChatApp(
              sidebar: const Center(child: Text('Nav')),
              sidebarOpen: open,
              onSidebarDismiss: () => setState(() => open = false),
              body: const Center(child: Text('Body')),
            ),
            reduce: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nav'), findsOneWidget);

      await tester.tapAt(const Offset(500, 60)); // scrim, clear of the panel
      await tester.pumpAndSettle();
      expect(find.text('Nav'), findsNothing);
    });
  });
}
