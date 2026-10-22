import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/breadcrumb.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';

Widget _app(Widget child, {bool reduce = false, double? width}) {
  Widget content = width == null ? child : SizedBox(width: width, child: child);
  if (reduce) {
    content = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: content,
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: Center(child: content)),
  );
}

void main() {
  testWidgets('ancestor link reports activation', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      _app(
        BeuiBreadcrumb(
          child: BeuiBreadcrumbList(
            children: [
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbLink(
                  onPressed: () => activated = true,
                  child: const Text('Workspace'),
                ),
              ),
              const BeuiBreadcrumbItem(
                child: BeuiBreadcrumbPage(child: Text('Project')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Workspace'));
    expect(activated, isTrue);
  });

  testWidgets('hovered ancestor link paints muted at 60 percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiBreadcrumbLink(child: Text('Workspace'))),
    );

    final link = find.byType(TextButton);

    final pointer = tester.getCenter(find.text('Workspace'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: pointer);
    await mouse.moveTo(pointer);
    await tester.pump();

    final style = tester.widget<TextButton>(link).style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.hovered}),
      BeuiColors.light().muted.withValues(alpha: 0.6),
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.hovered}),
      BeuiColors.light().foreground,
    );
  });

  testWidgets('breadcrumb exposes a navigation landmark and current page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const BeuiBreadcrumb(
          child: BeuiBreadcrumbList(
            children: [
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbPage(child: Text('Settings')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(BeuiBreadcrumb)),
      matchesSemantics(label: 'Breadcrumb'),
    );
    expect(find.text('Settings'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('overflow button opens hidden paths', (tester) async {
    await tester.pumpWidget(
      _app(
        BeuiBreadcrumb(
          child: BeuiBreadcrumbList(
            maxItems: 3,
            children: [
              for (var i = 0; i < 5; i++)
                BeuiBreadcrumbItem(
                  key: ValueKey('item-$i'),
                  child: i == 4
                      ? BeuiBreadcrumbPage(child: Text('Path $i'))
                      : BeuiBreadcrumbLink(
                          child: Text('Path $i'),
                          onPressed: () {},
                        ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show hidden paths'), findsOneWidget);
    await tester.tap(find.byTooltip('Show hidden paths'));
    await tester.pumpAndSettle();
    expect(find.text('Path 1'), findsOneWidget);
    expect(find.text('Path 2'), findsOneWidget);
  });

  testWidgets('reduced motion renders path without entrance movement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiBreadcrumb(
          child: BeuiBreadcrumbList(
            children: [
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbPage(child: Text('Home')),
              ),
            ],
          ),
        ),
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      _app(
        const BeuiBreadcrumb(
          child: BeuiBreadcrumbList(
            maxItems: 3,
            children: [
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbLink(child: Text('Workspace')),
              ),
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbLink(child: Text('Project')),
              ),
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbLink(child: Text('Design')),
              ),
              BeuiBreadcrumbItem(
                child: BeuiBreadcrumbPage(child: Text('Breadcrumb')),
              ),
            ],
          ),
        ),
        width: 360,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiBreadcrumb),
      matchesGoldenFile('goldens/beui_breadcrumb.png'),
    );
  });
}
