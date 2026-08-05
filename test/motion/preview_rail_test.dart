import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <BeuiPreviewRailItem>[
  BeuiPreviewRailItem(
    id: 'a',
    label: 'Alpha',
    description: Text('First item.'),
  ),
  BeuiPreviewRailItem(
    id: 'b',
    label: 'Beta',
    description: Text('Second item.'),
  ),
  BeuiPreviewRailItem(
    id: 'c',
    label: 'Gamma',
    description: Text('Third item.'),
  ),
  BeuiPreviewRailItem(
    id: 'd',
    label: 'Delta',
    description: Text('Fourth item.'),
  ),
];

Widget _app({
  List<BeuiPreviewRailItem> items = _items,
  BeuiPreviewRailOrientation orientation = BeuiPreviewRailOrientation.vertical,
  String? label,
  String? activeId,
  String? defaultActiveId,
  ValueChanged<String>? onActiveChange,
  ValueChanged<BeuiPreviewRailItem>? onItemSelect,
  bool showPreview = true,
  BeuiPreviewRailPreviewSide previewSide = BeuiPreviewRailPreviewSide.after,
  bool highlightActive = false,
  BeuiPreviewRailStyle? style,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 480,
      height: 320,
      child: BeuiPreviewRail(
        items: items,
        label: label ?? 'Section navigation',
        orientation: orientation,
        activeId: activeId,
        defaultActiveId: defaultActiveId,
        onActiveChange: onActiveChange,
        onItemSelect: onItemSelect,
        showPreview: showPreview,
        previewSide: previewSide,
        highlightActive: highlightActive,
        style: style,
      ),
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: child),
  );
}

/// The tick button for [label]. Not `bySemanticsLabel`: once a preview card is
/// open its title carries the same text, so that finder turns ambiguous.
Finder _tick(String label) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      w.properties.button == true &&
      w.properties.label == label,
  description: 'preview-rail tick "$label"',
);

/// Settled scale of one tick line — the vertical rail scales on x, so this is
/// the pyramid magnitude the spring landed on.
double _tickScale(WidgetTester tester, String label) {
  final transform = tester
      .widgetList<Transform>(
        find.descendant(of: _tick(label), matching: find.byType(Transform)),
      )
      .first;
  return transform.transform.storage[0];
}

Future<void> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  group('BeuiPreviewRail interaction', () {
    testWidgets('renders one tick cell per item', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
      // No preview card at rest (nothing hovered/focused).
      expect(find.text('First item.'), findsNothing);
    });

    testWidgets('tap selects via onActiveChange', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(onActiveChange: (id) => changed = id));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Beta'));
      await tester.pump();
      expect(changed, 'b');
    });

    testWidgets('controlled activeId does not mutate internal state', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(activeId: 'a', onActiveChange: (id) => changed = id),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Gamma'));
      await tester.pump();
      // Callback fires, but selection stays where the controller put it.
      expect(changed, 'c');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Alpha')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('hovering reveals the matching preview card', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Second item.'), findsNothing);
      await _hover(tester, find.bySemanticsLabel('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Second item.'), findsOneWidget);
    });
  });

  group('BeuiPreviewRail motion fidelity', () {
    testWidgets('tick scales spring under normal motion', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Each tick drives its scale through a motor SingleMotionBuilder.
      expect(find.byType(Transform), findsWidgets);
      await _hover(tester, find.bySemanticsLabel('Alpha'));
      // Mid-flight: the spring has not settled immediately.
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(BeuiPreviewRail), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('preview card fades in on hover, out on leave', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _hover(tester, find.bySemanticsLabel('Gamma'));
      await tester.pumpAndSettle();
      expect(find.text('Third item.'), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('reduced motion still reveals the card without springs', (
      tester,
    ) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.pumpAndSettle();
      await _hover(tester, find.bySemanticsLabel('Delta'));
      await tester.pumpAndSettle();
      expect(find.text('Fourth item.'), findsOneWidget);
    });
  });

  group('BeuiPreviewRail keyboard', () {
    testWidgets('focus reveals a preview and enter selects', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(onActiveChange: (id) => changed = id));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // First item focused → its preview shows.
      expect(find.text('First item.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(changed, 'a');
    });
  });

  group('BeuiPreviewRail content slot', () {
    testWidgets('renders the child to the right of the rail (vertical)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 480,
                height: 320,
                child: BeuiPreviewRail(
                  items: _items,
                  child: Text('PANEL CONTENT'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PANEL CONTENT'), findsOneWidget);
      // Content fills the flex-1 region to the right of the rail ticks.
      final contentLeft = tester.getRect(find.text('PANEL CONTENT')).left;
      final railLeft = tester.getRect(find.bySemanticsLabel('Alpha')).left;
      expect(contentLeft, greaterThan(railLeft));
    });

    testWidgets('renders the child below the rail (horizontal)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 480,
                height: 320,
                child: BeuiPreviewRail(
                  items: _items,
                  orientation: BeuiPreviewRailOrientation.horizontal,
                  child: Text('PANEL CONTENT'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PANEL CONTENT'), findsOneWidget);
    });

    testWidgets('no content slot by default (backward compatible)', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('PANEL CONTENT'), findsNothing);
    });
  });

  group('BeuiPreviewRail label', () {
    testWidgets('names the rail group with the source default', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Section navigation'), findsOneWidget);
      // The group name never swallows the item names.
      expect(find.bySemanticsLabel('Alpha'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a custom label replaces it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(label: 'Chapter navigation'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Chapter navigation'), findsOneWidget);
      expect(find.bySemanticsLabel('Section navigation'), findsNothing);
      handle.dispose();
    });
  });

  group('BeuiPreviewRail onItemSelect', () {
    testWidgets('fires with the whole item, after onActiveChange', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          onActiveChange: (id) => calls.add('change:$id'),
          onItemSelect: (item) => calls.add('select:${item.id}:${item.label}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Beta'));
      await tester.pump();
      expect(calls, ['change:b', 'select:b:Beta']);
    });

    testWidgets('fires again when the already selected item is re-picked', (
      tester,
    ) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _app(
          defaultActiveId: 'c',
          onItemSelect: (item) => selected.add(item.id),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Gamma'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Gamma'));
      await tester.pump();
      expect(selected, ['c', 'c']);
    });

    testWidgets('fires on keyboard activation too', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _app(onItemSelect: (item) => selected.add(item.id)),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selected, ['a']);
    });
  });

  group('BeuiPreviewRail showPreview', () {
    testWidgets('false renders no card even while hovering', (tester) async {
      await tester.pumpWidget(_app(showPreview: false));
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Second item.'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BeuiPreviewRail),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
        reason: 'the preview surface is not built at all',
      );
    });

    testWidgets('false keeps the hover pyramid working', (tester) async {
      await tester.pumpWidget(_app(showPreview: false));
      await tester.pumpAndSettle();
      expect(_tickScale(tester, 'Beta'), moreOrLessEquals(0.25, epsilon: 0.02));
      await _hover(tester, _tick('Beta'));
      await tester.pumpAndSettle();
      expect(_tickScale(tester, 'Beta'), moreOrLessEquals(1.0, epsilon: 0.02));
    });
  });

  group('BeuiPreviewRail previewSide', () {
    testWidgets('after (default) floats the card past the rail', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Beta'));
      await tester.pumpAndSettle();
      final card = tester.getRect(find.text('Second item.'));
      final rail = tester.getRect(_tick('Beta'));
      expect(card.left, greaterThan(rail.right));
    });

    testWidgets('before mirrors it: rail trailing, card leading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(previewSide: BeuiPreviewRailPreviewSide.before),
      );
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Beta'));
      await tester.pumpAndSettle();
      final card = tester.getRect(find.text('Second item.'));
      final rail = tester.getRect(_tick('Beta'));
      expect(card.right, lessThan(rail.left));
      // The rail itself moved to the trailing edge of the 480px box.
      expect(rail.left, greaterThan(240));
    });
  });

  group('BeuiPreviewRail highlightActive', () {
    testWidgets('false leaves every tick at rest with nothing hovered', (
      tester,
    ) async {
      await tester.pumpWidget(_app(defaultActiveId: 'b'));
      await tester.pumpAndSettle();
      for (final label in ['Alpha', 'Beta', 'Gamma', 'Delta']) {
        expect(
          _tickScale(tester, label),
          moreOrLessEquals(0.25, epsilon: 0.02),
          reason: '$label should rest',
        );
      }
    });

    testWidgets('true anchors the pyramid on the selection at rest', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(defaultActiveId: 'b', highlightActive: true),
      );
      await tester.pumpAndSettle();
      expect(_tickScale(tester, 'Beta'), moreOrLessEquals(1.0, epsilon: 0.02));
      expect(
        _tickScale(tester, 'Alpha'),
        moreOrLessEquals(0.68, epsilon: 0.02),
      );
      expect(
        _tickScale(tester, 'Gamma'),
        moreOrLessEquals(0.68, epsilon: 0.02),
      );
      expect(
        _tickScale(tester, 'Delta'),
        moreOrLessEquals(0.44, epsilon: 0.02),
      );
    });

    testWidgets('true still never summons the preview card', (tester) async {
      await tester.pumpWidget(
        _app(defaultActiveId: 'b', highlightActive: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second item.'), findsNothing);
    });

    testWidgets('hover wins over the resting highlight', (tester) async {
      await tester.pumpWidget(
        _app(defaultActiveId: 'b', highlightActive: true),
      );
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Delta'));
      await tester.pumpAndSettle();
      expect(_tickScale(tester, 'Delta'), moreOrLessEquals(1.0, epsilon: 0.02));
      expect(_tickScale(tester, 'Beta'), moreOrLessEquals(0.44, epsilon: 0.02));
    });
  });

  group('BeuiPreviewRailStyle.itemSize', () {
    testWidgets('defaults to a 20px slot per item', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.getSize(_tick('Alpha')).height, 20);
      expect(
        tester.getCenter(_tick('Delta')).dy -
            tester.getCenter(_tick('Alpha')).dy,
        3 * 20,
      );
    });

    testWidgets('resizes each tick slot and the whole rail', (tester) async {
      await tester.pumpWidget(
        _app(style: const BeuiPreviewRailStyle(itemSize: 32)),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(_tick('Alpha')).height, 32);
      // The rail is one slot per item, so the ticks spread with it.
      expect(
        tester.getCenter(_tick('Delta')).dy -
            tester.getCenter(_tick('Alpha')).dy,
        3 * 32,
      );
    });

    testWidgets('wins over the deprecated trackExtent alias', (tester) async {
      await tester.pumpWidget(
        _app(
          style: const BeuiPreviewRailStyle(
            itemSize: 32,
            // ignore: deprecated_member_use_from_same_package
            trackExtent: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(_tick('Alpha')).height, 32);
    });

    testWidgets('trackExtent alone still applies', (tester) async {
      await tester.pumpWidget(
        _app(
          style: const BeuiPreviewRailStyle(
            // ignore: deprecated_member_use_from_same_package
            trackExtent: 28,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(_tick('Alpha')).height, 28);
    });
  });

  testWidgets('rest-state golden (vertical, nothing displayed)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              height: 320,
              child: BeuiPreviewRail(items: _items, defaultActiveId: 'b'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiPreviewRail),
      matchesGoldenFile('goldens/beui_preview_rail.png'),
    );
  });
}
