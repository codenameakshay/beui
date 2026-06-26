import 'package:beui/beui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lucide icon re-export', () {
    test('LucideIcons is reachable through the beui barrel', () {
      // Imported via package:beui/beui.dart only — no direct flutter_lucide
      // import in this file — proving the barrel re-export works.
      expect(LucideIcons.bell, isA<IconData>());
    });

    test('glyphs are framework-native IconData (swappable icon package)', () {
      const IconData icon = LucideIcons.check;
      expect(icon, isA<IconData>());
    });
  });
}
