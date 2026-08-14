import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeuiAgentTheme defaults match source-fidelity tokens', () {
    test('standard typography sizes', () {
      final t = BeuiAgentTheme.standard.typography;
      expect(t.assistantBody.fontSize, 14);
      expect(t.userBody.fontSize, 14);
      expect(t.title.fontSize, 16);
      expect(t.description.fontSize, 14);
      expect(t.metadata.fontSize, 11);
      expect(t.status.fontSize, 12);
      expect(t.action.fontSize, 12);
      expect(t.mono.fontSize, 12);
      expect(t.mono.fontFamily, 'monospace');
    });

    test('standard shapes', () {
      final s = BeuiAgentTheme.standard.shapes;
      expect(s.userBubble, BorderRadius.circular(16));
      expect(s.assistantBubble, BorderRadius.circular(16));
      expect(s.card, BorderRadius.circular(16));
      expect(s.nested, BorderRadius.circular(12));
      expect(s.control, BorderRadius.circular(8));
      expect(s.chip, BorderRadius.circular(6));
      expect(s.pill, BorderRadius.circular(999));
      expect(s.cardRadius, 16);
    });

    test('standard layout', () {
      final l = BeuiAgentTheme.standard.layout;
      expect(l.density, BeuiAgentDensity.standard);
      expect(l.conversationGutter, EdgeInsets.zero);
      expect(l.turnSpacing, 16);
      expect(l.groupedMessageSpacing, 6);
      expect(l.groupedMessageSpacingRelaxed, 12);
      expect(
        l.bubblePadding,
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );
      expect(l.cardPadding, const EdgeInsets.all(16));
      expect(l.maxBubbleWidthFactor, 0.82);
    });
  });

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
      expect(BeuiAgentTheme.compact.layout.density, BeuiAgentDensity.compact);
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
