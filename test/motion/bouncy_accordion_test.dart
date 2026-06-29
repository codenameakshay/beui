import 'package:beui/beui.dart';
import 'package:beui/src/motion/bouncy_accordion.dart'
    show beuiAccordionPanelKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <BeuiBouncyAccordionItem>[
  BeuiBouncyAccordionItem(
    id: 'a',
    title: Text('Alpha'),
    description: SizedBox(height: 120, child: Center(child: Text('Body A'))),
  ),
  BeuiBouncyAccordionItem(
    id: 'b',
    title: Text('Bravo'),
    description: SizedBox(height: 200, child: Center(child: Text('Body B'))),
  ),
  BeuiBouncyAccordionItem(
    id: 'c',
    title: Text('Charlie'),
    description: SizedBox(height: 160, child: Center(child: Text('Body C'))),
  ),
];

Widget _host({
  String? value,
  String? defaultValue,
  ValueChanged<String?>? onChanged,
  bool collapsible = true,
  bool reduce = false,
}) {
  Widget accordion = BeuiBouncyAccordion(
    items: _items,
    value: value,
    defaultValue: defaultValue,
    onChanged: onChanged,
    collapsible: collapsible,
  );
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: Center(child: SizedBox(width: 360, child: accordion)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a row morphs its panel open (height grows over time)', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // Collapsed: panel is clipped to ~0 even though content is laid out.
    final clipped = tester.getSize(
      find.ancestor(
        of: find.byKey(beuiAccordionPanelKey('a')),
        matching: find.byType(ClipRect),
      ),
    );
    expect(clipped.height, lessThan(2.0));

    await tester.tap(find.text('Alpha'));
    await tester.pump(); // start the spring

    // Mid-morph: the clip has begun opening but not yet reached full height.
    await tester.pump(const Duration(milliseconds: 90));
    final midClip = tester.getSize(
      find.ancestor(
        of: find.byKey(beuiAccordionPanelKey('a')),
        matching: find.byType(ClipRect),
      ),
    );
    expect(midClip.height, greaterThan(2.0));
    expect(midClip.height, lessThan(140.0)); // not snapped

    await tester.pumpAndSettle();
    final openClip = tester.getSize(
      find.ancestor(
        of: find.byKey(beuiAccordionPanelKey('a')),
        matching: find.byType(ClipRect),
      ),
    );
    expect(openClip.height, greaterThan(midClip.height));
    expect(openClip.height, closeTo(140.0, 1.0)); // measured content height
  });

  testWidgets('single-open: opening one row closes the previously open row', (
    tester,
  ) async {
    String? changed = 'unset';
    await tester.pumpWidget(
      _host(defaultValue: 'a', onChanged: (v) => changed = v),
    );
    await tester.pumpAndSettle();

    double clipHeight(String id) => tester
        .getSize(
          find.ancestor(
            of: find.byKey(beuiAccordionPanelKey(id)),
            matching: find.byType(ClipRect),
          ),
        )
        .height;

    expect(clipHeight('a'), greaterThan(100)); // a is open
    expect(clipHeight('b'), lessThan(2.0)); // b is closed

    await tester.tap(find.text('Bravo'));
    expect(changed, 'b');
    await tester.pumpAndSettle();

    expect(clipHeight('b'), greaterThan(100)); // b opened
    expect(clipHeight('a'), lessThan(2.0)); // a closed (single-open)
  });

  testWidgets('collapsible: tapping the open row collapses it', (tester) async {
    String? changed = 'unset';
    await tester.pumpWidget(
      _host(defaultValue: 'a', onChanged: (v) => changed = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    expect(changed, isNull); // collapsed back to nothing
    await tester.pumpAndSettle();

    final clip = tester.getSize(
      find.ancestor(
        of: find.byKey(beuiAccordionPanelKey('a')),
        matching: find.byType(ClipRect),
      ),
    );
    expect(clip.height, lessThan(2.0));
  });

  testWidgets('non-collapsible: tapping the open row keeps it open', (
    tester,
  ) async {
    String? changed = 'unset';
    await tester.pumpWidget(
      _host(
        defaultValue: 'a',
        collapsible: false,
        onChanged: (v) => changed = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    // No state change emitted; row stays open.
    expect(changed, 'unset');
    await tester.pumpAndSettle();

    final clip = tester.getSize(
      find.ancestor(
        of: find.byKey(beuiAccordionPanelKey('a')),
        matching: find.byType(ClipRect),
      ),
    );
    expect(clip.height, greaterThan(100));
  });

  testWidgets('controlled: value drives open state, onChanged reports intent', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(_host(value: 'a', onChanged: (v) => changed = v));
    await tester.pumpAndSettle();

    // Tapping a closed row reports intent but does NOT self-open (controlled).
    await tester.tap(find.text('Bravo'));
    expect(changed, 'b');
    await tester.pumpAndSettle();

    final bClip = tester
        .getSize(
          find.ancestor(
            of: find.byKey(beuiAccordionPanelKey('b')),
            matching: find.byType(ClipRect),
          ),
        )
        .height;
    expect(bClip, lessThan(2.0)); // still closed — value is still 'a'
  });

  testWidgets('reduced motion: opening is instant (no spring frames)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduce: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    // A single frame — the morph snaps to full height with no spring frames
    // (reduced motion drops movement entirely rather than oscillating).
    await tester.pump();

    final clip = tester.getSize(
      find.ancestor(
        of: find.byKey(beuiAccordionPanelKey('a')),
        matching: find.byType(ClipRect),
      ),
    );
    expect(clip.height, closeTo(140.0, 1.0)); // snapped, not mid-spring

    // Content is intact under reduced motion.
    expect(find.text('Body A'), findsOneWidget);
  });

  testWidgets('a tap mid-bounce still toggles (stable hit target)', (
    tester,
  ) async {
    double clipHeight(String id) => tester
        .getSize(
          find.ancestor(
            of: find.byKey(beuiAccordionPanelKey(id)),
            matching: find.byType(ClipRect),
          ),
        )
        .height;

    await tester.pumpWidget(_host()); // uncontrolled, nothing open
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pump(); // start opening 'a'
    await tester.pump(const Duration(milliseconds: 80)); // mid-bounce
    expect(clipHeight('a'), greaterThan(2.0)); // 'a' is springing open

    // Tapping another row WHILE 'a' is still animating must register — the tap
    // target is threaded as a stable child, not rebuilt each spring frame.
    await tester.tap(find.text('Bravo'));
    await tester.pumpAndSettle();

    expect(clipHeight('b'), greaterThan(100)); // 'b' opened
    expect(clipHeight('a'), lessThan(2.0)); // 'a' closed (single-open)
  });
}
