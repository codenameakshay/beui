import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'citations.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiStreamingResponse] surface
/// (source `StreamingResponseStatus`).
enum BeuiStreamingResponseStatus {
  /// Tokens are still arriving; completion actions stay hidden.
  streaming,

  /// Stream finished successfully — feedback + actions may appear.
  complete,

  /// Stream finished with an error — retry/copy may still appear.
  error,
}

/// Thumb-vote state for a completed response
/// (source `StreamingResponseFeedback`: `"up" | "down" | null`).
///
/// [none] maps to the source's `null` (no selection). When the [feedback]
/// prop on [BeuiStreamingResponse] is itself null the widget is *uncontrolled*;
/// pass [none] explicitly for a controlled cleared vote.
enum BeuiStreamingResponseFeedback {
  /// No thumbs selection (source `null`).
  none,

  /// Helpful / thumbs-up.
  up,

  /// Not helpful / thumbs-down.
  down,
}

// ---------------------------------------------------------------------------
// Motion tokens (local curves mirroring source timings)
// ---------------------------------------------------------------------------

/// Actions bar entrance — 220ms EASE_OUT (source `duration: 0.22, ease: EASE_OUT`).
const _actionsEnterMotion = CurvedMotion(
  Duration(milliseconds: 220),
  beuiEaseOut,
);

/// Actions bar exit — opacity only, same 220ms in source (exit drops y).
const _actionsExitMotion = CurvedMotion(
  Duration(milliseconds: 220),
  beuiEaseOut,
);

/// Reduced-motion actions fade — 120ms (source `duration: 0.12`).
const _actionsReduceMotion = CurvedMotion(
  Duration(milliseconds: 120),
  beuiEaseOut,
);

/// Disclosure open 220ms / close 140ms EASE_OUT (source `AgentDisclosure`).
const _disclosureOpenMotion = CurvedMotion(
  Duration(milliseconds: 220),
  beuiEaseOut,
);
const _disclosureCloseMotion = CurvedMotion(
  Duration(milliseconds: 140),
  beuiEaseOut,
);

/// Copy-feedback window (source `setTimeout(..., 1600)`).
const _copyFeedback = Duration(milliseconds: 1600);

// ---------------------------------------------------------------------------
// BeuiStreamingResponse
// ---------------------------------------------------------------------------

/// A stable response surface with completion actions, rendered content, and an
/// expandable source summary — the Flutter port of beUI's `streaming-response`.
///
/// While [status] is [BeuiStreamingResponseStatus.streaming], only the response
/// [child] is shown (`aria-busy`). On completion (or error) an actions row
/// fades/slides in with optional copy, retry, thumbs feedback, and an
/// expandable [sources] disclosure built on [BeuiCitationStack] +
/// [BeuiCitationList].
///
/// Controlled + uncontrolled for both sources open state and feedback:
/// * [sourcesOpen] non-null → controlled sources panel
/// * [feedback] non-null → controlled vote (use [BeuiStreamingResponseFeedback.none]
///   for a cleared controlled vote)
class BeuiStreamingResponse extends StatefulWidget {
  /// Creates a streaming response surface.
  const BeuiStreamingResponse({
    required this.child,
    this.status = BeuiStreamingResponseStatus.streaming,
    this.copyText,
    this.onCopy,
    this.onRetry,
    this.sources = const <BeuiCitationItem>[],
    this.sourcesOpen,
    this.defaultSourcesOpen = false,
    this.onSourcesOpenChange,
    this.sourceIdPrefix,
    this.feedback,
    this.defaultFeedback = BeuiStreamingResponseFeedback.none,
    this.onFeedbackChange,
    this.announce = true,
    this.showActions = true,
    super.key,
  });

  /// Rendered response content. Pass plain text or a markdown widget tree.
  final Widget child;

  /// Stream lifecycle. Defaults to [BeuiStreamingResponseStatus.streaming].
  final BeuiStreamingResponseStatus status;

  /// Plain-text value copied by the built-in copy action.
  final String? copyText;

  /// Overrides the built-in clipboard action. When non-null (or [copyText] is
  /// non-null) the copy control is shown after streaming ends.
  final FutureOr<void> Function()? onCopy;

  /// Optional retry handler — shows a retry control when non-null.
  final VoidCallback? onRetry;

  /// Optional sources shown as a compact footer disclosure after streaming.
  final List<BeuiCitationItem> sources;

  /// Controlled sources open state. When non-null the panel is *controlled* —
  /// keep it in sync via [onSourcesOpenChange]. Leave null for uncontrolled.
  final bool? sourcesOpen;

  /// Initial open state in the uncontrolled case (ignored when [sourcesOpen]
  /// is supplied). Source default is `false`.
  final bool defaultSourcesOpen;

  /// Called with the new open state on every sources toggle.
  final ValueChanged<bool>? onSourcesOpenChange;

  /// Anchor prefix shared with [BeuiCitation] markers. Auto-generated when
  /// null (source `useId()` fallback → `response-source-…`).
  final String? sourceIdPrefix;

  /// Controlled feedback vote. When non-null the vote is *controlled* — keep
  /// it in sync via [onFeedbackChange]. Leave null for uncontrolled (seeded by
  /// [defaultFeedback]). Pass [BeuiStreamingResponseFeedback.none] for a
  /// controlled cleared vote.
  final BeuiStreamingResponseFeedback? feedback;

  /// Initial feedback in the uncontrolled case. Source default is `null` →
  /// [BeuiStreamingResponseFeedback.none].
  final BeuiStreamingResponseFeedback defaultFeedback;

  /// Called with the new vote (or [BeuiStreamingResponseFeedback.none] when
  /// toggled off) on every feedback press.
  final ValueChanged<BeuiStreamingResponseFeedback>? onFeedbackChange;

  /// When true, the content region is a polite live region so assistive tech
  /// announces streamed text. Set false when a surrounding conversation log
  /// already announces (source `announce`).
  final bool announce;

  /// Hides the built-in completion actions without changing response status.
  final bool showActions;

  @override
  State<BeuiStreamingResponse> createState() => _BeuiStreamingResponseState();
}

class _BeuiStreamingResponseState extends State<BeuiStreamingResponse> {
  bool _copied = false;
  late BeuiStreamingResponseFeedback _internalFeedback = widget.defaultFeedback;
  late bool _internalSourcesOpen = widget.defaultSourcesOpen;
  late String _resolvedSourcePrefix =
      widget.sourceIdPrefix ?? 'response-source-${identityHashCode(this)}';

  Timer? _copyTimer;

  // Per-action press / hover chrome.
  bool _copyPressed = false;
  bool _copyHovered = false;
  bool _retryPressed = false;
  bool _retryHovered = false;
  bool _upPressed = false;
  bool _upHovered = false;
  bool _downPressed = false;
  bool _downHovered = false;
  bool _sourcesHovered = false;

  bool get _streaming => widget.status == BeuiStreamingResponseStatus.streaming;
  bool get _complete => widget.status == BeuiStreamingResponseStatus.complete;
  bool get _canCopy => widget.copyText != null || widget.onCopy != null;
  bool get _hasSources => widget.sources.isNotEmpty;
  bool get _sourcesControlled => widget.sourcesOpen != null;
  bool get _feedbackControlled => widget.feedback != null;
  bool get _currentSourcesOpen => widget.sourcesOpen ?? _internalSourcesOpen;
  BeuiStreamingResponseFeedback get _currentFeedback =>
      widget.feedback ?? _internalFeedback;

  bool get _shouldShowActions =>
      widget.showActions &&
      !_streaming &&
      (_canCopy || widget.onRetry != null || _complete || _hasSources);

  @override
  void didUpdateWidget(BeuiStreamingResponse old) {
    super.didUpdateWidget(old);
    if (widget.sourceIdPrefix != null &&
        widget.sourceIdPrefix != _resolvedSourcePrefix) {
      _resolvedSourcePrefix = widget.sourceIdPrefix!;
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
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
    _copyTimer = Timer(_copyFeedback, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _setFeedback(BeuiStreamingResponseFeedback next) {
    // Toggle off when re-pressing the active vote (source:
    // `currentFeedback === next ? null : next`).
    final value = _currentFeedback == next
        ? BeuiStreamingResponseFeedback.none
        : next;
    if (!_feedbackControlled) {
      setState(() => _internalFeedback = value);
    }
    widget.onFeedbackChange?.call(value);
  }

  void _setSourcesOpen(bool next) {
    if (next == _currentSourcesOpen) return;
    if (!_sourcesControlled) {
      setState(() => _internalSourcesOpen = next);
    }
    widget.onSourcesOpenChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final contentColor = colors.foreground.withValues(alpha: 0.9);

    // Source: aria-busy while streaming; aria-live polite when announce.
    // Flutter has no Semantics.busy — surface streaming in the label.
    final busyLabel = _streaming ? 'Response, busy' : 'Response';

    return Semantics(
      container: true,
      label: busyLabel,
      liveRegion: widget.announce,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----- rendered content -----
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 14, // text-sm
              height: 24 / 14, // leading-6
              color: contentColor,
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: 16, color: contentColor),
              child: widget.child,
            ),
          ),

          // ----- completion actions -----
          _ActionsReveal(
            visible: _shouldShowActions,
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.only(top: 12), // mt-3
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    spacing: 2, // gap-0.5
                    children: [
                      if (_canCopy)
                        _ResponseAction(
                          label: _copied ? 'Copied' : 'Copy response',
                          pressed: _copyPressed,
                          hovered: _copyHovered,
                          active: false,
                          reduce: reduce,
                          colors: colors,
                          onHover: (h) => setState(() => _copyHovered = h),
                          onPressed: (p) => setState(() => _copyPressed = p),
                          onTap: _handleCopy,
                          child: Icon(
                            _copied ? LucideIcons.check : LucideIcons.copy,
                            size: 14, // size-3.5
                            color: _copyHovered
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                        ),
                      if (widget.onRetry != null)
                        _ResponseAction(
                          label: 'Retry response',
                          pressed: _retryPressed,
                          hovered: _retryHovered,
                          active: false,
                          reduce: reduce,
                          colors: colors,
                          onHover: (h) => setState(() => _retryHovered = h),
                          onPressed: (p) => setState(() => _retryPressed = p),
                          onTap: widget.onRetry!,
                          child: Icon(
                            LucideIcons.rotate_ccw,
                            size: 14,
                            color: _retryHovered
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                        ),
                      if (_complete) ...[
                        _ResponseAction(
                          label: 'Helpful',
                          pressed: _upPressed,
                          hovered: _upHovered,
                          active:
                              _currentFeedback ==
                              BeuiStreamingResponseFeedback.up,
                          toggleable: true,
                          reduce: reduce,
                          colors: colors,
                          onHover: (h) => setState(() => _upHovered = h),
                          onPressed: (p) => setState(() => _upPressed = p),
                          onTap: () =>
                              _setFeedback(BeuiStreamingResponseFeedback.up),
                          child: Icon(
                            LucideIcons.thumbs_up,
                            size: 14,
                            color:
                                _upHovered ||
                                    _currentFeedback ==
                                        BeuiStreamingResponseFeedback.up
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                        ),
                        _ResponseAction(
                          label: 'Not helpful',
                          pressed: _downPressed,
                          hovered: _downHovered,
                          active:
                              _currentFeedback ==
                              BeuiStreamingResponseFeedback.down,
                          toggleable: true,
                          reduce: reduce,
                          colors: colors,
                          onHover: (h) => setState(() => _downHovered = h),
                          onPressed: (p) => setState(() => _downPressed = p),
                          onTap: () =>
                              _setFeedback(BeuiStreamingResponseFeedback.down),
                          child: Icon(
                            LucideIcons.thumbs_down,
                            size: 14,
                            color:
                                _downHovered ||
                                    _currentFeedback ==
                                        BeuiStreamingResponseFeedback.down
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                        ),
                      ],
                      if (_hasSources)
                        Padding(
                          padding: const EdgeInsets.only(left: 4), // ml-1
                          child: _SourcesToggle(
                            open: _currentSourcesOpen,
                            count: widget.sources.length,
                            sources: widget.sources,
                            hovered: _sourcesHovered,
                            reduce: reduce,
                            colors: colors,
                            onHover: (h) => setState(() => _sourcesHovered = h),
                            onTap: () => _setSourcesOpen(!_currentSourcesOpen),
                          ),
                        ),
                    ],
                  ),
                  if (_hasSources)
                    _AgentDisclosure(
                      open: _currentSourcesOpen,
                      reduce: reduce,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8), // mt-2
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.muted, // bg-muted
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // rounded-xl
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8), // p-2
                            child: BeuiCitationList(
                              citations: widget.sources,
                              idPrefix: _resolvedSourcePrefix,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions reveal (AnimatePresence of the actions block)
// ---------------------------------------------------------------------------

/// Fades/slides the completion actions in and out.
///
/// Source:
/// * enter: `{ opacity: 0, y: 4 }` → `{ opacity: 1, y: 0 }`, 220ms EASE_OUT
///   (opacity-only under reduced motion, 120ms)
/// * exit: `{ opacity: 0 }`
class _ActionsReveal extends StatelessWidget {
  const _ActionsReveal({
    required this.visible,
    required this.reduce,
    required this.child,
  });

  final bool visible;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = visible ? 1.0 : 0.0;
    final Motion motion;
    if (reduce) {
      motion = _actionsReduceMotion;
    } else {
      motion = visible ? _actionsEnterMotion : _actionsExitMotion;
    }

    // Reduced motion: keep opacity, drop the y movement.
    if (reduce) {
      return SingleMotionBuilder(
        value: target,
        motion: motionFor(context, motion, isMovement: false),
        builder: (context, t, child) {
          final tt = t.clamp(0.0, 1.0);
          if (!visible && tt <= 0.001) return const SizedBox.shrink();
          return IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible && tt < 0.5,
              child: Opacity(opacity: tt, child: child),
            ),
          );
        },
        child: child,
      );
    }

    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, motion, isMovement: true),
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        if (!visible && tt <= 0.001) return const SizedBox.shrink();
        // Enter y: 4 → 0; exit keeps y at 0 (source exit is opacity-only).
        final y = visible ? 4.0 * (1 - tt) : 0.0;
        return IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(
            excluding: !visible && tt < 0.5,
            child: Opacity(
              opacity: tt,
              child: Transform.translate(offset: Offset(0, y), child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Response action button (source ResponseAction)
// ---------------------------------------------------------------------------

class _ResponseAction extends StatelessWidget {
  const _ResponseAction({
    required this.label,
    required this.pressed,
    required this.hovered,
    required this.active,
    required this.reduce,
    required this.colors,
    required this.onHover,
    required this.onPressed,
    required this.onTap,
    required this.child,
    this.toggleable = false,
  });

  final String label;
  final bool pressed;
  final bool hovered;
  final bool active;
  final bool toggleable;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onPressed;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // whileTap scale 0.9 + SPRING_PRESS; reduce-gated target (not NoMotion).
    final pressTarget = (pressed && !reduce) ? 0.9 : 1.0;
    final bg = active || hovered ? colors.muted : Colors.transparent;

    return Semantics(
      button: true,
      label: label,
      toggled: toggleable ? active : null,
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
                width: 28, // size-7
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6), // rounded-md
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

// ---------------------------------------------------------------------------
// Sources toggle (stack + count + chevron)
// ---------------------------------------------------------------------------

class _SourcesToggle extends StatelessWidget {
  const _SourcesToggle({
    required this.open,
    required this.count,
    required this.sources,
    required this.hovered,
    required this.reduce,
    required this.colors,
    required this.onHover,
    required this.onTap,
  });

  final bool open;
  final int count;
  final List<BeuiCitationItem> sources;
  final bool hovered;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = hovered ? colors.foreground : colors.mutedForeground;
    final label = count == 1 ? '1 source' : '$count sources';

    return Semantics(
      button: true,
      expanded: open,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28), // min-h-7
            child: Padding(
              // ml-1 px-1.5 → left 4+6, right 6
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiCitationStack(citations: sources),
                  const SizedBox(width: 8), // gap-2
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12, // text-xs
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Chevron(
                    open: open,
                    reduce: reduce,
                    color: colors.mutedForeground.withValues(
                      alpha: hovered ? 1.0 : 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final icon = Icon(LucideIcons.chevron_down, size: 12, color: color);
    if (reduce) {
      // Source: transition duration 0 under reduce → snap.
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

// ---------------------------------------------------------------------------
// Agent disclosure (shared pattern — height + opacity + y: -4)
// ---------------------------------------------------------------------------

/// Transform-only reveal for collapsible agent content — the Flutter port of
/// the source's `AgentDisclosure`.
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
    final motion = open ? _disclosureOpenMotion : _disclosureCloseMotion;

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
