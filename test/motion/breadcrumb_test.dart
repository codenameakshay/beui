import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  for (final reduce in [false, true]) {
    testWidgets('overflow stays open while hovering its trigger, RM=$reduce', (
      tester,
    ) async {
      var activations = 0;
      await tester.pumpWidget(
        _app(
          BeuiBreadcrumbEllipsis(
            children: [
              BeuiBreadcrumbLink(
                onPressed: () => activations++,
                child: const Text('Hidden route'),
              ),
            ],
          ),
          reduce: reduce,
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
      await tester.pump();
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Hidden route'), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.text('Hidden route'),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isFalse,
      );
      await mouse.moveTo(tester.getCenter(find.text('Hidden route')));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Hidden route')));
      expect(activations, 1);
      await mouse.moveTo(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('Hidden route'), findsNothing);
      await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
      await tester.pumpAndSettle();
      expect(find.text('Hidden route'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Hidden route'), findsNothing);
      await mouse.removePointer();
    });
    testWidgets(
      'reflow extent settles after rapid resize and removal, RM=$reduce',
      (tester) async {
        var first = true;
        var width = 180.0;
        var activations = 0;
        late StateSetter update;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SizedBox(
                  width: width,
                  child: BeuiBreadcrumbList(
                    maxItems: null,
                    children: [
                      if (first)
                        const BeuiBreadcrumbItem(
                          key: ValueKey('first'),
                          child: SizedBox(width: 100, height: 32),
                        ),
                      BeuiBreadcrumbItem(
                        key: const ValueKey('kept'),
                        child: SizedBox(
                          width: 100,
                          height: 32,
                          child: BeuiBreadcrumbLink(
                            onPressed: () => activations++,
                            child: const Text('Kept route'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            reduce: reduce,
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byType(BeuiBreadcrumbList);
        expect(tester.getSize(list).height, 68);
        var expectedActivations = 0;
        for (final change in [
          () => first = false,
          () {
            first = true;
            width = 300;
          },
          () => width = 180,
          () => first = false,
        ]) {
          update(change);
          await tester.pump();
          await tester.tapAt(tester.getCenter(find.text('Kept route')));
          expect(activations, ++expectedActivations);
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(activations, 4);
        if (reduce) expect(tester.getSize(list).height, 32);
        await tester.pumpAndSettle();
        expect(tester.getSize(list).height, closeTo(32, .01));
        expect(find.text('Kept route'), findsOneWidget);
      },
    );
  }
  testWidgets('surviving segments spring from their painted layout position', (
    tester,
  ) async {
    var prepend = false;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 400,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiBreadcrumbList(
                children: [
                  if (prepend)
                    const BeuiBreadcrumbItem(
                      key: ValueKey('new'),
                      child: SizedBox(width: 100, height: 32),
                    ),
                  const BeuiBreadcrumbItem(
                    key: ValueKey('kept'),
                    child: SizedBox(
                      key: ValueKey('kept-box'),
                      width: 80,
                      height: 32,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final box = find.byKey(const ValueKey('kept-box'));
    final before = tester.getTopLeft(box);
    update(() => prepend = true);
    await tester.pump();
    expect(tester.getTopLeft(box).dx, closeTo(before.dx, .01));
    await tester.pump(const Duration(milliseconds: 80));
    final travel = tester.getTopLeft(box).dx - before.dx;
    expect(travel, inExclusiveRange(0, 104));
    update(() => prepend = false);
    await tester.pump();
    expect(tester.getTopLeft(box).dx - before.dx, closeTo(travel, .01));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(box).dx - before.dx, lessThan(travel));
    await tester.pumpAndSettle();
    expect((tester.getTopLeft(box) - before).distance, closeTo(0, .01));
    update(() => prepend = true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(box).dx - before.dx, closeTo(104, .01));
  });
  testWidgets('reduced motion moves surviving segments without a spring', (
    tester,
  ) async {
    var prepend = false;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 400,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiBreadcrumbList(
                children: [
                  if (prepend)
                    const BeuiBreadcrumbItem(
                      key: ValueKey('new'),
                      child: SizedBox(width: 100, height: 32),
                    ),
                  const BeuiBreadcrumbItem(
                    key: ValueKey('kept'),
                    child: SizedBox(
                      key: ValueKey('kept-box'),
                      width: 80,
                      height: 32,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        reduce: true,
      ),
    );
    final box = find.byKey(const ValueKey('kept-box'));
    final before = tester.getTopLeft(box);
    update(() => prepend = true);
    await tester.pump();
    expect(tester.getTopLeft(box).dx - before.dx, 104);
  });
  testWidgets('removed routes retain visual exit but cannot activate', (
    tester,
  ) async {
    var removed = false;
    var activations = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiBreadcrumbList(
              maxItems: null,
              children: [
                const BeuiBreadcrumbItem(
                  key: ValueKey('home'),
                  child: BeuiBreadcrumbPage(child: Text('Home')),
                ),
                if (!removed)
                  BeuiBreadcrumbItem(
                    key: const ValueKey('old'),
                    child: BeuiBreadcrumbLink(
                      onPressed: () => activations++,
                      child: const Text('Old route'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Old route'));
    expect(activations, 1);
    final old = tester.getRect(find.text('Old route'));
    final held = await tester.startGesture(old.center);
    await tester.pump(const Duration(milliseconds: 50));
    update(() => removed = true);
    await tester.pump();
    await held.up();
    expect(activations, 1);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Old route'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Old route')).dy, greaterThan(old.top));
    await tester.tapAt(old.center);
    expect(activations, 1);
    await tester.pumpAndSettle();
    expect(find.text('Old route'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
    'overflow keyboard open focuses an actual link and Escape returns',
    (tester) async {
      var activations = 0;
      await tester.pumpWidget(
        _app(
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
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);
    },
  );
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
