import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
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
  testWidgets('review: closing breadcrumb cancels a held route press', (
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
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(activations, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final press = await tester.startGesture(
      tester.getCenter(find.text('Projects')),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await press.up();
    await tester.pump();
    expect(activations, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('review: closing viewer cancels a held zoom press', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiImageViewer(images: _images, defaultValue: 'red')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    final press = await tester.startGesture(
      tester.getCenter(find.byTooltip('Zoom in')),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await press.up();
    await tester.pump();
    expect(find.byTooltip('Zoom out'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'review: viewer reopening during exit recaptures keyboard focus',
    (tester) async {
      String? selected;
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
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
          width: 360,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Open Red'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Blue'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      update(() => selected = 'red');
      await tester.pumpAndSettle();
      expect(find.text('Red'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Blue'), findsOneWidget);
    },
  );

  testWidgets('review: picker clamps against the root overlay viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => const Material(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: BeuiColorPicker(
                        trigger: SizedBox(
                          width: 100,
                          height: 40,
                          child: Text('Open color'),
                        ),
                        child: BeuiColorPickerContent(
                          child: BeuiColorPickerArea(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open color'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(BeuiColorPickerContent));
    expect(panel.right, closeTo(792, .01));
    expect(panel.width, 288);
  });
}
