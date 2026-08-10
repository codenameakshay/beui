import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'code_block.dart' show BeuiCodeLanguage;

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
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _disclosureOpen = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _disclosureClose = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);
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
/// same lightweight [TextSpan] tokeniser approach as [BeuiCodeBlock]
/// (keywords, strings, comments, numbers) so the package stays free of heavy
/// highlighting dependencies.
///
/// **Motion.** Chevron rotates on [beuiSpringSwap]; copy press scales on
/// [beuiSpringPress]; disclosure open/close uses EASE_OUT at 220ms / 140ms
/// (source `AgentDisclosure`). While [BeuiFileDiffStatus.streaming] the
/// viewport auto-scrolls to the live edge. Transitioning streaming → complete
/// with [collapseOnComplete] closes the panel; resuming streaming re-opens it.
///
/// **API mapping** (source → Flutter):
/// * `file` → [file] ([String] or [Widget])
/// * `lines` → [lines]
/// * `status` → [status]
/// * `open` / `defaultOpen` / `onOpenChange` / `collapseOnComplete` → same
/// * `maxHeight` / `language` / `copyText` / `onCopy` → same
class BeuiFileDiff extends StatefulWidget {
  /// Creates a file-diff disclosure surface.
  const BeuiFileDiff({
    required this.file,
    required this.lines,
    this.status = BeuiFileDiffStatus.streaming,
    this.open,
    this.defaultOpen = true,
    this.onOpenChange,
    this.collapseOnComplete = true,
    this.maxHeight = 220,
    this.language = BeuiCodeLanguage.typescript,
    this.copyText,
    this.onCopy,
    super.key,
  });

  /// File path / label shown in the header. Accepts a [String] or any [Widget]
  /// (source `file: ReactNode`).
  final Object file;

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
  final bool collapseOnComplete;

  /// Max viewport height in logical pixels (source `maxHeight`, default 220).
  final double maxHeight;

  /// Language for the lightweight highlighter (source `language`).
  final BeuiCodeLanguage language;

  /// Text written to the clipboard when the copy button is pressed. When null
  /// and [onCopy] is also null, the copy control is hidden.
  final String? copyText;

  /// Optional override for the copy action. Prefer this when you need custom
  /// side-effects; otherwise [copyText] is written to the system clipboard.
  final FutureOr<void> Function()? onCopy;

  @override
  State<BeuiFileDiff> createState() => _BeuiFileDiffState();
}

class _BeuiFileDiffState extends State<BeuiFileDiff>
    with SingleTickerProviderStateMixin {
  late bool _internalOpen = widget.defaultOpen;
  final ScrollController _scroll = ScrollController();
  late final AnimationController _spin;
  bool _copied = false;
  bool _copyHovered = false;
  bool _copyPressed = false;
  Timer? _copyTimer;

  bool get _isControlled => widget.open != null;
  bool get _currentOpen => widget.open ?? _internalOpen;
  bool get _streaming => widget.status == BeuiFileDiffStatus.streaming;
  bool get _canCopy => widget.copyText != null || widget.onCopy != null;

  int get _additions =>
      widget.lines.where((l) => l.type == BeuiFileDiffLineType.added).length;

  int get _deletions =>
      widget.lines.where((l) => l.type == BeuiFileDiffLineType.removed).length;

  @override
  void initState() {
    super.initState();
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
    _scroll.dispose();
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
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_currentOpen || !_streaming) {
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
    } else {
      final text = widget.copyText;
      if (text != null) {
        await Clipboard.setData(ClipboardData(text: text));
      }
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(_copyFeedback, () {
      if (mounted) setState(() => _copied = false);
    });
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
    final child = widget.file is Widget
        ? widget.file as Widget
        : Text(widget.file.toString());
    return DefaultTextStyle(
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isLight = theme.brightness == Brightness.light;
    final palette = _DiffPalette.of(colors, theme.brightness);
    final addColor = isLight ? _emerald600 : _emerald400;
    final delColor = isLight ? _rose600 : _rose400;
    final pressTarget = (_copyPressed && !reduce) ? 0.9 : 1.0;

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
          ),
          _AgentDisclosure(
            open: _currentOpen,
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.only(left: 24, top: 6), // pl-6 pt-1.5
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
                      constraints: BoxConstraints(maxHeight: widget.maxHeight),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          controller: _scroll,
                          child: _DiffLines(
                            lines: widget.lines,
                            language: widget.language,
                            palette: palette,
                            colors: colors,
                            addColor: addColor,
                            delColor: delColor,
                          ),
                        ),
                      ),
                    ),
                    if (_canCopy)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: _copied ? 'Copied' : 'Copy diff',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _copyHovered = true),
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
                                  motion: motionFor(
                                    context,
                                    _pressMotion,
                                    isMovement: true,
                                  ),
                                  builder: (context, scale, child) =>
                                      Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _copyHovered
                                          ? colors.background.withValues(
                                              alpha: 0.7,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
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
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

    return Semantics(
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: const BoxConstraints(minHeight: 36), // min-h-9
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: _focused
                  ? Border.all(color: colors.ring, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.file_code,
                  size: 16,
                  color: colors.mutedForeground,
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
    final icon = Icon(LucideIcons.chevron_down, size: 14, color: color);
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
// Agent disclosure (height + opacity + y clip reveal)
// ---------------------------------------------------------------------------

/// Shared transform-only reveal for collapsible agent content — the Flutter
/// port of the source's `AgentDisclosure`.
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
  });

  final List<BeuiFileDiffLine> lines;
  final BeuiCodeLanguage language;
  final _DiffPalette palette;
  final BeuiColors colors;
  final Color addColor;
  final Color delColor;

  static const _gutterW = 36.0; // 2.25rem
  static const _markerW = 16.0; // 1rem
  static const _lineHeight = 20.0;
  static const _fontSize = 12.0;

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
      height: _lineHeight / _fontSize,
      color: palette.base,
    );
    final gutterStyle = baseStyle.copyWith(
      color: colors.mutedForeground.withValues(alpha: 0.4),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          _DiffLineRow(
            key: ValueKey<String>(line.id),
            line: line,
            tokens: _highlightLine(line.content, language, palette),
            baseStyle: baseStyle,
            gutterStyle: gutterStyle,
            addColor: addColor,
            delColor: delColor,
          ),
      ],
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
    super.key,
  });

  final BeuiFileDiffLine line;
  final List<_CodeToken> tokens;
  final TextStyle baseStyle;
  final TextStyle gutterStyle;
  final Color addColor;
  final Color delColor;

  @override
  Widget build(BuildContext context) {
    final type = line.type;
    final bg = switch (type) {
      BeuiFileDiffLineType.added => _emerald500.withValues(alpha: 0.07),
      BeuiFileDiffLineType.removed => _rose500.withValues(alpha: 0.07),
      BeuiFileDiffLineType.context => null,
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

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text.rich(
              TextSpan(style: baseStyle, children: spans),
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );

    if (bg == null) return row;
    return ColoredBox(color: bg, child: row);
  }
}

// ---------------------------------------------------------------------------
// Lightweight highlighter (reduced Shiki substitute — no new deps)
// ---------------------------------------------------------------------------

@immutable
class _DiffPalette {
  const _DiffPalette({
    required this.base,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.entity,
    required this.punct,
  });

  // Shiki `github-light-high-contrast` / `github-dark-high-contrast` — the
  // themes the source's AgentCode highlighter is created with
  // (agent-code.tsx LIGHT_THEME / DARK_THEME).
  factory _DiffPalette.of(BeuiColors colors, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return _DiffPalette(
      // file-diff.tsx renders its grid with no `text-foreground/NN` dimming.
      base: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
      keyword: isLight ? const Color(0xFFA0111F) : const Color(0xFFFF9492),
      string: isLight ? const Color(0xFF032563) : const Color(0xFFADDCFF),
      comment: isLight ? const Color(0xFF4B535D) : const Color(0xFFBDC4CC),
      number: isLight ? const Color(0xFF023B95) : const Color(0xFF91CBFF),
      entity: isLight ? const Color(0xFF622CBC) : const Color(0xFFDBB7FF),
      punct: isLight ? const Color(0xFF0E1116) : const Color(0xFFF0F3F6),
    );
  }

  final Color base;
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color entity;
  final Color punct;
}

@immutable
class _CodeToken {
  const _CodeToken(this.text, this.color);
  final String text;
  final Color color;
}

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

List<_CodeToken> _highlightLine(
  String line,
  BeuiCodeLanguage language,
  _DiffPalette palette,
) {
  if (line.isEmpty) return const [];
  if (language == BeuiCodeLanguage.text) {
    return [_CodeToken(line, palette.base)];
  }
  if (language == BeuiCodeLanguage.diff) {
    if (line.startsWith('+') && !line.startsWith('+++')) {
      return [_CodeToken(line, palette.keyword)];
    }
    if (line.startsWith('-') && !line.startsWith('---')) {
      return [_CodeToken(line, palette.comment)];
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

List<_CodeToken> _highlightJson(String line, _DiffPalette palette) {
  final out = <_CodeToken>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '"') {
      final end = _scanString(line, i);
      final slice = line.substring(i, end);
      final after = line.substring(end).trimLeft();
      final isKey = after.startsWith(':');
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
  _DiffPalette palette,
  BeuiCodeLanguage language,
) {
  final out = <_CodeToken>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
      out.add(_CodeToken(line.substring(i), palette.comment));
      break;
    }
    if (language == BeuiCodeLanguage.bash && ch == '#') {
      out.add(_CodeToken(line.substring(i), palette.comment));
      break;
    }
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '*') {
      out.add(_CodeToken(line.substring(i), palette.comment));
      break;
    }
    if (ch == "'" || ch == '"' || ch == '`') {
      final end = _scanString(line, i, quote: ch);
      out.add(_CodeToken(line.substring(i, end), palette.string));
      i = end;
      continue;
    }
    if (_isDigit(ch) ||
        (ch == '.' && i + 1 < line.length && _isDigit(line[i + 1]))) {
      final end = _scanNumber(line, i);
      out.add(_CodeToken(line.substring(i, end), palette.number));
      i = end;
      continue;
    }
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
  return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;
}

bool _isIdentPart(String ch) {
  final c = ch.codeUnitAt(0);
  return _isIdentStart(ch) || _isDigit(ch) || c == 0x24;
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
    if (s[i] == q) return i + 1;
    i++;
  }
  return s.length;
}
