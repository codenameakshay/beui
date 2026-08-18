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
import '_focus_ring.dart';
import '_hit_target.dart';
import 'loading_states.dart';

// ---------------------------------------------------------------------------
// Types — one-to-one port of agent-activity/types.ts
// ---------------------------------------------------------------------------

/// Run phase for [BeuiAgentActivity] (source `AgentActivityStatus`, extended
/// with the two failure phases the source has no representation for).
///
/// The source ships only [working] and [complete], so a crashed run summarised
/// as "Ran 3 tools" — indistinguishable from a run that succeeded. [failed] and
/// [cancelled] close that hole: each carries its own summary copy, its own
/// glyph, and its own status tier, so the outcome is encoded three ways
/// (shape + color + text) rather than being silently dropped.
enum BeuiAgentActivityStatus {
  /// Active stream — disclosure stays open; header shows a thinking shimmer.
  working,

  /// Finished stream — disclosure is collapsible with a summary trigger.
  complete,

  /// The run crashed or errored out. Summarises as `Failed · <detail>`, takes
  /// the [BeuiAgentStatus.failed] tier, and force-opens on arrival: the
  /// evidence of a failure is the one thing a reader needs.
  failed,

  /// The run was stopped before it finished. Summarises as
  /// `Cancelled · <detail>` and takes the quiet [BeuiAgentStatus.neutral] tier
  /// — stopping a run deliberately is not an error and should not read as one.
  cancelled,
}

extension _ActivityStatusRoles on BeuiAgentActivityStatus {
  /// Whether the run has stopped producing items.
  bool get isTerminal => this != BeuiAgentActivityStatus.working;

  /// Whether the terminal outcome is a failure the reader must not miss.
  /// Drives the card treatment and overrides `collapseOnComplete`.
  bool get isFailure =>
      this == BeuiAgentActivityStatus.failed ||
      this == BeuiAgentActivityStatus.cancelled;

  /// The shared status tier this phase paints from. Every color the header
  /// shows resolves through [BeuiAgentTheme.statusColorsFor] — there are no
  /// status color literals in this file.
  BeuiAgentStatus get tier => switch (this) {
    BeuiAgentActivityStatus.working => BeuiAgentStatus.running,
    BeuiAgentActivityStatus.complete => BeuiAgentStatus.success,
    BeuiAgentActivityStatus.failed => BeuiAgentStatus.failed,
    BeuiAgentActivityStatus.cancelled => BeuiAgentStatus.neutral,
  };

  /// The leading glyph on the completed summary, or null when the phase needs
  /// none. [BeuiAgentActivityStatus.complete] deliberately stays bare: the
  /// source's finished trace is quiet chrome, and only an outcome that
  /// contradicts "it worked" earns a mark.
  IconData? glyph(BeuiAgentIcons icons) => switch (this) {
    BeuiAgentActivityStatus.working || BeuiAgentActivityStatus.complete => null,
    BeuiAgentActivityStatus.failed => icons.warning,
    BeuiAgentActivityStatus.cancelled => icons.close,
  };
}

/// Status mark on a [BeuiAgentActivityStep] (source `AgentStepStatus`).
enum BeuiAgentStepStatus {
  /// Not started — hollow circle, dim label.
  pending,

  /// Currently running — pulsing dot.
  active,

  /// Done — check mark.
  complete,
}

/// Kind of activity content, plus [mixed] when the stream is heterogeneous
/// (source `AgentActivityContentType`).
enum BeuiAgentActivityContentType {
  /// Reasoning / checklist steps.
  step,

  /// Freeform text lines.
  text,

  /// Web search queries + results.
  search,

  /// Tool call rows (read / edit / run / …).
  tool,

  /// Structured execution-trace rows.
  trace,

  /// Heterogeneous mix of the above.
  mixed,
}

/// Trace-row glyph kind (source `AgentTraceKind`). Unknown strings fall through
/// to a wrench glyph.
enum BeuiAgentTraceKind {
  /// Sparkles — model thinking.
  thinking,

  /// Message bubble.
  message,

  /// Write / edit action.
  write,

  /// Shell / command run.
  run,

  /// Read / image inspect.
  read,

  /// Generic tool (fallback for unknown kinds).
  other,
}

/// One chronological entry in a [BeuiAgentActivity] stream
/// (source `AgentActivityItem`).
@immutable
sealed class BeuiAgentActivityItem {
  /// Creates an activity item with a stable [id] used as the list key.
  const BeuiAgentActivityItem({required this.id});

  /// Stable identity — keys enter/exit layout and list animation.
  final String id;

  /// Discriminator for content-type inference.
  BeuiAgentActivityContentType get contentType;
}

/// A checklist / reasoning step (source `AgentActivityStep`).
@immutable
class BeuiAgentActivityStep extends BeuiAgentActivityItem {
  /// Creates a step row.
  const BeuiAgentActivityStep({
    required super.id,
    required this.label,
    this.status = BeuiAgentStepStatus.complete,
    this.meta,
  });

  /// Step copy.
  final String label;

  /// Progress mark. Defaults to [BeuiAgentStepStatus.complete].
  final BeuiAgentStepStatus status;

  /// Optional trailing meta (e.g. timing).
  final String? meta;

  @override
  BeuiAgentActivityContentType get contentType =>
      BeuiAgentActivityContentType.step;
}

/// A freeform text line (source `AgentActivityText`).
@immutable
class BeuiAgentActivityText extends BeuiAgentActivityItem {
  /// Creates a text row.
  const BeuiAgentActivityText({required super.id, required this.content});

  /// Body copy.
  final String content;

  @override
  BeuiAgentActivityContentType get contentType =>
      BeuiAgentActivityContentType.text;
}

/// One result under a [BeuiAgentActivitySearch] (source `AgentSearchResult`).
@immutable
class BeuiAgentSearchResult {
  /// Creates a search result chip.
  const BeuiAgentSearchResult({
    required this.id,
    required this.title,
    this.domain,
    this.url,
    this.icon,
    this.onTap,
  });

  /// Stable identity for enter/exit animation.
  final String id;

  /// Result title.
  final String title;

  /// Optional domain label.
  final String? domain;

  /// Optional URL (data only — use [onTap] to open it).
  final String? url;

  /// Optional leading glyph; defaults to [LucideIcons.earth].
  final Widget? icon;

  /// Optional tap handler (e.g. open [url]).
  final VoidCallback? onTap;
}

/// A web-search activity row (source `AgentActivitySearch`).
@immutable
class BeuiAgentActivitySearch extends BeuiAgentActivityItem {
  /// Creates a search row.
  const BeuiAgentActivitySearch({
    required super.id,
    required this.query,
    this.results,
    this.moreCount,
  });

  /// Search query shown next to the search glyph.
  final String query;

  /// Optional nested results (animated in as they arrive).
  final List<BeuiAgentSearchResult>? results;

  /// Optional “+N more” footer count.
  final int? moreCount;

  @override
  BeuiAgentActivityContentType get contentType =>
      BeuiAgentActivityContentType.search;
}

/// A tool-call activity row (source `AgentActivityTool`).
@immutable
class BeuiAgentActivityTool extends BeuiAgentActivityItem {
  /// Creates a tool row.
  ///
  /// [action] is freeform; known values `read` / `edit` / `write` / `run` pick
  /// default glyphs. Any other string falls back to a wrench.
  const BeuiAgentActivityTool({
    required super.id,
    required this.action,
    required this.target,
    this.additions,
    this.deletions,
  });

  /// Verb shown capitalised (`read` → `Read`).
  final String action;

  /// Target path / command, mono-styled.
  final String target;

  /// Optional green “+N” diff count.
  final int? additions;

  /// Optional rose “−N” diff count.
  final int? deletions;

  @override
  BeuiAgentActivityContentType get contentType =>
      BeuiAgentActivityContentType.tool;
}

/// A structured execution-trace row (source `AgentActivityTrace`).
@immutable
class BeuiAgentActivityTrace extends BeuiAgentActivityItem {
  /// Creates a trace row.
  const BeuiAgentActivityTrace({
    required super.id,
    required this.kind,
    required this.label,
    this.detail,
    this.icon,
  });

  /// Glyph selector when [icon] is null.
  final BeuiAgentTraceKind kind;

  /// Primary label.
  final String label;

  /// Optional mono detail chip.
  final String? detail;

  /// Optional custom leading glyph.
  final Widget? icon;

  @override
  BeuiAgentActivityContentType get contentType =>
      BeuiAgentActivityContentType.trace;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Formats elapsed run time for the completed summary
/// (source `formatDuration` — whole seconds, `5s` / `2m` / `2m 5s`).
String beuiFormatAgentActivityDuration(num durationSeconds) {
  final seconds = math.max(0, durationSeconds.round());
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
}

BeuiAgentActivityContentType _inferContentType(
  List<BeuiAgentActivityItem> items,
  BeuiAgentActivityContentType? fallback,
) {
  if (items.isEmpty) return fallback ?? BeuiAgentActivityContentType.mixed;
  final first = items.first.contentType;
  for (final item in items) {
    if (item.contentType != first) return BeuiAgentActivityContentType.mixed;
  }
  return first;
}

String _activeLabelFor(
  BeuiAgentActivityContentType type,
  BeuiAgentStrings strings,
) {
  return switch (type) {
    BeuiAgentActivityContentType.search => strings.activitySearching,
    BeuiAgentActivityContentType.tool => strings.activityRunningTools,
    BeuiAgentActivityContentType.trace => strings.activityWorkingThroughRun,
    BeuiAgentActivityContentType.mixed => strings.activityWorking,
    BeuiAgentActivityContentType.step ||
    BeuiAgentActivityContentType.text => strings.activityThinking,
  };
}

/// Elapsed run time through the theme's duration formatters.
///
/// [beuiFormatAgentActivityDuration] is the same arithmetic against the stock
/// English strings; this variant exists so a localized [BeuiAgentStrings] can
/// re-spell `5s` / `2m` / `2m 5s` without the widget hardcoding the units.
String _formatDuration(num duration, BeuiAgentStrings strings) {
  final seconds = math.max(0, duration.round());
  if (seconds < 60) return strings.durationSeconds(seconds);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0
      ? strings.durationMinutes(minutes)
      : strings.durationMinutesSeconds(minutes, remainder);
}

/// The content half of the completed summary — what the run *did*, with no
/// judgement about whether it worked.
String _summaryDetail(
  BeuiAgentActivityContentType type,
  List<BeuiAgentActivityItem> items,
  num duration,
  BeuiAgentStrings strings,
) {
  switch (type) {
    case BeuiAgentActivityContentType.step:
    case BeuiAgentActivityContentType.text:
      return strings.activityThoughtFor(_formatDuration(duration, strings));
    case BeuiAgentActivityContentType.search:
      return strings.activitySearchedWeb;
    case BeuiAgentActivityContentType.tool:
      return strings.activityRanTools(items.length);
    case BeuiAgentActivityContentType.trace:
      final messages = items.where((item) {
        if (item is! BeuiAgentActivityTrace) return false;
        return item.kind == BeuiAgentTraceKind.thinking ||
            item.kind == BeuiAgentTraceKind.message;
      }).length;
      final tools = items.length - messages;
      return strings.activityToolCallsAndMessages(tools, messages);
    case BeuiAgentActivityContentType.mixed:
      return strings.activityCompletedSteps(items.length);
  }
}

/// The full summary string for a terminal phase.
///
/// [BeuiAgentActivityStatus.complete] reads as the bare detail ("Ran 3 tools").
/// A failure prefixes the outcome, so the same three tool calls read
/// "Failed · Ran 3 tools" and can never be mistaken for a clean finish.
String _summaryTextFor({
  required BeuiAgentActivityStatus status,
  required BeuiAgentActivityContentType type,
  required List<BeuiAgentActivityItem> items,
  required num duration,
  required BeuiAgentStrings strings,
  required String? failedOverride,
  required String? cancelledOverride,
}) {
  final detail = _summaryDetail(type, items, duration, strings);
  switch (status) {
    case BeuiAgentActivityStatus.working:
    case BeuiAgentActivityStatus.complete:
      return detail;
    case BeuiAgentActivityStatus.failed:
      return failedOverride ?? strings.activityFailedSummary(detail);
    case BeuiAgentActivityStatus.cancelled:
      return cancelledOverride ?? strings.activityCancelledSummary(detail);
  }
}

// Item enter: opacity 180ms EASE_OUT + y SPRING_LAYOUT (source motion.div).
const _itemOpacityMotion = CurvedMotion(
  Duration(milliseconds: 180),
  beuiEaseOut,
);

// The disclosure's 220ms open / 140ms close now live once, in
// `_disclosure.dart` (beuiDisclosureOpenMotion / beuiDisclosureCloseMotion),
// shared by every collapsible agent surface.
//
// The diff-count colors that used to be Tailwind literals here now resolve
// from BeuiAgentStatusColors: `+N` is the success tier, `−N` the failed tier.

// ---------------------------------------------------------------------------
// BeuiAgentActivity
// ---------------------------------------------------------------------------

/// One adaptive activity stream for reasoning, searches, tool calls, structured
/// execution traces, or a chronological mix — the Flutter port of beUI's
/// `agent-activity`.
///
/// While [status] is [BeuiAgentActivityStatus.working] the panel stays open,
/// the header shows a [BeuiThinkingShimmer], and the list glides so the latest
/// entry stays visible within [maxHeight]. On complete it collapses (when
/// [collapseOnComplete]) into a tappable summary with a rotating chevron.
///
/// A run that ends in [BeuiAgentActivityStatus.failed] or
/// [BeuiAgentActivityStatus.cancelled] additionally gets a card shell — an
/// emphasis-width border in the failed tier, a hairline in the neutral tier —
/// so a bad outcome is legible before a word of it is read.
///
/// Controlled when [open] is non-null; otherwise seeds from [defaultOpen].
/// Reduced motion drops the stream glide, chevron spin, and item rise while
/// keeping opacity fades.
class BeuiAgentActivity extends StatefulWidget {
  /// Creates an agent activity stream over [items].
  const BeuiAgentActivity({
    required this.items,
    this.contentType,
    this.status = BeuiAgentActivityStatus.working,
    this.duration = 0,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.collapseOnComplete = true,
    this.activeLabel,
    this.summary,
    this.failedSummary,
    this.cancelledSummary,
    this.maxHeight = 208,
    this.style,
    this.contentPadding,
    super.key,
  });

  /// Chronological activity entries. Append or update items as events stream.
  final List<BeuiAgentActivityItem> items;

  /// Expected activity kind before the first streamed item arrives.
  final BeuiAgentActivityContentType? contentType;

  /// Current run phase. Active runs always stay expanded.
  final BeuiAgentActivityStatus status;

  /// Elapsed run time, in seconds. Used by the step/text summary.
  final num duration;

  /// Controlled expanded state used after the run completes.
  final bool? open;

  /// Initial expanded state used after the run completes.
  ///
  /// Defaults to `false`, and the cluster policy is why: **a finished trace is
  /// a historical record, so it collapses; a surface that is still running or
  /// still asking stays open.** An activity stream is the archive of work
  /// already done — the summary line ("Ran 3 tools") is the answer, and the
  /// step-by-step is evidence you open only when you doubt it. Compare
  /// `BeuiTodoList.defaultOpen`, which is `true` for exactly the opposite
  /// reason: an in-flight task list is live state.
  ///
  /// This seeds the *initial* state only. A run that is still
  /// [BeuiAgentActivityStatus.working] is always expanded regardless, and a run
  /// that fails force-opens — see [collapseOnComplete].
  final bool defaultOpen;

  /// Called when the completed activity disclosure changes state.
  final ValueChanged<bool>? onOpenChange;

  /// Collapse the disclosure when the run finishes cleanly.
  ///
  /// Applies to [BeuiAgentActivityStatus.complete] only. A transition into
  /// [BeuiAgentActivityStatus.failed] or [BeuiAgentActivityStatus.cancelled]
  /// force-opens the panel whatever this is set to: hiding the steps that led
  /// to a crash behind a chevron is the exact failure this component's error
  /// states exist to prevent.
  final bool collapseOnComplete;

  /// Optional label shown while the run is active.
  ///
  /// Overrides the content-type default from [BeuiAgentStrings]
  /// (`activityThinking`, `activitySearching`, …).
  final String? activeLabel;

  /// Optional completed summary. Derived from the item types by default.
  ///
  /// Takes precedence over [failedSummary] and [cancelledSummary] — supply a
  /// widget only when you want to own the whole line, including the failure
  /// prefix and the glyph's label.
  final Widget? summary;

  /// Replaces the whole summary line when [status] is
  /// [BeuiAgentActivityStatus.failed].
  ///
  /// Overrides [BeuiAgentStrings.activityFailedSummary], which composes
  /// `"Failed · <detail>"` by default — e.g. `"Failed · Ran 3 tools"`. Set
  /// this to spell the failure out ("Failed · rate limited after 3 tools").
  final String? failedSummary;

  /// Replaces the whole summary line when [status] is
  /// [BeuiAgentActivityStatus.cancelled]. Overrides
  /// [BeuiAgentStrings.activityCancelledSummary], which composes
  /// `"Cancelled · <detail>"` by default.
  final String? cancelledSummary;

  /// Maximum visible activity height before the stream begins gliding
  /// (source default `208`).
  final double maxHeight;

  /// Optional style override for the root text size (source `text-sm`).
  final TextStyle? style;

  /// Optional padding around the activity list (source content `py-2` + gaps).
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<BeuiAgentActivity> createState() => _BeuiAgentActivityState();
}

class _BeuiAgentActivityState extends State<BeuiAgentActivity> {
  late bool _internalOpen = widget.defaultOpen;
  BeuiAgentActivityStatus _previousStatus = BeuiAgentActivityStatus.working;
  final GlobalKey _contentKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  double _contentHeight = 0;

  bool get _isControlled => widget.open != null;
  bool get _currentOpen => widget.open ?? _internalOpen;
  bool get _working => widget.status == BeuiAgentActivityStatus.working;
  bool get _expanded => _working || _currentOpen;

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.status;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(BeuiAgentActivity old) {
    super.didUpdateWidget(old);
    // working → terminal: seed open from collapseOnComplete (source useEffect).
    // A failure ignores collapseOnComplete and forces the panel open — see
    // [BeuiAgentActivity.collapseOnComplete].
    if (_previousStatus == BeuiAgentActivityStatus.working &&
        widget.status.isTerminal) {
      _setOpen(widget.status.isFailure || !widget.collapseOnComplete);
    }
    _previousStatus = widget.status;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (!_isControlled) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
  }

  void _toggle() {
    final next = !_currentOpen;
    _setOpen(next);
    if (next) {
      // Source: requestAnimationFrame → scrollTo top on expand.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  void _measure() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _contentHeight).abs() > 0.5) {
      setState(() => _contentHeight = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final agent = BeuiAgentTheme.of(context);
    final strings = agent.strings;
    final statusColors = agent.statusColorsFor(theme.brightness);
    final palette = statusColors.palette(widget.status.tier);
    final rowTheme = _RowTheme(
      colors: colors,
      agent: agent,
      statusColors: statusColors,
    );
    final reduce = MediaQuery.disableAnimationsOf(context);

    final contentType = _inferContentType(widget.items, widget.contentType);
    final liveLabel =
        widget.activeLabel ?? _activeLabelFor(contentType, strings);
    final summaryText = _summaryTextFor(
      status: widget.status,
      type: contentType,
      items: widget.items,
      duration: widget.duration,
      strings: strings,
      failedOverride: widget.failedSummary,
      cancelledOverride: widget.cancelledSummary,
    );

    // A24: reserve only what the stream actually occupies. The panel used to
    // hold the full `maxHeight` open for the whole run, so a single-item run
    // showed one row over ~180px of blank. `min` keeps the cap as a *ceiling*
    // rather than a floor; once the content outgrows it the viewport pins at
    // maxHeight and the stream glides underneath exactly as before.
    final maxH = math.max(0.0, widget.maxHeight);
    final viewportHeight = math.min(_contentHeight, maxH);
    final capped = _contentHeight > maxH;
    final streamOffset = _working
        ? math.min(0.0, viewportHeight - _contentHeight)
        : 0.0;

    final baseStyle =
        widget.style ??
        agent.typography.description.copyWith(
          // Tailwind tracking is `normal`. Pin it at the root so an ambient
          // Material text theme (bodyMedium letterSpacing 0.25) cannot leak
          // into every row and widen the stream.
          letterSpacing: 0,
          color: colors.foreground,
        );

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: shimmer while working, summary + chevron once terminal.
        if (_working)
          SizedBox(
            height: 28, // h-7
            child: Align(
              alignment: Alignment.centerLeft,
              // The label is announced by the live region wrapping this
              // header; letting the shimmer's own text node through would
              // read it twice.
              child: ExcludeSemantics(
                child: BeuiThinkingShimmer(
                  text: liveLabel,
                  style: baseStyle.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
        else
          _SummaryTrigger(
            expanded: _expanded,
            summary: widget.summary,
            summaryText: summaryText,
            glyph: widget.status.glyph(agent.icons),
            glyphColor: palette.foreground,
            emphasize: widget.status.isFailure,
            muted: colors.mutedForeground,
            foreground: colors.foreground,
            agent: agent,
            reduce: reduce,
            onTap: _toggle,
          ),
        BeuiAgentDisclosureInternal(
          open: _expanded,
          openHeight: viewportHeight,
          reduce: reduce,
          child: _StreamViewport(
            height: viewportHeight,
            capped: capped,
            working: _working,
            expanded: _expanded,
            streamOffset: streamOffset,
            reduce: reduce,
            scrollController: _scrollController,
            contentKey: _contentKey,
            contentPadding: widget.contentPadding,
            items: widget.items,
            rowTheme: rowTheme,
            onLayout: _measure,
          ),
        ),
      ],
    );

    // A37/A38: a failure earns a card. `decorateCard` carries the theme's
    // surface decision (muted fill, or glass + backdrop blur when
    // `useGlassSurfaces` is on); the ring on top is drawn in the status tier at
    // `emphasisBorderWidth` for a crash and the ordinary `borderWidth` for a
    // cancellation — stopping a run on purpose is not an emergency.
    if (widget.status.isFailure) {
      content = agent.decorateCard(
        colors: colors,
        child: Padding(padding: agent.layout.cardPadding, child: content),
      );
      content = DecoratedBox(
        // Foreground, so the ring sits on the card edge instead of being
        // painted over by the fill.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: agent.shapes.card,
          border: Border.all(
            color: palette.border,
            width: widget.status == BeuiAgentActivityStatus.failed
                ? agent.structure.emphasisBorderWidth
                : agent.structure.borderWidth,
          ),
        ),
        child: content,
      );
    }

    return DefaultTextStyle.merge(
      style: baseStyle,
      child: Semantics(
        container: true,
        // A30: the old `liveRegion: _working` switched the announcement off at
        // exactly the moment the outcome arrived, so "Failed" was never spoken.
        // The region is now always live and its label carries the phase, so it
        // announces once per transition — including the terminal one — and
        // stays quiet while nothing changes.
        liveRegion: true,
        explicitChildNodes: true,
        label: _announcement(strings, liveLabel),
        child: content,
      ),
    );
  }

  /// What the live region says for the current phase. Deliberately independent
  /// of the expanded state: a disclosure toggle must not re-announce.
  String _announcement(BeuiAgentStrings strings, String liveLabel) {
    return switch (widget.status) {
      BeuiAgentActivityStatus.working => liveLabel,
      BeuiAgentActivityStatus.complete => strings.statusCompleted,
      BeuiAgentActivityStatus.failed => strings.statusFailed,
      BeuiAgentActivityStatus.cancelled => strings.statusCancelled,
    };
  }
}

// ---------------------------------------------------------------------------
// Summary trigger (complete state)
// ---------------------------------------------------------------------------

/// The completed-run summary line: a real disclosure button.
///
/// A32: this used to be focusable and nothing else — no role, no name, no
/// expanded state, no keyboard activation, and a focus "ring" drawn as a
/// border inside the box model (which shifted the summary 2px on focus). It is
/// now a labelled `button` carrying its `expanded` state, activated by Enter
/// and Space, ringed by [BeuiFocusRing] outside layout, and hit-testable across
/// the full 44px floor via [BeuiMinHitTarget].
class _SummaryTrigger extends StatefulWidget {
  const _SummaryTrigger({
    required this.expanded,
    required this.summary,
    required this.summaryText,
    required this.glyph,
    required this.glyphColor,
    required this.emphasize,
    required this.muted,
    required this.foreground,
    required this.agent,
    required this.reduce,
    required this.onTap,
  });

  final bool expanded;

  /// A caller-supplied summary widget, or null to render [summaryText].
  final Widget? summary;

  /// The derived summary string. Doubles as the button's accessible name when
  /// [summary] is null.
  final String summaryText;

  /// Outcome glyph, or null for a phase that needs none.
  final IconData? glyph;

  /// Status-tier color for [glyph] and, when [emphasize] is set, the text.
  final Color glyphColor;

  /// Whether this outcome is a failure. Failures keep the status color on the
  /// summary text at rest; a clean finish stays quiet chrome, as in the source.
  final bool emphasize;

  final Color muted;
  final Color foreground;
  final BeuiAgentTheme agent;
  final bool reduce;
  final VoidCallback onTap;

  @override
  State<_SummaryTrigger> createState() => _SummaryTriggerState();
}

class _SummaryTriggerState extends State<_SummaryTrigger> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() => widget.onTap();

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final active = _hovered || _focused;
    final restColor = widget.emphasize ? widget.glyphColor : widget.muted;
    final color = active ? widget.foreground : restColor;
    final chevronColor = active
        ? widget.foreground
        // Decorative chrome, not information — the alpha stays.
        : widget.muted.withValues(alpha: 0.7);

    final label = widget.agent.typography.description.copyWith(
      color: color,
      fontWeight: FontWeight.w500,
      // Tabular figures keep the duration from jittering as it counts.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget summary =
        widget.summary ??
        Text(
          widget.summaryText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: label,
        );

    Widget row = SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.glyph != null) ...[
            Icon(
              widget.glyph,
              size: agent.layout.iconSize,
              color: widget.glyphColor,
            ),
            const SizedBox(width: 6), // gap-1.5
          ],
          Flexible(
            child: DefaultTextStyle.merge(style: label, child: summary),
          ),
          const SizedBox(width: 6), // gap-1.5
          _Chevron(
            expanded: widget.expanded,
            color: chevronColor,
            reduce: widget.reduce,
          ),
        ],
      ),
    );

    row = BeuiFocusRing(
      focused: _focused,
      borderRadius: agent.shapes.chip,
      width: agent.structure.emphasisBorderWidth,
      child: row,
    );

    // A31. The 28px visual keeps its source geometry (`h-7`); only the hit
    // area grows, and the 8px of bottom slop lands in the stream's own `py-2`
    // padding where nothing else is interactive.
    //
    // This has to be the *outermost* box. Every proxy above it — the semantics
    // annotation, the focus detector's `MouseRegion` — does the standard
    // `size.contains(position)` check in `RenderBox.hitTest` and rejects an
    // out-of-bounds pointer before the slop is ever consulted.
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        expanded: widget.expanded,
        label: widget.summary == null ? widget.summaryText : null,
        // Load-bearing: `excludeSemantics` below drops the gesture detector's
        // own tap action, so without this the node would advertise `button`
        // with no way for a screen reader to press it.
        onTap: _activate,
        // Only swallow the child's own semantics when this node names itself;
        // a caller-supplied summary widget keeps its own tree.
        excludeSemantics: widget.summary == null,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (v) {
            if (mounted) setState(() => _focused = v);
          },
          onShowHoverHighlight: (v) {
            if (mounted) setState(() => _hovered = v);
          },
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _activate,
            child: Align(alignment: Alignment.centerLeft, child: row),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.expanded,
    required this.color,
    required this.reduce,
  });

  final bool expanded;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final target = expanded ? math.pi : 0.0;
    final icon = Icon(
      BeuiAgentTheme.of(context).icons.expand,
      size: 14, // size-3.5
      color: color,
    );
    if (reduce) {
      return Transform.rotate(angle: target, child: icon);
    }
    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, beuiSpringSwap, isMovement: true),
      builder: (context, angle, child) =>
          Transform.rotate(angle: angle, child: child),
      child: icon,
    );
  }
}

// The private `_AgentDisclosure` that used to live here — one of eight
// near-identical copies across the agent family, and the one that hard-cut
// under reduced motion — is gone. `BeuiAgentDisclosureInternal`
// (`_disclosure.dart`) replaces it, taking this component's fixed viewport
// height through its `openHeight` parameter so the stream cannot reflow
// mid-reveal, and keeping a ~120ms opacity cross-fade when movement is off.

// ---------------------------------------------------------------------------
// Stream viewport + list
// ---------------------------------------------------------------------------

/// The resolved theming an activity row paints from.
///
/// One bundle instead of three parallel parameters on every row: the palette
/// ([BeuiColors]), the semantic agent contract ([BeuiAgentTheme] — type,
/// shape, layout, strings, icons), and the status tiers. A37: before this,
/// `agent_activity` read *zero* theme roles; every size, radius, gap, and
/// status color was a literal.
@immutable
class _RowTheme {
  const _RowTheme({
    required this.colors,
    required this.agent,
    required this.statusColors,
  });

  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final BeuiAgentStatusColors statusColors;

  BeuiAgentStrings get strings => agent.strings;
  BeuiAgentTypography get type => agent.typography;
  BeuiAgentLayout get layout => agent.layout;
  BeuiAgentShapes get shapes => agent.shapes;

  /// The 14/20 body role every activity row shares (source `text-sm
  /// leading-5`).
  TextStyle get body => type.description;

  BeuiAgentStatusPalette palette(BeuiAgentStatus status) =>
      statusColors.palette(status);
}

class _StreamViewport extends StatelessWidget {
  const _StreamViewport({
    required this.height,
    required this.capped,
    required this.working,
    required this.expanded,
    required this.streamOffset,
    required this.reduce,
    required this.scrollController,
    required this.contentKey,
    required this.contentPadding,
    required this.items,
    required this.rowTheme,
    required this.onLayout,
  });

  final double height;
  final bool capped;
  final bool working;
  final bool expanded;
  final double streamOffset;
  final bool reduce;
  final ScrollController scrollController;
  final GlobalKey contentKey;
  final EdgeInsetsGeometry? contentPadding;
  final List<BeuiAgentActivityItem> items;
  final _RowTheme rowTheme;
  final VoidCallback onLayout;

  @override
  Widget build(BuildContext context) {
    final canScroll = capped && expanded && !working;

    Widget list = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        SchedulerBinding.instance.addPostFrameCallback((_) => onLayout());
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(
          key: contentKey,
          child: Padding(
            padding:
                contentPadding ??
                const EdgeInsets.symmetric(vertical: 8), // py-2
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2), // space-y-0.5
                  _EnterAnim(
                    key: ValueKey<String>(items[i].id),
                    reduce: reduce,
                    child: _ActivityRow(item: items[i], rowTheme: rowTheme),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Stream sticks to bottom while working (source animate y: streamOffset).
    list = SingleMotionBuilder(
      value: streamOffset,
      motion: reduce
          ? const NoMotion()
          : motionFor(context, beuiSpringLayout, isMovement: true),
      builder: (context, y, child) =>
          Transform.translate(offset: Offset(0, y), child: child),
      child: list,
    );

    Widget viewport = SizedBox(
      height: height,
      child: canScroll
          ? SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: list,
            )
          : ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: list,
              ),
            ),
    );

    // Fade masks (source maskImage). Working: top only. Complete capped: both.
    // This is the reference scroll affordance for the whole agent family (the
    // audit's R12/A22 point at it) — behaviour preserved verbatim.
    if (capped && expanded) {
      final h = height <= 0 ? 1.0 : height;
      final topStop = (12 / h).clamp(0.0, 0.5);
      final bottomStop = (1 - 12 / h).clamp(0.5, 1.0);
      viewport = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: working
              ? const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000)]
              : const [
                  Color(0x00000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x00000000),
                ],
          stops: working
              ? [0.0, topStop, 1.0]
              : [0.0, topStop, bottomStop, 1.0],
        ).createShader(rect),
        child: viewport,
      );
    }

    return viewport;
  }
}

// ---------------------------------------------------------------------------
// Enter animation shell
// ---------------------------------------------------------------------------

/// Item entrance: an 180ms opacity ease and a 6→0px spring rise.
///
/// A18: this used to nest two [SingleMotionBuilder]s and rebuild an [Opacity]
/// widget every frame. The two channels genuinely need different motions (a
/// curve for the fade, a spring for the rise), so they are driven by two
/// controllers instead — the fade through [FadeTransition], which updates an
/// opacity layer without rebuilding anything, and the rise through a single
/// [AnimatedBuilder] whose `child` is passed through untouched.
class _EnterAnim extends StatefulWidget {
  const _EnterAnim({required this.reduce, required this.child, super.key});

  final bool reduce;
  final Widget child;

  @override
  State<_EnterAnim> createState() => _EnterAnimState();
}

class _EnterAnimState extends State<_EnterAnim> with TickerProviderStateMixin {
  late final SingleMotionController _fade;
  late final SingleMotionController _rise;

  @override
  void initState() {
    super.initState();
    // Reduced motion lands settled on the first frame: opacity 1, no offset.
    // The fade is not *dropped* — there is simply nothing to fade in from,
    // because the row is already present when the panel appears.
    _fade = SingleMotionController(
      vsync: this,
      motion: _itemOpacityMotion,
      initialValue: widget.reduce ? 1 : 0,
    );
    _rise = SingleMotionController(
      vsync: this,
      motion: widget.reduce ? const NoMotion() : beuiSpringLayout,
      initialValue: widget.reduce ? 0 : 1,
    );
    if (!widget.reduce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fade.animateTo(1);
        _rise.animateTo(0);
      });
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _rise,
        builder: (context, child) => Transform.translate(
          // Source enter y: 6 → 0; exit would be -3 (unused, append-only).
          offset: Offset(0, 6 * _rise.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity rows
// ---------------------------------------------------------------------------

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.rowTheme});

  final BeuiAgentActivityItem item;
  final _RowTheme rowTheme;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      BeuiAgentActivityText(:final content) => _TextRow(
        content: content,
        rowTheme: rowTheme,
      ),
      BeuiAgentActivitySearch() => _SearchRow(
        item: item as BeuiAgentActivitySearch,
        rowTheme: rowTheme,
      ),
      BeuiAgentActivityTool() => _ToolRow(
        item: item as BeuiAgentActivityTool,
        rowTheme: rowTheme,
      ),
      BeuiAgentActivityTrace() => _TraceRow(
        item: item as BeuiAgentActivityTrace,
        rowTheme: rowTheme,
      ),
      BeuiAgentActivityStep() => _StepRow(
        item: item as BeuiAgentActivityStep,
        rowTheme: rowTheme,
      ),
    };
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.item, required this.rowTheme});

  final BeuiAgentActivityStep item;
  final _RowTheme rowTheme;

  @override
  Widget build(BuildContext context) {
    final colors = rowTheme.colors;
    final state = item.status;
    // A8: the step label and its timing are the content of this row, not
    // chrome. They used to be `mutedForeground` at 55% alpha — ~2.3:1. The
    // pending/complete distinction is carried by the mark, which is where a
    // status difference belongs.
    final labelColor = state == BeuiAgentStepStatus.pending
        ? colors.mutedForeground
        : colors.foreground.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 4,
      ), // px-1.5 py-1
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2), // mt-0.5
            child: SizedBox(
              width: rowTheme.layout.iconSize,
              height: rowTheme.layout.iconSize,
              child: Center(
                child: _StepMark(status: state, rowTheme: rowTheme),
              ),
            ),
          ),
          const SizedBox(width: 10), // gap-2.5
          Expanded(
            child: Text(
              item.label,
              style: rowTheme.body.copyWith(color: labelColor),
            ),
          ),
          if (item.meta != null) ...[
            const SizedBox(width: 10),
            Text(
              item.meta!,
              style: rowTheme.body.copyWith(color: colors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepMark extends StatefulWidget {
  const _StepMark({required this.status, required this.rowTheme});

  final BeuiAgentStepStatus status;
  final _RowTheme rowTheme;

  @override
  State<_StepMark> createState() => _StepMarkState();
}

class _StepMarkState extends State<_StepMark>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didUpdateWidget(_StepMark old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _syncPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  void _syncPulse() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final active = widget.status == BeuiAgentStepStatus.active;
    if (active && !reduce) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      if (!_pulse!.isAnimating) _pulse!.repeat(reverse: true);
    } else {
      _pulse?.stop();
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.rowTheme.colors;
    // Decorative chrome: the mark repeats what the label already says, so the
    // alpha stays (A8 is about information-bearing text).
    final muted = colors.mutedForeground.withValues(alpha: 0.7);
    final iconSize = widget.rowTheme.layout.iconSize;
    return switch (widget.status) {
      BeuiAgentStepStatus.complete => Icon(
        widget.rowTheme.agent.icons.approved,
        size: iconSize,
        color: muted,
      ),
      BeuiAgentStepStatus.pending => Icon(
        LucideIcons.circle,
        size: 12,
        color: muted,
      ),
      BeuiAgentStepStatus.active => SizedBox(
        width: 12,
        height: 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo: `bg-foreground/10` with opacity pulse [0.35, 0.8].
            if (_pulse != null)
              FadeTransition(
                opacity: _pulse!.drive(Tween<double>(begin: 0.35, end: 0.8)),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.foreground.withValues(alpha: 0.1),
                  ),
                ),
              )
            else
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.foreground.withValues(alpha: 0.1),
                ),
              ),
            Container(
              width: 6, // size-1.5
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.foreground.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.content, required this.rowTheme});

  final String content;
  final _RowTheme rowTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        content,
        style: rowTheme.body.copyWith(color: rowTheme.colors.mutedForeground),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.item, required this.rowTheme});

  final BeuiAgentActivitySearch item;
  final _RowTheme rowTheme;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = rowTheme.colors;
    final results = item.results ?? const <BeuiAgentSearchResult>[];
    // A31: a tappable result row is ~28px tall against a 44px floor, and the
    // slop that fixes that overhangs its neighbours. Where the rows are
    // actually interactive the visual gap opens up to match, because hit slop
    // is not a substitute for spacing controls apart.
    final interactive = results.any((r) => r.onTap != null || r.url != null);
    final resultGap = interactive ? rowTheme.layout.actionSpacing : 2.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Icon(
                rowTheme.agent.icons.search,
                size: rowTheme.layout.iconSize,
                color: colors.mutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rowTheme.body.copyWith(color: colors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: rowTheme.layout.sectionSpacing,
            ), // pl-4
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < results.length; i++) ...[
                  if (i > 0) SizedBox(height: resultGap),
                  _EnterAnim(
                    key: ValueKey<String>(results[i].id),
                    reduce: reduce,
                    child: _SearchResultRow(
                      result: results[i],
                      rowTheme: rowTheme,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (item.moreCount != null && item.moreCount! > 0)
          _EnterAnim(
            key: const ValueKey<String>('more-results'),
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                32,
                4,
                6,
                4,
              ), // pl-8 px-1.5 py-1
              child: Text(
                // A8: "+5 more" is a count, not decoration — full muted
                // contrast, no alpha multiplier.
                rowTheme.strings.activityMoreResults(item.moreCount!),
                style: rowTheme.body.copyWith(color: colors.mutedForeground),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.rowTheme});

  final BeuiAgentSearchResult result;
  final _RowTheme rowTheme;

  @override
  Widget build(BuildContext context) {
    final colors = rowTheme.colors;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child:
                  result.icon ??
                  Icon(
                    // Source `Globe2` — `earth` in flutter_lucide, not `globe`.
                    rowTheme.agent.icons.web,
                    size: 12,
                    color: colors.mutedForeground,
                  ),
            ),
          ),
          SizedBox(width: rowTheme.layout.rowGap), // gap-2
          Flexible(
            child: Text(
              result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: rowTheme.body.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.foreground.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (result.domain != null) ...[
            SizedBox(width: rowTheme.layout.rowGap),
            Flexible(
              child: Text(
                result.domain!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // A8: the domain is what makes a source verifiable. It was the
                // least legible string in the row at 55% muted.
                style: rowTheme.body.copyWith(color: colors.mutedForeground),
              ),
            ),
          ],
        ],
      ),
    );

    if (result.onTap != null || result.url != null) {
      return BeuiMinHitTarget(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: result.onTap,
            borderRadius: rowTheme.shapes.chip,
            child: row,
          ),
        ),
      );
    }
    return row;
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.item, required this.rowTheme});

  final BeuiAgentActivityTool item;
  final _RowTheme rowTheme;

  IconData _actionIcon(BeuiAgentIcons icons) {
    final a = item.action.toLowerCase();
    if (a == 'read') return icons.document;
    // No theme slot matches lucide `pencil-line`; `icons.edit` is `pencil`,
    // a different glyph, so the source mark stays a literal here.
    if (a == 'edit' || a == 'write') return LucideIcons.pencil_line;
    if (a == 'run') return icons.terminal;
    return icons.tool;
  }

  String get _actionLabel {
    if (item.action.isEmpty) return item.action;
    return item.action[0].toUpperCase() + item.action.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = rowTheme.colors;
    // A36: the diff counters were Tailwind emerald-500 / rose-500 literals.
    // They are the success and failed tiers — retintable, and in light mode
    // now the 700 tier, which clears AA where the 500s did not.
    final additions = rowTheme.palette(BeuiAgentStatus.success).foreground;
    final deletions = rowTheme.palette(BeuiAgentStatus.failed).foreground;
    // Size from the body role (source `text-sm`), family from the mono role.
    final countStyle = rowTheme.body.copyWith(
      fontFamily: rowTheme.type.mono.fontFamily,
      fontFamilyFallback: rowTheme.type.mono.fontFamilyFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32), // min-h-8
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ), // px-1.5 py-0.5
        child: Row(
          children: [
            SizedBox(
              width: rowTheme.layout.iconSize,
              height: rowTheme.layout.iconSize,
              child: Icon(
                _actionIcon(rowTheme.agent.icons),
                size: rowTheme.layout.iconSize,
                color: colors.mutedForeground.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _actionLabel,
              style: rowTheme.body.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.foreground.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ), // px-2.5 py-1
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.8),
                  borderRadius: rowTheme.shapes.control, // rounded-lg
                ),
                child: Text(
                  item.target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // A8: this string names *what ran*. It was 70% muted.
                  style: rowTheme.type.mono.copyWith(
                    height: 16 / 12,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ),
            if (item.additions != null || item.deletions != null) ...[
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.additions != null)
                    Text(
                      rowTheme.strings.diffAdditions(item.additions!),
                      style: countStyle.copyWith(color: additions),
                    ),
                  if (item.additions != null && item.deletions != null)
                    SizedBox(width: rowTheme.layout.actionSpacing), // gap-2
                  if (item.deletions != null)
                    Text(
                      rowTheme.strings.diffDeletions(item.deletions!),
                      style: countStyle.copyWith(color: deletions),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.item, required this.rowTheme});

  final BeuiAgentActivityTrace item;
  final _RowTheme rowTheme;

  IconData _kindIcon(BeuiAgentIcons icons) => switch (item.kind) {
    BeuiAgentTraceKind.thinking => icons.thinking,
    BeuiAgentTraceKind.message => icons.message,
    // No theme slot for `pencil-line` / `image` — see `_ToolRow._actionIcon`.
    BeuiAgentTraceKind.write => LucideIcons.pencil_line,
    BeuiAgentTraceKind.run => icons.terminal,
    BeuiAgentTraceKind.read => LucideIcons.image,
    BeuiAgentTraceKind.other => icons.tool,
  };

  @override
  Widget build(BuildContext context) {
    final colors = rowTheme.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32), // min-h-8
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: rowTheme.layout.iconSize,
              height: rowTheme.layout.iconSize,
              child:
                  item.icon ??
                  Icon(
                    _kindIcon(rowTheme.agent.icons),
                    size: rowTheme.layout.iconSize,
                    color: colors.mutedForeground.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: rowTheme.body.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.foreground.withValues(alpha: 0.9),
              ),
            ),
            if (item.detail != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.8),
                    borderRadius: rowTheme.shapes.control,
                  ),
                  child: Text(
                    item.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // A8: the detail *is* the command that ran.
                    style: rowTheme.type.mono.copyWith(
                      height: 16 / 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
