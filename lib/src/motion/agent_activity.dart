import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'loading_states.dart';

// ---------------------------------------------------------------------------
// Types — one-to-one port of agent-activity/types.ts
// ---------------------------------------------------------------------------

/// Run phase for [BeuiAgentActivity] (source `AgentActivityStatus`).
enum BeuiAgentActivityStatus {
  /// Active stream — disclosure stays open; header shows a thinking shimmer.
  working,

  /// Finished stream — disclosure is collapsible with a summary trigger.
  complete,
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

  /// Optional leading glyph; defaults to [LucideIcons.globe].
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

String _activeLabelFor(BeuiAgentActivityContentType type) {
  return switch (type) {
    BeuiAgentActivityContentType.search => 'Searching the web…',
    BeuiAgentActivityContentType.tool => 'Running tools…',
    BeuiAgentActivityContentType.trace => 'Working through the run…',
    BeuiAgentActivityContentType.mixed => 'Working through it…',
    BeuiAgentActivityContentType.step ||
    BeuiAgentActivityContentType.text => 'Thinking…',
  };
}

Widget _defaultSummary(
  BeuiAgentActivityContentType type,
  List<BeuiAgentActivityItem> items,
  num duration,
  Color color,
) {
  final style = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: color,
  );
  switch (type) {
    case BeuiAgentActivityContentType.step:
    case BeuiAgentActivityContentType.text:
      return Text.rich(
        TextSpan(
          text: 'Thought for ',
          style: style,
          children: [
            TextSpan(
              text: beuiFormatAgentActivityDuration(duration),
              style: style.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    case BeuiAgentActivityContentType.search:
      return Text(
        'Searched the web',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    case BeuiAgentActivityContentType.tool:
      final n = items.length;
      return Text(
        'Ran $n ${n == 1 ? 'tool' : 'tools'}',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    case BeuiAgentActivityContentType.trace:
      final messages = items.where((item) {
        if (item is! BeuiAgentActivityTrace) return false;
        return item.kind == BeuiAgentTraceKind.thinking ||
            item.kind == BeuiAgentTraceKind.message;
      }).length;
      final tools = items.length - messages;
      return Text(
        '$tools ${tools == 1 ? 'tool call' : 'tool calls'}, '
        '$messages ${messages == 1 ? 'message' : 'messages'}',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    case BeuiAgentActivityContentType.mixed:
      final n = items.length;
      return Text(
        'Completed $n ${n == 1 ? 'step' : 'steps'}',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
  }
}

// Item enter: opacity 180ms EASE_OUT + y SPRING_LAYOUT (source motion.div).
const _itemOpacityMotion = CurvedMotion(
  Duration(milliseconds: 180),
  beuiEaseOut,
);

// Disclosure open 220ms / close 140ms EASE_OUT (source AgentDisclosure).
const _disclosureOpenMotion = CurvedMotion(
  Duration(milliseconds: 220),
  beuiEaseOut,
);
const _disclosureCloseMotion = CurvedMotion(
  Duration(milliseconds: 140),
  beuiEaseOut,
);

// Tailwind emerald-500 / rose-500 for tool diff counts.
const _emerald500 = Color(0xFF10B981);
const _rose500 = Color(0xFFF43F5E);

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
  final bool defaultOpen;

  /// Called when the completed activity disclosure changes state.
  final ValueChanged<bool>? onOpenChange;

  /// Collapse the disclosure when status changes from working to complete.
  final bool collapseOnComplete;

  /// Optional label shown while the run is active.
  final String? activeLabel;

  /// Optional completed summary. Derived from the item types by default.
  final Widget? summary;

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
    // working → complete: seed open from collapseOnComplete (source useEffect).
    if (_previousStatus == BeuiAgentActivityStatus.working &&
        widget.status == BeuiAgentActivityStatus.complete) {
      _setOpen(!widget.collapseOnComplete);
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
    final reduce = MediaQuery.disableAnimationsOf(context);

    final contentType = _inferContentType(widget.items, widget.contentType);
    final liveLabel = widget.activeLabel ?? _activeLabelFor(contentType);
    final completedSummary =
        widget.summary ??
        _defaultSummary(
          contentType,
          widget.items,
          widget.duration,
          colors.mutedForeground,
        );

    final maxH = math.max(0.0, widget.maxHeight);
    final cappedHeight = math.min(_contentHeight, maxH);
    final viewportHeight = _working ? maxH : cappedHeight;
    final capped = _contentHeight > maxH;
    final streamOffset = _working
        ? math.min(0.0, viewportHeight - _contentHeight)
        : 0.0;

    final baseStyle =
        widget.style ??
        TextStyle(
          fontSize: 14, // text-sm
          height: 20 / 14, // leading-5
          color: colors.foreground,
        );

    return DefaultTextStyle.merge(
      style: baseStyle,
      child: Semantics(
        container: true,
        liveRegion: _working,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: shimmer while working, summary + chevron when complete.
            if (_working)
              SizedBox(
                height: 28, // h-7
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BeuiThinkingShimmer(
                    text: liveLabel,
                    style: baseStyle.copyWith(
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              _SummaryTrigger(
                expanded: _expanded,
                summary: completedSummary,
                muted: colors.mutedForeground,
                foreground: colors.foreground,
                ring: colors.ring,
                reduce: reduce,
                onTap: _toggle,
              ),
            _AgentDisclosure(
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
                colors: colors,
                onLayout: _measure,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary trigger (complete state)
// ---------------------------------------------------------------------------

class _SummaryTrigger extends StatefulWidget {
  const _SummaryTrigger({
    required this.expanded,
    required this.summary,
    required this.muted,
    required this.foreground,
    required this.ring,
    required this.reduce,
    required this.onTap,
  });

  final bool expanded;
  final Widget summary;
  final Color muted;
  final Color foreground;
  final Color ring;
  final bool reduce;
  final VoidCallback onTap;

  @override
  State<_SummaryTrigger> createState() => _SummaryTriggerState();
}

class _SummaryTriggerState extends State<_SummaryTrigger> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = (_hovered || _focused) ? widget.foreground : widget.muted;
    final chevronColor = (_hovered || _focused)
        ? widget.foreground
        : widget.muted.withValues(alpha: 0.7);

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: _focused
                  ? Border.all(color: widget.ring, width: 2)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                    child: widget.summary,
                  ),
                ),
                const SizedBox(width: 6), // gap-1.5
                _Chevron(
                  expanded: widget.expanded,
                  color: chevronColor,
                  reduce: widget.reduce,
                ),
              ],
            ),
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
      LucideIcons.chevron_down,
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

// ---------------------------------------------------------------------------
// Agent disclosure (source AgentDisclosure)
// ---------------------------------------------------------------------------

class _AgentDisclosure extends StatelessWidget {
  const _AgentDisclosure({
    required this.open,
    required this.openHeight,
    required this.reduce,
    required this.child,
  });

  final bool open;
  final double openHeight;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = open ? 1.0 : 0.0;
    final motion = open ? _disclosureOpenMotion : _disclosureCloseMotion;

    // Reduced motion: opacity only (source), height snaps. Unmount content
    // when closed so it is neither hittable nor found by default finders
    // (source `inert` + `aria-hidden`).
    if (reduce) {
      if (!open) return const SizedBox.shrink();
      return SizedBox(
        height: openHeight,
        child: ClipRect(child: child),
      );
    }

    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, motion, isMovement: true),
      builder: (context, t, _) {
        final tt = t.clamp(0.0, 1.0);
        // Fully closed after exit — drop the subtree (keeps content during the
        // close animation while tt is still > 0).
        if (!open && tt <= 0.001) return const SizedBox.shrink();
        final height = openHeight * tt;
        // Source y: open ? 0 : -4
        final y = -4.0 * (1 - tt);
        return IgnorePointer(
          ignoring: !open,
          child: Opacity(
            opacity: tt,
            child: SizedBox(
              height: height < 0 ? 0 : height,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(0, y),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: openHeight > 0 ? openHeight : null,
                    minHeight: openHeight > 0 ? openHeight : null,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stream viewport + list
// ---------------------------------------------------------------------------

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
    required this.colors,
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
  final BeuiColors colors;
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
                    child: _ActivityRow(item: items[i], colors: colors),
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

class _EnterAnim extends StatefulWidget {
  const _EnterAnim({required this.reduce, required this.child, super.key});

  final bool reduce;
  final Widget child;

  @override
  State<_EnterAnim> createState() => _EnterAnimState();
}

class _EnterAnimState extends State<_EnterAnim> {
  double _opacity = 0;
  double _y = 1; // 0 = settled, 1 = enter offset

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _opacity = 1;
      _y = 0;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _opacity = 1;
            _y = 0;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) {
      return Opacity(opacity: _opacity, child: widget.child);
    }
    return SingleMotionBuilder(
      value: _opacity,
      from: 0,
      motion: motionFor(context, _itemOpacityMotion, isMovement: false),
      builder: (context, o, child) {
        return SingleMotionBuilder(
          value: _y,
          from: 1,
          motion: motionFor(context, beuiSpringLayout, isMovement: true),
          builder: (context, y, child) {
            return Opacity(
              opacity: o.clamp(0.0, 1.0),
              child: Transform.translate(
                // Source enter y: 6 → 0; exit would be -3 (not used for append-only).
                offset: Offset(0, 6 * y),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Activity rows
// ---------------------------------------------------------------------------

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.colors});

  final BeuiAgentActivityItem item;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      BeuiAgentActivityText(:final content) => _TextRow(
        content: content,
        colors: colors,
      ),
      BeuiAgentActivitySearch() => _SearchRow(
        item: item as BeuiAgentActivitySearch,
        colors: colors,
      ),
      BeuiAgentActivityTool() => _ToolRow(
        item: item as BeuiAgentActivityTool,
        colors: colors,
      ),
      BeuiAgentActivityTrace() => _TraceRow(
        item: item as BeuiAgentActivityTrace,
        colors: colors,
      ),
      BeuiAgentActivityStep() => _StepRow(
        item: item as BeuiAgentActivityStep,
        colors: colors,
      ),
    };
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.item, required this.colors});

  final BeuiAgentActivityStep item;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final state = item.status;
    final labelColor = state == BeuiAgentStepStatus.pending
        ? colors.mutedForeground.withValues(alpha: 0.55)
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
              width: 16,
              height: 16,
              child: Center(
                child: _StepMark(status: state, colors: colors),
              ),
            ),
          ),
          const SizedBox(width: 10), // gap-2.5
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: labelColor,
              ),
            ),
          ),
          if (item.meta != null) ...[
            const SizedBox(width: 10),
            Text(
              item.meta!,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.mutedForeground.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepMark extends StatefulWidget {
  const _StepMark({required this.status, required this.colors});

  final BeuiAgentStepStatus status;
  final BeuiColors colors;

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
    final muted = widget.colors.mutedForeground.withValues(alpha: 0.7);
    return switch (widget.status) {
      BeuiAgentStepStatus.complete => Icon(
        LucideIcons.check,
        size: 16,
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
              AnimatedBuilder(
                animation: _pulse!,
                builder: (context, _) {
                  final opacity = 0.35 + 0.45 * _pulse!.value;
                  return Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.colors.foreground.withValues(alpha: 0.1),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.colors.foreground.withValues(alpha: 0.1),
                ),
              ),
            Container(
              width: 6, // size-1.5
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.colors.foreground.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.content, required this.colors});

  final String content;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.item, required this.colors});

  final BeuiAgentActivitySearch item;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final results = item.results ?? const <BeuiAgentSearchResult>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 16, color: colors.mutedForeground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16), // pl-4
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < results.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _EnterAnim(
                    key: ValueKey<String>(results[i].id),
                    reduce: reduce,
                    child: _SearchResultRow(result: results[i], colors: colors),
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
                '+${item.moreCount} more',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: colors.mutedForeground.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.colors});

  final BeuiAgentSearchResult result;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
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
                    LucideIcons.globe,
                    size: 12,
                    color: colors.mutedForeground,
                  ),
            ),
          ),
          const SizedBox(width: 8), // gap-2
          Flexible(
            child: Text(
              result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w500,
                color: colors.foreground.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (result.domain != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                result.domain!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: colors.mutedForeground.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (result.onTap != null || result.url != null) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: result.onTap,
          borderRadius: BorderRadius.circular(6),
          child: row,
        ),
      );
    }
    return row;
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.item, required this.colors});

  final BeuiAgentActivityTool item;
  final BeuiColors colors;

  IconData get _actionIcon {
    final a = item.action.toLowerCase();
    if (a == 'read') return LucideIcons.file_text;
    if (a == 'edit' || a == 'write') return LucideIcons.pencil_line;
    if (a == 'run') return LucideIcons.square_terminal;
    return LucideIcons.wrench;
  }

  String get _actionLabel {
    if (item.action.isEmpty) return item.action;
    return item.action[0].toUpperCase() + item.action.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ), // px-1.5 py-0.5
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Icon(
              _actionIcon,
              size: 16,
              color: colors.mutedForeground.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _actionLabel,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
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
                borderRadius: BorderRadius.circular(8), // rounded-lg
              ),
              child: Text(
                item.target,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, // text-xs
                  height: 16 / 12,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
                  color: colors.mutedForeground.withValues(alpha: 0.7),
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
                    '+${item.additions}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: _emerald500,
                    ),
                  ),
                if (item.additions != null && item.deletions != null)
                  const SizedBox(width: 8), // gap-2
                if (item.deletions != null)
                  Text(
                    '−${item.deletions}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: _rose500,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.item, required this.colors});

  final BeuiAgentActivityTrace item;
  final BeuiColors colors;

  IconData get _kindIcon => switch (item.kind) {
    BeuiAgentTraceKind.thinking => LucideIcons.sparkles,
    BeuiAgentTraceKind.message => LucideIcons.message_square,
    BeuiAgentTraceKind.write => LucideIcons.pencil_line,
    BeuiAgentTraceKind.run => LucideIcons.square_terminal,
    BeuiAgentTraceKind.read => LucideIcons.image,
    BeuiAgentTraceKind.other => LucideIcons.wrench,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child:
                item.icon ??
                Icon(
                  _kindIcon,
                  size: 16,
                  color: colors.mutedForeground.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(width: 10),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const [
                      'Menlo',
                      'Consolas',
                      'monospace',
                    ],
                    color: colors.mutedForeground.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
