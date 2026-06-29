import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _icons = <IconData>[
  LucideIcons.house,
  LucideIcons.mail,
  LucideIcons.calendar,
  LucideIcons.music,
  LucideIcons.sparkles,
];

Widget _app({
  bool magnify = false,
  bool reduce = false,
  int activeIndex = 0,
}) {
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

/// Number of active-pill highlights currently rendered (rounded-xl, r=12).
int _pillCount(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(BeuiDock),
        matching: find.byType(DecoratedBox),
      ),
    )
    .where((d) {
      final dec = d.decoration;
      return dec is BoxDecoration &&
          dec.borderRadius == BorderRadius.circular(12);
    })
    .length;

void main() {
  group('default (faithful) dock', () {
    testWidgets('hovering does NOT magnify — items carry no scaling transform',
        (tester) async {
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

    testWidgets('exactly one active pill is rendered behind the active item',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(_pillCount(tester), 1);
    });

    testWidgets('active pill glides to the newly active item', (tester) async {
      await tester.pumpWidget(_app(activeIndex: 0));
      await tester.pumpAndSettle();
      expect(_pillCount(tester), 1);

      // Re-pump with a different active item: still exactly one pill, now behind
      // the new item (the source's layoutId shared-layout glide).
      await tester.pumpWidget(_app(activeIndex: 3));
      await tester.pumpAndSettle();
      expect(_pillCount(tester), 1);
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
    });

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

    testWidgets('reduced motion keeps the dock static (no magnification)',
        (tester) async {
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
}
