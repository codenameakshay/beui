import 'package:beui/src/motion/_disclosure.dart'
    show BeuiAgentDisclosureInternal;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _body = SizedBox(
  height: 100,
  width: 200,
  child: Center(child: Text('body')),
);

Widget _app({required bool open, bool reduce = false}) {
  Widget disclosure = Center(
    child: BeuiAgentDisclosureInternal(
      key: const ValueKey('disclosure'),
      open: open,
      reduce: false,
      child: _body,
    ),
  );
  if (reduce) {
    disclosure = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: disclosure,
      ),
    );
  }
  return MaterialApp(home: Scaffold(body: disclosure));
}

double _h(WidgetTester t) =>
    t.getSize(find.byType(BeuiAgentDisclosureInternal)).height;

void main() {
  testWidgets('debug reduced-motion close', (tester) async {
    await tester.pumpWidget(_app(open: true, reduce: true));
    await tester.pumpAndSettle();
    debugPrint('after open settle: ${_h(tester)}');

    await tester.pumpWidget(_app(open: false, reduce: true));
    debugPrint('immediately after pumpWidget(open:false): ${_h(tester)}');
    await tester.pump();
    debugPrint('after one extra pump(): ${_h(tester)}');
    await tester.pump(const Duration(milliseconds: 60));
    debugPrint('after +60ms: ${_h(tester)}');
    await tester.pump(const Duration(milliseconds: 80));
    debugPrint('after +80ms more (settled): ${_h(tester)}');
  });
}
