import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_syntax.dart';

// `BeuiCodeLanguage` moved to `_syntax.dart` — the language enum belongs with
// the tokenizer, and keeping it here forced an import cycle once the shared
// highlighter landed. Re-exported so the public API is unchanged: consumers
// and the barrel still see it on this library.
export '_syntax.dart' show BeuiCodeLanguage;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiCodeBlock] surface (source `CodeBlockStatus`).
enum BeuiCodeBlockStatus {
  /// Content is still being written; the viewport follows the live edge.
  streaming,

  /// Stream finished — shows the ready checkmark.
  complete,
}

// ---------------------------------------------------------------------------
// Highlight palette (reduced Shiki substitute)
// ---------------------------------------------------------------------------

/// Colours used by the lightweight tokeniser. Tuned to read like a soft
/// github-light / github-dark contrast theme against [BeuiColors].
@immutable
class _CodePalette {
  const _CodePalette({
    required this.base,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.entity,
    required this.punct,
    required this.diffAdd,
    required this.diffDel,
  });

  // Shiki `github-light-high-contrast` / `github-dark-high-contrast` — the
  // themes the source's AgentCode highlighter is created with
  // (agent-code.tsx LIGHT_THEME / DARK_THEME).
  factory _CodePalette.of(BeuiColors colors, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return _CodePalette(
      base: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
      keyword: isLight ? const Color(0xFFA0111F) : const Color(0xFFFF9492),
      string: isLight ? const Color(0xFF032563) : const Color(0xFFADDCFF),
      comment: isLight ? const Color(0xFF4B535D) : const Color(0xFFBDC4CC),
      number: isLight ? const Color(0xFF023B95) : const Color(0xFF91CBFF),
      entity: isLight ? const Color(0xFF622CBC) : const Color(0xFFDBB7FF),
      punct: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
      diffAdd: isLight ? const Color(0xFF055D20) : const Color(0xFF26CD4D),
      diffDel: isLight ? const Color(0xFFA0111F) : const Color(0xFFFF9492),
    );
  }

  final Color base;
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color entity;
  final Color punct;
  final Color diffAdd;
  final Color diffDel;
}

// ---------------------------------------------------------------------------
// Lightweight tokeniser
// ---------------------------------------------------------------------------

/// A single coloured span inside a code line.
@immutable
class _CodeToken {
  const _CodeToken(this.text, this.color);
  final String text;
  final Color color;
}

/// Keywords shared by TypeScript / TSX.
const _tsKeywords = <String>{
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

const _bashKeywords = <String>{
  'if',
  'then',
  'else',
  'elif',
  'fi',
  'for',
  'while',
  'do',
  'done',
  'case',
  'esac',
  'function',
  'in',
  'return',
  'export',
  'local',
  'readonly',
  'source',
  'alias',
  'cd',
  'echo',
  'exit',
  'set',
  'unset',
  'true',
  'false',
};

/// Tokenise [line] for [language] using a small regex pass.
///
/// Reduced highlighting — not a full lexer. Comments, strings, numbers, and a
/// keyword set are coloured; everything else stays [palette.base].
List<_CodeToken> _highlightLine(
  String line,
  BeuiCodeLanguage language,
  _CodePalette palette,
) {
  if (line.isEmpty) return const [];
  if (language == BeuiCodeLanguage.text) {
    return [_CodeToken(line, palette.base)];
  }

  if (language == BeuiCodeLanguage.diff) {
    if (line.startsWith('+') && !line.startsWith('+++')) {
      return [_CodeToken(line, palette.diffAdd)];
    }
    if (line.startsWith('-') && !line.startsWith('---')) {
      return [_CodeToken(line, palette.diffDel)];
    }
    if (line.startsWith('@@')) {
      return [_CodeToken(line, palette.keyword)];
    }
    return [_CodeToken(line, palette.base)];
  }

  if (language == BeuiCodeLanguage.json) {
    return _highlightJson(line, palette);
  }

  final keywords = switch (language) {
    BeuiCodeLanguage.bash => _bashKeywords,
    BeuiCodeLanguage.typescript || BeuiCodeLanguage.tsx => _tsKeywords,
    _ => const <String>{},
  };

  return _highlightGeneric(line, keywords, palette, language);
}

List<_CodeToken> _highlightJson(String line, _CodePalette palette) {
  final out = <_CodeToken>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '"') {
      final end = _scanString(line, i);
      final slice = line.substring(i, end);
      // Key vs value: a key is followed (after whitespace) by `:`.
      final after = line.substring(end).trimLeft();
      final isKey = after.startsWith(':');
      // github-*-high-contrast paints JSON property names with the constant
      // colour, not the keyword colour.
      out.add(_CodeToken(slice, isKey ? palette.number : palette.string));
      i = end;
      continue;
    }
    if (_isDigit(ch) ||
        (ch == '-' && i + 1 < line.length && _isDigit(line[i + 1]))) {
      final end = _scanNumber(line, i);
      out.add(_CodeToken(line.substring(i, end), palette.number));
      i = end;
      continue;
    }
    if (_isIdentStart(ch)) {
      final end = _scanIdent(line, i);
      final word = line.substring(i, end);
      final color = (word == 'true' || word == 'false' || word == 'null')
          ? palette.keyword
          : palette.base;
      out.add(_CodeToken(word, color));
      i = end;
      continue;
    }
    out.add(_CodeToken(ch, palette.punct));
    i++;
  }
  return out;
}

List<_CodeToken> _highlightGeneric(
  String line,
  Set<String> keywords,
  _CodePalette palette,
  BeuiCodeLanguage language,
) {
  final out = <_CodeToken>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];

    // Line comments
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
      out.add(_CodeToken(line.substring(i), palette.comment));
      break;
    }
    if (language == BeuiCodeLanguage.bash && ch == '#') {
      out.add(_CodeToken(line.substring(i), palette.comment));
      break;
    }

    // Block comment open — colour rest of line (multi-line not tracked).
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '*') {
      out.add(_CodeToken(line.substring(i), palette.comment));
      break;
    }

    // Strings: ' " `
    if (ch == "'" || ch == '"' || ch == '`') {
      final end = _scanString(line, i, quote: ch);
      out.add(_CodeToken(line.substring(i, end), palette.string));
      i = end;
      continue;
    }

    // Numbers
    if (_isDigit(ch) ||
        (ch == '.' && i + 1 < line.length && _isDigit(line[i + 1]))) {
      final end = _scanNumber(line, i);
      out.add(_CodeToken(line.substring(i, end), palette.number));
      i = end;
      continue;
    }

    // Identifiers / keywords
    if (_isIdentStart(ch) || ch == r'$') {
      final end = _scanIdent(line, i);
      final word = line.substring(i, end);
      final color = keywords.contains(word)
          ? palette.keyword
          : _callsAhead(line, end)
          ? palette.entity
          : palette.base;
      out.add(_CodeToken(word, color));
      i = end;
      continue;
    }

    // Punctuation / whitespace
    final color = ch.trim().isEmpty ? palette.base : palette.punct;
    out.add(_CodeToken(ch, color));
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

bool _isDigit(String ch) =>
    ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

bool _isIdentStart(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F; // _
}

bool _isIdentPart(String ch) {
  final c = ch.codeUnitAt(0);
  return _isIdentStart(ch) || _isDigit(ch) || c == 0x24; // $
}

int _scanIdent(String s, int start) {
  var i = start + 1;
  while (i < s.length && _isIdentPart(s[i])) {
    i++;
  }
  return i;
}

int _scanNumber(String s, int start) {
  var i = start;
  if (s[i] == '-') i++;
  while (i < s.length &&
      (_isDigit(s[i]) ||
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

int _scanString(String s, int start, {String? quote}) {
  final q = quote ?? s[start];
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

// ---------------------------------------------------------------------------
// BeuiCodeBlock
// ---------------------------------------------------------------------------

/// A syntax-highlighted code surface with stable streaming updates, line
/// numbers, focused lines, smooth following, and copy feedback — the Flutter
/// port of beUI's agent `CodeBlock`.
///
/// **Highlighting.** The source uses Shiki (`github-light/dark-high-contrast`).
/// This port uses a lightweight [TextSpan] tokeniser for keywords, strings,
/// comments, and numbers so the package stays free of heavy highlighting
/// dependencies. Visual fidelity is reduced relative to Shiki; structure
/// (chrome, streaming follow, focus lines, copy feedback) matches the source.
///
/// **Motion.** Copy-button press scales to 0.9 on [beuiSpringPress]. While
/// [BeuiCodeBlockStatus.streaming], the viewport auto-scrolls to the live edge
/// (smooth when animations are enabled, jump when reduced motion is on). The
/// loader icon spins while writing.
///
/// **API mapping** (source → Flutter):
/// * `code` → [code]
/// * `language` → [language] ([BeuiCodeLanguage])
/// * `filename` → [filename] ([String] or [Widget])
/// * `status` → [status]
/// * `showLineNumbers` / `highlightLines` / `maxHeight` / `wrap` / `copyable` → same
/// * `onCopy` → [onCopy]
class BeuiCodeBlock extends StatefulWidget {
  /// Creates a code block surface.
  const BeuiCodeBlock({
    required this.code,
    this.language = BeuiCodeLanguage.typescript,
    this.filename,
    this.status = BeuiCodeBlockStatus.complete,
    this.showLineNumbers = true,
    this.highlightLines = const [],
    this.maxHeight = 280,
    this.wrap = false,
    this.copyable = true,
    this.onCopy,
    super.key,
  });

  /// Full source text rendered inside the block.
  final String code;

  /// Language label + highlighter (source `language`, default `typescript`).
  final BeuiCodeLanguage language;

  /// Optional filename shown in the chrome bar. Accepts a [String] or any
  /// [Widget] (source `filename?: ReactNode`).
  final Object? filename;

  /// Streaming vs complete chrome (source `status`, default `complete`).
  final BeuiCodeBlockStatus status;

  /// Whether to paint 1-based line numbers in a gutter (default `true`).
  final bool showLineNumbers;

  /// 1-based line numbers to soft-highlight (source `highlightLines`).
  final List<int> highlightLines;

  /// Max viewport height in logical pixels (source `maxHeight`, default 280).
  final double maxHeight;

  /// Soft-wrap long lines instead of horizontal scroll (source `wrap`).
  final bool wrap;

  /// Show the copy button (source `copyable`, default `true`). Still shown when
  /// [onCopy] is non-null even if this is false — matching the source
  /// `copyable || onCopy` gate.
  final bool copyable;

  /// Optional override for the copy action. Defaults to clipboard write of
  /// [code]. Called before the copied checkmark feedback.
  final FutureOr<void> Function()? onCopy;

  @override
  State<BeuiCodeBlock> createState() => _BeuiCodeBlockState();
}

class _BeuiCodeBlockState extends State<BeuiCodeBlock>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  bool _copied = false;
  bool _copyHovered = false;
  bool _copyPressed = false;
  Timer? _copyTimer;
  late final AnimationController _spin;

  bool get _streaming => widget.status == BeuiCodeBlockStatus.streaming;
  bool get _showCopy => widget.copyable || widget.onCopy != null;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (_streaming) {
      _spin.repeat();
      _scheduleFollow();
    }
  }

  @override
  void didUpdateWidget(covariant BeuiCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_streaming != (oldWidget.status == BeuiCodeBlockStatus.streaming)) {
      if (_streaming) {
        _spin.repeat();
      } else {
        _spin
          ..stop()
          ..value = 0;
      }
    }
    if (_streaming &&
        (widget.code != oldWidget.code || widget.status != oldWidget.status)) {
      _scheduleFollow();
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _scroll.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _scheduleFollow() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return;
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _scroll.jumpTo(max);
      } else {
        _scroll.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: beuiEaseOut,
        );
      }
    });
  }

  Future<void> _handleCopy() async {
    final custom = widget.onCopy;
    if (custom != null) {
      await custom();
    } else {
      await Clipboard.setData(ClipboardData(text: widget.code));
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final palette = _CodePalette.of(colors, theme.brightness);
    final highlight = widget.highlightLines.toSet();

    final lines = widget.code.split('\n');
    // Preserve trailing empty line behaviour of split — matches source.

    // Status chrome colours: blue while writing, emerald when ready.
    const writingBlue = Color(0xFF155DFC); // blue-600
    const writingBlueDark = Color(0xFF51A2FF); // blue-400
    const readyGreen = Color(0xFF009966); // emerald-600
    const readyGreenDark = Color(0xFF00D492); // emerald-400
    final isLight = theme.brightness == Brightness.light;
    final statusColor = _streaming
        ? (isLight ? writingBlue : writingBlueDark)
        : (isLight ? readyGreen : readyGreenDark);

    final pressTarget = (_copyPressed && !reduce) ? 0.9 : 1.0;

    return Semantics(
      container: true,
      liveRegion: _streaming,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.8),
          borderRadius: agent.shapes.card, // rounded-2xl
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ----- chrome bar -----
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      agent.icons.file,
                      size: 14,
                      color: colors.mutedForeground.withValues(alpha: 0.7),
                    ),
                    if (widget.filename != null) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontFamilyFallback: const [
                              'Menlo',
                              'Monaco',
                              'Consolas',
                              'Courier New',
                            ],
                            fontSize: 12,
                            // Tailwind `tracking-normal`. Explicit because an
                            // unset letterSpacing inherits Material's body
                            // styles (0.25), widening every mono line.
                            letterSpacing: 0,
                            color: colors.foreground.withValues(alpha: 0.8),
                            height: 16 / 12, // text-xs default leading-4
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          child: widget.filename is Widget
                              ? widget.filename! as Widget
                              : Text(widget.filename.toString()),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Text(
                      widget.language.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.25, // tracking-wide (0.025em @ 10px)
                        color: colors.mutedForeground.withValues(alpha: 0.55),
                      ),
                    ),
                    const Spacer(),
                    _StatusIcon(
                      streaming: _streaming,
                      reduce: reduce,
                      color: statusColor,
                      spin: _spin,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _streaming ? 'Writing' : 'Ready',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0, // tracking-normal
                        color: statusColor,
                      ),
                    ),
                    if (_showCopy) ...[
                      const SizedBox(width: 10), // gap-2.5
                      Semantics(
                        button: true,
                        label: _copied ? 'Copied' : 'Copy code',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _copyHovered = true),
                          onExit: (_) => setState(() {
                            _copyHovered = false;
                            _copyPressed = false;
                          }),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) =>
                                setState(() => _copyPressed = true),
                            onTapUp: (_) =>
                                setState(() => _copyPressed = false),
                            onTapCancel: () =>
                                setState(() => _copyPressed = false),
                            onTap: _handleCopy,
                            child: SingleMotionBuilder(
                              value: pressTarget,
                              motion: beuiSpringPress,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _copyHovered
                                      ? colors.background.withValues(alpha: 0.7)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _copied
                                      ? agent.icons.copied
                                      : agent.icons.copy,
                                  size: 14,
                                  color: _copyHovered
                                      ? colors.foreground
                                      : colors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ----- code viewport -----
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.foreground.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    // Horizontal scroll when not wrapping.
                    scrollDirection: Axis.vertical,
                    child: widget.wrap
                        ? _CodeLines(
                            lines: lines,
                            language: widget.language,
                            palette: palette,
                            colors: colors,
                            showLineNumbers: widget.showLineNumbers,
                            highlight: highlight,
                            wrap: true,
                          )
                        // source `pre` is `min-w-max` inside the scroller, so
                        // every line row is at least as wide as the viewport
                        // and the highlight band fills the whole row.
                        : LayoutBuilder(
                            builder: (context, viewport) =>
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: viewport.maxWidth,
                                    ),
                                    child: IntrinsicWidth(
                                      child: _CodeLines(
                                        lines: lines,
                                        language: widget.language,
                                        palette: palette,
                                        colors: colors,
                                        showLineNumbers: widget.showLineNumbers,
                                        highlight: highlight,
                                        wrap: false,
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.streaming,
    required this.reduce,
    required this.color,
    required this.spin,
  });

  final bool streaming;
  final bool reduce;
  final Color color;
  final AnimationController spin;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      streaming ? LucideIcons.loader_circle : LucideIcons.check,
      size: 12,
      color: color,
    );
    if (!streaming || reduce) return icon;
    return RotationTransition(turns: spin, child: icon);
  }
}

// ---------------------------------------------------------------------------
// Line list
// ---------------------------------------------------------------------------

class _CodeLines extends StatelessWidget {
  const _CodeLines({
    required this.lines,
    required this.language,
    required this.palette,
    required this.colors,
    required this.showLineNumbers,
    required this.highlight,
    required this.wrap,
  });

  final List<String> lines;
  final BeuiCodeLanguage language;
  final _CodePalette palette;
  final BeuiColors colors;
  final bool showLineNumbers;
  final Set<int> highlight;
  final bool wrap;

  static const _gutterWidth = 44.0; // ~2.75rem
  static const _lineHeight = 20.0; // leading-5
  static const _fontSize = 12.0; // text-xs

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const [
        'Menlo',
        'Monaco',
        'Consolas',
        'Courier New',
        'monospace',
      ],
      fontSize: _fontSize,
      // Tailwind `tracking-normal`; see the filename style for why.
      letterSpacing: 0,
      height: _lineHeight / _fontSize,
      color: palette.base,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++)
          _CodeLineRow(
            lineNumber: i + 1,
            content: lines[i],
            tokens: _highlightLine(lines[i], language, palette),
            showLineNumbers: showLineNumbers,
            highlighted: highlight.contains(i + 1),
            wrap: wrap,
            colors: colors,
            baseStyle: baseStyle,
            highlightFill: const Color(0xFF2B7FFF).withValues(alpha: 0.07),
          ),
      ],
    );
  }
}

class _CodeLineRow extends StatelessWidget {
  const _CodeLineRow({
    required this.lineNumber,
    required this.content,
    required this.tokens,
    required this.showLineNumbers,
    required this.highlighted,
    required this.wrap,
    required this.colors,
    required this.baseStyle,
    required this.highlightFill,
  });

  final int lineNumber;
  final String content;
  final List<_CodeToken> tokens;
  final bool showLineNumbers;
  final bool highlighted;
  final bool wrap;
  final BeuiColors colors;
  final TextStyle baseStyle;
  final Color highlightFill;

  @override
  Widget build(BuildContext context) {
    final spans = tokens.isEmpty
        ? <InlineSpan>[TextSpan(text: content.isEmpty ? ' ' : content)]
        : [
            for (final t in tokens)
              TextSpan(
                text: t.text,
                style: TextStyle(color: t.color),
              ),
          ];

    final code = Text.rich(
      TextSpan(style: baseStyle, children: spans),
      softWrap: wrap,
      overflow: wrap ? TextOverflow.visible : TextOverflow.clip,
    );

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: wrap ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (showLineNumbers)
            SizedBox(
              width: _CodeLines._gutterWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$lineNumber',
                  textAlign: TextAlign.right,
                  style: baseStyle.copyWith(
                    color: colors.mutedForeground.withValues(alpha: 0.35),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          if (wrap)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: showLineNumbers ? 4 : 16,
                  right: 16,
                ),
                child: code,
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(
                left: showLineNumbers ? 4 : 16,
                right: 16,
              ),
              child: code,
            ),
        ],
      ),
    );

    if (!highlighted) return row;

    return ColoredBox(color: highlightFill, child: row);
  }
}
