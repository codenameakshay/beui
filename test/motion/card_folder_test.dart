import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _artwork(bool visible) => Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF383A38), Color(0xFF111211)]),
  ),
  alignment: Alignment.center,
  child: Text(
    visible ? '3745 6987 4096 0806' : '•••• •••• •••• 0806',
    style: const TextStyle(color: Colors.white),
  ),
);

String _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? '')
    .join();

Widget _app({
  bool? open,
  bool defaultOpen = false,
  bool? detailsVisible,
  ValueChanged<bool>? onOpenChange,
  ValueChanged<bool>? onDetailsVisibleChange,
  VoidCallback? onAction,
  bool disabled = false,
  bool reduce = false,
}) => beuiTestApp(
  BeuiCardFolder(
    title: 'Travel Card',
    cardNumber: '3745 6987 4096 0806',
    expiry: '08/29',
    cvv: '123',
    card: _artwork(detailsVisible ?? false),
    open: open,
    defaultOpen: defaultOpen,
    onOpenChange: onOpenChange,
    detailsVisible: detailsVisible,
    onDetailsVisibleChange: onDetailsVisibleChange,
    onAction: onAction,
    disabled: disabled,
  ),
  reduce: reduce,
);

void main() {
  testWidgets('closed rest state masks details and retains last four', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_renderedText(tester), contains('0806'));
    expect(_renderedText(tester), contains('•••'));
    expect(_renderedText(tester), isNot(contains('123')));
    expect(
      find.bySemanticsLabel(
        'Open Travel Card, card ending in 0806, expires 08/29',
      ),
      findsOneWidget,
    );
  });

  testWidgets('folder tap reports open state', (tester) async {
    final states = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: states.add));
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(
        'Open Travel Card, card ending in 0806, expires 08/29',
      ),
    );
    await tester.pump();
    expect(states, [true]);
  });

  testWidgets('details toggle reveals number and CVV', (tester) async {
    var visible = false;
    await tester.pumpWidget(
      _app(onDetailsVisibleChange: (next) => visible = next),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show card details'));
    await tester.pumpAndSettle();
    expect(visible, isTrue);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    expect(find.byTooltip('Hide card details'), findsOneWidget);
  });

  testWidgets('action fires without toggling the folder', (tester) async {
    var actions = 0;
    var opens = 0;
    await tester.pumpWidget(
      _app(onAction: () => actions++, onOpenChange: (_) => opens++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open actions for Travel Card'));
    await tester.pump();
    expect(actions, 1);
    expect(opens, 0);
  });

  testWidgets('disabled folder ignores tap and detail toggle', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _app(
        disabled: true,
        onOpenChange: (_) => changes++,
        onDetailsVisibleChange: (_) => changes++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(
        'Open Travel Card, card ending in 0806, expires 08/29',
      ),
    );
    await tester.tap(find.byTooltip('Show card details'));
    await tester.pump();
    expect(changes, 0);
  });

  testWidgets('reduced motion does not lift the card', (tester) async {
    await tester.pumpWidget(_app(reduce: true, open: false));
    await tester.pumpAndSettle();
    final topBefore = tester.getTopLeft(find.byType(ClipRRect)).dy;
    await tester.pumpWidget(_app(reduce: true, open: true));
    await tester.pump(const Duration(milliseconds: 80));
    final topAfter = tester.getTopLeft(find.byType(ClipRRect)).dy;
    expect(topAfter, topBefore);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiCardFolder),
      matchesGoldenFile('goldens/beui_card_folder.png'),
    );
  });
}
