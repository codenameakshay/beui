/// The shared syntax highlighter — one tokenizer for every code surface.
///
/// Package-internal, except [BeuiCodeLanguage], which lives here because the
/// language enum belongs with the tokenizer rather than with one widget.
/// `code_block.dart` re-exports it, so the public API is unchanged.
///
/// `code_block.dart`, `file_diff.dart`, and `tool_result.dart` all share this
/// one tokenizer rather than keeping their own copies, so diff, JSON, bash,
/// and comment handling behave identically across every code surface.
///
/// Highlighting is a deliberately **reduced** port of the source's Shiki
/// themes: a small hand-rolled scanner, not a lexer. Full Shiki fidelity is out
/// of scope so the package stays free of a heavy highlighting dependency.
library;

import 'package:flutter/widgets.dart';

/// Supported language labels / lightweight highlighters (source
/// `AgentCodeLanguage`).
///
/// Highlighting is a **reduced** port of the source's Shiki themes: a small
/// regex tokeniser paints keywords, strings, comments, and numbers. Full
/// Shiki fidelity is intentionally omitted so the package stays free of heavy
/// highlighting dependencies.
enum BeuiCodeLanguage {
  /// Shell / bash scripts.
  bash('bash'),

  /// Unified diffs.
  diff('diff'),

  /// JSON payloads.
  json('json'),

  /// Plain text — no token colouring.
  text('text'),

  /// TypeScript / TSX (shared keyword set).
  tsx('tsx'),

  /// TypeScript.
  typescript('typescript');

  const BeuiCodeLanguage(this.label);

  /// Display label shown in the chrome bar (source uppercase language slug).
  final String label;
}

/// A single coloured span inside a code line.
@immutable
class BeuiSyntaxToken {
  /// Creates a token.
  const BeuiSyntaxToken(this.text, this.color);

  /// The slice of the source line.
  final String text;

  /// The colour to paint it.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is BeuiSyntaxToken && other.text == text && other.color == color;

  @override
  int get hashCode => Object.hash(text, color);

  @override
  String toString() => 'BeuiSyntaxToken($text, $color)';
}

/// The colour roles the tokenizer paints with, covering every code surface
/// in the library: diff colours ([diffAdd] / [diffDel]) alongside JSON/code
/// roles ([property] / [variable]).
@immutable
class BeuiSyntaxPalette {
  /// Creates a palette. Prefer [BeuiSyntaxPalette.of].
  const BeuiSyntaxPalette({
    required this.base,
    required this.keyword,
    required this.property,
    required this.string,
    required this.comment,
    required this.number,
    required this.entity,
    required this.variable,
    required this.punct,
    required this.diffAdd,
    required this.diffDel,
  });

  /// The Shiki `github-light-high-contrast` / `github-dark-high-contrast`
  /// palette — the themes the source's `AgentCode` highlighter is created with
  /// (`agent-code.tsx` `LIGHT_THEME` / `DARK_THEME`).
  ///
  /// Verified at 7.2-13.4:1 light and 8.1-11.9:1 dark against the code surface
  /// — a real light/dark split, not one palette dimmed.
  factory BeuiSyntaxPalette.of(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return BeuiSyntaxPalette(
      base: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
      keyword: isLight ? const Color(0xFFA0111F) : const Color(0xFFFF9492),
      property: isLight ? const Color(0xFF024C1A) : const Color(0xFF72F088),
      string: isLight ? const Color(0xFF032563) : const Color(0xFFADDCFF),
      comment: isLight ? const Color(0xFF4B535D) : const Color(0xFFBDC4CC),
      number: isLight ? const Color(0xFF023B95) : const Color(0xFF91CBFF),
      entity: isLight ? const Color(0xFF622CBC) : const Color(0xFFDBB7FF),
      variable: isLight ? const Color(0xFF702C00) : const Color(0xFFFFB757),
      punct: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
      diffAdd: isLight ? const Color(0xFF055D20) : const Color(0xFF26CD4D),
      diffDel: isLight ? const Color(0xFFA0111F) : const Color(0xFFFF9492),
    );
  }

  /// Uncoloured source text.
  final Color base;

  /// Language keywords, and `true` / `false` / `null` in JSON.
  final Color keyword;

  /// JSON property names (Shiki `support.type.property-name.json`).
  final Color property;

  /// String literals, and unquoted shell arguments.
  final Color string;

  /// Line and block comments.
  final Color comment;

  /// Numeric literals.
  final Color number;

  /// Identifiers in call position (Shiki `entity.name.function`).
  final Color entity;

  /// The shell command word (Shiki `variable`).
  final Color variable;

  /// Punctuation.
  final Color punct;

  /// Added lines in a unified diff.
  final Color diffAdd;

  /// Removed lines in a unified diff.
  final Color diffDel;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiSyntaxPalette &&
        other.base == base &&
        other.keyword == keyword &&
        other.property == property &&
        other.string == string &&
        other.comment == comment &&
        other.number == number &&
        other.entity == entity &&
        other.variable == variable &&
        other.punct == punct &&
        other.diffAdd == diffAdd &&
        other.diffDel == diffDel;
  }

  @override
  int get hashCode => Object.hash(
    base,
    keyword,
    property,
    string,
    comment,
    number,
    entity,
    variable,
    punct,
    diffAdd,
    diffDel,
  );
}

/// Keywords shared by TypeScript / TSX.
const beuiTsKeywords = <String>{
  'abstract',
  'as',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'debugger',
  'default',
  'delete',
  'do',
  'else',
  'enum',
  'export',
  'extends',
  'false',
  'finally',
  'for',
  'from',
  'function',
  'get',
  'if',
  'implements',
  'import',
  'in',
  'instanceof',
  'interface',
  'let',
  'new',
  'null',
  'of',
  'package',
  'private',
  'protected',
  'public',
  'return',
  'set',
  'static',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typeof',
  'undefined',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

/// Tokenises one [line] of [language] against [palette].
///
/// Returns an empty list for an empty line, matching all three implementations
/// this replaces (callers rely on it to skip the span entirely).
///
/// ## Which behaviour won, and why
///
/// * **diff** — `code_block`'s. It paints `+` with [BeuiSyntaxPalette.diffAdd]
///   and `-` with [BeuiSyntaxPalette.diffDel], and recognises `@@` hunk
///   headers. `file_diff`'s copy painted `+` with `keyword` (the *deletion*
///   red — actively misleading) and `-` with `comment` (grey), and dropped
///   `@@` entirely; `tool_result` treated diffs as plain text. `+++` / `---`
///   file headers stay [BeuiSyntaxPalette.base], as in the original. U+2212
///   MINUS SIGN is accepted alongside ASCII `-`, because `file_diff` renders
///   its counters with the real minus and pasted diffs follow.
/// * **json** — `tool_result`'s. Property names take
///   [BeuiSyntaxPalette.property] (Shiki scopes them
///   `support.type.property-name.json`, painted green), not the `number` blue
///   the other two guessed. This one is measured against beui.dev and pinned by
///   an exact-colour regression test.
/// * **bash** — `tool_result`'s. Shell lines are tokenised positionally rather
///   than by keyword set: the first word is the command and takes
///   [BeuiSyntaxPalette.variable], later bare words are unquoted arguments and
///   take [BeuiSyntaxPalette.string], and a bare number keeps
///   [BeuiSyntaxPalette.number]. The keyword-set approach the other two used
///   painted `cd`/`echo`/`set` red mid-line and left real commands uncoloured.
///   Verified token-by-token against beui.dev's tool-approval and tool-result
///   previews.
/// * **generic (ts/tsx and the fallback)** — `code_block`'s, which is a strict
///   superset: it also closes on `/*` block-comment openers and starts a number
///   at a leading `.` (`.5`). `tool_result`'s did neither.
List<BeuiSyntaxToken> beuiHighlightLine(
  String line,
  BeuiCodeLanguage language,
  BeuiSyntaxPalette palette,
) {
  if (line.isEmpty) return const [];

  switch (language) {
    case BeuiCodeLanguage.text:
      return [BeuiSyntaxToken(line, palette.base)];
    case BeuiCodeLanguage.diff:
      return _highlightDiff(line, palette);
    case BeuiCodeLanguage.json:
      return _highlightJson(line, palette);
    case BeuiCodeLanguage.bash:
      return _highlightBash(line, palette);
    case BeuiCodeLanguage.typescript:
    case BeuiCodeLanguage.tsx:
      return _highlightGeneric(line, beuiTsKeywords, palette);
  }
}

/// U+2212 MINUS SIGN — the glyph `file_diff` uses for deletion counts.
const String _unicodeMinus = '−';

List<BeuiSyntaxToken> _highlightDiff(String line, BeuiSyntaxPalette palette) {
  if (line.startsWith('+') && !line.startsWith('+++')) {
    return [BeuiSyntaxToken(line, palette.diffAdd)];
  }
  if (line.startsWith('-') && !line.startsWith('---')) {
    return [BeuiSyntaxToken(line, palette.diffDel)];
  }
  if (line.startsWith(_unicodeMinus)) {
    return [BeuiSyntaxToken(line, palette.diffDel)];
  }
  if (line.startsWith('@@')) {
    return [BeuiSyntaxToken(line, palette.keyword)];
  }
  return [BeuiSyntaxToken(line, palette.base)];
}

List<BeuiSyntaxToken> _highlightJson(String line, BeuiSyntaxPalette palette) {
  final out = <BeuiSyntaxToken>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '"') {
      final end = _scanString(line, i);
      // Key vs value: a key is followed (after whitespace) by `:`.
      final isKey = line.substring(end).trimLeft().startsWith(':');
      out.add(
        BeuiSyntaxToken(
          line.substring(i, end),
          isKey ? palette.property : palette.string,
        ),
      );
      i = end;
      continue;
    }
    if (_isDigit(line.codeUnitAt(i)) ||
        (ch == '-' &&
            i + 1 < line.length &&
            _isDigit(line.codeUnitAt(i + 1)))) {
      final end = _scanNumber(line, i);
      out.add(BeuiSyntaxToken(line.substring(i, end), palette.number));
      i = end;
      continue;
    }
    if (_isIdentStart(line.codeUnitAt(i))) {
      final end = _scanIdent(line, i);
      final word = line.substring(i, end);
      final color = (word == 'true' || word == 'false' || word == 'null')
          ? palette.keyword
          : palette.base;
      out.add(BeuiSyntaxToken(word, color));
      i = end;
      continue;
    }
    out.add(BeuiSyntaxToken(ch, palette.punct));
    i++;
  }
  return out;
}

/// Shell lines, the way Shiki's bash grammar tokenises them under
/// `github-*-high-contrast`.
///
/// Note the positional rule: in `49 pass · 0 fail`, the leading `49` is the
/// command word and takes [BeuiSyntaxPalette.variable], while the later `0` is
/// an argument that happens to be numeric and takes
/// [BeuiSyntaxPalette.number]. That asymmetry is real, not a bug — it is what
/// beui.dev renders.
List<BeuiSyntaxToken> _highlightBash(String line, BeuiSyntaxPalette palette) {
  final out = <BeuiSyntaxToken>[];
  var i = 0;
  var first = true;
  while (i < line.length) {
    final ch = line[i];
    if (ch == ' ' || ch == '\t') {
      final start = i;
      while (i < line.length && (line[i] == ' ' || line[i] == '\t')) {
        i++;
      }
      out.add(BeuiSyntaxToken(line.substring(start, i), palette.base));
      continue;
    }
    if (ch == '#') {
      out.add(BeuiSyntaxToken(line.substring(i), palette.comment));
      break;
    }
    if (ch == "'" || ch == '"' || ch == '`') {
      final end = _scanString(line, i);
      out.add(BeuiSyntaxToken(line.substring(i, end), palette.string));
      i = end;
      first = false;
      continue;
    }
    final start = i;
    while (i < line.length &&
        line[i] != ' ' &&
        line[i] != '\t' &&
        line[i] != "'" &&
        line[i] != '"' &&
        line[i] != '`') {
      i++;
    }
    final word = line.substring(start, i);
    final Color color;
    if (first) {
      color = palette.variable;
    } else if (_isBareNumber(word)) {
      color = palette.number;
    } else {
      color = palette.string;
    }
    out.add(BeuiSyntaxToken(word, color));
    first = false;
  }
  return out;
}

/// True for a word made only of digits and `.` — Shiki's `constant.numeric`.
bool _isBareNumber(String word) {
  var sawDigit = false;
  for (var i = 0; i < word.length; i++) {
    if (_isDigit(word.codeUnitAt(i))) {
      sawDigit = true;
    } else if (word[i] != '.') {
      return false;
    }
  }
  return sawDigit;
}

List<BeuiSyntaxToken> _highlightGeneric(
  String line,
  Set<String> keywords,
  BeuiSyntaxPalette palette,
) {
  final out = <BeuiSyntaxToken>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];

    // Line comments.
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
      out.add(BeuiSyntaxToken(line.substring(i), palette.comment));
      break;
    }

    // Block comment open — colour rest of line (multi-line not tracked).
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '*') {
      out.add(BeuiSyntaxToken(line.substring(i), palette.comment));
      break;
    }

    // Strings: ' " `
    if (ch == "'" || ch == '"' || ch == '`') {
      final end = _scanString(line, i);
      out.add(BeuiSyntaxToken(line.substring(i, end), palette.string));
      i = end;
      continue;
    }

    // Numbers, including a leading `.` (`.5`).
    if (_isDigit(line.codeUnitAt(i)) ||
        (ch == '.' &&
            i + 1 < line.length &&
            _isDigit(line.codeUnitAt(i + 1)))) {
      final end = _scanNumber(line, i);
      out.add(BeuiSyntaxToken(line.substring(i, end), palette.number));
      i = end;
      continue;
    }

    // Identifiers / keywords.
    if (_isIdentStart(line.codeUnitAt(i)) || ch == r'$') {
      final end = _scanIdent(line, i);
      final word = line.substring(i, end);
      final color = keywords.contains(word)
          ? palette.keyword
          : _callsAhead(line, end)
          ? palette.entity
          : palette.base;
      out.add(BeuiSyntaxToken(word, color));
      i = end;
      continue;
    }

    // Punctuation / whitespace.
    out.add(
      BeuiSyntaxToken(ch, ch.trim().isEmpty ? palette.base : palette.punct),
    );
    i++;
  }
  return out;
}

/// True when the next non-space character after [end] opens a call — the
/// source's Shiki themes paint those identifiers with the `entity` colour.
bool _callsAhead(String line, int end) {
  var j = end;
  while (j < line.length && line[j] == ' ') {
    j++;
  }
  return j < line.length && line[j] == '(';
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isIdentStart(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F; // _

bool _isIdentPart(int c) => _isIdentStart(c) || _isDigit(c) || c == 0x24; // $

int _scanIdent(String s, int start) {
  var i = start + 1;
  while (i < s.length && _isIdentPart(s.codeUnitAt(i))) {
    i++;
  }
  return i;
}

int _scanNumber(String s, int start) {
  var i = start;
  if (s[i] == '-') i++;
  while (i < s.length &&
      (_isDigit(s.codeUnitAt(i)) ||
          s[i] == '.' ||
          s[i] == 'e' ||
          s[i] == 'E' ||
          s[i] == '+' ||
          s[i] == '-')) {
    // Keep simple — stop on non-number-ish after first char of exponent.
    if ((s[i] == '+' || s[i] == '-') &&
        i > start &&
        s[i - 1] != 'e' &&
        s[i - 1] != 'E') {
      break;
    }
    i++;
  }
  return i;
}

int _scanString(String s, int start) {
  final q = s[start];
  var i = start + 1;
  while (i < s.length) {
    if (s[i] == r'\' && i + 1 < s.length) {
      i += 2;
      continue;
    }
    if (s[i] == q) {
      return i + 1;
    }
    i++;
  }
  return s.length;
}
