import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
import '_syntax.dart';
import '_viewport_follow.dart';

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
// BeuiCodeBlock
// ---------------------------------------------------------------------------

/// A syntax-highlighted code surface with stable streaming updates, line
/// numbers, focused lines, smooth following, and copy feedback — the Flutter
/// port of beUI's agent `CodeBlock`.
///
/// **Highlighting.** The source uses Shiki (`github-light/dark-high-contrast`).
/// This port uses the shared lightweight tokeniser in `_syntax.dart` (keywords,
/// strings, comments, numbers) so the package stays free of heavy highlighting
/// dependencies. Visual fidelity is reduced relative to Shiki; structure
/// (chrome, streaming follow, focus lines, copy feedback) matches the source.
///
/// **Motion.** Copy-button press scales to 0.97 on [beuiSpringPress] — the
/// library's single press token, which this widget used to undercut at 0.9.
/// While [BeuiCodeBlockStatus.streaming], the viewport follows the live edge
/// *until the reader scrolls away from it*, at which point following stops and
/// a "Jump to latest" pill appears. The loader icon spins while writing.
///
/// **Hidden content.** The viewport caps at [maxHeight] with scrollbars off, to
/// match the source. A bottom fade plus an "N more lines" count make the
/// remainder discoverable rather than silently clipped.
///
/// **API mapping** (source → Flutter):
/// * `code` → [code]
/// * `language` → [language] ([BeuiCodeLanguage])
/// * `filename` → [filename] ([String]) / [filenameWidget] ([Widget])
/// * `status` → [status]
/// * `showLineNumbers` / `highlightLines` / `maxHeight` / `wrap` / `copyable` → same
/// * `onCopy` → [onCopy]
class BeuiCodeBlock extends StatefulWidget {
  /// Creates a code block surface.
  const BeuiCodeBlock({
    required this.code,
    this.language = BeuiCodeLanguage.typescript,
    this.filename,
    this.filenameWidget,
    @Deprecated(
      'Split into filename (String) and filenameWidget (Widget) so the '
      'compiler can reject filename: 42. Pass one of those instead.',
    )
    this.filenameNode,
    this.status = BeuiCodeBlockStatus.complete,
    this.showLineNumbers = true,
    this.highlightLines = const [],
    this.maxHeight = 280,
    this.wrap = false,
    this.copyable = true,
    this.onCopy,
    this.emptyPlaceholder,
    super.key,
  });

  /// Full source text rendered inside the block.
  final String code;

  /// Language label + highlighter (source `language`, default `typescript`).
  final BeuiCodeLanguage language;

  /// Optional filename shown in the chrome bar, as plain text.
  ///
  /// Narrowed from the old `Object?`: the untyped slot accepted `filename: 42`
  /// and rendered `"42"`. Pass a widget through [filenameWidget] instead.
  final String? filename;

  /// Optional filename shown in the chrome bar, as an arbitrary widget
  /// (source `filename?: ReactNode`). Wins over [filename] when both are set.
  final Widget? filenameWidget;

  /// Deprecated untyped filename slot, kept so existing call sites compile.
  ///
  /// A [String] renders as text, a [Widget] renders as-is, and anything else
  /// falls back to `toString()` — the old behaviour, bug included.
  @Deprecated(
    'Split into filename (String) and filenameWidget (Widget) so the '
    'compiler can reject filename: 42. Pass one of those instead.',
  )
  final Object? filenameNode;

  /// Streaming vs complete chrome (source `status`, default `complete`).
  final BeuiCodeBlockStatus status;

  /// Whether to paint 1-based line numbers in a gutter (default `true`).
  final bool showLineNumbers;

  /// 1-based line numbers to soft-highlight (source `highlightLines`).
  ///
  /// Rendered as a tinted row *and* a 2px leading bar: the wash alone measured
  /// 1.08:1 against the code surface, which is not a cue.
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

  /// Shown in place of the line list when [code] is empty and the block is not
  /// streaming. Defaults to a muted "No code to show".
  ///
  /// Without this an empty block rendered a single blank numbered line — a
  /// gutter `1` next to nothing, which reads as a bug rather than a state.
  final Widget? emptyPlaceholder;

  @override
  State<BeuiCodeBlock> createState() => _BeuiCodeBlockState();
}

class _BeuiCodeBlockState extends State<BeuiCodeBlock>
    with SingleTickerProviderStateMixin {
  late final BeuiLiveEdgeFollower _follow;
  bool _copied = false;
  bool _copyHovered = false;
  bool _copyPressed = false;
  bool _copyFocused = false;
  Timer? _copyTimer;
  late final AnimationController _spin;

  bool get _streaming => widget.status == BeuiCodeBlockStatus.streaming;
  bool get _showCopy => widget.copyable || widget.onCopy != null;

  /// True when there is nothing to render but the stream has finished.
  bool get _isEmpty => widget.code.isEmpty && !_streaming;

  @override
  void initState() {
    super.initState();
    _follow = BeuiLiveEdgeFollower(
      onPinnedChanged: () {
        if (mounted) setState(() {});
      },
    )..attach();
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
    _follow.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _scheduleFollow() {
    if (!mounted) return;
    _follow.follow(context);
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

  /// Resolves the chrome-bar filename across the typed pair and the deprecated
  /// untyped slot, newest API first.
  Widget? _resolveFilename() {
    if (widget.filenameWidget != null) return widget.filenameWidget;
    if (widget.filename != null) return Text(widget.filename!);
    // ignore: deprecated_member_use_from_same_package
    final legacy = widget.filenameNode;
    if (legacy == null) return null;
    if (legacy is Widget) return legacy;
    return Text(legacy.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final palette = BeuiSyntaxPalette.of(theme.brightness);
    final highlight = widget.highlightLines.toSet();

    final lines = widget.code.split('\n');
    // Preserve trailing empty line behaviour of split — matches source.

    // Keep the hidden-content cue honest as the content grows.
    _follow.syncMetrics();

    // Status chrome colours: blue while writing, emerald when ready.
    const writingBlue = Color(0xFF155DFC); // blue-600
    const writingBlueDark = Color(0xFF51A2FF); // blue-400
    const readyGreen = Color(0xFF009966); // emerald-600
    const readyGreenDark = Color(0xFF00D492); // emerald-400
    final isLight = theme.brightness == Brightness.light;
    final statusColor = _streaming
        ? (isLight ? writingBlue : writingBlueDark)
        : (isLight ? readyGreen : readyGreenDark);

    // 0.97, the library press token. This widget used to press to 0.9, which
    // read as a different component on the same screen (audit T8).
    final pressTarget = (_copyPressed && !reduce) ? 0.97 : 1.0;
    final filename = _resolveFilename();
    final surface = Color.alphaBlend(
      colors.muted.withValues(alpha: 0.8),
      colors.background,
    );

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
                    ExcludeSemantics(
                      child: Icon(
                        agent.icons.file,
                        size: 14,
                        color: colors.mutedForeground.withValues(alpha: 0.7),
                      ),
                    ),
                    if (filename != null) ...[
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
                          child: filename,
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
                        // Un-multiplied: which language a block is in is
                        // information, and at 0.55 alpha it measured 2.3:1.
                        color: colors.mutedForeground,
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
                        // Live only while the confirmation is up, so the swap
                        // to "Copied" is actually announced instead of just
                        // relabelling a silent node (audit R28 / T7).
                        liveRegion: _copied,
                        label: _copied ? 'Copied' : 'Copy code',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _copyHovered = true),
                          onExit: (_) => setState(() {
                            _copyHovered = false;
                            _copyPressed = false;
                          }),
                          child: FocusableActionDetector(
                            mouseCursor: SystemMouseCursors.click,
                            onShowFocusHighlight: (v) {
                              if (mounted) setState(() => _copyFocused = v);
                            },
                            actions: <Type, Action<Intent>>{
                              ActivateIntent: CallbackAction<ActivateIntent>(
                                onInvoke: (_) {
                                  unawaited(_handleCopy());
                                  return null;
                                },
                              ),
                            },
                            child: BeuiMinHitTarget(
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
                                  motion: motionFor(
                                    context,
                                    beuiSpringPress,
                                    isMovement: true,
                                  ),
                                  builder: (context, scale, child) =>
                                      Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                  child: BeuiFocusRing(
                                    focused: _copyFocused,
                                    borderRadius: BorderRadius.circular(999),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _copyHovered
                                            ? colors.background.withValues(
                                                alpha: 0.7,
                                              )
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
                child: _isEmpty
                    ? _EmptyCode(
                        colors: colors,
                        placeholder: widget.emptyPlaceholder,
                      )
                    : Stack(
                        children: [
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(scrollbars: false),
                            child: SingleChildScrollView(
                              controller: _follow.controller,
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
                                  // source `pre` is `min-w-max` inside the
                                  // scroller, so every line row is at least as
                                  // wide as the viewport and the highlight band
                                  // fills the whole row.
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
                                                  showLineNumbers:
                                                      widget.showLineNumbers,
                                                  highlight: highlight,
                                                  wrap: false,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                          // Hidden-content cue: the viewport turns scrollbars
                          // off for fidelity, so without this a long file reads
                          // as a short one that stops mid-statement (R12).
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: BeuiHiddenContentFooter(
                              extentBelow: _follow.extentBelow,
                              rowExtent: _CodeLines.lineHeight,
                              surface: surface,
                            ),
                          ),
                          // The reader owns the viewport: once they scroll off
                          // the live edge, following stops and this is how they
                          // opt back in (R7).
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: BeuiJumpToLatest(
                              visible: _streaming && _follow.pinned,
                              onTap: () => _follow.follow(context, force: true),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state body — a finished block with no code at all.
class _EmptyCode extends StatelessWidget {
  const _EmptyCode({required this.colors, required this.placeholder});

  final BeuiColors colors;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            letterSpacing: 0,
            color: colors.mutedForeground,
          ),
          child: placeholder ?? const Text('No code to show'),
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
  final BeuiSyntaxPalette palette;
  final BeuiColors colors;
  final bool showLineNumbers;
  final Set<int> highlight;
  final bool wrap;

  static const _gutterWidth = 44.0; // ~2.75rem

  /// One rendered row, `leading-5`. Public to the library so the hidden-content
  /// footer can turn scroll extent into a line count.
  static const lineHeight = 20.0;
  static const _fontSize = 12.0; // text-xs

  /// Blue-500 focus wash (source `highlightLines`).
  static const highlightHue = Color(0xFF2B7FFF);

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
      height: lineHeight / _fontSize,
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
            tokens: beuiHighlightLine(lines[i], language, palette),
            showLineNumbers: showLineNumbers,
            highlighted: highlight.contains(i + 1),
            wrap: wrap,
            colors: colors,
            baseStyle: baseStyle,
            // 0.10 fill (was 0.07 → a 1.08:1 wash) plus a 2px leading bar at
            // 0.6, so the highlight survives as more than a rounding error.
            highlightFill: highlightHue.withValues(alpha: 0.10),
            highlightBar: highlightHue.withValues(alpha: 0.6),
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
    required this.highlightBar,
  });

  final int lineNumber;
  final String content;
  final List<BeuiSyntaxToken> tokens;
  final bool showLineNumbers;
  final bool highlighted;
  final bool wrap;
  final BeuiColors colors;
  final TextStyle baseStyle;
  final Color highlightFill;
  final Color highlightBar;

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
                    // 0.75, not 0.35. The gutter is the cross-reference channel
                    // for "I changed line 19"; at 0.35 it measured 1.63:1 and
                    // could not be read at all (audit R8).
                    color: colors.mutedForeground.withValues(alpha: 0.75),
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

    // Fill *and* a leading bar: colour alone at this alpha is not a cue, and a
    // 2px edge survives both low-contrast displays and colour blindness.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlightFill,
        border: BorderDirectional(
          start: BorderSide(color: highlightBar, width: 2),
        ),
      ),
      child: row,
    );
  }
}
