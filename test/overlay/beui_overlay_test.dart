import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panel = ValueKey<String>('panel');

class _Host extends StatefulWidget {
  const _Host({this.barrierDismissible = true, this.trapFocus = true});
  final bool barrierDismissible;
  final bool trapFocus;

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
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      ),
      home: Scaffold(
        body: Center(
          child: BeuiOverlay(
            open: open,
            barrierDismissible: widget.barrierDismissible,
            trapFocus: widget.trapFocus,
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
                  color: const Color(0xFF202020),
                ),
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

  // Regression: the Esc binding used to sit inside `Focus(autofocus: trapFocus)`,
  // so with no focus trap nothing in the overlay ever took focus and the key
  // event never travelled up to the binding — Esc was dead on the composer's
  // menus, the select popover, the tooltip and the table menu (audit I2).
  testWidgets('Esc dismisses with trapFocus: false', (tester) async {
    await tester.pumpWidget(const _Host(trapFocus: false));
    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(host(tester).dismissCount, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsNothing);
  });

  testWidgets('Esc fires onDismiss exactly once with trapFocus: false', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(trapFocus: false));
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // A second Esc after the overlay closed must not re-fire: the state
    // deregisters as soon as `open` flips false.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(host(tester).dismissCount, 1);
  });

  testWidgets('Esc closes only the topmost non-trapping overlay', (
    tester,
  ) async {
    final dismissed = <String>[];
    var outerOpen = true;
    var innerOpen = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BeuiOverlay(
              open: outerOpen,
              trapFocus: false,
              barrier: false,
              onDismiss: () {
                dismissed.add('outer');
                setState(() => outerOpen = false);
              },
              overlayBuilder: (context, animation, link) => const SizedBox(),
              child: BeuiOverlay(
                open: innerOpen,
                trapFocus: false,
                barrier: false,
                onDismiss: () {
                  dismissed.add('inner');
                  setState(() => innerOpen = false);
                },
                overlayBuilder: (context, animation, link) => const SizedBox(),
                child: const SizedBox(width: 50, height: 50),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Registration order is mount order (outer, then inner), and Esc unwinds
    // the stack from the top.
    expect(dismissed, ['inner']);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dismissed, ['inner', 'outer']);
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
