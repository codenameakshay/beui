import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'action_swap.dart';
import 'code_block.dart' show BeuiCodeLanguage;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiToolResult] surface (source `ToolResultStatus`).
enum BeuiToolResultStatus {
  /// Tool is still executing; the viewport follows the live edge.
  running,

  /// Finished successfully.
  success,

  /// Finished with an error.
  error,

  /// Aborted / denied.
  cancelled,
}

/// Visual kind of a [BeuiToolResult] — picks the default leading icon
/// (source `ToolResultKind`).
enum BeuiToolResultKind {
  /// Shell / CLI output (square-terminal glyph).
  terminal,

  /// HTTP / API request-response (braces glyph).
  request,

  /// Generic tool (wrench glyph).
  custom,
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _disclosureOpen = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _disclosureClose = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);
const _spinPeriod = Duration(milliseconds: 900);

// Status palette — Tailwind blue / emerald / rose matching the source classes.
const _blue600 = Color(0xFF155DFC);
const _blue400 = Color(0xFF51A2FF);
const _emerald600 = Color(0xFF009966);
const _emerald400 = Color(0xFF00D492);
const _rose600 = Color(0xFFEC003F);
const _rose400 = Color(0xFFFF637E);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _statusLabel(BeuiToolResultStatus status) => switch (status) {
  BeuiToolResultStatus.running => 'Running',
  BeuiToolResultStatus.success => 'Completed',
  BeuiToolResultStatus.error => 'Failed',
  BeuiToolResultStatus.cancelled => 'Cancelled',
};

Color _statusColor(BeuiToolResultStatus status, bool isLight, BeuiColors c) =>
    switch (status) {
      BeuiToolResultStatus.running => isLight ? _blue600 : _blue400,
      BeuiToolResultStatus.success => isLight ? _emerald600 : _emerald400,
      BeuiToolResultStatus.error => isLight ? _rose600 : _rose400,
      BeuiToolResultStatus.cancelled => c.mutedForeground,
    };

IconData _kindIcon(BeuiToolResultKind kind) => switch (kind) {
  BeuiToolResultKind.terminal => LucideIcons.square_terminal,
  BeuiToolResultKind.request => LucideIcons.braces,
  BeuiToolResultKind.custom => LucideIcons.wrench,
};

IconData _statusIcon(BeuiToolResultStatus status) => switch (status) {
  BeuiToolResultStatus.running => LucideIcons.loader_circle,
  BeuiToolResultStatus.success => LucideIcons.circle_check,
  BeuiToolResultStatus.error => LucideIcons.circle_x,
  BeuiToolResultStatus.cancelled => LucideIcons.ban,
};

String _swapKey(Object? value, String fallback) {
  if (value is String || value is num) return value.toString();
  return fallback;
}

Widget _asWidget(Object value, {TextStyle? style, int? maxLines}) {
  if (value is Widget) return value;
  return Text(
    value.toString(),
    style: style,
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : null,
    softWrap: maxLines == null,
  );
}

// ---------------------------------------------------------------------------
// BeuiToolResultOutput
// ---------------------------------------------------------------------------

/// Syntax-tinted terminal / request body text for use inside [BeuiToolResult]
/// — the Flutter port of the source's `ToolResultOutput` (backed by
/// `AgentCode`).
///
/// Highlighting is a **reduced** port of the source's Shiki themes: a small
/// regex tokeniser paints keywords, strings, comments, and numbers. Full
/// Shiki fidelity is intentionally omitted (same approach as [BeuiCodeBlock]).
class BeuiToolResultOutput extends StatelessWidget {
  /// Creates a soft-wrapped mono output block.
  const BeuiToolResultOutput({
    required this.code,
    this.language = BeuiCodeLanguage.bash,
    super.key,
  });

  /// Source text to render.
  final String code;

  /// Language for the lightweight highlighter (source default `bash`).
  final BeuiCodeLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final palette = _OutputPalette.of(colors, theme.brightness);
    final lines = code.split('\n');

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.55,
        color: colors.foreground.withValues(alpha: 0.8),
      ),
      child: SelectionArea(
        child: Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                ..._highlightLine(lines[i], language, palette).map(
                  (t) => TextSpan(
                    text: t.text,
                    style: TextStyle(color: t.color),
                  ),
                ),
                if (i < lines.length - 1) const TextSpan(text: '\n'),
              ],
            ],
          ),
          softWrap: true,
        ),
      ),
    );
  }
}

@immutable
class _OutputPalette {
  const _OutputPalette({
    required this.base,
    required this.keyword,
    required this.property,
    required this.string,
    required this.comment,
    required this.number,
    required this.entity,
    required this.punct,
  });

  // Shiki `github-light-high-contrast` / `github-dark-high-contrast` — the
  // themes the source's AgentCode highlighter is created with
  // (agent-code.tsx LIGHT_THEME / DARK_THEME).
  factory _OutputPalette.of(BeuiColors colors, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return _OutputPalette(
      base: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
      keyword: isLight ? const Color(0xFFA0111F) : const Color(0xFFFF9492),
      // Shiki scopes a JSON property name as `support.type.property-name.json`,
      // which these themes paint green — NOT the red they use for keywords.
      property: isLight ? const Color(0xFF024C1A) : const Color(0xFF72F088),
      string: isLight ? const Color(0xFF032563) : const Color(0xFFADDCFF),
      comment: isLight ? const Color(0xFF4B535D) : const Color(0xFFBDC4CC),
      number: isLight ? const Color(0xFF023B95) : const Color(0xFF91CBFF),
      entity: isLight ? const Color(0xFF622CBC) : const Color(0xFFDBB7FF),
      punct: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
    );
  }

  final Color base;
  final Color keyword;
  final Color property;
  final Color string;
  final Color comment;
  final Color number;
  final Color entity;
  final Color punct;
}

@immutable
class _Tok {
  const _Tok(this.text, this.color);
  final String text;
  final Color color;
}

const _bashKw = <String>{
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

const _tsKw = <String>{
  'const',
  'let',
  'var',
  'function',
  'return',
  'import',
  'export',
  'from',
  'async',
  'await',
  'class',
  'interface',
  'type',
  'true',
  'false',
  'null',
  'undefined',
  'if',
  'else',
  'for',
  'while',
  'new',
  'typeof',
  'void',
};

List<_Tok> _highlightLine(
  String line,
  BeuiCodeLanguage language,
  _OutputPalette p,
) {
  if (line.isEmpty) return const [];
  if (language == BeuiCodeLanguage.text || language == BeuiCodeLanguage.diff) {
    return [_Tok(line, p.base)];
  }
  if (language == BeuiCodeLanguage.json) {
    return _hlJson(line, p);
  }
  final kw = switch (language) {
    BeuiCodeLanguage.bash => _bashKw,
    BeuiCodeLanguage.typescript || BeuiCodeLanguage.tsx => _tsKw,
    _ => const <String>{},
  };
  return _hlGeneric(line, kw, p, language);
}

List<_Tok> _hlJson(String line, _OutputPalette p) {
  final out = <_Tok>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '"') {
      final end = _scanStr(line, i);
      final after = line.substring(end).trimLeft();
      out.add(
        _Tok(
          line.substring(i, end),
          after.startsWith(':') ? p.property : p.string,
        ),
      );
      i = end;
      continue;
    }
    if (_isDigit(ch) ||
        (ch == '-' && i + 1 < line.length && _isDigit(line[i + 1]))) {
      final end = _scanNum(line, i);
      out.add(_Tok(line.substring(i, end), p.number));
      i = end;
      continue;
    }
    if (_isIdentStart(ch)) {
      final end = _scanIdent(line, i);
      final w = line.substring(i, end);
      out.add(
        _Tok(
          w,
          (w == 'true' || w == 'false' || w == 'null') ? p.keyword : p.base,
        ),
      );
      i = end;
      continue;
    }
    out.add(_Tok(ch, p.punct));
    i++;
  }
  return out;
}

List<_Tok> _hlGeneric(
  String line,
  Set<String> keywords,
  _OutputPalette p,
  BeuiCodeLanguage language,
) {
  final out = <_Tok>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
      out.add(_Tok(line.substring(i), p.comment));
      break;
    }
    if (language == BeuiCodeLanguage.bash && ch == '#') {
      out.add(_Tok(line.substring(i), p.comment));
      break;
    }
    if (ch == "'" || ch == '"' || ch == '`') {
      final end = _scanStr(line, i, quote: ch);
      out.add(_Tok(line.substring(i, end), p.string));
      i = end;
      continue;
    }
    if (_isDigit(ch)) {
      final end = _scanNum(line, i);
      out.add(_Tok(line.substring(i, end), p.number));
      i = end;
      continue;
    }
    if (_isIdentStart(ch) || ch == r'$') {
      final end = _scanIdent(line, i);
      final w = line.substring(i, end);
      out.add(
        _Tok(
          w,
          keywords.contains(w)
              ? p.keyword
              : _callsAhead(line, end)
              ? p.entity
              : p.base,
        ),
      );
      i = end;
      continue;
    }
    out.add(_Tok(ch, ch.trim().isEmpty ? p.base : p.punct));
    i++;
  }
  return out;
}

bool _isDigit(String ch) {
  final c = ch.codeUnitAt(0);
  return c >= 0x30 && c <= 0x39;
}

bool _isIdentStart(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;
}

bool _isIdentPart(String ch) {
  final c = ch.codeUnitAt(0);
  return _isIdentStart(ch) || _isDigit(ch) || c == 0x24;
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

int _scanIdent(String s, int start) {
  var i = start + 1;
  while (i < s.length && _isIdentPart(s[i])) {
    i++;
  }
  return i;
}

int _scanNum(String s, int start) {
  var i = start;
  if (s[i] == '-') i++;
  while (i < s.length &&
      (_isDigit(s[i]) || s[i] == '.' || s[i] == 'e' || s[i] == 'E')) {
    i++;
  }
  return i;
}

int _scanStr(String s, int start, {String? quote}) {
  final q = quote ?? s[start];
  var i = start + 1;
  while (i < s.length) {
    if (s[i] == r'\' && i + 1 < s.length) {
      i += 2;
      continue;
    }
    if (s[i] == q) return i + 1;
    i++;
  }
  return s.length;
}

// ---------------------------------------------------------------------------
// BeuiToolResult
// ---------------------------------------------------------------------------

/// A lightweight execution disclosure for terminal output / request responses
/// that collapses into a compact completed state — the Flutter port of beUI's
/// `tool-result`.
///
/// **Layout.** A header row (kind icon · title · meta · tool · status · chevron)
/// toggles an [AgentDisclosure]-style panel. The body is a capped, scrollable
/// viewport (follows the live edge while [status] is
/// [BeuiToolResultStatus.running]) with optional copy / retry chrome.
///
/// **Open state.** Controlled when [open] is non-null (drive via [onOpenChange]);
/// otherwise internal state seeded by [defaultOpen]. Entering `running` expands;
/// leaving `running` collapses when [collapseOnComplete] is true.
///
/// **Motion.** Chevron rotates on [beuiSpringSwap]; status / title / meta / tool
/// labels roll via [BeuiActionSwapText]; action buttons press-scale on
/// [beuiSpringPress]; disclosure opens in 220ms / closes in 140ms [beuiEaseOut].
/// Reduced motion drops movement (scale, translate, spin, chevron rotate) while
/// keeping opacity / color swaps.
///
/// **API mapping** (source → Flutter):
/// * `tool` / `title` / `meta` → [tool] / [title] / [meta] (`String` or [Widget])
/// * `status` / `kind` / `icon` → [status] / [kind] / [icon]
/// * `open` / `defaultOpen` / `onOpenChange` → same
/// * `collapseOnComplete` / `maxHeight` / `copyText` / `onCopy` / `onRetry` → same
/// * `children` → [child]
class BeuiToolResult extends StatefulWidget {
  /// Creates a tool-result disclosure.
  const BeuiToolResult({
    required this.tool,
    required this.title,
    required this.child,
    this.status = BeuiToolResultStatus.running,
    this.kind = BeuiToolResultKind.custom,
    this.meta,
    this.icon,
    this.open,
    this.defaultOpen = true,
    this.onOpenChange,
    this.collapseOnComplete = true,
    this.maxHeight = 220,
    this.copyText,
    this.onCopy,
    this.onRetry,
    super.key,
  });

  /// Tool slug shown mono on the right of the title cluster (e.g.
  /// `terminal.run`). Accepts a [String] or any [Widget].
  final Object tool;

  /// Primary header label. Accepts a [String] or any [Widget].
  final Object title;

  /// Body content — typically [BeuiToolResultOutput] or custom widgets.
  final Widget child;

  /// Execution lifecycle (source `status`, default `running`).
  final BeuiToolResultStatus status;

  /// Kind icon when [icon] is null (source `kind`, default `custom`).
  final BeuiToolResultKind kind;

  /// Compact trailing metadata next to the title (e.g. `"2.9s"`, `"429"`).
  /// Accepts a [String] or any [Widget].
  final Object? meta;

  /// Optional leading icon override (source `icon`). Defaults to a kind glyph.
  final Widget? icon;

  /// Controlled open state. When non-null, the widget does not hold internal
  /// open state (source `open`).
  final bool? open;

  /// Initial open state when uncontrolled (source `defaultOpen`, default true).
  final bool defaultOpen;

  /// Fired whenever open toggles (source `onOpenChange`).
  final ValueChanged<bool>? onOpenChange;

  /// Collapse the panel when status leaves `running` (source
  /// `collapseOnComplete`, default true).
  final bool collapseOnComplete;

  /// Max viewport height in logical pixels (source `maxHeight`, default 220).
  final double maxHeight;

  /// Text written to the clipboard by the copy action (source `copyText`).
  final String? copyText;

  /// Optional override for the copy action (source `onCopy`). When null and
  /// [copyText] is set, the default is a clipboard write of [copyText].
  final FutureOr<void> Function()? onCopy;

  /// Optional retry handler — shows a "Run again" action (source `onRetry`).
  final VoidCallback? onRetry;

  @override
  State<BeuiToolResult> createState() => _BeuiToolResultState();
}

class _BeuiToolResultState extends State<BeuiToolResult>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late bool _internalOpen;
  bool _copied = false;
  bool _copyHovered = false;
  bool _retryHovered = false;
  bool _copyPressed = false;
  bool _retryPressed = false;
  Timer? _copyTimer;
  late BeuiToolResultStatus _previousStatus;
  late final AnimationController _spin;

  bool get _running => widget.status == BeuiToolResultStatus.running;
  bool get _currentOpen => widget.open ?? _internalOpen;
  bool get _canCopy => widget.copyText != null || widget.onCopy != null;

  @override
  void initState() {
    super.initState();
    _internalOpen = widget.defaultOpen;
    _previousStatus = widget.status;
    _spin = AnimationController(vsync: this, duration: _spinPeriod);
    if (_running) {
      _spin.repeat();
      _scheduleFollow();
    }
  }

  @override
  void didUpdateWidget(covariant BeuiToolResult oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Status transitions drive open/collapse (source useEffect on status).
    if (widget.status != _previousStatus) {
      if (_previousStatus != BeuiToolResultStatus.running &&
          widget.status == BeuiToolResultStatus.running) {
        _setOpen(true);
      }
      if (_previousStatus == BeuiToolResultStatus.running &&
          widget.status != BeuiToolResultStatus.running &&
          widget.collapseOnComplete) {
        _setOpen(false);
      }
      _previousStatus = widget.status;
    }

    final wasRunning = oldWidget.status == BeuiToolResultStatus.running;
    if (_running != wasRunning) {
      if (_running) {
        _spin.repeat();
      } else {
        _spin
          ..stop()
          ..value = 0;
      }
    }
    if (_running &&
        _currentOpen &&
        (widget.child != oldWidget.child ||
            widget.status != oldWidget.status)) {
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

  void _setOpen(bool next) {
    if (widget.open == null && _internalOpen != next) {
      setState(() => _internalOpen = next);
    }
    widget.onOpenChange?.call(next);
  }

  void _toggle() => _setOpen(!_currentOpen);

  void _scheduleFollow() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_currentOpen || !_running) {
        return;
      }
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
    } else if (widget.copyText != null) {
      await Clipboard.setData(ClipboardData(text: widget.copyText!));
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isLight = theme.brightness == Brightness.light;
    final statusColor = _statusColor(widget.status, isLight, colors);
    final statusLabel = _statusLabel(widget.status);
    final titleKey = _swapKey(widget.title, widget.status.name);
    final metaKey = _swapKey(widget.meta, '${widget.status.name}-meta');
    final toolKey = _swapKey(widget.tool, '${widget.status.name}-tool');

    return Semantics(
      container: true,
      liveRegion: _running,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ----- header trigger -----
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: Center(
                            child:
                                widget.icon ??
                                Icon(
                                  _kindIcon(widget.kind),
                                  size: 16,
                                  color: colors.mutedForeground,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: widget.title is String
                                    ? BeuiActionSwapText(
                                        value: titleKey,
                                        text: widget.title as String,
                                        variant: BeuiActionSwapVariant.roll,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: colors.foreground.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      )
                                    : DefaultTextStyle.merge(
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: colors.foreground.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                        child: _asWidget(widget.title),
                                      ),
                              ),
                              if (widget.meta != null) ...[
                                const SizedBox(width: 8),
                                widget.meta is String
                                    ? BeuiActionSwapText(
                                        value: metaKey,
                                        text: widget.meta as String,
                                        variant: BeuiActionSwapVariant.roll,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.mutedForeground
                                              .withValues(alpha: 0.6),
                                        ),
                                      )
                                    : DefaultTextStyle.merge(
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.mutedForeground
                                              .withValues(alpha: 0.6),
                                        ),
                                        child: _asWidget(widget.meta!),
                                      ),
                              ],
                              const SizedBox(width: 8),
                              Flexible(
                                child: widget.tool is String
                                    ? BeuiActionSwapText(
                                        value: toolKey,
                                        text: widget.tool as String,
                                        variant: BeuiActionSwapVariant.roll,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: colors.mutedForeground
                                              .withValues(alpha: 0.55),
                                        ),
                                      )
                                    : DefaultTextStyle.merge(
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: colors.mutedForeground
                                              .withValues(alpha: 0.55),
                                        ),
                                        child: _asWidget(widget.tool),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status chip
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusGlyph(
                              status: widget.status,
                              color: statusColor,
                              reduce: reduce,
                              spin: _spin,
                            ),
                            const SizedBox(width: 4),
                            BeuiActionSwapText(
                              value: widget.status.name,
                              text: statusLabel,
                              variant: BeuiActionSwapVariant.roll,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8), // gap-2
                        _Chevron(
                          open: _currentOpen,
                          reduce: reduce,
                          color: colors.mutedForeground.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ----- disclosure body -----
            _AgentDisclosure(
              open: _currentOpen,
              reduce: reduce,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: widget.maxHeight,
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(
                            context,
                          ).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            child: widget.child,
                          ),
                        ),
                      ),
                      if (_canCopy || widget.onRetry != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                          child: Row(
                            children: [
                              if (_canCopy)
                                _ActionButton(
                                  label: _copied ? 'Copied' : 'Copy result',
                                  pressed: _copyPressed,
                                  hovered: _copyHovered,
                                  reduce: reduce,
                                  colors: colors,
                                  onHover: (h) =>
                                      setState(() => _copyHovered = h),
                                  onPressed: (p) =>
                                      setState(() => _copyPressed = p),
                                  onTap: _handleCopy,
                                  child: Icon(
                                    _copied
                                        ? LucideIcons.check
                                        : LucideIcons.copy,
                                    size: 14,
                                    color: _copyHovered
                                        ? colors.foreground
                                        : colors.mutedForeground,
                                  ),
                                ),
                              if (widget.onRetry != null)
                                _ActionButton(
                                  label: 'Run again',
                                  pressed: _retryPressed,
                                  hovered: _retryHovered,
                                  reduce: reduce,
                                  colors: colors,
                                  onHover: (h) =>
                                      setState(() => _retryHovered = h),
                                  onPressed: (p) =>
                                      setState(() => _retryPressed = p),
                                  onTap: widget.onRetry!,
                                  child: Icon(
                                    LucideIcons.rotate_ccw,
                                    size: 14,
                                    color: _retryHovered
                                        ? colors.foreground
                                        : colors.mutedForeground,
                                  ),
                                ),
                              const Spacer(),
                              BeuiActionSwapText(
                                value: widget.status.name,
                                text: statusLabel,
                                variant: BeuiActionSwapVariant.roll,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.mutedForeground.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.status,
    required this.color,
    required this.reduce,
    required this.spin,
  });

  final BeuiToolResultStatus status;
  final Color color;
  final bool reduce;
  final AnimationController spin;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_statusIcon(status), size: 12, color: color);
    if (status == BeuiToolResultStatus.running && !reduce) {
      return RotationTransition(turns: spin, child: icon);
    }
    return icon;
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.open,
    required this.reduce,
    required this.color,
  });

  final bool open;
  final bool reduce;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(LucideIcons.chevron_down, size: 14, color: color);
    if (reduce) {
      return Transform.rotate(angle: open ? math.pi : 0, child: icon);
    }
    return SingleMotionBuilder(
      value: open ? 180.0 : 0.0,
      motion: motionFor(context, beuiSpringSwap, isMovement: true),
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180.0, child: child),
      child: icon,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.pressed,
    required this.hovered,
    required this.reduce,
    required this.colors,
    required this.onHover,
    required this.onPressed,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool pressed;
  final bool hovered;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onPressed;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pressTarget = (pressed && !reduce) ? 0.9 : 1.0;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHover(true),
          onExit: (_) {
            onHover(false);
            onPressed(false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => onPressed(true),
            onTapUp: (_) => onPressed(false),
            onTapCancel: () => onPressed(false),
            onTap: onTap,
            child: SingleMotionBuilder(
              value: pressTarget,
              motion: motionFor(context, beuiSpringPress, isMovement: true),
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered ? colors.muted : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared transform-only reveal for collapsible agent content — the Flutter
/// port of the source's `AgentDisclosure` (height + opacity + y: -4).
class _AgentDisclosure extends StatelessWidget {
  const _AgentDisclosure({
    required this.open,
    required this.reduce,
    required this.child,
  });

  final bool open;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = open ? 1.0 : 0.0;
    final motion = open ? _disclosureOpen : _disclosureClose;

    if (reduce) {
      return Offstage(
        offstage: !open,
        child: IgnorePointer(
          ignoring: !open,
          child: ExcludeSemantics(
            excluding: !open,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: open ? 1.0 : 0.0,
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, motion, isMovement: true),
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        final closed = tt < 0.01;
        return Offstage(
          offstage: closed,
          child: IgnorePointer(
            ignoring: closed,
            child: ExcludeSemantics(
              excluding: closed,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: tt,
                  child: Opacity(
                    opacity: tt,
                    child: Transform.translate(
                      offset: Offset(0, -4 * (1 - tt)),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
