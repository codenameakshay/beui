import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  for (final design in ['stepped', 'wave', 'bubble']) {
    testWidgets('$design disabled drag cannot bypass the pointer-down guard', (
      tester,
    ) async {
      for (final enabled in [true, false]) {
        final changes = <double>[];
        final Widget slider = switch (design) {
          'wave' => BeuiWaveSlider(
            key: ValueKey(enabled),
            defaultValue: 40,
            enabled: enabled,
            onChanged: changes.add,
          ),
          'bubble' => BeuiBubbleSlider(
            key: ValueKey(enabled),
            defaultValue: 40,
            enabled: enabled,
            onChanged: changes.add,
          ),
          _ => BeuiRangeSlider(
            key: ValueKey(enabled),
            defaultValue: 40,
            enabled: enabled,
            onChanged: changes.add,
          ),
        };
        await tester.pumpWidget(beuiTestApp(slider, width: 200));
        final hitArea = find
            .descendant(
              of: find.byWidget(slider),
              matching: find.byType(GestureDetector),
            )
            .first;
        final rect = tester.getRect(hitArea);
        await tester.dragFrom(
          Offset(rect.left + rect.width * .1, rect.center.dy),
          Offset(rect.width * .8, 0),
        );
        await tester.pump(const Duration(milliseconds: 300));
        if (enabled) {
          expect(changes.last, 90);
        } else {
          expect(changes, isEmpty);
        }
      }
    });
  }

  testWidgets('one native move preserves the entire table resize delta', (
    tester,
  ) async {
    double? resized;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTable<String>(
          data: const ['Ava'],
          resizable: true,
          columns: [
            BeuiTableColumn(
              key: 'name',
              header: 'Name',
              width: 200,
              value: (row) => row,
            ),
            BeuiTableColumn(
              key: 'role',
              header: 'Role',
              width: 200,
              value: (_) => 'Owner',
            ),
          ],
          onColumnResize: (key, width) => resized = width,
        ),
        width: 400,
      ),
    );
    final handle = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Resize name column',
    );
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(const Offset(50, 0));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(resized, 250);
  });

  testWidgets('metallic rim fills the button without adding content padding', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMetallicButton(
          paused: true,
          onPressed: () => activations++,
          child: const SizedBox(width: 80, height: 16),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(BeuiMetallicButton)),
      const Size(120, 40),
    );
    await tester.tap(find.byType(BeuiMetallicButton));
    await tester.pump();
    expect(activations, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 2);
  });
  for (final reduce in [false, true]) {
    for (final design in ['stepped', 'fluid', 'wave', 'bubble', 'ruler']) {
      testWidgets('$design commits pointer down and PageUp, reduce=$reduce', (
        tester,
      ) async {
        var value = 20.0;
        final changes = <double>[];
        await tester.pumpWidget(
          beuiTestApp(
            StatefulBuilder(
              builder: (context, setState) {
                void onChanged(double next) {
                  changes.add(next);
                  setState(() => value = next);
                }

                final slider = switch (design) {
                  'stepped' => BeuiRangeSlider(
                    value: value,
                    onChanged: onChanged,
                  ),
                  'fluid' => BeuiFluidSlider(
                    value: value,
                    onChanged: onChanged,
                  ),
                  'wave' => BeuiWaveSlider(value: value, onChanged: onChanged),
                  'bubble' => BeuiBubbleSlider(
                    value: value,
                    onChanged: onChanged,
                  ),
                  _ => BeuiRulerSlider(value: value, onChanged: onChanged),
                };
                return SizedBox(width: 384, child: slider);
              },
            ),
            reduce: reduce,
          ),
        );
        await tester.pump();
        final target = find.byWidgetPredicate(
          (w) => switch (design) {
            'stepped' => w is BeuiRangeSlider,
            'fluid' => w is BeuiFluidSlider,
            'wave' => w is BeuiWaveSlider,
            'bubble' => w is BeuiBubbleSlider,
            _ => w is BeuiRulerSlider,
          },
        );
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 200));
        final before = value;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await tester.pump(const Duration(milliseconds: 300));
        expect(value, (before + 10).clamp(0, 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump(const Duration(milliseconds: 300));
        expect(value, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump(const Duration(milliseconds: 300));
        expect(value, 100);
      });
    }
  }

  testWidgets('sortable header keeps native keyboard focus after click', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTable<String>(
          data: const ['Ava', 'Zoe'],
          columns: [
            BeuiTableColumn(
              key: 'name',
              header: 'Name',
              sortable: true,
              value: (row) => row,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Name'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Zoe')).dy,
      lessThan(tester.getTopLeft(find.text('Ava')).dy),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Ava')).dy,
      lessThan(tester.getTopLeft(find.text('Zoe')).dy),
    );
  });

  testWidgets('table handle opens, dismisses and selects with native keys', (
    tester,
  ) async {
    var insertion = '';
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTable<String>(
          data: const ['Ava'],
          columns: [
            BeuiTableColumn(key: 'name', header: 'Name', value: (row) => row),
          ],
          onInsertRow: (index, position) =>
              insertion = '$index:${position.name}',
        ),
        width: 400,
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Ava')));
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.ellipsis_vertical));
    await tester.pumpAndSettle();
    expect(find.text('Insert before'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Insert before'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Insert before'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(insertion, '0:before');
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('table empty-state action restores a row after native deletion', (
    tester,
  ) async {
    var rows = ['Ava'];
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => BeuiTable<String>(
            data: rows,
            columns: [
              BeuiTableColumn(key: 'name', header: 'Name', value: (row) => row),
            ],
            height: 240,
            onDeleteRow: (_, index) => setState(() => rows = []),
            emptyState: TextButton(
              onPressed: () => setState(() => rows = ['New row']),
              child: const Text('Insert first row'),
            ),
          ),
        ),
        width: 400,
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Ava')));
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.ellipsis_vertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete row'));
    await tester.pumpAndSettle();
    expect(find.text('Insert first row'), findsOneWidget);
    await tester.tap(find.text('Insert first row'));
    await tester.pumpAndSettle();
    expect(find.text('New row'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 150));
  });
}
