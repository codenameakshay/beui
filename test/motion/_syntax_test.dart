// Equivalence tests for the shared highlighter.
//
// These pin the token-for-token output of `_syntax.dart` against the three
// implementations it replaces. Where those three disagreed, the expectation
// here is the one with evidence behind it — see the `beuiHighlightLine` docs
// for which won and why. A failure means either a real regression or a
// deliberate divergence that has to be argued for in the doc comment first.

import 'package:beui/src/motion/_syntax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts the exact (text, colour) sequence, so a change to *either* the
/// slicing or the colouring fails loudly.
void expectTokens(
  List<BeuiSyntaxToken> actual,
  List<(String, Color)> expected,
) {
  expect(
    actual.map((t) => (t.text, t.color)).toList(),
    expected,
    reason: 'got ${actual.map((t) => t.text).toList()}',
  );
}

void main() {
  final light = BeuiSyntaxPalette.of(Brightness.light);
  final dark = BeuiSyntaxPalette.of(Brightness.dark);

  group('palette', () {
    test('light and dark are a real split, not one palette dimmed', () {
      expect(light.base, isNot(dark.base));
      expect(light.keyword, isNot(dark.keyword));
      expect(light.diffAdd, isNot(dark.diffAdd));
    });

    test('carries the union of the three palettes it replaces', () {
      // code_block had diffAdd/diffDel but no property/variable...
      expect(light.diffAdd, const Color(0xFF055D20));
      expect(light.diffDel, const Color(0xFFA0111F));
      // ...tool_result had property/variable but no diff colours.
      expect(light.property, const Color(0xFF024C1A));
      expect(light.variable, const Color(0xFF702C00));
      expect(dark.property, const Color(0xFF72F088));
      expect(dark.variable, const Color(0xFFFFB757));
    });

    test('shared slots keep the values all three already agreed on', () {
      expect(light.base, const Color(0xFF0E1116));
      expect(light.keyword, const Color(0xFFA0111F));
      expect(light.string, const Color(0xFF032563));
      expect(light.comment, const Color(0xFF4B535D));
      expect(light.number, const Color(0xFF023B95));
      expect(light.entity, const Color(0xFF622CBC));
      expect(light.punct, const Color(0xFF0E1116));
      expect(dark.base, const Color(0xFFF0F3F6));
      expect(dark.keyword, const Color(0xFFFF9492));
      expect(dark.string, const Color(0xFFADDCFF));
      expect(dark.comment, const Color(0xFFBDC4CC));
      expect(dark.number, const Color(0xFF91CBFF));
      expect(dark.entity, const Color(0xFFDBB7FF));
    });

    test('is a value type', () {
      expect(BeuiSyntaxPalette.of(Brightness.light), light);
      expect(BeuiSyntaxPalette.of(Brightness.light).hashCode, light.hashCode);
    });
  });

  group('every language: an empty line yields no tokens', () {
    test('callers rely on this to skip the span entirely', () {
      for (final language in BeuiCodeLanguage.values) {
        expect(beuiHighlightLine('', language, light), isEmpty);
      }
    });
  });

  group('text', () {
    test('is one uncoloured span, whatever it contains', () {
      expectTokens(
        beuiHighlightLine('const x = "not code"', BeuiCodeLanguage.text, light),
        [('const x = "not code"', light.base)],
      );
    });
  });

  group('diff — code_block behaviour won', () {
    test('added lines take diffAdd, not the deletion red', () {
      // file_diff painted this with `keyword` (#A0111F) — the *deletion*
      // colour. That is the divergence this module resolves.
      expectTokens(
        beuiHighlightLine('+  const x = 1;', BeuiCodeLanguage.diff, light),
        [('+  const x = 1;', light.diffAdd)],
      );
      expect(light.diffAdd, isNot(light.keyword));
    });

    test('removed lines take diffDel, not the comment grey', () {
      expectTokens(
        beuiHighlightLine('-  const x = 0;', BeuiCodeLanguage.diff, light),
        [('-  const x = 0;', light.diffDel)],
      );
      expect(light.diffDel, isNot(light.comment));
    });

    test('a U+2212 MINUS SIGN removal is recognised too', () {
      final tokens = beuiHighlightLine(
        '−  const x = 0;',
        BeuiCodeLanguage.diff,
        light,
      );
      expect(tokens.single.color, light.diffDel);
    });

    test('@@ hunk headers take the keyword colour', () {
      // file_diff dropped this branch entirely — hunk headers rendered as
      // ordinary body text.
      expectTokens(
        beuiHighlightLine('@@ -1,4 +1,6 @@', BeuiCodeLanguage.diff, light),
        [('@@ -1,4 +1,6 @@', light.keyword)],
      );
    });

    test('+++ / --- file headers stay base, not add/remove', () {
      expectTokens(
        beuiHighlightLine('+++ b/lib/main.dart', BeuiCodeLanguage.diff, light),
        [('+++ b/lib/main.dart', light.base)],
      );
      expectTokens(
        beuiHighlightLine('--- a/lib/main.dart', BeuiCodeLanguage.diff, light),
        [('--- a/lib/main.dart', light.base)],
      );
    });

    test('context lines stay base', () {
      expectTokens(
        beuiHighlightLine('   unchanged();', BeuiCodeLanguage.diff, light),
        [('   unchanged();', light.base)],
      );
    });
  });

  group('json — tool_result behaviour won', () {
    // Pins the exact colours asserted by the widget-level regression test in
    // tool_result_test.dart ("JSON property names take the theme green, not
    // keyword red"). Shiki scopes a property name as
    // `support.type.property-name.json`; github-*-high-contrast paints it
    // green. code_block and file_diff both guessed the `number` blue.
    test('property names take property green; values take string blue', () {
      expectTokens(
        beuiHighlightLine(
          '  "error": "rate_limit_exceeded"',
          BeuiCodeLanguage.json,
          light,
        ),
        [
          (' ', light.punct),
          (' ', light.punct),
          ('"error"', light.property),
          (':', light.punct),
          (' ', light.punct),
          ('"rate_limit_exceeded"', light.string),
        ],
      );
      expect(light.property, const Color(0xFF024C1A));
      expect(light.string, const Color(0xFF032563));
      expect(light.property, isNot(light.number));
      expect(light.property, isNot(light.keyword));
    });

    test('literals take keyword; numbers take number', () {
      expectTokens(
        beuiHighlightLine('  "ok": true,', BeuiCodeLanguage.json, light),
        [
          (' ', light.punct),
          (' ', light.punct),
          ('"ok"', light.property),
          (':', light.punct),
          (' ', light.punct),
          ('true', light.keyword),
          (',', light.punct),
        ],
      );
      expectTokens(
        beuiHighlightLine('  "n": -12.5', BeuiCodeLanguage.json, light),
        [
          (' ', light.punct),
          (' ', light.punct),
          ('"n"', light.property),
          (':', light.punct),
          (' ', light.punct),
          ('-12.5', light.number),
        ],
      );
    });

    test('bare identifiers that are not literals stay base', () {
      expectTokens(beuiHighlightLine('nan', BeuiCodeLanguage.json, light), [
        ('nan', light.base),
      ]);
    });

    test('braces are punctuation', () {
      expectTokens(beuiHighlightLine('{', BeuiCodeLanguage.json, light), [
        ('{', light.punct),
      ]);
    });
  });

  group('bash — tool_result behaviour won', () {
    test('the command word takes variable; arguments take string', () {
      expectTokens(
        beuiHighlightLine('echo hello', BeuiCodeLanguage.bash, light),
        [('echo', light.variable), (' ', light.base), ('hello', light.string)],
      );
    });

    test('a later bare number takes number, but a leading one does not', () {
      // The asymmetry is real: it is what beui.dev renders for the
      // tool-result preview's "49 pass - 0 fail" line.
      expectTokens(
        beuiHighlightLine('49 pass 0 fail', BeuiCodeLanguage.bash, light),
        [
          ('49', light.variable),
          (' ', light.base),
          ('pass', light.string),
          (' ', light.base),
          ('0', light.number),
          (' ', light.base),
          ('fail', light.string),
        ],
      );
    });

    test('quoted runs are strings and do not consume the command slot', () {
      expectTokens(
        beuiHighlightLine("git commit -m 'wip'", BeuiCodeLanguage.bash, light),
        [
          ('git', light.variable),
          (' ', light.base),
          ('commit', light.string),
          (' ', light.base),
          ('-m', light.string),
          (' ', light.base),
          ("'wip'", light.string),
        ],
      );
    });

    test('# starts a comment that runs to end of line', () {
      expectTokens(
        beuiHighlightLine('bun test # the suite', BeuiCodeLanguage.bash, light),
        [
          ('bun', light.variable),
          (' ', light.base),
          ('test', light.string),
          (' ', light.base),
          ('# the suite', light.comment),
        ],
      );
    });

    test('runs of whitespace collapse into one base token', () {
      expectTokens(
        beuiHighlightLine('ls   -la', BeuiCodeLanguage.bash, light),
        [('ls', light.variable), ('   ', light.base), ('-la', light.string)],
      );
    });

    test('bash is NOT tokenised by keyword set any more', () {
      // The old code_block/file_diff path painted `cd` and `echo` with the
      // keyword red wherever they appeared. Positionally, a mid-line `echo`
      // is an argument.
      final tokens = beuiHighlightLine(
        'sh -c echo',
        BeuiCodeLanguage.bash,
        light,
      );
      expect(tokens.last.text, 'echo');
      expect(tokens.last.color, light.string);
      expect(tokens.last.color, isNot(light.keyword));
    });
  });

  group('typescript / tsx — code_block behaviour won', () {
    test('keywords, calls, numbers, and punctuation', () {
      expectTokens(
        beuiHighlightLine(
          'const x = foo(1);',
          BeuiCodeLanguage.typescript,
          light,
        ),
        [
          ('const', light.keyword),
          (' ', light.base),
          ('x', light.base),
          (' ', light.base),
          ('=', light.punct),
          (' ', light.base),
          ('foo', light.entity),
          ('(', light.punct),
          ('1', light.number),
          (')', light.punct),
          (';', light.punct),
        ],
      );
    });

    test('tsx shares the typescript keyword set', () {
      expect(
        beuiHighlightLine('export', BeuiCodeLanguage.tsx, light),
        beuiHighlightLine('export', BeuiCodeLanguage.typescript, light),
      );
    });

    test('// line comments run to end of line', () {
      expectTokens(
        beuiHighlightLine('let a; // note', BeuiCodeLanguage.typescript, light),
        [
          ('let', light.keyword),
          (' ', light.base),
          ('a', light.base),
          (';', light.punct),
          (' ', light.base),
          ('// note', light.comment),
        ],
      );
    });

    test(
      '/* block comment openers close the line — tool_result lacked this',
      () {
        expectTokens(
          beuiHighlightLine(
            'let a; /* note',
            BeuiCodeLanguage.typescript,
            light,
          ),
          [
            ('let', light.keyword),
            (' ', light.base),
            ('a', light.base),
            (';', light.punct),
            (' ', light.base),
            ('/* note', light.comment),
          ],
        );
      },
    );

    test('a leading-dot number is a number — tool_result lacked this', () {
      expectTokens(
        beuiHighlightLine('x = .5;', BeuiCodeLanguage.typescript, light),
        [
          ('x', light.base),
          (' ', light.base),
          ('=', light.punct),
          (' ', light.base),
          ('.5', light.number),
          (';', light.punct),
        ],
      );
    });

    test('strings honour backslash escapes', () {
      expectTokens(
        beuiHighlightLine(r'"a\"b" c', BeuiCodeLanguage.typescript, light),
        [(r'"a\"b"', light.string), (' ', light.base), ('c', light.base)],
      );
    });

    test('an unterminated string runs to end of line', () {
      expectTokens(
        beuiHighlightLine('"oops', BeuiCodeLanguage.typescript, light),
        [('"oops', light.string)],
      );
    });

    test(r'$-prefixed identifiers scan as one word', () {
      expectTokens(
        beuiHighlightLine(r'$el.x', BeuiCodeLanguage.typescript, light),
        [(r'$el', light.base), ('.', light.punct), ('x', light.base)],
      );
    });

    test('tokens always reassemble into the original line', () {
      const lines = [
        'const x = foo(1);',
        'let a; // note',
        r'"a\"b" c',
        'x = .5;',
        r'if (a === b) { return `t${a}`; }',
      ];
      for (final line in lines) {
        final joined = beuiHighlightLine(
          line,
          BeuiCodeLanguage.typescript,
          light,
        ).map((t) => t.text).join();
        expect(joined, line, reason: 'lossy tokenisation of: $line');
      }
    });
  });

  group('no language drops characters', () {
    test('tokens reassemble into the original line, every language', () {
      const samples = [
        'echo "hi" # x',
        '{"a": 1, "b": [true, null]}',
        '+added line',
        '@@ -1 +1 @@',
        'const y = bar();',
      ];
      for (final language in BeuiCodeLanguage.values) {
        for (final line in samples) {
          final joined = beuiHighlightLine(
            line,
            language,
            light,
          ).map((t) => t.text).join();
          expect(
            joined,
            line,
            reason: 'lossy tokenisation of "$line" as ${language.label}',
          );
        }
      }
    });
  });
}
