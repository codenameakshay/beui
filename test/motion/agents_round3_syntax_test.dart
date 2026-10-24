import 'package:beui/src/motion/_syntax.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;
    final palette = BeuiSyntaxPalette.of(brightness);
    final blue = Color(dark ? 0xFF91CBFF : 0xFF023B95);
    final red = Color(dark ? 0xFFFF9492 : 0xFFA0111F);
    final purple = Color(dark ? 0xFFDBB7FF : 0xFF622CBC);
    final base = Color(dark ? 0xFFF0F3F6 : 0xFF0E1116);
    for (final sample in [
      ('const total = await compute(input);', blue),
      ('const answer = 42;', blue),
      ('let total = 42;', base),
      ('var total = 42;', base),
      ('const run = () => 42;', purple),
      ('const run = async (input) => input;', purple),
    ]) {
      test('source binding and assignment roles $brightness ${sample.$1}', () {
        final tokens = beuiHighlightLine(
          sample.$1,
          BeuiCodeLanguage.typescript,
          palette,
        );
        expect(tokens.map((token) => token.text).join(), sample.$1);
        expect(tokens[2].color, sample.$2);
        expect(tokens.firstWhere((token) => token.text == '=').color, red);
      });
    }
    test('strings and comments do not become operators $brightness', () {
      final tokens = beuiHighlightLine(
        'let label = "const = value"; // const = ignored',
        BeuiCodeLanguage.typescript,
        palette,
      );
      expect(tokens.firstWhere((token) => token.text == 'label').color, base);
      expect(
        tokens.firstWhere((token) => token.text == '"const = value"').color,
        Color(dark ? 0xFFADDCFF : 0xFF032563),
      );
      expect(tokens.last.text, '// const = ignored');
      expect(tokens.last.color, Color(dark ? 0xFFBDC4CC : 0xFF4B535D));
    });
  }
}
