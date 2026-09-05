import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_status_colors.dart';
import '../theme/beui_agent_strings.dart';
import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_disclosure.dart';
import '_engine.dart';
import '_hit_target.dart';
import '_syntax.dart';
import '_viewport_follow.dart';
import 'action_swap.dart';
import 'tool_approval.dart' show beuiAgentPressScale;

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

/// Spinner period for the `running` glyph.
const _spinPeriod = Duration(milliseconds: 900);

/// Hover-in for the action-button chip. Its exit is [_hoverOut] — deliberately
/// shorter, per the repo rule that exits beat entrances (the audit's A19).
const _hoverIn = Duration(milliseconds: 150);

/// Hover-out for the action-button chip.
const _hoverOut = Duration(milliseconds: 110);

/// How long the "Copied" confirmation is held.
const _copiedHold = Duration(milliseconds: 1600);

/// Width below which the seven-element header wraps onto two lines (A15).
const double _twoLineBreakpoint = 400;

/// The output line box, in logical pixels — `text-xs` (12px) on `leading-5`
/// (20px). Used to translate a scroll extent into a line count (A22).
const double _outputLineHeight = 20;

/// Inner padding of the output viewport (source `p-3`).
///
/// There is no 12px role on [BeuiAgentLayout] — `cardPadding` is the 16px
/// `p-4` card role, and this is a nested panel — so the source value stands.
const EdgeInsets _outputPadding = EdgeInsets.all(12);

/// Height of the bottom fade over a capped, overflowing viewport (A22).
const double _fadeExtent = 24;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Maps a tool-result lifecycle onto the shared agent status tier, so one
/// [BeuiAgentTheme] override retints every agent surface at once (A36).
///
/// `cancelled` maps to [BeuiAgentStatus.neutral] rather than
/// [BeuiAgentStatus.denied]: a cancelled run is not a refusal, it simply did
/// not finish — see [BeuiAgentStrings.statusCancelled].
BeuiAgentStatus _agentStatus(BeuiToolResultStatus status) => switch (status) {
  BeuiToolResultStatus.running => BeuiAgentStatus.running,
  BeuiToolResultStatus.success => BeuiAgentStatus.success,
  BeuiToolResultStatus.error => BeuiAgentStatus.failed,
  BeuiToolResultStatus.cancelled => BeuiAgentStatus.neutral,
};

String _statusLabel(BeuiToolResultStatus status, BeuiAgentStrings strings) =>
    switch (status) {
      BeuiToolResultStatus.running => strings.statusRunning,
      BeuiToolResultStatus.success => strings.statusCompleted,
      BeuiToolResultStatus.error => strings.statusFailed,
      BeuiToolResultStatus.cancelled => strings.statusCancelled,
    };

IconData _kindIcon(BeuiToolResultKind kind, BeuiAgentIcons icons) =>
    switch (kind) {
      BeuiToolResultKind.terminal => icons.terminal,
      BeuiToolResultKind.request => icons.request,
      BeuiToolResultKind.custom => icons.tool,
    };

IconData _statusIcon(BeuiToolResultStatus status, BeuiAgentIcons icons) =>
    switch (status) {
      BeuiToolResultStatus.running => icons.spinner,
      BeuiToolResultStatus.success => LucideIcons.circle_check,
      BeuiToolResultStatus.error => LucideIcons.circle_x,
      BeuiToolResultStatus.cancelled => LucideIcons.ban,
    };

// ---------------------------------------------------------------------------
// BeuiToolResultOutput
// ---------------------------------------------------------------------------

/// Syntax-tinted terminal / request body text for use inside [BeuiToolResult]
/// — the Flutter port of beUI's `ToolResultOutput` (backed by `AgentCode`).
///
/// Highlighting comes from the shared tokenizer in `_syntax.dart`
/// ([beuiHighlightLine]) against [BeuiSyntaxPalette] — the Shiki
/// `github-*-high-contrast` themes the source builds its highlighter with. It
/// is a deliberately **reduced** port: a small scanner, not a lexer.
///
/// The body text is painted at full [BeuiColors.foreground]. It used to be
/// alpha-multiplied to 0.8, which dimmed the one thing on the card the reader
/// actually came for (the audit's A8 — never alpha-multiply
/// information-bearing text).
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
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final palette = BeuiSyntaxPalette.of(theme.brightness);
    final lines = code.split('\n');

    return DefaultTextStyle(
      // Source `AgentCode`: `font-mono text-xs leading-5` — a 20px line box at
      // 12px, not a relative leading. The family/size come from the theme's
      // mono role so a consumer can restyle every code surface at once (A37).
      style: agent.typography.mono.copyWith(
        height: _outputLineHeight / (agent.typography.mono.fontSize ?? 12),
        color: colors.foreground,
      ),
      child: SelectionArea(
        child: Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                ...beuiHighlightLine(lines[i], language, palette).map(
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

// ---------------------------------------------------------------------------
// BeuiToolResult
// ---------------------------------------------------------------------------

/// A lightweight execution disclosure for terminal output / request responses
/// that collapses into a compact completed state — the Flutter port of beUI's
/// `tool-result`.
///
/// **Layout.** A header row (kind icon · title · meta · slug · status · chevron)
/// toggles a disclosure panel. The body is a capped, scrollable viewport that
/// follows the live edge while [status] is [BeuiToolResultStatus.running].
///
/// Under [_twoLineBreakpoint] (400px) the header **wraps onto two lines** —
/// title and status on the first, metadata and tool slug on the second. Seven
/// elements in one row collapsed badly on a phone bubble (the audit's A15).
///
/// **Actions stay reachable.** Copy result / Run again render *outside* the
/// collapsible panel by default, so a completed-and-collapsed result can still
/// be copied or re-run. Set [keepActionsVisibleWhenCollapsed] to false for the
/// old behaviour, where the actions live inside the panel and disappear with it.
///
/// **Open state.** Controlled when [open] is non-null (drive via [onOpenChange]);
/// otherwise internal state seeded by [defaultOpen].
///
/// **`defaultOpen` policy (the audit's A42).** The rule across the agent family
/// is: *a surface that is still asking or still running opens; a historical
/// record collapses.* A tool result is a live process while it runs, so
/// entering `running` force-opens the panel; on completion it becomes a
/// record, so leaving `running` collapses it when [collapseOnComplete] is true.
/// [defaultOpen] therefore defaults to `true` — the common case is a result
/// mounted while it is still streaming. Mounting a finished result into a
/// scrollback should pass `defaultOpen: false`.
///
/// **Concurrent tool calls (the audit's A25).** There is no separate
/// "tool group" component, and there should not be: several tools running at
/// once is a [Column] of [BeuiToolResult]s inside one message, each with its
/// own [status], [tool], and body. They collapse and expand independently, and
/// each announces its own outcome.
///
/// ```dart
/// BeuiMessageContent(
///   children: [
///     for (final call in message.toolCalls)
///       BeuiToolResult(
///         key: ValueKey(call.id),
///         tool: call.tool,
///         title: call.title,
///         status: call.status,          // each has its own lifecycle
///         collapseOnComplete: true,     // finished calls fold away
///         copyText: call.output,
///         child: BeuiToolResultOutput(code: call.output),
///       ),
///   ],
/// )
/// ```
///
/// Give each one a stable [Key] so a call finishing out of order does not
/// hand its state to a sibling.
///
/// **Motion.** Chevron rotates on [beuiSpringSwap]; status / title / meta / tool
/// labels roll via [BeuiActionSwapText]; action buttons press-scale to
/// [beuiAgentPressScale] on [beuiSpringPress]; the disclosure opens in 220ms /
/// closes in 140ms [beuiEaseOut] via [BeuiAgentDisclosureInternal]. Every exit
/// is shorter than its entrance (A19). Reduced motion drops movement (scale,
/// translate, spin, chevron rotate) while keeping opacity / colour.
///
/// **API mapping** (source → Flutter):
/// * `tool` / `title` / `meta` → [tool] / [title] / [meta] (or the `…Widget`
///   siblings)
/// * `status` / `kind` / `icon` → [status] / [kind] / [icon]
/// * `open` / `defaultOpen` / `onOpenChange` → same
/// * `collapseOnComplete` / `maxHeight` / `copyText` / `onCopy` / `onRetry` → same
/// * `children` → [child]
class BeuiToolResult extends StatefulWidget {
  /// Creates a tool-result disclosure.
  ///
  /// Exactly one of [tool] / [toolWidget] and one of [title] / [titleWidget]
  /// must be supplied.
  const BeuiToolResult({
    required this.child,
    this.tool,
    this.toolWidget,
    this.title,
    this.titleWidget,
    this.meta,
    this.metaWidget,
    this.status = BeuiToolResultStatus.running,
    this.kind = BeuiToolResultKind.custom,
    this.icon,
    this.open,
    this.defaultOpen = true,
    this.onOpenChange,
    this.collapseOnComplete = true,
    this.keepActionsVisibleWhenCollapsed = true,
    this.maxHeight = 220,
    this.hiddenLineCount,
    this.copyText,
    this.onCopy,
    this.onRetry,
    this.copyLabel,
    this.copiedLabel,
    this.runAgainLabel,
    super.key,
  }) : assert(
         tool == null || toolWidget == null,
         'Pass either tool or toolWidget, not both.',
       ),
       assert(
         tool != null || toolWidget != null,
         'Pass one of tool or toolWidget.',
       ),
       assert(
         title == null || titleWidget == null,
         'Pass either title or titleWidget, not both.',
       ),
       assert(
         title != null || titleWidget != null,
         'Pass one of title or titleWidget.',
       ),
       assert(
         meta == null || metaWidget == null,
         'Pass either meta or metaWidget, not both.',
       );

  /// Body content — typically [BeuiToolResultOutput] or custom widgets.
  final Widget child;

  /// Tool slug shown mono beside the title (e.g. `terminal.run`).
  ///
  /// This is the string that says *what ran*, so it is painted at full
  /// [BeuiColors.mutedForeground] rather than alpha-multiplied down to a
  /// decoration (the audit's A8 / A14). For a non-text slug use [toolWidget].
  final String? tool;

  /// Widget form of [tool], for callers that need more than a string.
  final Widget? toolWidget;

  /// Primary header label.
  final String? title;

  /// Widget form of [title].
  final Widget? titleWidget;

  /// Compact trailing metadata next to the title (e.g. `"2.9s"`, `"429"`).
  final String? meta;

  /// Widget form of [meta].
  final Widget? metaWidget;

  /// Execution lifecycle (source `status`, default `running`).
  final BeuiToolResultStatus status;

  /// Kind icon when [icon] is null (source `kind`, default `custom`).
  final BeuiToolResultKind kind;

  /// Optional leading icon override (source `icon`). Defaults to a kind glyph.
  final Widget? icon;

  /// Controlled open state. When non-null, the widget does not hold internal
  /// open state (source `open`).
  final bool? open;

  /// Initial open state when uncontrolled (source `defaultOpen`, default true).
  /// See the `defaultOpen` policy note on [BeuiToolResult].
  final bool defaultOpen;

  /// Fired whenever open toggles (source `onOpenChange`).
  final ValueChanged<bool>? onOpenChange;

  /// Collapse the panel when status leaves `running` (source
  /// `collapseOnComplete`, default true).
  final bool collapseOnComplete;

  /// Keep Copy result / Run again mounted outside the collapsible panel, so
  /// they survive [collapseOnComplete] (default true).
  ///
  /// The actions used to live *inside* the disclosure, which meant a run that
  /// auto-collapsed on completion took its own copy button away at exactly the
  /// moment the reader wanted it. Pass false to restore that layout.
  final bool keepActionsVisibleWhenCollapsed;

  /// Max viewport height in logical pixels (source `maxHeight`, default 220).
  final double maxHeight;

  /// Number of output lines hidden below the fold, for callers that already
  /// know it (a paginated log, a truncated server response).
  ///
  /// Null (the default) derives the count from the output text — the [code] of
  /// a [BeuiToolResultOutput] child, else [copyText] — against the measured
  /// viewport. Either way the cue only appears while the content actually
  /// overflows (the audit's A22).
  final int? hiddenLineCount;

  /// Text written to the clipboard by the copy action (source `copyText`).
  final String? copyText;

  /// Optional override for the copy action (source `onCopy`). When null and
  /// [copyText] is set, the default is a clipboard write of [copyText].
  final FutureOr<void> Function()? onCopy;

  /// Optional retry handler — shows a "Run again" action (source `onRetry`).
  final VoidCallback? onRetry;

  /// Per-instance override for the copy action label. Falls back to
  /// [BeuiAgentStrings.copyResult].
  final String? copyLabel;

  /// Per-instance override for the copied confirmation. Falls back to
  /// [BeuiAgentStrings.copied].
  final String? copiedLabel;

  /// Per-instance override for the retry action label. Falls back to
  /// [BeuiAgentStrings.runAgain].
  final String? runAgainLabel;

  @override
  State<BeuiToolResult> createState() => _BeuiToolResultState();
}

class _BeuiToolResultState extends State<BeuiToolResult>
    with SingleTickerProviderStateMixin {
  /// F12: this viewport used to yank itself to the bottom on every streamed
  /// chunk with no notion of a reader who had scrolled up — the last unpinned
  /// streaming surface in the library. It now shares the code block's and the
  /// diff's follower, so scrolling away pins the viewport and raises the same
  /// "jump to latest" pill.
  late final BeuiLiveEdgeFollower _follow;

  /// Keeps the scroll view's element (and therefore its [ScrollPosition])
  /// alive across the overflow fade mounting and unmounting around it.
  final GlobalKey _viewportKey = GlobalKey();

  late bool _internalOpen;
  bool _copied = false;
  bool _copyHovered = false;
  bool _retryHovered = false;
  bool _copyPressed = false;
  bool _retryPressed = false;
  Timer? _copyTimer;
  late BeuiToolResultStatus _previousStatus;
  late final AnimationController _spin;

  /// Whether the capped viewport has content below the fold.
  bool _overflowing = false;

  /// Lines still hidden below the fold, or null when nothing is.
  int? _hiddenLines;

  bool get _running => widget.status == BeuiToolResultStatus.running;
  bool get _currentOpen => widget.open ?? _internalOpen;
  bool get _canCopy => widget.copyText != null || widget.onCopy != null;
  bool get _hasActions => _canCopy || widget.onRetry != null;

  /// The output text, when the widget can see it — the source of the hidden
  /// line count (A22).
  String? get _outputText {
    final child = widget.child;
    if (child is BeuiToolResultOutput) return child.code;
    return widget.copyText;
  }

  @override
  void initState() {
    super.initState();
    _internalOpen = widget.defaultOpen;
    _previousStatus = widget.status;
    _follow = BeuiLiveEdgeFollower(
      onPinnedChanged: () {
        if (mounted) setState(() {});
      },
    )..attach();
    _spin = AnimationController(vsync: this, duration: _spinPeriod);
    if (_running) {
      _spin.repeat();
      _scheduleFollow();
    }
  }

  @override
  void didUpdateWidget(covariant BeuiToolResult oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Status transitions drive open/collapse (source useEffect on status), per
    // the `defaultOpen` policy documented on the widget.
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
    _follow.dispose();
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

  /// Follows the live edge, unless the reader has pinned the viewport by
  /// scrolling away. Only a *running* tool with an open panel follows at all —
  /// a settled result has no live edge to chase.
  void _scheduleFollow() {
    if (!_currentOpen || !_running) return;
    _follow.follow(context);
  }

  /// Recomputes the overflow cue. Converges after one extra frame — it only
  /// calls [setState] when a value actually changed, so scheduling it from
  /// every build cannot loop.
  void _syncOverflow() {
    if (!mounted) return;
    var overflowing = false;
    int? hidden;

    if (_follow.controller.hasClients) {
      final pos = _follow.controller.position;
      final remaining = pos.maxScrollExtent - pos.pixels;
      // Below the fold by more than half a pixel — anything less is rounding.
      overflowing = remaining > 0.5;
      if (overflowing) hidden = _hiddenLinesFor(pos);
    }

    if (overflowing != _overflowing || hidden != _hiddenLines) {
      setState(() {
        _overflowing = overflowing;
        _hiddenLines = hidden;
      });
    }
  }

  /// Lines below the fold, derived from the output text when it is available
  /// and from the scroll extent otherwise.
  ///
  /// Soft-wrapped lines count once, so this is an approximation for very long
  /// lines — a deliberate one: it matches what the reader would count.
  int? _hiddenLinesFor(ScrollMetrics pos) {
    final explicit = widget.hiddenLineCount;
    if (explicit != null) return explicit > 0 ? explicit : null;

    final lineHeight = _outputLineHeight;
    final text = _outputText;
    if (text != null) {
      final total = text.split('\n').length;
      final viewport =
          pos.viewportDimension - _outputPadding.top - _outputPadding.bottom;
      final shown = math.max(1, (viewport / lineHeight).floor());
      final scrolledPast = (pos.pixels / lineHeight).floor();
      final hidden = total - shown - scrolledPast;
      return hidden > 0 ? hidden : null;
    }

    final hidden = ((pos.maxScrollExtent - pos.pixels) / lineHeight).ceil();
    return hidden > 0 ? hidden : null;
  }

  Future<void> _handleCopy() async {
    final custom = widget.onCopy;
    if (custom != null) {
      await custom();
    } else if (widget.copyText != null) {
      await Clipboard.setData(ClipboardData(text: widget.copyText!));
    }
    if (!mounted) return;
    // A30: the copy confirmation was visual only. Flipping `_copied` swaps the
    // button's semantic label *and* turns it into a live region for the length
    // of the confirmation, so the label change is announced. The revert is not
    // announced, because `liveRegion` goes back to false with it.
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(_copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final strings = agent.strings;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // A36/A7: every status colour comes from the themeable role set. The
    // light-mode foregrounds there are the 700 tier, which clears 4.5:1.
    final statusPalette = agent
        .statusColorsFor(theme.brightness)
        .palette(_agentStatus(widget.status));
    final statusColor = statusPalette.foreground;
    final statusLabel = _statusLabel(widget.status, strings);

    SchedulerBinding.instance.addPostFrameCallback((_) => _syncOverflow());

    return DefaultTextStyle.merge(
      style: agent.typography.assistantBody,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              constraints.hasBoundedWidth &&
              constraints.maxWidth < _twoLineBreakpoint;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(
                context,
                colors: colors,
                agent: agent,
                reduce: reduce,
                narrow: narrow,
                statusColor: statusColor,
                statusLabel: statusLabel,
              ),
              BeuiAgentDisclosureInternal(
                open: _currentOpen,
                reduce: reduce,
                child: _buildPanel(
                  context,
                  colors: colors,
                  agent: agent,
                  strings: strings,
                  reduce: reduce,
                  narrow: narrow,
                  statusLabel: statusLabel,
                ),
              ),
              if (widget.keepActionsVisibleWhenCollapsed && _hasActions)
                Padding(
                  padding: EdgeInsets.only(
                    left: agent.layout.iconSize + agent.layout.rowGap,
                    top: 2,
                  ),
                  child: _buildActions(
                    context,
                    colors: colors,
                    agent: agent,
                    strings: strings,
                    reduce: reduce,
                    // Redundant with the always-visible header status once the
                    // row lives outside the panel.
                    statusLabel: null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _buildHeader(
    BuildContext context, {
    required BeuiColors colors,
    required BeuiAgentTheme agent,
    required bool reduce,
    required bool narrow,
    required Color statusColor,
    required String statusLabel,
  }) {
    final gap = agent.layout.rowGap;

    final leading = SizedBox(
      width: agent.layout.iconSize,
      height: agent.layout.iconSize,
      child: Center(
        child:
            widget.icon ??
            Icon(
              _kindIcon(widget.kind, agent.icons),
              size: agent.layout.iconSize,
              color: colors.mutedForeground,
            ),
      ),
    );

    final title = _titleLabel(colors, agent);
    final meta = _metaLabel(colors, agent);
    final tool = _toolLabel(colors, agent);

    final status = Row(
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
          style: agent.typography.metadata.copyWith(
            fontWeight: FontWeight.w500,
            color: statusColor,
          ),
        ),
      ],
    );

    final chevron = _Chevron(
      open: _currentOpen,
      reduce: reduce,
      color: colors.mutedForeground,
    );

    final Widget content;
    if (narrow) {
      // A15: seven elements do not fit under 400px. Title + status lead; the
      // metadata and the slug drop to a second line, indented under the title.
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              leading,
              SizedBox(width: gap),
              Expanded(child: title),
              SizedBox(width: gap),
              status,
              SizedBox(width: gap),
              chevron,
            ],
          ),
          if (meta != null || tool != null)
            Padding(
              padding: EdgeInsets.only(
                left: agent.layout.iconSize + gap,
                top: 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ?meta,
                  if (meta != null && tool != null) SizedBox(width: gap),
                  if (tool != null) Flexible(child: tool),
                ],
              ),
            ),
        ],
      );
    } else {
      content = Row(
        children: [
          leading,
          SizedBox(width: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: title),
                if (meta != null) ...[SizedBox(width: gap), meta],
                SizedBox(width: gap),
                if (tool != null) Flexible(child: tool),
              ],
            ),
          ),
          SizedBox(width: gap),
          status,
          SizedBox(width: gap),
          chevron,
        ],
      );
    }

    // A30 + A31 + keyboard: one merged node carrying the label, the button
    // role, the expanded state, the tap action — and `liveRegion`, so a
    // terminal outcome ("Failed", "Cancelled") is announced. The old code put
    // `liveRegion` on the card and gated it on `running`, switching it off
    // exactly when the outcome arrived.
    return MergeSemantics(
      child: Semantics(
        liveRegion: true,
        expanded: _currentOpen,
        child: BeuiMinHitTarget(
          minSize: kMinInteractiveDimension,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _toggle,
              borderRadius: agent.shapes.chip,
              child: ConstrainedBox(
                // A31: the whole header is the toggle, and it is a real
                // 48px-tall target rather than 36px plus hit slop, so the
                // semantics rect passes the tap-target guidelines too.
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleLabel(BeuiColors colors, BeuiAgentTheme agent) {
    // 14 / w500 — the assistant body role plus medium weight. Full foreground:
    // the title is the primary string on the header.
    final style = agent.typography.assistantBody.copyWith(
      fontWeight: FontWeight.w500,
      color: colors.foreground,
    );
    final text = widget.title;
    if (text != null) {
      return BeuiActionSwapText(
        value: text,
        text: text,
        variant: BeuiActionSwapVariant.roll,
        style: style,
      );
    }
    return DefaultTextStyle.merge(style: style, child: widget.titleWidget!);
  }

  Widget? _metaLabel(BeuiColors colors, BeuiAgentTheme agent) {
    // A8: un-multiplied mutedForeground. It was `@0.6`.
    final style = agent.typography.status.copyWith(
      color: colors.mutedForeground,
    );
    final text = widget.meta;
    if (text != null) {
      return BeuiActionSwapText(
        value: text,
        text: text,
        variant: BeuiActionSwapVariant.roll,
        style: style,
      );
    }
    final custom = widget.metaWidget;
    if (custom == null) return null;
    return DefaultTextStyle.merge(style: style, child: custom);
  }

  Widget? _toolLabel(BeuiColors colors, BeuiAgentTheme agent) {
    // A8 / A14: the slug identifies *what ran*, so it gets the mono role at
    // full mutedForeground rather than 11px at `@0.55` (2.29:1).
    final style = agent.typography.mono.copyWith(color: colors.mutedForeground);
    final text = widget.tool;
    if (text != null) {
      return BeuiActionSwapText(
        value: text,
        text: text,
        variant: BeuiActionSwapVariant.roll,
        style: style,
      );
    }
    final custom = widget.toolWidget;
    if (custom == null) return null;
    return DefaultTextStyle.merge(style: style, child: custom);
  }

  // -------------------------------------------------------------------------
  // Panel
  // -------------------------------------------------------------------------

  Widget _buildPanel(
    BuildContext context, {
    required BeuiColors colors,
    required BeuiAgentTheme agent,
    required BeuiAgentStrings strings,
    required bool reduce,
    required bool narrow,
    required String statusLabel,
  }) {
    Widget viewport = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _syncOverflow();
            return false;
          },
          child: SingleChildScrollView(
            // F12: the ShaderMask below is mounted and unmounted as the
            // viewport starts and stops overflowing, which *re-parents* this
            // scroll view. Without a stable identity Flutter rebuilds the
            // element, and with it a fresh ScrollPosition at offset 0 — which
            // silently cancelled every follow animation the moment the fade
            // appeared. A GlobalKey moves the element instead of recreating it.
            key: _viewportKey,
            controller: _follow.controller,
            padding: _outputPadding,
            child: widget.child,
          ),
        ),
      ),
    );

    // A22 (a): a bottom fade over content that continues below the fold. Ported
    // from `agent_activity.dart`'s mask. Only mounted while the viewport
    // actually overflows, so it costs a saveLayer only when it earns one —
    // never over a fully visible, syntax-highlighted body (A18).
    if (_overflowing) {
      viewport = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final h = rect.height <= 0 ? 1.0 : rect.height;
          final stop = (1 - _fadeExtent / h).clamp(0.5, 1.0);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0.0, stop, 1.0],
          ).createShader(rect);
        },
        child: viewport,
      );
    }

    // F12: the way back to the live edge, stacked *outside* the ShaderMask so
    // the pill is not itself faded out by the overflow wash.
    viewport = Stack(
      children: [
        viewport,
        Positioned(
          right: 10,
          bottom: 8,
          child: BeuiJumpToLatest(
            visible: _running && _currentOpen && _follow.pinned,
            onTap: () => _follow.follow(context, force: true),
          ),
        ),
      ],
    );

    final hidden = _hiddenLines;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.8),
        borderRadius: agent.shapes.nested,
        // A38: `structure.borderWidth` was dead in this cluster. One hairline
        // gives the nested panel the same edge treatment as its siblings.
        border: Border.all(
          color: colors.border,
          width: agent.structure.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          viewport,
          // A22 (b): say how much is hidden. A fade alone reads as a styling
          // choice; a count reads as content.
          if (_overflowing && hidden != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                _outputPadding.left,
                0,
                _outputPadding.right,
                6,
              ),
              child: Text(
                // F13: the same copy the code block and the diff use for the
                // same fact, through the same field.
                strings.hiddenLines(hidden),
                style: agent.typography.metadata.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
          if (!widget.keepActionsVisibleWhenCollapsed && _hasActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: _buildActions(
                context,
                colors: colors,
                agent: agent,
                strings: strings,
                reduce: reduce,
                statusLabel: narrow ? null : statusLabel,
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Widget _buildActions(
    BuildContext context, {
    required BeuiColors colors,
    required BeuiAgentTheme agent,
    required BeuiAgentStrings strings,
    required bool reduce,
    required String? statusLabel,
  }) {
    final copiedLabel = widget.copiedLabel ?? strings.copied;
    final copyLabel = widget.copyLabel ?? strings.copyResult;
    final retryLabel = widget.runAgainLabel ?? strings.runAgain;

    return Row(
      children: [
        if (_canCopy)
          _ActionButton(
            label: _copied ? copiedLabel : copyLabel,
            // A30: announce the confirmation, not the idle label.
            liveRegion: _copied,
            pressed: _copyPressed,
            hovered: _copyHovered,
            reduce: reduce,
            colors: colors,
            agent: agent,
            onHover: (h) => setState(() => _copyHovered = h),
            onPressed: (p) => setState(() => _copyPressed = p),
            onTap: _handleCopy,
            child: Icon(
              _copied ? agent.icons.copied : agent.icons.copy,
              size: 14,
              color: _copyHovered ? colors.foreground : colors.mutedForeground,
            ),
          ),
        // A31: real spacing between the buttons, so the 48px slop of one does
        // not overhang the other and steal its taps.
        if (_canCopy && widget.onRetry != null)
          SizedBox(width: agent.layout.actionSpacing),
        if (widget.onRetry != null)
          _ActionButton(
            label: retryLabel,
            pressed: _retryPressed,
            hovered: _retryHovered,
            reduce: reduce,
            colors: colors,
            agent: agent,
            onHover: (h) => setState(() => _retryHovered = h),
            onPressed: (p) => setState(() => _retryPressed = p),
            onTap: widget.onRetry!,
            child: Icon(
              agent.icons.retry,
              size: 14,
              color: _retryHovered ? colors.foreground : colors.mutedForeground,
            ),
          ),
        const Spacer(),
        if (statusLabel != null)
          Flexible(
            child: BeuiActionSwapText(
              value: widget.status.name,
              text: statusLabel,
              variant: BeuiActionSwapVariant.roll,
              style: agent.typography.metadata.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
      ],
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
    final icon = Icon(
      _statusIcon(status, BeuiAgentTheme.of(context).icons),
      size: 12,
      color: color,
    );
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
      motion: motionFor(context, beuiSpringSwap, isMovement: true),
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180.0, child: child),
      child: icon,
    );
  }
}

/// A 48px icon action with a 28px painted chip.
///
/// The visual is unchanged from the source; the *box* is a full tap target so
/// the semantics rect clears the platform guidelines (A31). Hit slop alone
/// would not — `BeuiMinHitTarget` widens hit testing, not the semantics node —
/// so the target is real and the chip is centred inside it.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.liveRegion = false,
    required this.pressed,
    required this.hovered,
    required this.reduce,
    required this.colors,
    required this.agent,
    required this.onHover,
    required this.onPressed,
    required this.onTap,
    required this.child,
  });

  final String label;

  /// Announce [label] when it changes — used to voice "Copied".
  final bool liveRegion;
  final bool pressed;
  final bool hovered;
  final bool reduce;
  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onPressed;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pressTarget = (pressed && !reduce) ? beuiAgentPressScale : 1.0;

    final chip = SingleMotionBuilder(
      value: pressTarget,
      motion: motionFor(context, beuiSpringPress, isMovement: true),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        // Exit shorter than entrance (A19).
        duration: hovered ? _hoverIn : _hoverOut,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hovered ? colors.muted : Colors.transparent,
          borderRadius: agent.shapes.chip,
        ),
        child: child,
      ),
    );

    return Semantics(
      button: true,
      label: label,
      liveRegion: liveRegion,
      onTap: onTap,
      // One node carrying label + role + action, so a labelled-tap-target
      // check sees the label on the node that actually handles the tap.
      excludeSemantics: true,
      child: BeuiMinHitTarget(
        minSize: kMinInteractiveDimension,
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
              child: SizedBox.square(
                dimension: kMinInteractiveDimension,
                child: Center(child: chip),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
