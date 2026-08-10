import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panel = ValueKey<String>('beui_bottom_sheet_panel');

class _Host extends StatefulWidget {
  const _Host({this.reduce = false});
  final bool reduce;

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
    final sheet = BeuiBottomSheet(
      open: open,
      onOpenChange: (v) {
        changes++;
        setState(() => open = v);
      },
      snapPoints: const [0.5, 0.92],
      title: 'Sheet',
      description: 'A draggable sheet.',
      child: const SizedBox(height: 600, child: Center(child: Text('BODY'))),
    );
    return MaterialApp(
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      ),
      home: Scaffold(
        // Toggle reduced motion while keeping the ambient MediaQuery (size etc.).
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: widget.reduce),
            child: sheet,
          ),
        ),
      ),
    );
  }
}

void main() {
  _HostState host(WidgetTester t) => t.state<_HostState>(find.byType(_Host));
  double sheetHeight(WidgetTester t) => t.getSize(find.byKey(_panel)).height;

  testWidgets('opens and closes', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('BODY'), findsNothing);

    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('Sheet'), findsOneWidget); // title in the drag area

    host(tester).hide();
    await tester.pump();
    expect(find.text('BODY'), findsOneWidget); // still exiting
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('opens at the default snap (half the viewport)', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    final screenH = tester.getSize(find.byType(MaterialApp)).height;
    expect(sheetHeight(tester), closeTo(screenH * 0.5, 1)); // snapPoints[0]
  });

  testWidgets('backdrop tap dismisses', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 40)); // scrim, well above the sheet
    await tester.pump();
    expect(host(tester).changes, 1);
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('Esc dismisses', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(host(tester).changes, 1);
  });

  testWidgets('flinging the handle up snaps to the taller point', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    final screenH = tester.getSize(find.byType(MaterialApp)).height;
    expect(sheetHeight(tester), closeTo(screenH * 0.5, 1));

    // Fling the drag handle (the title lives in it) upward → next snap (0.92).
    await tester.fling(find.text('Sheet'), const Offset(0, -240), 1200);
    await tester.pumpAndSettle();

    expect(sheetHeight(tester), closeTo(screenH * 0.92, 1));
    expect(host(tester).changes, 0); // snapped, not dismissed
  });

  testWidgets('flinging the handle down from the lowest snap dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    // At snap 0 (the lowest), a strong downward fling closes the sheet.
    await tester.fling(find.text('Sheet'), const Offset(0, 300), 1500);
    await tester.pump();
    expect(host(tester).changes, 1);
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('reduced motion opens instantly (opacity, no slide)', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(reduce: true));
    host(tester).show();
    await tester.pump(); // one frame — no long slide to settle
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('BODY'), findsOneWidget);
    final screenH = tester.getSize(find.byType(MaterialApp)).height;
    expect(sheetHeight(tester), closeTo(screenH * 0.5, 1));
  });
}
