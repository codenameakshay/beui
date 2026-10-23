import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Tab enters a visible narrow chart before the following control',
    (tester) async {
      final before = FocusNode();
      final after = FocusNode();
      addTearDown(before.dispose);
      addTearDown(after.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      TextButton(
                        focusNode: before,
                        onPressed: () {},
                        child: const Text('Before'),
                      ),
                      const BeuiSankeyChart(
                        nodes: [
                          BeuiSankeyNode(id: 'a', label: 'A'),
                          BeuiSankeyNode(id: 'b', label: 'B'),
                          BeuiSankeyNode(id: 'c', label: 'C'),
                        ],
                        links: [
                          BeuiSankeyLink(source: 'a', target: 'c', value: 30),
                          BeuiSankeyLink(source: 'b', target: 'c', value: 70),
                        ],
                      ),
                      TextButton(
                        focusNode: after,
                        onPressed: () {},
                        child: const Text('Outside'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Sankey a');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(after.hasPrimaryFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Sankey a');
    },
  );
}
