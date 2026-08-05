import 'dart:ui' show ImageFilter;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const _icons = <IconData>[
  LucideIcons.house,
  LucideIcons.mail,
  LucideIcons.calendar,
  LucideIcons.music,
  LucideIcons.sparkles,
];

Widget _app({bool magnify = false, bool reduce = false, int activeIndex = 0}) {
  Widget dock = BeuiDock(
    magnify: magnify,
    items: [
      for (var i = 0; i < _icons.length; i++)
        BeuiDockItem(icon: _icons[i], active: i == activeIndex, onTap: () {}),
    ],
  );
  if (reduce) {
    dock = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: dock,
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: Center(child: dock)),
  );
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  return g;
}

/// Uniform scale applied to the dock item carrying [icon], or `null` if the item
/// has no scaling `Transform` (the faithful dock paints items at fixed size).
double? _scaleOf(WidgetTester tester, IconData icon) {
  final transforms = find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(Transform),
  );
  if (transforms.evaluate().isEmpty) return null;
  return tester.widget<Transform>(transforms.first).transform.storage[0];
}

/// The active pill — the rounded-xl (r=12) highlight behind the active item.
Finder _pillFinder() => find.descendant(
  of: find.byType(BeuiDock),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius ==
            BorderRadius.circular(12),
  ),
);

int _pillCount(WidgetTester tester) => _pillFinder().evaluate().length;

double _pillCenterX(WidgetTester tester) => tester.getCenter(_pillFinder()).dx;

double _iconCenterX(WidgetTester tester, IconData icon) =>
    tester.getCenter(find.byIcon(icon)).dx;

void main() {
  group('default (faithful) dock', () {
    testWidgets('hovering does NOT magnify — items carry no scaling transform', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      final g = await _mouse(tester);

      // Items render at fixed size: no scaling Transform anywhere over them.
      for (final icon in _icons) {
        expect(_scaleOf(tester, icon), isNull);
      }

      await g.moveTo(tester.getCenter(find.byIcon(LucideIcons.house)));
      await tester.pumpAndSettle();

      // Still no scaling after hover — the default dock does no pointer tracking.
      for (final icon in _icons) {
        expect(_scaleOf(tester, icon), isNull);
      }
    });

    testWidgets('exactly one active pill is rendered behind the active item', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_pillCount(tester), 1);
    });

    testWidgets('bar is frosted glass: one backdrop blur at sigma 12', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final filters = find.descendant(
        of: find.byType(BeuiDock),
        matching: find.byType(BackdropFilter),
      );
      // Exactly one frosted surface (backdrop-blur-xl) behind the bar.
      expect(filters, findsOneWidget);

      // backdrop-blur-xl = 24px CSS blur → sigma 24/2 = 12.
      final filter = tester.widget<BackdropFilter>(filters).filter;
      expect(filter, isA<ImageFilter>());
      expect(filter.toString(), contains('12.0'));
    });

    testWidgets('active pill glides to the newly active item', (tester) async {
      await tester.pumpWidget(_app(activeIndex: 0));
      await tester.pumpAndSettle();
      expect(_pillCount(tester), 1);
      expect(
        _pillCenterX(tester),
        closeTo(_iconCenterX(tester, _icons[0]), 4),
      ); // behind item 0

      // Make item 3 active. The SAME pill should spring across (not snap): one
      // pill throughout, still left of item 3 mid-glide, arriving after settle.
      await tester.pumpWidget(_app(activeIndex: 3));
      await tester.pump(); // measures the new active rect
      await tester.pump(const Duration(milliseconds: 30)); // mid-glide
      final item3x = _iconCenterX(tester, _icons[3]);
      expect(_pillCount(tester), 1);
      expect(_pillCenterX(tester), lessThan(item3x - 2)); // still gliding

      await tester.pumpAndSettle();
      expect(_pillCount(tester), 1);
      expect(_pillCenterX(tester), closeTo(item3x, 4)); // arrived behind item 3
    });
  });

  group('magnify: true', () {
    testWidgets('all items rest at scale 1', (tester) async {
      await tester.pumpWidget(_app(magnify: true));
      await tester.pumpAndSettle();
      for (final icon in _icons) {
        expect(_scaleOf(tester, icon), closeTo(1.0, 1e-3));
      }
    });

    testWidgets(
      'hovering an item magnifies it above 1 and more than a distant item',
      (tester) async {
        await tester.pumpWidget(_app(magnify: true));
        final g = await _mouse(tester);

        // Hover the first item (house); the last item (sparkles) is far away.
        await g.moveTo(tester.getCenter(find.byIcon(LucideIcons.house)));
        await tester.pumpAndSettle();

        final nearScale = _scaleOf(tester, LucideIcons.house)!;
        final farScale = _scaleOf(tester, LucideIcons.sparkles)!;

        expect(nearScale, greaterThan(1.0));
        expect(nearScale, greaterThan(farScale));
      },
    );

    testWidgets('leaving the dock resets every item to 1', (tester) async {
      await tester.pumpWidget(_app(magnify: true));
      final g = await _mouse(tester);

      await g.moveTo(tester.getCenter(find.byIcon(LucideIcons.calendar)));
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, LucideIcons.calendar)!, greaterThan(1.0));

      await g.moveTo(Offset.zero); // off the dock
      await tester.pumpAndSettle();
      for (final icon in _icons) {
        expect(_scaleOf(tester, icon), closeTo(1.0, 1e-3));
      }
    });

    testWidgets('reduced motion keeps the dock static (no magnification)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(magnify: true, reduce: true));
      final g = await _mouse(tester);

      await g.moveTo(tester.getCenter(find.byIcon(LucideIcons.house)));
      await tester.pumpAndSettle();

      // Under reduced motion the magnify path is disabled → faithful static dock,
      // so items carry no scaling transform regardless of hover.
      for (final icon in _icons) {
        expect(_scaleOf(tester, icon), isNull);
      }
    });
  });

  group('separator', () {
    Widget dockWith({
      double size = 44,
      bool magnify = false,
      bool activeFirst = false,
    }) => MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(
        body: Center(
          child: BeuiDock(
            size: size,
            magnify: magnify,
            items: [
              BeuiDockItem(
                icon: LucideIcons.house,
                tooltip: 'home',
                active: activeFirst,
                onTap: () {},
              ),
              const BeuiDockItem.separator(),
              BeuiDockItem(
                icon: LucideIcons.mail,
                tooltip: 'mail',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    // Source is a fixed `h-6` (24px) hairline regardless of icon size — it must
    // NOT scale with `size`.
    Finder separatorLine() => find.descendant(
      of: find.byType(BeuiDock),
      matching: find.byType(ColoredBox),
    );

    testWidgets('line is a fixed 24px tall at the default size', (
      tester,
    ) async {
      await tester.pumpWidget(dockWith());
      await tester.pumpAndSettle();
      expect(tester.getSize(separatorLine()).height, 24.0);
    });

    testWidgets('line stays 24px even when items are much larger', (
      tester,
    ) async {
      await tester.pumpWidget(dockWith(size: 88));
      await tester.pumpAndSettle();
      expect(tester.getSize(separatorLine()).height, 24.0);
    });

    testWidgets('is skipped by hover magnification while its neighbours grow', (
      tester,
    ) async {
      await tester.pumpWidget(dockWith(magnify: true));
      await tester.pumpAndSettle();
      final resting = tester.getSize(separatorLine());

      final g = await _mouse(tester);
      await g.moveTo(tester.getCenter(separatorLine()));
      await tester.pumpAndSettle();

      // The rule itself never scales...
      expect(tester.getSize(separatorLine()), resting);
      expect(
        find.descendant(
          of: find.byType(BeuiDock),
          matching: find.ancestor(
            of: separatorLine(),
            matching: find.byType(Transform),
          ),
        ),
        findsNothing,
      );
      // ...while the actions on either side of it do magnify, proving the
      // pointer was tracked.
      expect(_scaleOf(tester, LucideIcons.house)!, greaterThan(1.0));
      expect(_scaleOf(tester, LucideIcons.mail)!, greaterThan(1.0));
    });

    testWidgets('is decorative: no semantics node, nothing focusable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(dockWith());
      await tester.pumpAndSettle();

      // Only the two actions are announced; the rule contributes nothing
      // (source: aria-hidden).
      final labels = <String>[];
      void collect(SemanticsNode node) {
        if (node.label.isNotEmpty) labels.add(node.label);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(find.byType(BeuiDock)));
      labels.sort();
      expect(labels, ['home', 'mail']);

      // Nothing inside it can take focus, so keyboard traversal skips it.
      expect(
        find.descendant(
          of: find.byType(BeuiDock),
          matching: find.ancestor(
            of: separatorLine(),
            matching: find.byType(Focus),
          ),
        ),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('never attracts the active pill', (tester) async {
      await tester.pumpWidget(dockWith(activeFirst: true));
      await tester.pumpAndSettle();

      expect(_pillCount(tester), 1);
      expect(
        _pillCenterX(tester),
        closeTo(_iconCenterX(tester, LucideIcons.house), 4),
      );
    });
  });
}
