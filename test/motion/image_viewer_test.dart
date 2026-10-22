import 'package:beui/beui.dart';
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
  String? value,
  bool isControlled = false,
  String? defaultValue,
  ValueChanged<String?>? onChanged,
  bool reduce = false,
}) {
  final child = SizedBox(
    width: 360,
    child: BeuiImageViewer(
      images: _images,
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

void main() {
  group('BeuiImageViewer interaction', () {
    testWidgets('thumbnail opens and close dismisses', (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.bySemanticsLabel('Open Red study'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Image gallery'), findsWidgets);
      expect(find.text('01 / Red study'), findsOneWidget);

      await tester.tap(find.byTooltip('Close viewer'));
      await tester.pumpAndSettle();
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
