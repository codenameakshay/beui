import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panel = ValueKey<String>('panel');

class _Host extends StatefulWidget {
  const _Host({this.barrierDismissible = true});
  final bool barrierDismissible;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;
  int dismissCount = 0;

  void show() => setState(() => open = true);
  void hide() => setState(() => open = false);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(
        body: Center(
          child: BeuiOverlay(
            open: open,
            barrierDismissible: widget.barrierDismissible,
            onDismiss: () {
              dismissCount++;
              setState(() => open = false);
            },
            overlayBuilder: (context, animation, link) => Center(
              child: FadeTransition(
                opacity: animation,
                child: Container(
                    key: _panel,
                    width: 200,
                    height: 120,
                    color: const Color(0xFF202020)),
              ),
            ),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      ),
    );
  }
}

void main() {
  _HostState host(WidgetTester t) => t.state<_HostState>(find.byType(_Host));

  testWidgets('mounts on open, unmounts after close', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.byKey(_panel), findsNothing);

    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsOneWidget);

    host(tester).hide();
    await tester.pump(); // exit begins — still mounted
    expect(find.byKey(_panel), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsNothing);
  });

  testWidgets('content renders into the root overlay', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();
    // The panel is a descendant of an Overlay, not of the BeuiOverlay's child.
    expect(
      find.ancestor(of: find.byKey(_panel), matching: find.byType(Overlay)),
      findsWidgets,
    );
  });

  testWidgets('barrier tap dismisses', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10)); // on the barrier, off the panel
    await tester.pump();
    expect(host(tester).dismissCount, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsNothing);
  });

  testWidgets('Esc dismisses', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(host(tester).dismissCount, 1);
  });

  testWidgets('barrierDismissible: false ignores barrier taps', (tester) async {
    await tester.pumpWidget(const _Host(barrierDismissible: false));
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(host(tester).dismissCount, 0);
    expect(find.byKey(_panel), findsOneWidget);
  });
}
