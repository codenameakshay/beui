import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_status_colors.dart';
import '../theme/beui_agent_strings.dart';
import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_chevron.dart';
import '_disclosure.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
import '_transcript.dart';
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

  /// Stream finished with an error.
  ///
  /// Renders a destructive-tinted notice under the partial answer and, when
  /// [BeuiStreamingResponse.onRetry] is supplied, a labelled retry control.
  /// Before the UX pass this state was pixel-identical to [complete] and
  /// announced as plain `'Response'` — a failed answer looked finished.
  error,

  /// The reader (or the host) stopped the stream before it finished.
  ///
  /// Distinct from [complete] because the answer is *truncated*, and distinct
  /// from [error] because nothing went wrong. Renders a neutral notice and,
  /// when [BeuiStreamingResponse.onContinue] is supplied, a control to resume.
  /// Both demos previously flipped to [complete] on stop, presenting a
  /// half-written answer as a finished one.
  stopped,
}

/// Thumb-vote state for a completed response
/// (source `StreamingResponseFeedback`: `"up" | "down" | null`).
///
/// [none] maps to the source's `null` (no selection). When the
/// [BeuiStreamingResponse.feedback]
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

/// Actions bar exit — 140ms, deliberately faster than the 220ms entrance per
/// the repo motion rules. The source leaves the exit on Framer's default,
/// which lands at the same 220ms; matching the rest of the library here costs
/// no fidelity anyone can see and stops the row lingering.
const _actionsExitMotion = CurvedMotion(
  Duration(milliseconds: 140),
  beuiEaseOut,
);

/// Reduced-motion actions fade — 120ms (source `duration: 0.12`).
const _actionsReduceMotion = CurvedMotion(
  Duration(milliseconds: 120),
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
    this.announce,
    this.announceText,
    this.onAnnounce,
    this.showActions = true,
    this.onContinue,
    this.errorMessage,
    this.stoppedMessage,
    this.retryLabel,
    this.continueLabel,
    this.placeholder,
    this.hasContent,
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

  /// Whether the streamed text is announced to assistive tech (source
  /// `announce`).
  ///
  /// Null (the default) means yes. **Where** it is announced resolves
  /// automatically: when a [BeuiMessageScroller] is above this widget, the
  /// transcript owns the conversation's single live region and this response
  /// pushes whole sentences into it; with no scroller, the response opens a
  /// live node of its own so a standalone answer still announces.
  ///
  /// Either way there is exactly one live region per conversation. This
  /// replaces a `true` default that, combined with the scroller's own nested
  /// regions, produced three to five regions per transcript, none of which
  /// ever announced the streamed text because every label was a constant.
  ///
  /// Pass `false` for silence — for a decorative preview, or when the host app
  /// announces on its own (see [onAnnounce]).
  ///
  /// Announcements need the text: supply [announceText] (or [copyText]).
  /// Without either, nothing is announced regardless of this flag.
  final bool? announce;

  /// Plain text of the response so far, used for announcements.
  ///
  /// [child] is a widget tree, so the component cannot read the answer out of
  /// it. Feed the same string you are rendering. Falls back to [copyText] when
  /// null — for the common case where the full text is already supplied for
  /// the copy action, announcements come for free.
  ///
  /// The text is split at sentence boundaries and throttled (see
  /// [BeuiStreamAnnouncer]), so a 16ms token cadence produces about one
  /// announcement per sentence rather than sixty per second.
  final String? announceText;

  /// Called with each announcement chunk, at sentence boundaries.
  ///
  /// The escape hatch for hosts that own their own live region or want to log
  /// what a screen reader would say. Fires regardless of how [announce]
  /// resolves, so it also works as a pure observation hook.
  final ValueChanged<String>? onAnnounce;

  /// Hides the built-in completion actions without changing response status.
  final bool showActions;

  /// Resumes a [BeuiStreamingResponseStatus.stopped] response.
  ///
  /// Shows a labelled control in the stopped notice when non-null. Leave null
  /// when stopping is final and only [onRetry] makes sense.
  final VoidCallback? onContinue;

  /// Short message shown beside the destructive icon in the error notice.
  /// Overrides [BeuiAgentStrings.responseFailed] for this response.
  final String? errorMessage;

  /// Short message shown beside the neutral icon in the stopped notice.
  /// Overrides [BeuiAgentStrings.responseStopped] for this response.
  final String? stoppedMessage;

  /// Label for the inline retry control in the error notice. Overrides
  /// [BeuiAgentStrings.retry] for this response.
  final String? retryLabel;

  /// Label for the inline continue control in the stopped notice. Overrides
  /// [BeuiAgentStrings.continueAction] for this response.
  final String? continueLabel;

  /// Shown in place of [child] before the first token arrives.
  ///
  /// Gives a turn **one** indicator identity: pass the same thinking indicator
  /// here that you would render while pending, and it cross-fades into the
  /// first token instead of the reader seeing shimmer → empty box → text.
  /// Ignored once [hasContent] resolves true.
  final Widget? placeholder;

  /// Whether the response has produced any content yet.
  ///
  /// Null (the default) derives it from [announceText] / [copyText] being
  /// non-empty. Set it explicitly when neither is supplied but a [placeholder]
  /// is.
  final bool? hasContent;

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
  bool get _error => widget.status == BeuiStreamingResponseStatus.error;
  bool get _stopped => widget.status == BeuiStreamingResponseStatus.stopped;
  bool get _canCopy => widget.copyText != null || widget.onCopy != null;
  bool get _hasSources => widget.sources.isNotEmpty;
  bool get _sourcesControlled => widget.sourcesOpen != null;
  bool get _feedbackControlled => widget.feedback != null;
  bool get _currentSourcesOpen => widget.sourcesOpen ?? _internalSourcesOpen;
  BeuiStreamingResponseFeedback get _currentFeedback =>
      widget.feedback ?? _internalFeedback;

  /// The plain text backing announcements, if any.
  String get _announceSource => widget.announceText ?? widget.copyText ?? '';

  /// Whether the response has produced content.
  bool get _hasContent => widget.hasContent ?? _announceSource.isNotEmpty;

  bool get _shouldShowActions =>
      widget.showActions &&
      !_streaming &&
      (_canCopy ||
          widget.onRetry != null ||
          _complete ||
          _error ||
          _stopped ||
          _hasSources);

  /// Whether a notice (error / stopped) is shown under the content.
  bool get _hasNotice => _error || _stopped;

  // -- announcements ---------------------------------------------------

  BeuiStreamAnnouncer? _announcer;

  /// The transcript's announcement sink, when one is above us. Non-null means
  /// we push into the conversation's shared region instead of opening our own.
  ValueChanged<String>? _sink;

  /// Whether to announce at all. Separate from [_sink] on purpose: a transcript
  /// changes *where* the words go, not *whether* they are spoken. Conflating
  /// the two is what made the first cut of this fix silently drop every
  /// announcement inside a scroller.
  bool _announceEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = BeuiTranscriptScope.maybeOf(context);
    _sink = scope?.announce;
    _announceEnabled = widget.announce ?? true;
    _syncAnnouncer();
  }

  @override
  void didUpdateWidget(BeuiStreamingResponse old) {
    super.didUpdateWidget(old);
    if (widget.sourceIdPrefix != null &&
        widget.sourceIdPrefix != _resolvedSourcePrefix) {
      _resolvedSourcePrefix = widget.sourceIdPrefix!;
    }
    if (widget.announce != old.announce) {
      _announceEnabled = widget.announce ?? true;
    }
    _syncAnnouncer();

    // A terminal status flushes the trailing fragment: an answer that ends
    // without punctuation, or the tail of a stopped stream, still has to be
    // read out.
    if (widget.status != old.status && !_streaming) {
      _announcer?.flush();
    }
  }

  /// Creates or tears down the announcer and feeds it the current text.
  void _syncAnnouncer() {
    final wanted = _announceEnabled || widget.onAnnounce != null;
    if (!wanted) {
      _announcer?.dispose();
      _announcer = null;
      return;
    }
    _announcer ??= BeuiStreamAnnouncer(onChunk: _emitAnnouncement);
    final text = _announceSource;
    if (text.isNotEmpty) _announcer!.update(text);
  }

  void _emitAnnouncement(String chunk) {
    // The observation hook fires either way, so a host can log or re-route
    // what a reader would hear even with `announce: false`.
    widget.onAnnounce?.call(chunk);
    if (!_announceEnabled) return;
    final sink = _sink;
    if (sink != null) {
      // A transcript owns the conversation's region — push into it rather
      // than opening a second one.
      sink(chunk);
      return;
    }
    if (mounted) setState(() => _selfAnnouncement = chunk);
  }

  String _selfAnnouncement = '';

  @override
  void dispose() {
    _copyTimer?.cancel();
    _announcer?.dispose();
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
    final theme = Theme.of(context);
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final strings = agent.strings;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final contentColor = colors.foreground.withValues(alpha: 0.9);

    // Source: aria-busy while streaming; aria-live polite when announce.
    // Flutter has no Semantics.busy — surface the state in the label. C1/C13:
    // failure and truncation are now *named*, not left indistinguishable from
    // a finished answer.
    // Whole strings, not a stem plus a comma-joined modifier — a language
    // that inflects the noun for state cannot be served by concatenation, so
    // each state names itself.
    final statusLabel = switch (widget.status) {
      BeuiStreamingResponseStatus.streaming => strings.responseBusySemantics,
      BeuiStreamingResponseStatus.complete => strings.responseSemantics,
      BeuiStreamingResponseStatus.error => strings.responseFailedSemantics,
      BeuiStreamingResponseStatus.stopped => strings.responseStoppedSemantics,
    };

    // One indicator identity: the placeholder cross-fades into the first
    // token instead of the reader seeing shimmer → empty box → text. Opacity
    // only, so reduced motion keeps the transition.
    final placeholder = widget.placeholder;
    final Widget body = (placeholder != null && !_hasContent)
        ? placeholder
        : widget.child;
    final content = placeholder == null
        ? body
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: beuiEaseOut,
            switchOutCurve: beuiEaseOut,
            child: KeyedSubtree(key: ValueKey<bool>(_hasContent), child: body),
          );

    return Semantics(
      container: true,
      label: statusLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----- rendered content -----
          DefaultTextStyle.merge(
            style: agent.typography.assistantBody.copyWith(
              // Tailwind `tracking-normal`. Explicit because an unset
              // letterSpacing inherits the host theme's body style — 0.25 on
              // stock Material — and widens every prose line.
              letterSpacing: 0,
              color: contentColor,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                size: agent.layout.iconSize,
                color: contentColor,
              ),
              child: content,
            ),
          ),

          // Our own live node, used only when no transcript owns one.
          //
          // A separate node rather than a `liveRegion` on the content, so the
          // sentence chunk is announced *once* instead of the reader hearing
          // the label and then the same words again from the Text below it.
          // 1×1 rather than 0×0: Flutter drops semantics nodes with an empty
          // rect during tree compilation, so a zero-size live region is never
          // delivered to the platform at all.
          if (_selfAnnouncement.isNotEmpty && _sink == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: 1,
                height: 1,
                child: IgnorePointer(
                  child: Semantics(
                    liveRegion: true,
                    label: _selfAnnouncement,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),

          // ----- failure / stopped notice -----
          BeuiAgentDisclosureInternal(
            open: _hasNotice,
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              // The shared disclosure reveals through `Align(topCenter)`, which
              // centres a child that does not stretch — and the notice is
              // min-width by design. Pin it to the leading edge so it lines up
              // with the answer above it.
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _StatusNotice(
                  error: _error,
                  message: _error
                      ? (widget.errorMessage ?? strings.responseFailed)
                      : (widget.stoppedMessage ?? strings.responseStopped),
                  actionLabel: _error
                      ? (widget.retryLabel ?? strings.retry)
                      : (widget.continueLabel ?? strings.continueAction),
                  onAction: _error ? widget.onRetry : widget.onContinue,
                  colors: colors,
                  statusColors: agent.statusColorsFor(theme.brightness),
                ),
              ),
            ),
          ),

          // ----- completion actions -----
          // The reveal now animates `heightFactor` as well as opacity and
          // translate, so a completing response no longer shoves ~40px of
          // transcript in one frame while a scroller is following the live
          // edge. This is the shared disclosure the audit asked the seven
          // copies to collapse into.
          BeuiAgentDisclosureInternal(
            open: _shouldShowActions,
            reduce: reduce,
            openMotion: _actionsEnterMotion,
            closeMotion: _actionsExitMotion,
            reducedMotion: _actionsReduceMotion,
            child: Padding(
              // mt-3, less the 8px the taller row below now contributes.
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The row is a full hit target tall rather than 28.
                  // Slop alone cannot fix the vertical axis: a `RenderBox`
                  // only offers a pointer to its children when the pointer is
                  // inside *its own* box, so an overhang above a 28px row is
                  // never reached. The painted 28px chips are unchanged and
                  // centred — only the row's box grew.
                  //
                  // Spacing goes 2 → 6 for the horizontal axis: 44px of slop
                  // on controls 2px apart means neighbours overlap and paint
                  // order decides which one a finger hits.
                  SizedBox(
                    height: beuiMinHitTarget,
                    child: Row(
                      spacing: 6,
                      children: [
                        if (_canCopy)
                          _ResponseAction(
                            label: _copied ? strings.copied : strings.copy,
                            // "Copied" used to swap a label on a node that
                            // was not live, so the confirmation was visual-only.
                            announce: _copied,
                            pressed: _copyPressed,
                            hovered: _copyHovered,
                            active: false,
                            reduce: reduce,
                            colors: colors,
                            onHover: (h) => setState(() => _copyHovered = h),
                            onPressed: (p) => setState(() => _copyPressed = p),
                            onTap: _handleCopy,
                            child: Icon(
                              _copied ? agent.icons.copied : agent.icons.copy,
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
                              agent.icons.retry,
                              size: 14,
                              color: _retryHovered
                                  ? colors.foreground
                                  : colors.mutedForeground,
                            ),
                          ),
                        if (_complete) ...[
                          _ResponseAction(
                            label: strings.helpful,
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
                              agent.icons.thumbsUp,
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
                            label: strings.notHelpful,
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
                            onTap: () => _setFeedback(
                              BeuiStreamingResponseFeedback.down,
                            ),
                            child: Icon(
                              agent.icons.thumbsDown,
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
                            // Ml-1 is a *logical* start margin.
                            padding: const EdgeInsetsDirectional.only(start: 4),
                            child: _SourcesToggle(
                              open: _currentSourcesOpen,
                              count: widget.sources.length,
                              sources: widget.sources,
                              hovered: _sourcesHovered,
                              reduce: reduce,
                              colors: colors,
                              onHover: (h) =>
                                  setState(() => _sourcesHovered = h),
                              onTap: () =>
                                  _setSourcesOpen(!_currentSourcesOpen),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_hasSources)
                    // The seventh copy of `_AgentDisclosure` is gone —
                    // this is the shared primitive, which also fixes the
                    // reduced-motion hard cut the local copy had.
                    BeuiAgentDisclosureInternal(
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
// Failure / stopped notice
// ---------------------------------------------------------------------------

/// The affordance that tells a reader an answer did not finish.
///
/// Before the UX pass, `error` differed from `complete` by two absent thumb
/// icons and nothing else, and `stopped` did not exist at all — a failed or
/// truncated answer was indistinguishable from a finished one, in pixels and
/// in semantics.
///
/// Redundant encoding, as the rest of the library does it: a glyph (shape), a
/// tint (colour), and a message (text). Colour comes from the themeable status
/// palette, never a hex literal, so a consumer's `BeuiAgentTheme` reaches it.
class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.error,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.colors,
    required this.statusColors,
  });

  /// True for the destructive tier; false for the neutral "stopped" tier.
  final bool error;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final BeuiColors colors;
  final BeuiAgentStatusColors statusColors;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final palette = error ? statusColors.failed : statusColors.neutral;

    return Semantics(
      container: true,
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: palette.border,
            width: agent.structure.borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                error ? LucideIcons.triangle_alert : LucideIcons.circle_stop,
                size: 14,
                color: palette.foreground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: agent.typography.status.copyWith(
                    color: palette.foreground,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(width: 10),
                _NoticeAction(
                  label: actionLabel,
                  color: palette.foreground,
                  colors: colors,
                  onTap: onAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The labelled retry / continue control inside a [_StatusNotice].
///
/// A labelled control rather than the icon-only one in the action row: at the
/// moment a response fails, "what do I do now" should not require hovering a
/// 14px glyph to find out.
class _NoticeAction extends StatefulWidget {
  const _NoticeAction({
    required this.label,
    required this.color,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final Color color;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  State<_NoticeAction> createState() => _NoticeActionState();
}

class _NoticeActionState extends State<_NoticeAction> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Outermost, so the slop is reachable — see _ResponseAction.
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        label: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (v) => setState(() => _hovered = v),
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
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
            child: BeuiFocusRing(
              focused: _focused,
              borderRadius: BorderRadius.circular(6),
              child: SingleMotionBuilder(
                // One press scale for the library.
                value: (_pressed && !reduce) ? 0.97 : 1.0,
                motion: motionFor(context, beuiSpringPress, isMovement: true),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _hovered
                        ? widget.color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      widget.label,
                      style: agent.typography.action.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
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

// ---------------------------------------------------------------------------
// Response action button (source ResponseAction)
// ---------------------------------------------------------------------------

class _ResponseAction extends StatefulWidget {
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
    this.announce = false,
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

  /// Makes this control a live region for as long as it is true.
  ///
  /// Used for "Copied": the confirmation was previously a label swap on an
  /// ordinary node, so a screen reader never heard that the copy succeeded.
  final bool announce;

  @override
  State<_ResponseAction> createState() => _ResponseActionState();
}

class _ResponseActionState extends State<_ResponseAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // The source's whileTap is 0.9; on one screen the library ranged
    // 0.9–0.99. 0.97 is this port's single press scale.
    final pressTarget = (widget.pressed && !widget.reduce) ? 0.97 : 1.0;
    final bg = widget.active || widget.hovered
        ? widget.colors.muted
        : Colors.transparent;

    // The slop wrapper is the *outermost* widget of the control, and
    // that placement is load-bearing: `RenderBox.hitTest` rejects a pointer
    // outside its own box before consulting any child, so every proxy between
    // the parent and the slop — Semantics, Tooltip, FocusableActionDetector,
    // all of which size to the painted 28px — would swallow the overhang
    // first. Nested, the primitive is dead weight.
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        label: widget.label,
        liveRegion: widget.announce,
        toggled: widget.toggleable ? widget.active : null,
        child: Tooltip(
          message: widget.label,
          // The Semantics label above is the accessible name; a Tooltip
          // that also contributes semantics makes a reader say it twice.
          excludeFromSemantics: true,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) => setState(() => _focused = v),
            onShowHoverHighlight: widget.onHover,
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            child: MouseRegion(
              onExit: (_) => widget.onPressed(false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => widget.onPressed(true),
                onTapUp: (_) => widget.onPressed(false),
                onTapCancel: () => widget.onPressed(false),
                onTap: widget.onTap,
                child: BeuiFocusRing(
                  focused: _focused,
                  borderRadius: BorderRadius.circular(6),
                  child: SingleMotionBuilder(
                    value: pressTarget,
                    motion: motionFor(
                      context,
                      beuiSpringPress,
                      isMovement: true,
                    ),
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
                      child: widget.child,
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

// ---------------------------------------------------------------------------
// Sources toggle (stack + count + chevron)
// ---------------------------------------------------------------------------

class _SourcesToggle extends StatefulWidget {
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
  State<_SourcesToggle> createState() => _SourcesToggleState();
}

class _SourcesToggleState extends State<_SourcesToggle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final agent = BeuiAgentTheme.of(context);
    final fg = widget.hovered ? colors.foreground : colors.mutedForeground;
    final label = agent.strings.showSources(widget.count);

    // Outermost, so the slop is reachable — see _ResponseAction.
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        expanded: widget.open,
        label: label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: widget.onHover,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
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
            onTap: widget.onTap,
            child: BeuiFocusRing(
              focused: _focused,
              borderRadius: agent.shapes.pill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: beuiEaseOut,
                constraints: const BoxConstraints(minHeight: 28), // min-h-7
                decoration: BoxDecoration(
                  // At rest this control had no chrome and a chevron at
                  // 50% alpha, so it read as static metadata rather than
                  // something you could open. It now carries a resting
                  // surface, like every other toggle in the library.
                  color: widget.hovered ? colors.secondary : colors.muted,
                  borderRadius: agent.shapes.pill,
                ),
                child: Padding(
                  // Ml-1 px-1.5 are logical insets.
                  padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BeuiCitationStack(citations: widget.sources),
                      const SizedBox(width: 8), // gap-2
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12, // text-xs
                          letterSpacing: 0, // tracking-normal
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      BeuiDisclosureChevron(
                        open: widget.open,
                        reduce: widget.reduce,
                        size: 12,
                        // Full-strength token, not a 50% multiply of
                        // an already-muted foreground.
                        color: colors.mutedForeground,
                      ),
                    ],
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

