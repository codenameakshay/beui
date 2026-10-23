import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _images = [
  BeuiImageViewerImage(
    id: 'red',
    alt: 'Red',
    width: 4,
    height: 3,
    content: ColoredBox(color: Colors.red),
  ),
  BeuiImageViewerImage(
    id: 'blue',
    alt: 'Blue',
    width: 4,
    height: 3,
    content: ColoredBox(color: Colors.blue),
  ),
];

void main() {
  testWidgets('review: viewer exit cannot toggle zoom after dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiImageViewer(images: _images, defaultValue: 'red'),
        width: 360,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    final zoom = tester.getCenter(find.byTooltip('Zoom in'));
    await tester.tap(find.byTooltip('Close viewer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tapAt(zoom);
    await tester.pump();
    expect(find.byTooltip('Zoom out'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('review: breadcrumb exit cannot activate a hidden route', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiBreadcrumbEllipsis(
          children: [
            BeuiBreadcrumbLink(
              onPressed: () => activations++,
              child: const Text('Projects'),
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 1);
    final route = tester.getCenter(find.text('Projects'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tapAt(route);
    await tester.pump();
    expect(activations, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('review: picker exit cannot change color from retained focus', (
    tester,
  ) async {
    final changes = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiColorPicker(
          defaultOpen: true,
          defaultValue: '#ff0000',
          onChanged: changes.add,
          trigger: const BeuiColorPickerTrigger(),
          child: const BeuiColorPickerContent(child: BeuiColorPickerArea()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(changes, ['#ffffff']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changes, ['#ffffff']);
    await tester.pumpAndSettle();
  });

  testWidgets('review: controlled alert close restores focused action', (
    tester,
  ) async {
    final returnFocus = FocusNode();
    addTearDown(returnFocus.dispose);
    final actionFocus = FocusNode();
    addTearDown(actionFocus.dispose);
    var open = true;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  focusNode: returnFocus,
                  onPressed: () {},
                  child: const Text('Show alert'),
                ),
                BeuiAlert(
                  open: open,
                  returnFocus: returnFocus,
                  children: [
                    TextButton(
                      focusNode: actionFocus,
                      onPressed: () {},
                      child: const Text('Alert action'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    actionFocus.requestFocus();
    await tester.pump();
    expect(actionFocus.hasFocus, isTrue);
    update(() => open = false);
    await tester.pump();
    await tester.pump();
    expect(returnFocus.hasFocus, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('review: alert success respects the public theme override', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiAlert(
          variant: BeuiAlertVariant.success,
          children: [BeuiAlertTitle(child: Text('Saved'))],
        ),
        extensions: [BeuiColors.light().copyWith(success: Colors.purple)],
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Saved'));
    expect(DefaultTextStyle.of(context).style.color, Colors.purple);
  });

  testWidgets('review: rejected viewer request cannot own return focus', (
    tester,
  ) async {
    String? selected;
    final requests = <String?>[];
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiImageViewer(
              images: _images,
              isControlled: true,
              value: selected,
              onChanged: (value) {
                requests.add(value);
                if (value == null) setState(() => selected = null);
              },
            );
          },
        ),
        width: 360,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(requests, ['blue']);
    expect(find.byTooltip('Close viewer'), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    update(() => selected = 'red');
    await tester.pumpAndSettle();
    expect(find.text('Red'), findsOneWidget);
    await tester.tap(find.byTooltip('Close viewer'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(requests, ['blue', null, 'red']);
  });

  testWidgets('review: custom picker trigger keeps the spectrum visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiColorPicker(
          trigger: SizedBox(width: 120, height: 40, child: Text('Open color')),
          child: BeuiColorPickerContent(child: BeuiColorPickerArea()),
        ),
      ),
    );
    await tester.tap(find.text('Open color'));
    await tester.pumpAndSettle();
    final spectrum = find.byKey(const ValueKey('color-picker-spectrum'));
    expect(tester.getSize(spectrum), const Size(264, 160));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: spectrum, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('review: zoomed image does not paint over the viewer header', (
    tester,
  ) async {
    const capture = ValueKey('review-viewer-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: beuiTestApp(
          const BeuiImageViewer(images: _images, defaultValue: 'red'),
          width: 360,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(capture),
    );
    for (final zoomed in [false, true]) {
      if (zoomed) {
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
      }
      final pixel = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (35 * image.width + image.width ~/ 2) * 4;
        final channels = [
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        ];
        image.dispose();
        return channels;
      });
      expect(pixel![0], closeTo(26, 3), reason: 'zoomed=$zoomed');
      expect(pixel[1], closeTo(26, 3), reason: 'zoomed=$zoomed');
      expect(pixel[2], closeTo(26, 3), reason: 'zoomed=$zoomed');
    }
  });

  testWidgets('review: reduced motion suppresses the picker loupe', (
    tester,
  ) async {
    for (final reduce in [false, true]) {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiColorPicker(child: BeuiColorPickerArea()),
          width: 264,
          reduce: reduce,
        ),
      );
      await tester.pumpAndSettle();
      final pointer = await tester.startGesture(
        tester.getCenter(find.byType(BeuiColorPickerArea)),
      );
      await tester.pump();
      final count = find
          .byKey(const ValueKey('color-picker-loupe'))
          .evaluate()
          .length;
      await pointer.up();
      await tester.pumpAndSettle();
      expect(count, reduce ? 0 : 1, reason: 'reduce=$reduce');
    }
  });
}
