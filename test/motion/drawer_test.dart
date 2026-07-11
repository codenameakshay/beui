import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panel = ValueKey<String>('beui_drawer_panel');

class _Host extends StatefulWidget {
  const _Host({this.side = BeuiDrawerSide.right, this.dismissible = true});
  final BeuiDrawerSide side;
  final bool dismissible;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;
  int changes = 0;

  void show() => setState(() => open = true);
  void hide() => setState(() => open = false);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(
        body: BeuiDrawer(
          open: open,
          side: widget.side,
          dismissible: widget.dismissible,
          label: 'Menu',
          onOpenChange: (v) {
            changes++;
            setState(() => open = v);
          },
          child: const Center(child: Text('DRAWER')),
        ),
      ),
    );
  }
}

void main() {
  _HostState host(WidgetTester t) => t.state<_HostState>(find.byType(_Host));

  testWidgets('opens and closes', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('DRAWER'), findsNothing);

    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.text('DRAWER'), findsOneWidget);

    host(tester).hide();
    await tester.pump();
    expect(find.text('DRAWER'), findsOneWidget); // still exiting
    await tester.pumpAndSettle();
    expect(find.text('DRAWER'), findsNothing);
  });

  testWidgets('backdrop tap closes', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    // The right-side panel is on the right; tap the barrier on the left.
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    expect(host(tester).changes, 1);
    await tester.pumpAndSettle();
    expect(find.text('DRAWER'), findsNothing);
  });

  testWidgets('Esc closes', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(host(tester).changes, 1);
  });

  testWidgets('non-dismissible ignores backdrop taps', (tester) async {
    await tester.pumpWidget(const _Host(dismissible: false));
    host(tester).show();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    expect(host(tester).changes, 0);
    expect(find.text('DRAWER'), findsOneWidget);
  });

  testWidgets('right pins to the right edge', (tester) async {
    await tester.pumpWidget(const _Host(side: BeuiDrawerSide.right));
    host(tester).show();
    await tester.pumpAndSettle();
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(
      tester.getTopRight(find.byKey(_panel)).dx,
      closeTo(screen.width, 0.5),
    );
  });

  testWidgets('left pins to the left edge', (tester) async {
    await tester.pumpWidget(const _Host(side: BeuiDrawerSide.left));
    host(tester).show();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_panel)).dx, closeTo(0, 0.5));
  });
}
