import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _images = [
  const BeuiImageViewerImage(
    id: 'one',
    alt: 'Red study',
    caption: '01 / Red study',
    width: 4,
    height: 3,
    content: ColoredBox(color: Color(0xffc54d4d)),
  ),
  const BeuiImageViewerImage(
    id: 'two',
    alt: 'Blue study',
    caption: '02 / Blue study',
    width: 3,
    height: 4,
    content: ColoredBox(color: Color(0xff4d76c5)),
  ),
];

Widget _app({
  List<BeuiImageViewerImage>? images,
  String? value,
  bool isControlled = false,
  String? defaultValue,
  ValueChanged<String?>? onChanged,
  bool reduce = false,
}) {
  final child = SizedBox(
    width: 360,
    child: BeuiImageViewer(
      images: images ?? _images,
      value: value,
      isControlled: isControlled,
      defaultValue: defaultValue,
      onChanged: onChanged,
    ),
  );
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: Center(
        child: reduce
            ? Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child,
                ),
              )
            : child,
      ),
    ),
  );
}

Rect _imageRect(WidgetTester tester, Color color) => tester.getRect(
  find
      .byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == color,
      )
      .last,
);

void main() {
  testWidgets('modal image viewport keeps the source 12px control gaps', (
    tester,
  ) async {
    await tester.pumpWidget(_app(defaultValue: 'one'));
    await tester.pumpAndSettle();
    final zoom = tester.getRect(find.byTooltip('Zoom in'));
    final previous = tester.getRect(find.byTooltip('Previous image'));
    expect(previous.top - zoom.bottom, 24);
    expect(zoom.size, const Size(40, 40));
  });
  testWidgets(
    'zoom button doubles the image and keyboard pans without paging',
    (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'one'));
      await tester.pumpAndSettle();
      final rest = _imageRect(tester, const Color(0xffc54d4d));
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final zoomed = _imageRect(tester, const Color(0xffc54d4d));
      expect(zoomed.width, closeTo(rest.width * 2, .05));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final panned = _imageRect(tester, const Color(0xffc54d4d));
      expect(panned.center.dx - zoomed.center.dx, closeTo(40, .01));
      expect(find.text('01 / Red study'), findsOneWidget);
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      final restored = _imageRect(tester, const Color(0xffc54d4d));
      expect(restored.width, closeTo(rest.width, .05));
      expect((restored.center - rest.center).distance, lessThan(.05));
    },
  );

  testWidgets('zoomed drag clamps and vertical swipe never pages', (
    tester,
  ) async {
    await tester.pumpWidget(_app(defaultValue: 'one'));
    await tester.pumpAndSettle();
    final image = find
        .byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == const Color(0xffc54d4d),
        )
        .last;
    await tester.drag(image, const Offset(60, 100));
    await tester.pumpAndSettle();
    expect(find.text('01 / Red study'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 300), const Offset(2000, 0));
    await tester.pumpAndSettle();
    final clamped = _imageRect(tester, const Color(0xffc54d4d));
    await tester.dragFrom(const Offset(400, 300), const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(_imageRect(tester, const Color(0xffc54d4d)), clamped);
    expect(find.text('01 / Red study'), findsOneWidget);
  });

  testWidgets(
    'horizontal swipe pages and close restores the opening thumbnail',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.bySemanticsLabel('Open Red study'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(400, 300), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(find.text('02 / Blue study'), findsOneWidget);
      await tester.tap(find.byTooltip('Close viewer'));
      await tester.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus!;
      expect(focus.hasFocus, isTrue);
      expect(find.text('02 / Blue study'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('01 / Red study'), findsOneWidget);
    },
  );
  testWidgets('gallery fills three equal columns with the source gap', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final first = tester.getRect(find.bySemanticsLabel('Open Red study'));
    final second = tester.getRect(find.bySemanticsLabel('Open Blue study'));
    expect(first.width, 112);
    expect(second.width, 112);
    expect(second.left - first.right, 12);
  });

  testWidgets('thumbnail hover does not invent travel or brightness', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final thumbnail = find.bySemanticsLabel('Open Red study');
    final before = _imageRect(tester, const Color(0xffc54d4d));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(thumbnail));
    await tester.pumpAndSettle();
    expect(_imageRect(tester, const Color(0xffc54d4d)), before);
    expect(
      find.descendant(of: thumbnail, matching: find.byType(ColorFiltered)),
      findsNothing,
    );
  });

  group('BeuiImageViewer interaction', () {
    testWidgets('thumbnail opens and close dismisses', (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.bySemanticsLabel('Open Red study'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Image gallery'), findsWidgets);
      expect(find.text('01 / Red study'), findsOneWidget);

      final expanded = _imageRect(tester, const Color(0xffc54d4d));
      await tester.tap(find.byTooltip('Close viewer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final closing = _imageRect(tester, const Color(0xffc54d4d));
      expect(closing.width, lessThan(expanded.width * 0.8));
      expect(closing.width, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('01 / Red study'), findsNothing);
    });

    testWidgets('open mounts a morph overlay and close clears selection', (
      tester,
    ) async {
      final selections = <String?>[];
      await tester.pumpWidget(_app(onChanged: selections.add));
      await tester.tap(find.bySemanticsLabel('Open Red study'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
        _imageRect(tester, const Color(0xffc54d4d)).width,
        inExclusiveRange(100, 150),
      );
      await tester.pumpAndSettle();
      expect(
        _imageRect(tester, const Color(0xffc54d4d)).width,
        greaterThan(500),
      );
      expect(find.text('01 / Red study'), findsOneWidget);

      await tester.tap(find.byTooltip('Close viewer'));
      await tester.pumpAndSettle();
      expect(selections, ['one', null]);
      expect(find.text('01 / Red study'), findsNothing);
    });

    testWidgets('navigation controls and arrow keys change selection', (
      tester,
    ) async {
      await tester.pumpWidget(_app(defaultValue: 'one'));
      await tester.pumpAndSettle();
      expect(find.text('01 / Red study'), findsOneWidget);

      await tester.tap(find.byTooltip('Next image'));
      await tester.pumpAndSettle();
      expect(find.text('02 / Blue study'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('01 / Red study'), findsOneWidget);
    });

    testWidgets(
      'controlled selection reports requests without changing itself',
      (tester) async {
        String? requested;
        await tester.pumpWidget(
          _app(value: 'one', onChanged: (value) => requested = value),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next image'));
        await tester.pumpAndSettle();
        expect(requested, 'two');
        expect(find.text('01 / Red study'), findsOneWidget);
      },
    );

    testWidgets(
      'rejected controlled request cannot supply a later morph source',
      (tester) async {
        String? selected;
        final requests = <String?>[];
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: BeuiTextTheme.trackingNormal(
              ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
            ),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 360,
                      child: BeuiImageViewer(
                        images: _images,
                        value: selected,
                        isControlled: true,
                        onChanged: requests.add,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.bySemanticsLabel('Open Blue study'));
        await tester.pumpAndSettle();
        expect(requests, ['two']);
        expect(find.byTooltip('Close viewer'), findsNothing);
        update(() => selected = 'one');
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(find.text('01 / Red study'), findsOneWidget);
        expect(
          _imageRect(tester, const Color(0xffc54d4d)).width,
          greaterThan(500),
        );
        await tester.pumpAndSettle();
        update(() => selected = null);
        await tester.pumpAndSettle();
        // Even a later programmatic open of the rejected id is not acceptance
        // of that old request.
        update(() => selected = 'two');
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(find.text('02 / Blue study'), findsOneWidget);
        expect(
          _imageRect(tester, const Color(0xff4d76c5)).width,
          greaterThan(300),
        );
      },
    );

    testWidgets(
      'accepted controlled thumbnail source survives the close morph',
      (tester) async {
        String? selected;
        final requests = <String?>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) => SizedBox(
                    width: 360,
                    child: BeuiImageViewer(
                      images: _images,
                      value: selected,
                      isControlled: true,
                      onChanged: (value) {
                        requests.add(value);
                        setState(() => selected = value);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final thumbnail = tester.getRect(
          find.bySemanticsLabel('Open Red study'),
        );
        await tester.tap(find.bySemanticsLabel('Open Red study'));
        await tester.pumpAndSettle();
        final expanded = _imageRect(tester, const Color(0xffc54d4d));
        expect(expanded.width, greaterThan(500));
        await tester.tap(find.byTooltip('Close viewer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final closing = _imageRect(tester, const Color(0xffc54d4d));
        expect(closing.width, lessThan(expanded.width * 0.8));
        expect(
          (closing.center - thumbnail.center).distance,
          lessThan((expanded.center - thumbnail.center).distance),
        );
        expect(requests, ['one', null]);
        await tester.pumpAndSettle();
        expect(find.text('01 / Red study'), findsNothing);
      },
    );

    testWidgets(
      'reduced motion thumbnail hover keeps the source image unchanged',
      (tester) async {
        await tester.pumpWidget(_app(reduce: true));
        final thumbnail = find.bySemanticsLabel('Open Red study');
        final before = _imageRect(tester, const Color(0xffc54d4d));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(thumbnail));
        await tester.pump();
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(_imageRect(tester, const Color(0xffc54d4d)), before);
          for (final transform in tester.widgetList<Transform>(
            find.descendant(of: thumbnail, matching: find.byType(Transform)),
          )) {
            expect(transform.transform, Matrix4.identity());
          }
        }
        expect(
          find.descendant(of: thumbnail, matching: find.byType(ColorFiltered)),
          findsNothing,
        );
      },
    );

    testWidgets('controlled null stays closed until its owner changes value', (
      tester,
    ) async {
      String? requested;
      await tester.pumpWidget(
        _app(isControlled: true, onChanged: (value) => requested = value),
      );
      await tester.tap(find.bySemanticsLabel('Open Red study'));
      await tester.pumpAndSettle();
      expect(requested, 'one');
      expect(find.byTooltip('Close viewer'), findsNothing);
    });

    testWidgets('empty gallery can receive images and retry opening', (
      tester,
    ) async {
      await tester.pumpWidget(_app(images: const []));
      expect(find.byType(BeuiImageViewerThumbnail), findsNothing);
      expect(find.byTooltip('Close viewer'), findsNothing);
      await tester.pumpWidget(_app());
      await tester.tap(find.bySemanticsLabel('Open Red study'));
      await tester.pumpAndSettle();
      expect(find.text('01 / Red study'), findsOneWidget);
      await tester.pumpWidget(_app(images: const []));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close viewer'), findsNothing);
      await tester.pumpWidget(_app());
      await tester.tap(find.bySemanticsLabel('Open Blue study'));
      await tester.pumpAndSettle();
      expect(find.text('02 / Blue study'), findsOneWidget);
    });

    testWidgets('reduced motion keeps modal usable', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'one', reduce: true));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close viewer'), findsOneWidget);
      expect(find.text('01 / Red study'), findsOneWidget);
    });

    testWidgets('gallery and controls expose accessible labels', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(defaultValue: 'one'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Open Red study'), findsOneWidget);
      expect(find.bySemanticsLabel('Close viewer'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets('rest-state golden (thumbnail gallery)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiImageViewerGallery),
      matchesGoldenFile('goldens/beui_image_viewer.png'),
    );
  });
}
