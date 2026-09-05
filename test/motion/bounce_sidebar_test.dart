import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <BeuiBounceSidebarItem>[
  BeuiBounceSidebarItem(id: 'overview', label: Text('Overview')),
  BeuiBounceSidebarItem(id: 'components', label: Text('Components')),
  BeuiBounceSidebarItem(id: 'motion', label: Text('Motion')),
  BeuiBounceSidebarItem(id: 'templates', label: Text('Templates')),
  BeuiBounceSidebarItem(id: 'changelog', label: Text('Changelog')),
];

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: SizedBox(width: 220, child: child));
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  group('BeuiBounceSidebar', () {
    testWidgets('renders items', (tester) async {
      await tester.pumpWidget(
        _wrap(BeuiBounceSidebar(items: _items, defaultValue: 'components')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(beuiBounceSidebarIndicatorKey), findsOneWidget);
    });

    testWidgets('tapping item selects and fires onChanged (controlled)', (
      tester,
    ) async {
      String? changed;
      var value = 'overview';

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return BeuiBounceSidebar(
                items: _items,
                value: value,
                onChanged: (id) {
                  changed = id;
                  setState(() => value = id);
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Motion'));
      await tester.pump();
      expect(changed, 'motion');

      await tester.tap(find.text('Changelog'));
      await tester.pump();
      expect(changed, 'changelog');
    });

    testWidgets('uncontrolled defaultValue selects first tap via onChanged', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _wrap(
          BeuiBounceSidebar(
            items: _items,
            defaultValue: 'components',
            onChanged: (id) => changed = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Overview'));
      await tester.pump();
      expect(changed, 'overview');
    });

    testWidgets('disabled item does not fire onChanged', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _wrap(
          BeuiBounceSidebar(
            items: const [
              BeuiBounceSidebarItem(id: 'a', label: Text('Alpha')),
              BeuiBounceSidebarItem(
                id: 'b',
                label: Text('Bravo'),
                disabled: true,
              ),
              BeuiBounceSidebarItem(id: 'c', label: Text('Charlie')),
            ],
            defaultValue: 'a',
            onChanged: (id) => changed = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bravo'));
      await tester.pump();
      expect(changed, isNull);
    });
  });
}
