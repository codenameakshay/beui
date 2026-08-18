import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_disclosure.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
import '_syntax.dart';
import '_viewport_follow.dart';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiFileDiff] surface (source `FileDiffStatus`).
enum BeuiFileDiffStatus {
  /// Diff rows are still arriving; the viewport follows the live edge.
  streaming,

  /// Stream finished — shows the applied checkmark and may auto-collapse.
  complete,
}

/// Kind of change for a [BeuiFileDiffLine] (source `FileDiffLineType`).
enum BeuiFileDiffLineType {
  /// Newly introduced line (`+`).
  added,

  /// Deleted line (`−`).
  removed,

  /// Unchanged context line.
  context,
}

/// How a [BeuiFileDiff] handles lines wider than its viewport.
enum BeuiFileDiffWrap {
  /// Soft-wrap long lines onto the next row. Nothing is hidden, but line
  /// numbers stop lining up with visual rows.
  wrap,

  /// Keep one line per row and scroll horizontally — the desktop default, and
  /// the only mode in which a wide line can be read exactly as written.
  scroll,

  /// Wrap when the viewport is narrower than
  /// [BeuiFileDiff.wrapBreakpoint], scroll otherwise.
  ///
  /// The default. A phone-width bubble has roughly 260 logical pixels left for
  /// code after the gutters, which is about 30 characters of 12px mono; that is
  /// where horizontal scrolling stops being a convenience and starts being the
  /// only way to see the change.
  adaptive,
}

/// One row of a [BeuiFileDiff] — the Flutter port of the source's `FileDiffLine`.
@immutable
class BeuiFileDiffLine {
  /// Creates a diff row descriptor.
  const BeuiFileDiffLine({
    required this.id,
    required this.content,
    this.type = BeuiFileDiffLineType.context,
    this.oldLine,
    this.newLine,
  });

  /// Stable identity within the list (keys enter/exit).
  final String id;

  /// Change kind. Defaults to [BeuiFileDiffLineType.context].
  final BeuiFileDiffLineType type;

  /// 1-based line number in the original file (left gutter).
  final int? oldLine;

  /// 1-based line number in the new file (right gutter).
  final int? newLine;

  /// Raw source text for this row (no leading `+`/`-` prefix required).
  final String content;

  /// Whether this row represents an actual change (not context).
  bool get isChange => type != BeuiFileDiffLineType.context;
}

/// A gap between two rendered rows — unchanged lines the consumer did not send.
///
/// Derived, not supplied: [BeuiFileDiff] infers a hunk boundary whenever two
/// consecutive rows' line numbers are discontinuous, which needs no change to
/// [BeuiFileDiffLine] at all.
@immutable
class BeuiFileDiffHunkGap {
  /// Creates a gap descriptor.
  const BeuiFileDiffHunkGap({
    required this.hiddenCount,
    required this.before,
    required this.after,
  });

  /// How many unchanged lines are missing between [before] and [after].
  final int hiddenCount;

  /// The last row rendered above the gap.
  final BeuiFileDiffLine before;

  /// The first row rendered below the gap.
  final BeuiFileDiffLine after;
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _chevronMotion = beuiSpringSwap;
const _pressMotion = beuiSpringPress;
const _spinPeriod = Duration(milliseconds: 900);
const _copyFeedback = Duration(milliseconds: 1600);

// Tailwind emerald / rose for change counts and gutters.
const _emerald600 = Color(0xFF009966);
const _emerald400 = Color(0xFF00D492);
const _rose600 = Color(0xFFEC003F);
const _rose400 = Color(0xFFFF637E);
const _emerald500 = Color(0xFF00BC7D);
const _rose500 = Color(0xFFFF2056);

/// Row tint alpha for a changed line.
///
/// 0.14, not 0.07. At 0.07 the added and removed washes measured **1.04:1
/// against each other** — the two states a diff exists to distinguish were
/// visually identical, and the whole signal rested on one 12px glyph.
const double _rowTintAlpha = 0.14;

/// Width of the leading colour bar on a changed row, in logical pixels.
/// Reserved (transparent) on context rows so nothing shifts between them.
const double _rowBarWidth = 2;

// Unicode minus (source `−`), not ASCII hyphen.
const _minus = '−';

// ---------------------------------------------------------------------------
// BeuiFileDiff
// ---------------------------------------------------------------------------

/// A syntax-highlighted file change disclosure with progressive rows, dual
/// line numbers, live change counts, smooth following while streaming, and
/// optional collapse on complete — the Flutter port of beUI's agent
/// `file-diff`.
///
/// **Highlighting.** The source uses Shiki via `AgentCode`. This port uses the
/// shared lightweight tokeniser in `_syntax.dart`, the same one
/// [BeuiCodeBlock] uses. It previously carried its own forked copy, which had
/// drifted far enough to paint added lines in the *deletion* red.
///
/// **Wide lines.** One row per line with horizontal scroll by default, wrapping
/// on narrow viewports — see [wrap]. The widget used to ellipsise instead, which
/// hid the end of exactly the lines a reviewer needs to see.
///
/// **Motion.** Chevron rotates on [beuiSpringSwap]; presses scale to 0.97 on
/// [beuiSpringPress]; the disclosure is the shared
/// [BeuiAgentDisclosureInternal] (220ms open / 140ms close, and a real
/// cross-fade under reduced motion rather than a hard cut). While
/// [BeuiFileDiffStatus.streaming] the viewport follows the live edge until the
/// reader scrolls away from it. Transitioning streaming → complete with
/// [collapseOnComplete] closes the panel; resuming streaming re-opens it.
///
/// **API mapping** (source → Flutter):
/// * `file` → [file] ([String]) / [fileWidget] ([Widget])
/// * `lines` → [lines]
/// * `status` → [status]
/// * `open` / `defaultOpen` / `onOpenChange` / `collapseOnComplete` → same
/// * `maxHeight` / `language` / `copyText` / `onCopy` → same
class BeuiFileDiff extends StatefulWidget {
  /// Creates a file-diff disclosure surface.
  ///
  /// Supply the header label through [file] (a path) or [fileWidget].
  const BeuiFileDiff({
    required this.lines,
    this.file,
    this.fileWidget,
    @Deprecated(
      'Split into file (String) and fileWidget (Widget) so the compiler can '
      'reject file: 42. Pass one of those instead.',
    )
    this.fileNode,
    this.status = BeuiFileDiffStatus.streaming,
    this.open,
    this.defaultOpen = true,
    this.onOpenChange,
    this.collapseOnComplete = true,
    this.maxHeight = 220,
    this.language = BeuiCodeLanguage.typescript,
    this.wrap = BeuiFileDiffWrap.adaptive,
    this.wrapBreakpoint = 480,
    this.copyText,
    this.copyable = true,
    this.onCopy,
    this.onExpandContext,
    this.emptyPlaceholder,
    super.key,
  }) : assert(
         file != null ||
             fileWidget != null ||
             // ignore: deprecated_member_use_from_same_package
             fileNode != null,
         'BeuiFileDiff needs a header label: pass file (a path String) or '
         'fileWidget (a Widget).',
       );

  /// File path shown in the header, as plain text.
  ///
  /// Middle-truncated when it does not fit, so the basename — the part that
  /// identifies *which* file — always survives. End-ellipsis turned
  /// `src/components/button.tsx` into `src/compon…`.
  final String? file;

  /// File label shown in the header, as an arbitrary widget
  /// (source `file: ReactNode`). Wins over [file] when both are set, and is
  /// rendered verbatim — truncation is the caller's business.
  final Widget? fileWidget;

  /// Deprecated untyped file slot, kept so existing call sites compile.
  @Deprecated(
    'Split into file (String) and fileWidget (Widget) so the compiler can '
    'reject file: 42. Pass one of those instead.',
  )
  final Object? fileNode;

  /// Diff rows, top to bottom. Progressive streaming is achieved by growing
  /// this list over time (source preview slices visible rows).
  final List<BeuiFileDiffLine> lines;

  /// Streaming vs complete chrome (source `status`, default `streaming`).
  final BeuiFileDiffStatus status;

  /// Controlled open state. When non-null the disclosure is *controlled* —
  /// keep it in sync via [onOpenChange]. Leave null for uncontrolled.
  final bool? open;

  /// Initial open state in the uncontrolled case (ignored when [open] is set).
  final bool defaultOpen;

  /// Called with the new open state on every toggle / auto-collapse / re-open.
  final ValueChanged<bool>? onOpenChange;

  /// When true (default), auto-collapses on streaming → complete and re-opens
  /// when status returns to streaming (source `collapseOnComplete`).
  ///
  /// **This hides the finished diff at the moment it becomes reviewable.** The
  /// source does it, so it stays the default and stays faithful; the copy
  /// control has been moved into the header precisely so it survives the
  /// collapse. If your surface is a review step rather than a progress log,
  /// pass `false` — a reviewer who has to re-open the panel to see what
  /// changed is one who will approve without looking.
  final bool collapseOnComplete;

  /// Max viewport height in logical pixels (source `maxHeight`, default 220).
  final double maxHeight;

  /// Language for the lightweight highlighter (source `language`).
  final BeuiCodeLanguage language;

  /// How lines wider than the viewport are handled. Defaults to
  /// [BeuiFileDiffWrap.adaptive].
  ///
  /// Matches [BeuiCodeBlock.wrap] semantics: wrapping keeps everything on
  /// screen, scrolling keeps one line per row.
  final BeuiFileDiffWrap wrap;

  /// Viewport width below which [BeuiFileDiffWrap.adaptive] wraps, in logical
  /// pixels. Defaults to 480.
  final double wrapBreakpoint;

  /// Text written to the clipboard when the copy control is pressed.
  ///
  /// Defaults to the diff the widget already holds, serialised as a unified
  /// diff body (`+` / `-` / space prefixes, ASCII so it pastes into `git
  /// apply`). Supply this only to override that.
  final String? copyText;

  /// Whether the copy control is shown at all (default `true`). Still shown
  /// when [onCopy] is non-null even if this is false.
  final bool copyable;

  /// Optional override for the copy action. Prefer this when you need custom
  /// side-effects; otherwise [copyText] is written to the system clipboard.
  final FutureOr<void> Function()? onCopy;

  /// Called when the reader activates an "expand N hidden lines" separator.
  ///
  /// [BeuiFileDiff] can *detect* a context gap from discontinuous line numbers,
  /// but it cannot invent the lines that fill it — only the consumer has the
  /// file. Wire this up and grow [lines] in response to make gaps expandable;
  /// leave it null and gaps render as a static, honest marker instead of
  /// pretending the diff is contiguous.
  final void Function(BeuiFileDiffHunkGap gap)? onExpandContext;

  /// Shown in place of the row list when [lines] is empty and the diff is not
  /// streaming. Defaults to a muted "No changes in this file".
  final Widget? emptyPlaceholder;

  @override
  State<BeuiFileDiff> createState() => _BeuiFileDiffState();
}

class _BeuiFileDiffState extends State<BeuiFileDiff>
    with SingleTickerProviderStateMixin {
  late bool _internalOpen = widget.defaultOpen;
  late final BeuiLiveEdgeFollower _follow;
  late final AnimationController _spin;
  bool _copied = false;
  Timer? _copyTimer;

  /// Anchors for change-to-change navigation, keyed by line id.
  final Map<String, GlobalKey> _changeKeys = <String, GlobalKey>{};
  int _changeCursor = -1;

  bool get _isControlled => widget.open != null;
  bool get _currentOpen => widget.open ?? _internalOpen;
  bool get _streaming => widget.status == BeuiFileDiffStatus.streaming;
  bool get _canCopy => widget.copyable || widget.onCopy != null;
  bool get _isEmpty => widget.lines.isEmpty && !_streaming;

  int get _additions =>
      widget.lines.where((l) => l.type == BeuiFileDiffLineType.added).length;

  int get _deletions =>
      widget.lines.where((l) => l.type == BeuiFileDiffLineType.removed).length;

  List<BeuiFileDiffLine> get _changes =>
      widget.lines.where((l) => l.isChange).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _follow = BeuiLiveEdgeFollower(
      onPinnedChanged: () {
        if (mounted) setState(() {});
      },
    )..attach();
    _spin = AnimationController(vsync: this, duration: _spinPeriod);
    if (_streaming) {
      _spin.repeat();
      _scheduleFollow();
    }
  }

  @override
  void didUpdateWidget(covariant BeuiFileDiff oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto open/collapse on status transitions (source useEffect).
    // Use oldWidget.status (Flutter's update edge) rather than a mirrored ref —
    // a local previous-status field can desync when GlobalKey reparents State.
    final prev = oldWidget.status;
    final next = widget.status;
    if (prev != BeuiFileDiffStatus.streaming &&
        next == BeuiFileDiffStatus.streaming) {
      _setOpen(true);
    } else if (prev == BeuiFileDiffStatus.streaming &&
        next == BeuiFileDiffStatus.complete &&
        widget.collapseOnComplete) {
      _setOpen(false);
    }

    if (_streaming != (oldWidget.status == BeuiFileDiffStatus.streaming)) {
      if (_streaming) {
        _spin.repeat();
      } else {
        _spin
          ..stop()
          ..value = 0;
      }
    }

    if (_streaming &&
        _currentOpen &&
        (widget.lines.length != oldWidget.lines.length ||
            widget.status != oldWidget.status)) {
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

  void _setOpen(bool next) {
    if (next == _currentOpen) return;
    if (!_isControlled) {
      // Mutate directly so a didUpdateWidget-driven collapse is visible in the
      // imminent build; also mark dirty when we're not already rebuilding.
      _internalOpen = next;
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        setState(() {});
      }
    }
    widget.onOpenChange?.call(next);
  }

  void _toggle() => _setOpen(!_currentOpen);

  void _scheduleFollow() {
    if (!mounted) return;
    if (!_currentOpen || !_streaming) return;
    _follow.follow(context);
  }

  /// The clipboard payload: the caller's override, or the diff serialised as a
  /// unified diff body so consumers never have to re-derive what we already
  /// hold (audit R35).
  String get _resolvedCopyText {
    final override = widget.copyText;
    if (override != null) return override;
    return widget.lines
        .map((line) {
          final prefix = switch (line.type) {
            BeuiFileDiffLineType.added => '+',
            // ASCII hyphen, not the U+2212 the header renders: this string is
            // meant to survive a paste into `git apply`.
            BeuiFileDiffLineType.removed => '-',
            BeuiFileDiffLineType.context => ' ',
          };
          return '$prefix${line.content}';
        })
        .join('\n');
  }

  Future<void> _handleCopy() async {
    final custom = widget.onCopy;
    if (custom != null) {
      await custom();
    } else {
      await Clipboard.setData(ClipboardData(text: _resolvedCopyText));
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(_copyFeedback, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Moves the viewport to the next / previous changed row.
  void _stepChange(int direction) {
    final changes = _changes;
    if (changes.isEmpty) return;
    if (!_currentOpen) _setOpen(true);
    final nextCursor = _changeCursor < 0
        ? (direction > 0 ? 0 : changes.length - 1)
        : (_changeCursor + direction) % changes.length;
    _changeCursor = nextCursor < 0 ? changes.length - 1 : nextCursor;
    final target = changes[_changeCursor];
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Stepping is an explicit reader action; it should not be undone by the
    // stream yanking the viewport back a frame later, so it pins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _changeKeys[target.id]?.currentContext;
      if (anchor == null) return;
      unawaited(
        Scrollable.ensureVisible(
          anchor,
          alignment: 0.2,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
          curve: beuiEaseOut,
        ),
      );
    });
    setState(() {});
  }

  Widget _resolveFile(BeuiColors colors) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const [
        'Menlo',
        'Monaco',
        'Consolas',
        'Courier New',
        'monospace',
      ],
      fontSize: 12,
      // Tailwind's default `tracking-normal`. Set explicitly: without it the
      // span inherits Material's bodySmall/bodyMedium letterSpacing (0.25),
      // which widens every mono line by 0.25px per character.
      letterSpacing: 0,
      color: colors.foreground.withValues(alpha: 0.8),
      height: 16 / 12, // text-xs default leading-4
    );

    if (widget.fileWidget != null) {
      return DefaultTextStyle(
        style: style,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        child: widget.fileWidget!,
      );
    }
    // ignore: deprecated_member_use_from_same_package
    final legacy = widget.fileNode;
    if (widget.file == null && legacy is Widget) {
      return DefaultTextStyle(
        style: style,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        child: legacy,
      );
    }
    final path = widget.file ?? legacy?.toString() ?? '';
    return _MiddleTruncatedText(text: path, style: style);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isLight = theme.brightness == Brightness.light;
    final palette = BeuiSyntaxPalette.of(theme.brightness);
    final addColor = isLight ? _emerald600 : _emerald400;
    final delColor = isLight ? _rose600 : _rose400;

    _follow.syncMetrics();

    // Prune anchors for rows that are gone, so a long-running stream does not
    // leak a GlobalKey per line it ever rendered.
    final changes = _changes;
    final liveChangeIds = {for (final c in changes) c.id};
    _changeKeys.removeWhere((id, _) => !liveChangeIds.contains(id));
    for (final change in changes) {
      _changeKeys.putIfAbsent(change.id, GlobalKey.new);
    }

    // Navigation earns its place only when the changes cannot all be on screen
    // at once — below that the reader can just look.
    final contentHeight = widget.lines.length * _DiffLines.lineHeight;
    final showChangeNav =
        changes.length > 1 && contentHeight > widget.maxHeight;

    final surface = Color.alphaBlend(
      colors.muted.withValues(alpha: 0.8),
      colors.background,
    );

    return Semantics(
      container: true,
      liveRegion: _streaming,
      label: 'File changes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            open: _currentOpen,
            streaming: _streaming,
            file: _resolveFile(colors),
            additions: _additions,
            deletions: _deletions,
            addColor: addColor,
            delColor: delColor,
            colors: colors,
            reduce: reduce,
            spin: _spin,
            onToggle: _toggle,
            // The copy control lives in the header so `collapseOnComplete`
            // cannot take it away at the exact moment the diff is finished and
            // the reader wants it (audit R21).
            canCopy: _canCopy,
            copied: _copied,
            onCopy: _handleCopy,
            showChangeNav: showChangeNav,
            changeCount: changes.length,
            changeCursor: _changeCursor,
            onPreviousChange: () => _stepChange(-1),
            onNextChange: () => _stepChange(1),
          ),
          BeuiAgentDisclosureInternal(
            open: _currentOpen,
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.only(left: 24, top: 6), // pl-6 pt-1.5
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                ),
                child: _isEmpty
                    ? _EmptyDiff(
                        colors: colors,
                        placeholder: widget.emptyPlaceholder,
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: widget.maxHeight,
                        ),
                        child: Stack(
                          children: [
                            ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(scrollbars: false),
                              child: SingleChildScrollView(
                                controller: _follow.controller,
                                child: LayoutBuilder(
                                  builder: (context, viewport) {
                                    final shouldWrap = switch (widget.wrap) {
                                      BeuiFileDiffWrap.wrap => true,
                                      BeuiFileDiffWrap.scroll => false,
                                      BeuiFileDiffWrap.adaptive =>
                                        viewport.maxWidth.isFinite &&
                                            viewport.maxWidth <
                                                widget.wrapBreakpoint,
                                    };
                                    final rows = _DiffLines(
                                      lines: widget.lines,
                                      language: widget.language,
                                      palette: palette,
                                      colors: colors,
                                      addColor: addColor,
                                      delColor: delColor,
                                      wrap: shouldWrap,
                                      changeKeys: _changeKeys,
                                      onExpandContext: widget.onExpandContext,
                                    );
                                    if (shouldWrap) return rows;
                                    // Mirrors the code block: the row track is
                                    // at least as wide as the viewport, so the
                                    // change tints fill the whole row instead
                                    // of stopping at the end of the text.
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: viewport.maxWidth,
                                        ),
                                        child: IntrinsicWidth(child: rows),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: BeuiHiddenContentFooter(
                                extentBelow: _follow.extentBelow,
                                rowExtent: _DiffLines.lineHeight,
                                surface: surface,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 8,
                              child: BeuiJumpToLatest(
                                visible: _streaming && _follow.pinned,
                                onTap: () =>
                                    _follow.follow(context, force: true),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state body — a finished diff that touched nothing.
class _EmptyDiff extends StatelessWidget {
  const _EmptyDiff({required this.colors, required this.placeholder});

  final BeuiColors colors;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            letterSpacing: 0,
            color: colors.mutedForeground,
          ),
          child: placeholder ?? const Text('No changes in this file'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Middle truncation
// ---------------------------------------------------------------------------

/// Text that drops characters from the *middle* rather than the end.
///
/// Package-private for now: it is a genuinely reusable primitive, but the
/// public surface stays as small as the audit's findings require.
///
/// For a path, the tail is the part that identifies the file, so an
/// end-ellipsis destroys exactly the information the label exists to carry
/// (`src/components/button.tsx` → `src/compon…`). This keeps the basename whole
/// and eats into the directories instead
/// (`src/components/button.tsx` → `src/…/button.tsx`).
class _MiddleTruncatedText extends StatelessWidget {
  /// Creates a middle-truncating label.
  const _MiddleTruncatedText({required this.text, required this.style});

  /// The full string. Also the semantics label, so assistive technology hears
  /// the whole path however it is painted.
  final String text;

  /// Text style. Must be fully resolved — the measurement uses it directly.
  final TextStyle style;

  /// Replacement for the elided middle.
  static const String ellipsis = '…';

  /// The index the tail starts at: the last path separator, so the basename
  /// survives. Falls back to the last third of a separator-less string.
  int _tailStart() {
    final slash = text.lastIndexOf('/');
    if (slash >= 0 && slash < text.length - 1) return slash;
    return (text.length * 2 / 3).floor();
  }

  double _widthOf(String value, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            if (!maxWidth.isFinite ||
                text.isEmpty ||
                _widthOf(text, direction) <= maxWidth) {
              return Text(
                text,
                style: style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              );
            }

            final tail = text.substring(_tailStart());
            // Binary search the longest head that still fits alongside the
            // ellipsis and the whole tail. O(log n) layouts, and only when the
            // label actually overflows.
            var low = 0;
            var high = _tailStart();
            var best = 0;
            while (low <= high) {
              final mid = (low + high) ~/ 2;
              final candidate = '${text.substring(0, mid)}$ellipsis$tail';
              if (_widthOf(candidate, direction) <= maxWidth) {
                best = mid;
                low = mid + 1;
              } else {
                high = mid - 1;
              }
            }

            final head = text.substring(0, best);
            return Text(
              '$head$ellipsis$tail',
              style: style,
              maxLines: 1,
              softWrap: false,
              // The tail itself can still be wider than the box on a very
              // narrow viewport; clip rather than re-ellipsise it.
              overflow: TextOverflow.clip,
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatefulWidget {
  const _Header({
    required this.open,
    required this.streaming,
    required this.file,
    required this.additions,
    required this.deletions,
    required this.addColor,
    required this.delColor,
    required this.colors,
    required this.reduce,
    required this.spin,
    required this.onToggle,
    required this.canCopy,
    required this.copied,
    required this.onCopy,
    required this.showChangeNav,
    required this.changeCount,
    required this.changeCursor,
    required this.onPreviousChange,
    required this.onNextChange,
  });

  final bool open;
  final bool streaming;
  final Widget file;
  final int additions;
  final int deletions;
  final Color addColor;
  final Color delColor;
  final BeuiColors colors;
  final bool reduce;
  final AnimationController spin;
  final VoidCallback onToggle;
  final bool canCopy;
  final bool copied;
  final Future<void> Function() onCopy;
  final bool showChangeNav;
  final int changeCount;
  final int changeCursor;
  final VoidCallback onPreviousChange;
  final VoidCallback onNextChange;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final chevronColor = (_hovered || _focused)
        ? colors.mutedForeground
        : colors.mutedForeground.withValues(alpha: 0.45);

    final toggle = Semantics(
      button: true,
      expanded: widget.open,
      label:
          '${widget.additions} additions, ${widget.deletions} deletions. '
          '${widget.open ? 'Collapse' : 'Expand'} file diff',
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) {
          if (mounted) setState(() => _focused = v);
        },
        onShowHoverHighlight: (v) {
          if (mounted) setState(() => _hovered = v);
        },
        mouseCursor: SystemMouseCursors.click,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggle,
          // Ring painted outside layout, in the dedicated focusRing role: the
          // old in-decoration `colors.ring` border was a 1.3:1 hairline token
          // doing a focus indicator's job (audit R6).
          child: BeuiFocusRing(
            focused: _focused,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36), // min-h-9
              // 6 + 2: the geometry the old always-present transparent 2px
              // border used to contribute, preserved now that the ring has
              // moved out of the box model.
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      BeuiAgentTheme.of(context).icons.file,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: widget.file),
                  if (widget.additions > 0 || widget.deletions > 0) ...[
                    const SizedBox(width: 8),
                    if (widget.additions > 0)
                      Text(
                        '+${widget.additions}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          letterSpacing: 0, // tracking-normal
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: widget.addColor,
                        ),
                      ),
                    if (widget.additions > 0 && widget.deletions > 0)
                      const SizedBox(width: 8),
                    if (widget.deletions > 0)
                      Text(
                        '$_minus${widget.deletions}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          letterSpacing: 0, // tracking-normal
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: widget.delColor,
                        ),
                      ),
                  ],
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Center(
                      child: _StatusIcon(
                        streaming: widget.streaming,
                        reduce: widget.reduce,
                        color: colors.mutedForeground.withValues(alpha: 0.6),
                        spin: widget.spin,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // gap-2
                  _Chevron(
                    open: widget.open,
                    reduce: widget.reduce,
                    color: chevronColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Expanded(child: toggle),
        if (widget.showChangeNav) ...[
          _HeaderAction(
            icon: LucideIcons.chevron_up,
            label: widget.changeCursor < 0
                ? 'Go to last change of ${widget.changeCount}'
                : 'Previous change, ${widget.changeCursor + 1} of '
                      '${widget.changeCount}',
            colors: colors,
            onTap: widget.onPreviousChange,
          ),
          _HeaderAction(
            icon: LucideIcons.chevron_down,
            label: widget.changeCursor < 0
                ? 'Go to first change of ${widget.changeCount}'
                : 'Next change, ${widget.changeCursor + 1} of '
                      '${widget.changeCount}',
            colors: colors,
            onTap: widget.onNextChange,
          ),
        ],
        if (widget.canCopy)
          _HeaderAction(
            icon: widget.copied
                ? BeuiAgentTheme.of(context).icons.copied
                : BeuiAgentTheme.of(context).icons.copy,
            label: widget.copied
                ? BeuiAgentTheme.of(context).strings.copied
                : BeuiAgentTheme.of(context).strings.copyDiff,
            // Live only while the confirmation is up, so it is announced
            // rather than silently relabelled (audit R28).
            liveRegion: widget.copied,
            colors: colors,
            onTap: () => unawaited(widget.onCopy()),
          ),
      ],
    );
  }
}

/// A 28px icon control in the diff header, with the full interactive contract:
/// semantics, keyboard activation, a visible focus ring, a 44px hit target, a
/// click cursor, and the library's 0.97 press scale.
class _HeaderAction extends StatefulWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.liveRegion = false,
  });

  final IconData icon;
  final String label;
  final BeuiColors colors;
  final VoidCallback onTap;
  final bool liveRegion;

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // BeuiMinHitTarget sits outermost: every proxy between it and the pointer
    // is sized to the 28px paint, and a RenderBox refuses a hit outside its own
    // size, so slop nested any deeper is unreachable.
    return BeuiMinHitTarget(
      child: Semantics(
        container: true,
        button: true,
        liveRegion: widget.liveRegion,
        label: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) {
              if (mounted) setState(() => _focused = v);
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: SingleMotionBuilder(
                value: (_pressed && !reduce) ? 0.97 : 1.0,
                motion: motionFor(context, _pressMotion, isMovement: true),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: BeuiFocusRing(
                  focused: _focused,
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? colors.muted.withValues(alpha: 0.8)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 14,
                      color: _hovered
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
      size: 14,
      color: color,
      semanticLabel: streaming ? 'Applying changes' : 'Changes applied',
    );
    if (!streaming || reduce) return icon;
    return RotationTransition(turns: spin, child: icon);
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
    final icon = Icon(
      BeuiAgentTheme.of(context).icons.expand,
      size: 14,
      color: color,
    );
    if (reduce) {
      return Transform.rotate(angle: open ? math.pi : 0, child: icon);
    }
    return SingleMotionBuilder(
      value: open ? 180.0 : 0.0,
      motion: motionFor(context, _chevronMotion, isMovement: true),
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180.0, child: child),
      child: icon,
    );
  }
}

// ---------------------------------------------------------------------------
// Diff lines
// ---------------------------------------------------------------------------

class _DiffLines extends StatelessWidget {
  const _DiffLines({
    required this.lines,
    required this.language,
    required this.palette,
    required this.colors,
    required this.addColor,
    required this.delColor,
    required this.wrap,
    required this.changeKeys,
    required this.onExpandContext,
  });

  final List<BeuiFileDiffLine> lines;
  final BeuiCodeLanguage language;
  final BeuiSyntaxPalette palette;
  final BeuiColors colors;
  final Color addColor;
  final Color delColor;
  final bool wrap;
  final Map<String, GlobalKey> changeKeys;
  final void Function(BeuiFileDiffHunkGap gap)? onExpandContext;

  static const _gutterW = 36.0; // 2.25rem
  static const _markerW = 16.0; // 1rem

  /// One rendered row, matching the code block's `leading-5`.
  static const lineHeight = 20.0;
  static const _fontSize = 12.0;

  /// Unchanged lines missing between [a] and [b], or 0 when they are
  /// contiguous (or when there is not enough information to tell).
  static int gapBetween(BeuiFileDiffLine a, BeuiFileDiffLine b) {
    // Additions have no old-file number and deletions have no new-file one, so
    // compare on whichever axis both rows are anchored to.
    final aOld = a.oldLine;
    final bOld = b.oldLine;
    if (aOld != null && bOld != null) return math.max(0, bOld - aOld - 1);
    final aNew = a.newLine;
    final bNew = b.newLine;
    if (aNew != null && bNew != null) return math.max(0, bNew - aNew - 1);
    return 0;
  }

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
      // Tailwind `tracking-normal`; see _resolveFile for why this is explicit.
      letterSpacing: 0,
      height: lineHeight / _fontSize,
      color: palette.base,
    );
    final gutterStyle = baseStyle.copyWith(
      // 0.75, not 0.4: at 0.4 the dual gutters measured 1.78:1, and the gutter
      // is how a reviewer maps "line 19" onto the row in front of them.
      color: colors.mutedForeground.withValues(alpha: 0.75),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) {
        final hidden = gapBetween(lines[i - 1], line);
        if (hidden > 0) {
          children.add(
            _HunkSeparator(
              key: ValueKey<String>('gap-${lines[i - 1].id}-${line.id}'),
              gap: BeuiFileDiffHunkGap(
                hiddenCount: hidden,
                before: lines[i - 1],
                after: line,
              ),
              colors: colors,
              baseStyle: baseStyle,
              onExpand: onExpandContext,
            ),
          );
        }
      }
      final row = _DiffLineRow(
        key: ValueKey<String>(line.id),
        line: line,
        tokens: beuiHighlightLine(line.content, language, palette),
        baseStyle: baseStyle,
        gutterStyle: gutterStyle,
        addColor: addColor,
        delColor: delColor,
        wrap: wrap,
      );
      final anchor = changeKeys[line.id];
      children.add(
        anchor == null ? row : KeyedSubtree(key: anchor, child: row),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// The `@@`-equivalent: unchanged lines the consumer did not send.
///
/// Static text when [onExpand] is null, a button when it is not.
class _HunkSeparator extends StatefulWidget {
  const _HunkSeparator({
    required this.gap,
    required this.colors,
    required this.baseStyle,
    required this.onExpand,
    super.key,
  });

  final BeuiFileDiffHunkGap gap;
  final BeuiColors colors;
  final TextStyle baseStyle;
  final void Function(BeuiFileDiffHunkGap gap)? onExpand;

  @override
  State<_HunkSeparator> createState() => _HunkSeparatorState();
}

class _HunkSeparatorState extends State<_HunkSeparator> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final count = widget.gap.hiddenCount;
    final expandable = widget.onExpand != null;
    // F13: pluralization is the theme's problem, not a `count == 1 ? …` here —
    // languages with more than two plural forms cannot be served by a ternary.
    final strings = BeuiAgentTheme.of(context).strings;
    final text = expandable
        ? strings.expandHiddenLines(count)
        : strings.hiddenLinesCollapsed(count);

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: _hovered && expandable
            ? colors.foreground.withValues(alpha: 0.05)
            : colors.foreground.withValues(alpha: 0.02),
        border: Border(
          top: BorderSide(color: colors.foreground.withValues(alpha: 0.06)),
          bottom: BorderSide(color: colors.foreground.withValues(alpha: 0.06)),
        ),
      ),
      child: SizedBox(
        height: _DiffLines.lineHeight,
        child: Row(
          children: [
            SizedBox(
              width:
                  _DiffLines._gutterW * 2 + _DiffLines._markerW + _rowBarWidth,
              child: Text(
                '⋯',
                textAlign: TextAlign.center,
                style: widget.baseStyle.copyWith(
                  color: colors.mutedForeground.withValues(alpha: 0.75),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                text,
                style: widget.baseStyle.copyWith(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!expandable) {
      return Semantics(label: strings.hiddenLinesCollapsed(count), child: body);
    }

    // F14: the band paints 20px tall — half the 44px floor. The slop wrapper is
    // OUTERMOST because every box below it (Semantics, MouseRegion,
    // FocusableActionDetector) is sized to the paint and would reject an
    // out-of-bounds pointer before this widget ever saw it. Width already
    // clears the floor, so only the vertical overhang is doing work.
    //
    // The overhang is asymmetric in practice, and knowingly so: diff rows paint
    // their change tint through a hit-opaque box, and Flutter tests later
    // siblings first, so the row *below* claims the downward slop while the row
    // above yields the upward one. The reachable target is the 20px band plus
    // 12px above it — past WCAG 2.5.8 AA's 24px, short of the AAA 44px. Closing
    // the rest would mean growing the band's paint, which is a diff-rhythm and
    // source-fidelity change this fix is not licensed to make.
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        label: text,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) {
              if (mounted) setState(() => _focused = v);
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onExpand!(widget.gap);
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onExpand!(widget.gap),
              child: BeuiFocusRing(focused: _focused, child: body),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({
    required this.line,
    required this.tokens,
    required this.baseStyle,
    required this.gutterStyle,
    required this.addColor,
    required this.delColor,
    required this.wrap,
    super.key,
  });

  final BeuiFileDiffLine line;
  final List<BeuiSyntaxToken> tokens;
  final TextStyle baseStyle;
  final TextStyle gutterStyle;
  final Color addColor;
  final Color delColor;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final type = line.type;
    final bg = switch (type) {
      BeuiFileDiffLineType.added => _emerald500.withValues(
        alpha: _rowTintAlpha,
      ),
      BeuiFileDiffLineType.removed => _rose500.withValues(alpha: _rowTintAlpha),
      BeuiFileDiffLineType.context => null,
    };
    // The redundant channel the tints alone could not carry. Reserved as a
    // transparent strip on context rows so the code column never shifts.
    final bar = switch (type) {
      BeuiFileDiffLineType.added => addColor,
      BeuiFileDiffLineType.removed => delColor,
      BeuiFileDiffLineType.context => Colors.transparent,
    };
    final marker = switch (type) {
      BeuiFileDiffLineType.added => '+',
      BeuiFileDiffLineType.removed => _minus,
      BeuiFileDiffLineType.context => '',
    };
    final markerColor = switch (type) {
      BeuiFileDiffLineType.added => addColor,
      BeuiFileDiffLineType.removed => delColor,
      BeuiFileDiffLineType.context => gutterStyle.color ?? Colors.transparent,
    };

    final spans = tokens.isEmpty
        ? <InlineSpan>[
            TextSpan(text: line.content.isEmpty ? ' ' : line.content),
          ]
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
      // Never `ellipsis`. Truncating the end of a changed line hides the part
      // that changed — the single P0 this component carried (audit R1).
      overflow: wrap ? TextOverflow.visible : TextOverflow.clip,
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: wrap ? MainAxisSize.max : MainAxisSize.min,
      children: [
        SizedBox(
          width: _rowBarWidth,
          child: ColoredBox(color: bar),
        ),
        SizedBox(
          width: _DiffLines._gutterW,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              line.oldLine?.toString() ?? '',
              textAlign: TextAlign.right,
              style: gutterStyle,
            ),
          ),
        ),
        SizedBox(
          width: _DiffLines._gutterW,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              line.newLine?.toString() ?? '',
              textAlign: TextAlign.right,
              style: gutterStyle,
            ),
          ),
        ),
        SizedBox(
          width: _DiffLines._markerW,
          child: Text(
            marker,
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(color: markerColor),
          ),
        ),
        if (wrap)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: code,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: code,
          ),
      ],
    );

    // IntrinsicHeight so the leading bar spans a wrapped row's full height.
    final sized = wrap ? IntrinsicHeight(child: row) : row;
    if (bg == null) return sized;
    return ColoredBox(color: bg, child: sized);
  }
}
