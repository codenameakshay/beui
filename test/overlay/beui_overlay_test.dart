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

/// Like [_Host], but boxes the trigger in a [ClipRect] to prove the panel
/// escapes it — [BeuiOverlay] renders into the root [Overlay], not in place.
class _ClipHost extends StatefulWidget {
  const _ClipHost();

  @override
  State<_ClipHost> createState() => _ClipHostState();
}

class _ClipHostState extends State<_ClipHost> {
  bool open = false;

  void show() => setState(() => open = true);

  static const clipKey = ValueKey('clip');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      ),
      home: Scaffold(
        body: Center(
          child: ClipRect(
            key: clipKey,
            child: SizedBox(
              width: 50,
              height: 50,
              child: BeuiOverlay(
                open: open,
                overlayBuilder: (context, animation, link) => Container(
                  key: _panel,
                  width: 200,
                  height: 200,
                  color: const Color(0xFF202020),
                ),
                child: const SizedBox(width: 50, height: 50),
              ),
            ),
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

  testWidgets(
    'content renders into the root overlay, escaping an ancestor clip',
    (tester) async {
      await tester.pumpWidget(const _ClipHost());
      tester.state<_ClipHostState>(find.byType(_ClipHost)).show();
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsOneWidget);
      // `find.descendant` walks the *Element* tree, where an OverlayPortal's
      // overlay child stays a logical child of its portal (so ancestor
      // lookups like Theme still work) even though it *paints* elsewhere —
      // so an Element-tree check can't prove render-tree escape. Walk the
      // RenderObject parent chain instead: if BeuiOverlay rendered in place,
      // the panel's render object would sit under the ClipRect's; it does
      // not, because it renders into the root Overlay.
      RenderObject? node = tester.renderObject(find.byKey(_panel));
      final clipRenderObject = tester.renderObject(
        find.byKey(_ClipHostState.clipKey),
      );
      var underClip = false;
      while (node != null) {
        if (identical(node, clipRenderObject)) {
          underClip = true;
          break;
        }
        node = node.parent;
      }
      expect(underClip, isFalse);
    },
  );

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
