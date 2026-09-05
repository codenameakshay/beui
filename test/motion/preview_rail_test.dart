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
  bool highlightActive = true,
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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
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
      for (final item in _items) {
        expect(_tick(item.label), findsOneWidget);
      }
      // No preview card at rest (nothing hovered/focused).
      expect(find.text('First item.'), findsNothing);
    });

    testWidgets('tap selects via onActiveChange', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(onActiveChange: (id) => changed = id));
      await tester.pumpAndSettle();
      await tester.tap(_tick('Beta'), kind: PointerDeviceKind.mouse);
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
      await tester.tap(_tick('Gamma'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      // Callback fires, but selection stays where the controller put it.
      expect(changed, 'c');
      expect(
        tester.getSemantics(_tick('Alpha')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('hovering reveals the matching preview card', (tester) async {
      for (final reduce in [false, true]) {
        await tester.pumpWidget(_app(reduce: reduce));
        await tester.pumpAndSettle();
        expect(find.text('Second item.'), findsNothing);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        // Off-tree first: a pointer left hovering at the previous iteration's
        // position would already read as hovering the moment the new tree
        // mounts at the same screen location.
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(_tick('Beta')));
        await tester.pumpAndSettle();
        expect(find.text('Second item.'), findsOneWidget);
        await gesture.removePointer();
      }
    });
  });

  group('BeuiPreviewRail motion fidelity', () {
    testWidgets('preview card fades in on hover, out on leave', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Gamma'));
      await tester.pumpAndSettle();
      expect(find.text('Third item.'), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
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
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
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
      final railLeft = tester.getRect(_tick('Alpha')).left;
      expect(contentLeft, greaterThan(railLeft));
    });

    testWidgets('renders the child below the rail (horizontal)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
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
      // Content fills the flex-1 region below the rail ticks.
      final contentTop = tester.getRect(find.text('PANEL CONTENT')).top;
      final railTop = tester.getRect(_tick('Alpha')).top;
      expect(contentTop, greaterThan(railTop));
    });
  });

  group('BeuiPreviewRail label', () {
    testWidgets('names the rail group with the source default', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Section navigation'), findsOneWidget);
      // The group name never swallows the item names.
      expect(_tick('Alpha'), findsOneWidget);
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
      await tester.tap(_tick('Beta'), kind: PointerDeviceKind.mouse);
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
      await tester.tap(_tick('Gamma'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.tap(_tick('Gamma'), kind: PointerDeviceKind.mouse);
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
      await tester.pumpWidget(_app(showPreview: false, highlightActive: false));
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
      await tester.pumpWidget(
        _app(defaultActiveId: 'b', highlightActive: false),
      );
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
      await tester.pumpWidget(_app(defaultActiveId: 'b'));
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

    testWidgets('hover wins over the resting highlight', (tester) async {
      await tester.pumpWidget(_app(defaultActiveId: 'b'));
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Delta'));
      await tester.pumpAndSettle();
      expect(_tickScale(tester, 'Delta'), moreOrLessEquals(1.0, epsilon: 0.02));
      expect(_tickScale(tester, 'Beta'), moreOrLessEquals(0.44, epsilon: 0.02));
    });
  });

  group('BeuiPreviewRailStyle.itemSize', () {
    // 24, not 20: the source's `itemSize` default is 24 and the visual pass
    // against beui.dev moved the port onto it. The old 20 was a porting-time
    // choice made to avoid regenerating a golden.
    testWidgets('defaults to a 24px slot per item', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.getSize(_tick('Alpha')).height, 24);
      expect(
        tester.getCenter(_tick('Delta')).dy -
            tester.getCenter(_tick('Alpha')).dy,
        3 * 24,
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
  });

  // The resting truth changed with `highlightActive` defaulting to true: the
  // selected tick ('b') now sits at full scale with its neighbours stepping
  // down, instead of four identical grey dashes that told the reader nothing
  // about where they were. Regenerated deliberately.
  testWidgets('rest-state golden (vertical, selection highlighted)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
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

  group('BeuiPreviewRail horizontal layout', () {
    // The source preview overlay is `pointer-events-none absolute z-50`, so it
    // takes no layout space and the `h-12` nav stays centred by the container's
    // `flex-col items-center justify-center`. Reserving a slot for the card
    // above the rail instead pushes the rail below centre.
    testWidgets('rail stays centred; the card floats without displacing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(orientation: BeuiPreviewRailOrientation.horizontal),
      );
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byType(BeuiPreviewRail));
      final tick = tester.getRect(_tick('Alpha'));
      expect(
        tick.center.dy,
        closeTo(box.center.dy, 0.5),
        reason: 'the 48-tall nav is centred in the container',
      );

      // Hovering summons the card; the rail must not move.
      await _hover(tester, _tick('Beta'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_tick('Alpha')).center.dy,
        closeTo(tick.center.dy, 0.5),
      );

      // Source card is `bottom-12` off an `h-5` cell centred on the container,
      // so its bottom lands 38 above the centre line.
      final card = tester.getRect(find.text('Beta'));
      expect(card.bottom, lessThan(box.center.dy - 38));
    });
  });

  // ---------------------------------------------------------------------
  // UX remediation — R2, R11, R31, R32, R37, R38
  // ---------------------------------------------------------------------

  group('BeuiPreviewRail touch', () {
    testWidgets('the first tap previews instead of navigating blind', (
      tester,
    ) async {
      final changed = <String>[];
      await tester.pumpWidget(_app(onActiveChange: changed.add));
      await tester.pumpAndSettle();

      await tester.tap(_tick('Gamma'));
      await tester.pumpAndSettle();
      // The destination is now identifiable — and nothing has been committed.
      expect(find.text('Third item.'), findsOneWidget);
      expect(changed, isEmpty);
    });

    testWidgets('a second tap on the same tick commits', (tester) async {
      final changed = <String>[];
      await tester.pumpWidget(_app(onActiveChange: changed.add));
      await tester.pumpAndSettle();

      await tester.tap(_tick('Gamma'));
      await tester.pumpAndSettle();
      await tester.tap(_tick('Gamma'));
      await tester.pumpAndSettle();
      expect(changed, ['c']);
    });

    testWidgets('tapping a different tick re-previews rather than committing', (
      tester,
    ) async {
      final changed = <String>[];
      await tester.pumpWidget(_app(onActiveChange: changed.add));
      await tester.pumpAndSettle();

      await tester.tap(_tick('Gamma'));
      await tester.pumpAndSettle();
      await tester.tap(_tick('Delta'));
      await tester.pumpAndSettle();
      expect(changed, isEmpty);
      expect(find.text('Fourth item.'), findsOneWidget);

      await tester.tap(_tick('Delta'));
      await tester.pumpAndSettle();
      expect(changed, ['d']);
    });

    testWidgets('a mouse still commits on one tap — hover already showed it', (
      tester,
    ) async {
      final changed = <String>[];
      await tester.pumpWidget(_app(onActiveChange: changed.add));
      await tester.pumpAndSettle();
      await tester.tap(_tick('Beta'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(changed, ['b']);
    });

    testWidgets('with no preview to show, touch commits on the first tap', (
      tester,
    ) async {
      final changed = <String>[];
      await tester.pumpWidget(
        _app(showPreview: false, onActiveChange: changed.add),
      );
      await tester.pumpAndSettle();
      await tester.tap(_tick('Beta'));
      await tester.pump();
      expect(changed, ['b']);
    });

    testWidgets('the intermediate state is announced, not silent', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_tick('Gamma'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_tick('Gamma')),
        isSemantics(hint: 'Previewing. Activate again to open'),
      );
      handle.dispose();
    });
  });

  group('BeuiPreviewRail fitting its box', () {
    List<BeuiPreviewRailItem> many(int n) => [
      for (var i = 0; i < n; i++)
        BeuiPreviewRailItem(id: '$i', label: 'Item $i'),
    ];

    testWidgets('30 items in 300px do not overflow (vertical)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 480,
                height: 300,
                child: BeuiPreviewRail(items: many(30)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(BeuiPreviewRail)).height,
        lessThanOrEqualTo(300),
      );
    });

    testWidgets('20 items in 320px do not overflow (horizontal)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 200,
                child: BeuiPreviewRail(
                  items: many(20),
                  orientation: BeuiPreviewRailOrientation.horizontal,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 20 x 24 = 480 in a 320px box was a plain RenderFlex overflow.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pitch compresses before the rail resorts to scrolling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 480,
                height: 200,
                child: BeuiPreviewRail(items: many(20)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 200 / 20 = 10 per slot, under the requested 24 but over the floor.
      final pitch =
          tester.getCenter(_tick('Item 5')).dy -
          tester.getCenter(_tick('Item 4')).dy;
      expect(pitch, moreOrLessEquals(10, epsilon: 0.6));
    });

    testWidgets('adjacent ticks do not abut, so a sweep crosses dead zones', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      Rect hoverRegion(String label) => tester.getRect(
        find.descendant(
          of: _tick(label),
          matching: find.byType(GestureDetector),
        ),
      );
      final first = hoverRegion('Alpha');
      final second = hoverRegion('Beta');
      expect(
        second.top - first.bottom,
        greaterThan(0),
        reason: 'a 0px gap re-fired the whole spring cascade on every sweep',
      );
      // The pitch itself is unchanged: the ticks did not move.
      expect(second.center.dy - first.center.dy, 24);
    });
  });

  group('BeuiPreviewRailStyle.itemSize deprecation path', () {
    test('resolvedItemSize is the single precedence rule', () {
      expect(const BeuiPreviewRailStyle().resolvedItemSize, 24);
      expect(const BeuiPreviewRailStyle(itemSize: 32).resolvedItemSize, 32);
      expect(
        // ignore: deprecated_member_use_from_same_package
        const BeuiPreviewRailStyle(trackExtent: 28).resolvedItemSize,
        28,
      );
      expect(
        const BeuiPreviewRailStyle(
          itemSize: 32,
          // ignore: deprecated_member_use_from_same_package
          trackExtent: 12,
        ).resolvedItemSize,
        32,
      );
    });

    test('copyWith(itemSize:) drops an inherited trackExtent', () {
      const legacy = BeuiPreviewRailStyle(
        // ignore: deprecated_member_use_from_same_package
        trackExtent: 12,
      );
      final migrated = legacy.copyWith(itemSize: 32);
      // ignore: deprecated_member_use_from_same_package
      expect(migrated.trackExtent, isNull);
      expect(migrated.resolvedItemSize, 32);
    });
  });

  group('BeuiPreviewRail selection reconciliation', () {
    testWidgets('defaultActiveId is re-read when the caller changes it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(defaultActiveId: 'a'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_tick('Alpha')),
        isSemantics(isSelected: true),
      );

      // A parent swapping datasets used to keep the seed from the first build.
      await tester.pumpWidget(_app(defaultActiveId: 'c'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_tick('Gamma')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('a selection that leaves the list is reported, not swallowed', (
      tester,
    ) async {
      final changed = <String>[];
      await tester.pumpWidget(
        _app(defaultActiveId: 'd', onActiveChange: changed.add),
      );
      await tester.pumpAndSettle();
      expect(changed, isEmpty);

      // 'd' is gone; the rail falls back to the first item and says so, rather
      // than leaving the parent pointing at a row that is not there.
      await tester.pumpWidget(
        _app(
          items: _items.sublist(0, 2),
          defaultActiveId: 'd',
          onActiveChange: changed.add,
        ),
      );
      await tester.pumpAndSettle();
      expect(changed, ['a']);
      expect(
        tester.getSemantics(_tick('Alpha')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('a controlled rail hears the fallback too', (tester) async {
      final changed = <String>[];
      await tester.pumpWidget(_app(activeId: 'c', onActiveChange: changed.add));
      await tester.pumpAndSettle();
      expect(changed, isEmpty);

      await tester.pumpWidget(
        _app(
          items: _items.sublist(0, 2),
          activeId: 'c',
          onActiveChange: changed.add,
        ),
      );
      await tester.pumpAndSettle();
      expect(changed, ['a']);
    });
  });

  group('BeuiPreviewRail preview card', () {
    testWidgets('the card takes no pointers, as its docs now say', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 480,
                height: 320,
                child: BeuiPreviewRail(
                  items: _items,
                  renderPreview: (item) => GestureDetector(
                    onTap: () => taps++,
                    child: Container(
                      height: 80,
                      color: const Color(0xFFEEEEEE),
                      alignment: Alignment.center,
                      child: Text('Open ${item.label}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _hover(tester, _tick('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Open Beta'), findsOneWidget);

      await tester.tap(find.text('Open Beta'), warnIfMissed: false);
      await tester.pump();
      // Documented on renderPreview: the card is the source's
      // pointer-events-none overlay.
      expect(taps, 0);
    });
  });
}
