import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('of() returns standard outside a themed tree', (tester) async {
    late BeuiAgentTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = BeuiAgentTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, BeuiAgentTheme.standard);
  });

  testWidgets('of() returns the installed extension', (tester) async {
    late BeuiAgentTheme resolved;
    const custom = BeuiAgentTheme(layout: BeuiAgentLayout(turnSpacing: 22));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [custom]),
        home: Builder(
          builder: (context) {
            resolved = BeuiAgentTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved.layout.turnSpacing, 22);
  });

  group('copyWith / lerp / equality', () {
    test('copyWith replaces nested contracts', () {
      final next = BeuiAgentTheme.standard.copyWith(
        layout: const BeuiAgentLayout(cardPadding: EdgeInsets.all(8)),
      );
      expect(next.layout.cardPadding, const EdgeInsets.all(8));
      expect(next.shapes, BeuiAgentTheme.standard.shapes);
    });

    test('identical values compare equal (ThemeData contract)', () {
      const a = BeuiAgentTheme();
      const b = BeuiAgentTheme();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('lerp interpolates paddings and snaps icons', () {
      const a = BeuiAgentTheme.standard;
      const b = BeuiAgentTheme(
        layout: BeuiAgentLayout(turnSpacing: 32),
        icons: BeuiAgentIcons(edit: Icons.edit),
      );
      final mid = a.lerp(b, 0.5);
      expect(mid.layout.turnSpacing, 24);
      expect(mid.icons.edit, Icons.edit);
    });

    test('compact preset tightens layout only', () {
      expect(
        BeuiAgentTheme.compact.layout.cardPadding,
        const EdgeInsets.all(12),
      );
      expect(
        BeuiAgentTheme.compact.typography,
        BeuiAgentTheme.standard.typography,
      );
      expect(BeuiAgentTheme.compact.shapes, BeuiAgentTheme.standard.shapes);
    });
  });
}
