import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panel = ValueKey<String>('beui_modal_panel');

class _Host extends StatefulWidget {
  const _Host({this.placement = BeuiModalPlacement.bottom});
  final BeuiModalPlacement placement;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? viewId;
  int closes = 0;

  void open(String id) => setState(() => viewId = id);
  void close() => setState(() => viewId = null);

  Widget _view() => switch (viewId) {
    'a' => const SizedBox(height: 80, child: Center(child: Text('VIEW A'))),
    'b' => const SizedBox(height: 240, child: Center(child: Text('VIEW B'))),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(
        body: BeuiMorphingModal(
          viewId: viewId,
          placement: widget.placement,
          onClose: () {
            closes++;
            setState(() => viewId = null);
          },
          child: _view(),
        ),
      ),
    );
  }
}

void main() {
  _HostState host(WidgetTester t) => t.state<_HostState>(find.byType(_Host));
  double panelHeight(WidgetTester t) => t.getSize(find.byKey(_panel)).height;

  testWidgets('opens and closes', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('VIEW A'), findsNothing);

    host(tester).open('a');
    await tester.pumpAndSettle();
    expect(find.text('VIEW A'), findsOneWidget);

    host(tester).close();
    await tester.pumpAndSettle();
    expect(find.text('VIEW A'), findsNothing);
  });

  testWidgets('backdrop tap and Esc close', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).open('a');
    await tester.pumpAndSettle();

    await tester.tapAt(
      const Offset(10, 10),
    ); // backdrop (panel is bottom-center)
    await tester.pump();
    expect(host(tester).closes, 1);
    await tester.pumpAndSettle();

    host(tester).open('a');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(host(tester).closes, 2);
  });

  testWidgets('morphs height + swaps content between views', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).open('a');
    await tester.pumpAndSettle();
    final hA = panelHeight(tester);
    expect(find.text('VIEW A'), findsOneWidget);

    host(tester).open('b'); // taller view
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final hMid = panelHeight(tester);
    await tester.pumpAndSettle();
    final hB = panelHeight(tester);

    expect(find.text('VIEW B'), findsOneWidget);
    expect(find.text('VIEW A'), findsNothing);
    expect(hB, greaterThan(hA)); // morphed taller
    expect(hMid, greaterThan(hA));
    expect(hMid, lessThan(hB)); // mid-morph, i.e. animating not snapping
  });

  testWidgets('bottom placement sits near the bottom', (tester) async {
    await tester.pumpWidget(const _Host(placement: BeuiModalPlacement.bottom));
    host(tester).open('a');
    await tester.pumpAndSettle();
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(
      tester.getBottomLeft(find.byKey(_panel)).dy,
      greaterThan(screen.height * 0.6),
    );
  });
}
