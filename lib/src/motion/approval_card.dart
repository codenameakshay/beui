import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'action_swap.dart';
import 'button/base.dart';
import 'checkbox.dart';
import 'input.dart';
import 'radio.dart';
import 'tool_approval.dart' show beuiAgentPressScale;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiApprovalCard] — the Flutter port of the source's
/// `ApprovalCardStatus`.
enum BeuiApprovalCardStatus {
  /// Waiting for user input.
  pending,

  /// Submit / approve in flight.
  submitting,

  /// Simple-approval path accepted.
  approved,

  /// Simple-approval path declined.
  rejected,

  /// Simple-approval path asked for revision.
  changesRequested,

  /// Multi-question path finished submitting answers.
  answered,
}

/// One selectable choice on a [BeuiApprovalCardQuestion] — the Flutter port of
/// the source's `ApprovalCardOption`.
@immutable
class BeuiApprovalCardOption {
  /// Creates a choice option.
  const BeuiApprovalCardOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  /// Stable value written into [BeuiApprovalCardAnswer.selected].
  final String value;

  /// Human-readable label.
  final String label;

  /// Whether the option can be chosen. Source `disabled` inverted.
  final bool enabled;
}

/// One step in a multi-question [BeuiApprovalCard] — the Flutter port of the
/// source's `ApprovalCardQuestion`.
@immutable
class BeuiApprovalCardQuestion {
  /// Creates a question step.
  const BeuiApprovalCardQuestion({
    required this.id,
    required this.title,
    this.description,
    this.options,
    this.multiple = false,
    this.autoAdvance = true,
    this.allowCustom = false,
    this.customPlaceholder,
  });

  /// Stable identity; keys the answer map and title roll animation.
  final String id;

  /// Primary question label (rolls via [BeuiActionSwapText]).
  final String title;

  /// Optional supporting copy under the title.
  final String? description;

  /// Selectable choices. Null / empty + [allowCustom] yields a freeform step.
  final List<BeuiApprovalCardOption>? options;

  /// When true, options are multi-select checkboxes; otherwise single radio.
  final bool multiple;

  /// On single-select, auto-advance to the next step after 240ms (source
  /// default). Ignored for multi-select and the last step.
  final bool autoAdvance;

  /// Show a freeform custom-response field under the options.
  final bool allowCustom;

  /// Placeholder for the custom field. Defaults to `"Add another response…"`.
  final String? customPlaceholder;
}

/// Answer payload for one [BeuiApprovalCardQuestion] — the Flutter port of the
/// source's `ApprovalCardAnswer`.
@immutable
class BeuiApprovalCardAnswer {
  /// Creates an answer.
  const BeuiApprovalCardAnswer({this.selected = const [], this.custom = ''});

  /// Empty answer used when a step has not been touched.
  static const empty = BeuiApprovalCardAnswer();

  /// Selected option values (0–1 for single, many for multi).
  final List<String> selected;

  /// Freeform custom response (source `custom`).
  final String custom;

  /// Whether the user has provided a selection or non-blank custom text.
  bool get isAnswered => selected.isNotEmpty || custom.trim().isNotEmpty;

  /// Returns a copy with the given fields replaced.
  BeuiApprovalCardAnswer copyWith({List<String>? selected, String? custom}) {
    return BeuiApprovalCardAnswer(
      selected: selected ?? this.selected,
      custom: custom ?? this.custom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeuiApprovalCardAnswer &&
          listEquals(selected, other.selected) &&
          custom == other.custom;

  @override
  int get hashCode => Object.hash(Object.hashAll(selected), custom);
}

/// Map of question id → answer — the Flutter port of `ApprovalCardAnswers`.
typedef BeuiApprovalCardAnswers = Map<String, BeuiApprovalCardAnswer>;

// ---------------------------------------------------------------------------
// Status helpers / palette
// ---------------------------------------------------------------------------

String _statusLabel(BeuiApprovalCardStatus status, BeuiAgentStrings strings) {
  return switch (status) {
    BeuiApprovalCardStatus.submitting => strings.statusSubmitting,
    BeuiApprovalCardStatus.approved => strings.statusApproved,
    BeuiApprovalCardStatus.rejected => strings.statusRejected,
    BeuiApprovalCardStatus.changesRequested => strings.statusChangesRequested,
    BeuiApprovalCardStatus.answered => strings.statusResponseSubmitted,
    BeuiApprovalCardStatus.pending => strings.statusInputRequired,
  };
}

/// Maps a card status onto the themeable status role.
///
/// `rejected` lands on [BeuiAgentStatus.denied] rather than `failed`: nothing
/// broke, a person said no. The two roles ship the same default palette, but
/// keeping them distinct means a consumer can tint "a human refused this"
/// differently from "this blew up" without forking the widget.
BeuiAgentStatus _statusRole(BeuiApprovalCardStatus status) => switch (status) {
  BeuiApprovalCardStatus.pending => BeuiAgentStatus.pending,
  BeuiApprovalCardStatus.changesRequested => BeuiAgentStatus.pending,
  BeuiApprovalCardStatus.submitting => BeuiAgentStatus.running,
  BeuiApprovalCardStatus.approved => BeuiAgentStatus.success,
  BeuiApprovalCardStatus.answered => BeuiAgentStatus.success,
  BeuiApprovalCardStatus.rejected => BeuiAgentStatus.denied,
};

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _stepDuration = Duration(milliseconds: 200);
const _autoAdvanceDelay = Duration(milliseconds: 240);
const _spinPeriod = Duration(milliseconds: 900);

// ---------------------------------------------------------------------------
// BeuiApprovalCard
// ---------------------------------------------------------------------------

/// A human-in-the-loop decision surface for approvals, single or
/// multiple-choice questions, custom responses, and multi-step review flows —
/// the Flutter port of beUI's `approval-card`.
///
/// Two modes:
/// * **Simple approval** (no [questions]): Approve / Request changes / Reject
///   actions with an optional [child] summary block.
/// * **Question flow** ([questions] non-empty): stepped single/multi-select +
///   optional freeform custom answers, progress dots, auto-advance on
///   single-select, and a final Submit.
///
/// Controlled + uncontrolled for both answers and step (source parity): pass
/// [answers]/[step] to drive them, or seed [defaultAnswers]/[defaultStep]
/// and let the card hold state. [status] is always controlled by the consumer
/// (the card does not invent a status after submit).
///
/// Reduced motion drops movement (disclosure y-offset, step slide, progress-dot
/// scale, spinner rotation, compact-to-expanded height) while keeping opacity /
/// colour transitions.
///
/// **Compact-to-expanded.** Pass [expandedChild] to reveal a full editor (or
/// any detailed body) on demand. [compactChild] (falling back to [child]) is
/// the collapsed summary. Expansion is controlled when [expanded] is non-null,
/// otherwise seeded from [defaultExpanded]. The height transition uses
/// [beuiSpringLayout] and is interruptible; reduced motion snaps. Existing
/// call sites that omit [expandedChild] are unchanged.
class BeuiApprovalCard extends StatefulWidget {
  /// Creates an approval card.
  const BeuiApprovalCard({
    this.title,
    this.description,
    this.child,
    this.questions = const [],
    this.status = BeuiApprovalCardStatus.pending,
    this.answers,
    this.defaultAnswers = const {},
    this.onAnswersChange,
    this.step,
    this.defaultStep = 0,
    this.onStepChange,
    this.onSubmit,
    this.onApprove,
    this.onReject,
    this.onRequestChanges,
    this.onDismiss,
    this.approveLabel,
    this.submitLabel,
    this.rejectLabel,
    this.requestChangesLabel,
    this.result,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChanged,
    this.headerAction,
    this.compactChild,
    this.expandedChild,
    this.showExpandToggle = true,
    super.key,
  }) : assert(
         expandedChild == null || compactChild != null || child != null,
         'BeuiApprovalCard was given an expandedChild with nothing to collapse '
         'to: pass compactChild (or child) as the summary. Without one the '
         'card renders an expand affordance over a legitimately blank body.',
       );

  /// Header title when not in a question step (or when the step has no title).
  /// Defaults to [BeuiAgentStrings.approvalCardTitle].
  final String? title;

  /// Supporting copy for the simple-approval path.
  final String? description;

  /// Optional summary / metadata block under the description (simple path).
  final Widget? child;

  /// Multi-step questions. Non-empty enables question mode.
  final List<BeuiApprovalCardQuestion> questions;

  /// Current lifecycle status. Defaults to [BeuiApprovalCardStatus.pending].
  final BeuiApprovalCardStatus status;

  /// Controlled answers map (question id → answer).
  final BeuiApprovalCardAnswers? answers;

  /// Uncontrolled seed for answers when [answers] is null.
  final BeuiApprovalCardAnswers defaultAnswers;

  /// Called whenever answers change (both controlled and uncontrolled).
  final ValueChanged<BeuiApprovalCardAnswers>? onAnswersChange;

  /// Controlled step index into [questions].
  final int? step;

  /// Uncontrolled seed for the step when [step] is null.
  final int defaultStep;

  /// Called when the active step changes.
  final ValueChanged<int>? onStepChange;

  /// Called when the user submits the last question's answers.
  final ValueChanged<BeuiApprovalCardAnswers>? onSubmit;

  /// Simple-approval Accept action.
  final VoidCallback? onApprove;

  /// Simple-approval Reject action. When null the Reject button is hidden.
  final VoidCallback? onReject;

  /// Simple-approval Request-changes action. When null the button is hidden.
  final VoidCallback? onRequestChanges;

  /// Optional dismiss control (X) in the header.
  final VoidCallback? onDismiss;

  /// Label on the primary Approve button.
  ///
  /// Null falls through to [BeuiAgentStrings.approve]. Precedence throughout
  /// this widget is: per-instance label → theme string → built-in default.
  final String? approveLabel;

  /// Label on the final Submit button of a question flow.
  /// Null falls through to [BeuiAgentStrings.submitResponse].
  final String? submitLabel;

  /// Label on the Reject action. Null falls through to
  /// [BeuiAgentStrings.reject].
  ///
  /// **Reject, not Deny.** This card renders a *review verdict* — the user has
  /// read submitted work and turned it down. `BeuiToolApproval` renders a
  /// *permission refusal* and says "Deny". The audit found the two words
  /// used interchangeably across siblings; they are kept distinct on purpose.
  final String? rejectLabel;

  /// Label on the Request-changes action. Null falls through to
  /// [BeuiAgentStrings.requestChanges].
  final String? requestChangesLabel;

  /// Collapsed result copy shown when the card is no longer interactive.
  /// Falls back to the status label when null.
  final Widget? result;

  /// Controlled compact-to-expanded state. Null → uncontrolled.
  /// Ignored when [expandedChild] is null.
  final bool? expanded;

  /// Uncontrolled seed when [expanded] is null. Defaults to collapsed.
  ///
  /// **The cluster's disclosure policy.** Across the transcript the rule
  /// is: *a surface that is still asking or still running opens; a detail view
  /// the user can request stays shut.* The audit found `defaultOpen` set
  /// true/true/false/false across four sibling components with no stated
  /// reason, so each one now says why.
  ///
  /// Here the answer is collapsed, because [expandedChild] is by definition
  /// the *optional* depth behind a summary the user has already been given —
  /// unlike [BeuiToolApproval]'s parameters, which are the evidence for the
  /// decision being asked for and therefore open by default.
  final bool defaultExpanded;

  /// Called whenever compact/expanded changes.
  final ValueChanged<bool>? onExpandedChanged;

  /// Optional trailing header control (for example an edit glyph). Rendered
  /// before the dismiss button; it never toggles expansion, even when the rest
  /// of the header row does — see [showExpandToggle].
  final Widget? headerAction;

  /// Whether the header participates in expand/collapse.
  ///
  /// **The invariant.** The header row is a trigger *if and only if*
  /// `expandedChild != null && showExpandToggle`. When either is false the
  /// header is completely inert: no button semantics, no tap target, no
  /// keyboard stop, and [headerAction] behaves exactly as it does today. A
  /// card built with only [child] and a [headerAction] must never grow a
  /// second, invisible control underneath that action — so this is pinned by
  /// a test, not just by documentation.
  ///
  /// When it *is* a trigger, the whole row is the target (every sibling
  /// component already works this way; only the 20×20 chevron used to),
  /// [headerAction] and the dismiss button stay independently tappable, and
  /// the chevron remains as the visual affordance.
  final bool showExpandToggle;

  /// Compact summary shown when collapsed. Defaults to [child]. Ignored when
  /// [expandedChild] is null.
  final Widget? compactChild;

  /// Detailed body shown when expanded. When null, the card does not offer
  /// compact-to-expanded composition and behaves as it did before this API.
  final Widget? expandedChild;

  @override
  State<BeuiApprovalCard> createState() => _BeuiApprovalCardState();
}

class _BeuiApprovalCardState extends State<BeuiApprovalCard>
    with SingleTickerProviderStateMixin {
  late BeuiApprovalCardAnswers _internalAnswers;
  late int _internalStep;
  late bool _internalExpanded;
  Timer? _autoAdvanceTimer;
  late final AnimationController _spin;

  bool get _controlledAnswers => widget.answers != null;
  bool get _controlledStep => widget.step != null;
  bool get _controlledExpanded => widget.expanded != null;

  BeuiApprovalCardAnswers get _currentAnswers =>
      widget.answers ?? _internalAnswers;

  int get _currentStep {
    final raw = widget.step ?? _internalStep;
    final max = widget.questions.isEmpty ? 0 : widget.questions.length - 1;
    return raw.clamp(0, max);
  }

  bool get _expanded => widget.expanded ?? _internalExpanded;
  bool get _expandable => widget.expandedChild != null;

  /// The header-trigger invariant, in one place: the header is a trigger only when there
  /// is something to expand *and* the caller left the toggle on.
  bool get _headerIsTrigger => _expandable && widget.showExpandToggle;

  bool get _questionMode => widget.questions.isNotEmpty;
  bool get _pending => widget.status == BeuiApprovalCardStatus.pending;
  bool get _busy => widget.status == BeuiApprovalCardStatus.submitting;
  bool get _interactive => _pending || _busy;

  BeuiApprovalCardQuestion? get _question =>
      _questionMode ? widget.questions[_currentStep] : null;

  BeuiApprovalCardAnswer get _currentAnswer {
    final q = _question;
    if (q == null) return BeuiApprovalCardAnswer.empty;
    return _currentAnswers[q.id] ?? BeuiApprovalCardAnswer.empty;
  }

  @override
  void initState() {
    super.initState();
    _internalAnswers = Map<String, BeuiApprovalCardAnswer>.from(
      widget.defaultAnswers,
    );
    _internalStep = widget.defaultStep;
    _internalExpanded = widget.defaultExpanded;
    _spin = AnimationController(vsync: this, duration: _spinPeriod);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't available in initState; this also re-syncs whenever
    // the ambient reduced-motion setting changes.
    _syncSpin();
  }

  @override
  void didUpdateWidget(BeuiApprovalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _syncSpin();
  }

  @override
  void dispose() {
    _clearAutoAdvance();
    _spin.dispose();
    super.dispose();
  }

  void _syncSpin() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (_busy && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating || _spin.value != 0) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  void _clearAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _setAnswers(BeuiApprovalCardAnswers next) {
    if (!_controlledAnswers) setState(() => _internalAnswers = next);
    widget.onAnswersChange?.call(next);
  }

  void _setStep(int next) {
    _clearAutoAdvance();
    if (!_controlledStep) setState(() => _internalStep = next);
    widget.onStepChange?.call(next);
  }

  void _setExpanded(bool next) {
    if (_expanded == next) return;
    if (!_controlledExpanded) setState(() => _internalExpanded = next);
    widget.onExpandedChanged?.call(next);
  }

  void _updateCurrentAnswer(BeuiApprovalCardAnswer next) {
    final q = _question;
    if (q == null) return;
    _setAnswers({..._currentAnswers, q.id: next});
  }

  void _continueQuestion() {
    if (_currentStep < widget.questions.length - 1) {
      _setStep(_currentStep + 1);
      return;
    }
    widget.onSubmit?.call(_currentAnswers);
  }

  void _queueAutoAdvance() {
    final q = _question;
    if (q == null ||
        q.multiple ||
        !q.autoAdvance ||
        _currentStep >= widget.questions.length - 1 ||
        _busy) {
      return;
    }
    _clearAutoAdvance();
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted) return;
      _setStep(_currentStep + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final strings = agent.strings;
    final statusColors = agent.statusColorsFor(theme.brightness);

    final question = _question;
    // `approvalCardTitle` shipped in the strings role and nothing read it,
    // because the widget default beat it to the fallback slot.
    final displayTitle =
        question?.title ?? widget.title ?? strings.approvalCardTitle;
    final titleKey = question?.id ?? widget.status.name;
    final statusLabel = _statusLabel(widget.status, strings);
    final answer = _currentAnswer;

    final iconColor = _resolveIconColor(colors, statusColors);
    final statusIcon = _buildStatusIcon(iconColor, reduce, agent);

    Widget simpleBodyChild = widget.child ?? const SizedBox.shrink();
    if (_expandable) {
      simpleBodyChild = _ExpandableBody(
        expanded: _expanded,
        reduce: reduce,
        compact: widget.compactChild ?? widget.child ?? const SizedBox.shrink(),
        expandedChild: widget.expandedChild!,
      );
    }

    return Semantics(
      container: true,
      // The old gate was `_busy`, which switched the live region off at
      // exactly the moment the outcome arrived — "Rejected" and "Changes
      // requested" were never announced. Hold it through the terminal
      // transition instead; the label below carries the outcome.
      liveRegion: !_pending,
      expanded: _expandable ? _expanded : null,
      child: agent.decorateCard(
        colors: colors,
        child: Padding(
          padding: agent.layout.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 20, height: 20, child: Center(child: statusIcon)),
              SizedBox(width: agent.layout.rowGap + 4), // gap-3
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderRow(
                      titleKey: titleKey,
                      displayTitle: displayTitle,
                      colors: colors,
                      questionMode: _questionMode,
                      interactive: _interactive,
                      currentStep: _currentStep,
                      questionCount: widget.questions.length,
                      status: widget.status,
                      statusLabel: statusLabel,
                      statusColors: statusColors,
                      strings: strings,
                      onDismiss: widget.onDismiss,
                      headerAction: widget.headerAction,
                      expanded: _expanded,
                      // Null here means "inert header" — the only switch
                      // that turns the row into a control.
                      onToggleExpanded: _headerIsTrigger
                          ? () => _setExpanded(!_expanded)
                          : null,
                    ),
                    BeuiAgentDisclosureInternal(
                      open: _interactive,
                      reduce: reduce,
                      // The double-fire fix. The disclosure gates hit
                      // testing on its *animated* value, so for the ~140ms the
                      // body spends collapsing after a decision it was still
                      // tappable: a fast double-tap on Approve fired
                      // `onApprove` twice, the second time after the card had
                      // already left `pending`. This gate is driven by the
                      // state itself, so the row goes inert on the very frame
                      // the decision lands.
                      child: IgnorePointer(
                        ignoring: !_interactive,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_questionMode && question != null)
                              _QuestionBody(
                                question: question,
                                answer: answer,
                                busy: _busy,
                                reduce: reduce,
                                colors: colors,
                                onChange: _updateCurrentAnswer,
                                onSingleSelect: _queueAutoAdvance,
                              )
                            else
                              _SimpleBody(
                                description: widget.description,
                                colors: colors,
                                child: simpleBodyChild,
                              ),
                            SizedBox(height: agent.layout.sectionSpacing),
                            if (_questionMode)
                              _QuestionNav(
                                currentStep: _currentStep,
                                questionCount: widget.questions.length,
                                questionIds: widget.questions
                                    .map((q) => q.id)
                                    .toList(),
                                busy: _busy,
                                answered: answer.isAnswered,
                                reduce: reduce,
                                colors: colors,
                                submitLabel:
                                    widget.submitLabel ??
                                    strings.submitResponse,
                                onPrev: () => _setStep(_currentStep - 1),
                                onContinue: _continueQuestion,
                                spin: _spin,
                              )
                            else
                              _SimpleActions(
                                busy: _busy,
                                colors: colors,
                                statusColors: statusColors,
                                approveLabel:
                                    widget.approveLabel ?? strings.approve,
                                requestChangesLabel:
                                    widget.requestChangesLabel ??
                                    strings.requestChanges,
                                rejectLabel:
                                    widget.rejectLabel ?? strings.reject,
                                onApprove: widget.onApprove,
                                onRequestChanges: widget.onRequestChanges,
                                onReject: widget.onReject,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!_interactive)
                      Padding(
                        padding: const EdgeInsets.only(top: 4), // mt-1
                        child: DefaultTextStyle.merge(
                          style: agent.typography.description.copyWith(
                            color: colors.mutedForeground,
                          ),
                          child: widget.result ?? Text(statusLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveIconColor(BeuiColors colors, BeuiAgentStatusColors status) {
    if (_interactive) return colors.mutedForeground;
    return status.palette(_statusRole(widget.status)).foreground;
  }

  Widget _buildStatusIcon(Color color, bool reduce, BeuiAgentTheme agent) {
    final size = agent.layout.iconSize;
    if (_busy) {
      return _SpinIcon(controller: _spin, color: color, reduce: reduce);
    }
    if (_interactive) {
      return Icon(
        _questionMode
            ? agent.icons.pendingQuestion
            : agent.icons.pendingApproval,
        size: size,
        color: color,
      );
    }
    if (widget.status == BeuiApprovalCardStatus.rejected) {
      return Icon(agent.icons.rejected, size: size, color: color);
    }
    return Icon(agent.icons.approved, size: size, color: color);
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.titleKey,
    required this.displayTitle,
    required this.colors,
    required this.questionMode,
    required this.interactive,
    required this.currentStep,
    required this.questionCount,
    required this.status,
    required this.statusLabel,
    required this.statusColors,
    required this.strings,
    required this.onDismiss,
    this.headerAction,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final String titleKey;
  final String displayTitle;
  final BeuiColors colors;
  final bool questionMode;
  final bool interactive;
  final int currentStep;
  final int questionCount;
  final BeuiApprovalCardStatus status;
  final String statusLabel;
  final BeuiAgentStatusColors statusColors;
  final BeuiAgentStrings strings;
  final VoidCallback? onDismiss;
  final Widget? headerAction;
  final bool expanded;

  /// Non-null exactly when the header is a trigger — see
  /// [BeuiApprovalCard.showExpandToggle] for the invariant.
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final isTrigger = onToggleExpanded != null;

    // The trigger spans title + status + chevron. `headerAction` and the
    // dismiss button sit *outside* it: they are their own controls with their
    // own semantics, and nesting them inside a button would both break their
    // labels and make the header announce as a control containing controls.
    final Widget triggerArea = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          // `.merge` (not a replacing DefaultTextStyle) so the heading keeps the
          // ambient font family; the swap reads this style rather than being
          // handed a bare TextStyle that would reset the face to the default.
          child: DefaultTextStyle.merge(
            style: agent.typography.title.copyWith(color: colors.foreground),
            child: BeuiActionSwapText(
              value: titleKey,
              text: displayTitle,
              variant: BeuiActionSwapVariant.roll,
            ),
          ),
        ),
        SizedBox(width: agent.layout.rowGap + 4),
        if (questionMode && interactive)
          Text(
            strings.stepCounter(currentStep + 1, questionCount),
            style: agent.typography.status.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              // The step counter tells you where you are in the flow —
              // information, not chrome. It no longer gets alpha-multiplied
              // down to 3:1.
              color: colors.mutedForeground,
            ),
          )
        else
          _StatusBadge(
            label: statusLabel,
            palette: statusColors.palette(_statusRole(status)),
          ),
        if (isTrigger) ...[
          SizedBox(width: agent.layout.actionSpacing),
          _ExpandChevron(expanded: expanded, colors: colors),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: isTrigger
              ? _HeaderTrigger(
                  expanded: expanded,
                  onToggle: onToggleExpanded!,
                  label: expanded ? strings.hideDetails : strings.showDetails,
                  colors: colors,
                  child: triggerArea,
                )
              // The invariant's other half: with no expandedChild (or the toggle turned
              // off) the header is plain content — no Semantics(button), no
              // Focus stop, no hit target.
              : triggerArea,
        ),
        if (headerAction != null) ...[
          SizedBox(width: agent.layout.actionSpacing + 4),
          headerAction!,
        ],
        if (onDismiss != null) ...[
          SizedBox(width: agent.layout.rowGap + 4),
          _DismissButton(onDismiss: onDismiss!, colors: colors),
        ],
      ],
    );
  }
}

/// Makes the header row a real control: button semantics, Enter/Space, a
/// visible non-shifting focus ring, and a 44px hit target over the same
/// visual.
class _HeaderTrigger extends StatefulWidget {
  const _HeaderTrigger({
    required this.expanded,
    required this.onToggle,
    required this.label,
    required this.colors,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String label;
  final BeuiColors colors;
  final Widget child;

  @override
  State<_HeaderTrigger> createState() => _HeaderTriggerState();
}

class _HeaderTriggerState extends State<_HeaderTrigger> {
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      expanded: widget.expanded,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        child: BeuiFocusRing(
          focused: _focusVisible,
          borderRadius: agent.shapes.chip,
          child: BeuiMinHitTarget(
            child: GestureDetector(
              // Kept from the old 20×20 chevron control so existing call sites
              // and tests that target the toggle keep working.
              key: const ValueKey<String>('beui-approval-expand'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggle,
              // The row is the control, so the *row* has to clear the
              // touch floor. `BeuiMinHitTarget` widens hit testing but cannot
              // grow the semantics rect an accessibility audit measures, and a
              // title's line box is only ~20px tall — so the minimum height is
              // real, and the content stays top-aligned inside it.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ExcludeSemantics(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.palette});

  final String label;
  final BeuiAgentStatusPalette palette;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: agent.shapes.pill,
        border: Border.all(
          color: palette.border,
          width: agent.structure.borderWidth,
        ),
      ),
      child: Text(
        label,
        style: agent.typography.metadata.copyWith(
          fontWeight: FontWeight.w500,
          color: palette.foreground,
        ),
      ),
    );
  }
}

class _DismissButton extends StatefulWidget {
  const _DismissButton({required this.onDismiss, required this.colors});

  final VoidCallback onDismiss;
  final BeuiColors colors;

  @override
  State<_DismissButton> createState() => _DismissButtonState();
}

class _DismissButtonState extends State<_DismissButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered
        ? widget.colors.foreground
        : widget.colors.mutedForeground;
    return Semantics(
      button: true,
      label: BeuiAgentTheme.of(context).strings.dismiss,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onDismiss();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              BeuiAgentTheme.of(context).icons.close,
              size: BeuiAgentTheme.of(context).layout.iconSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bodies
// ---------------------------------------------------------------------------

class _SimpleBody extends StatelessWidget {
  const _SimpleBody({
    required this.description,
    required this.child,
    required this.colors,
  });

  final String? description;
  final Widget? child;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4), // mt-1
            child: Text(
              description!,
              style: agent.typography.description.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
        if (child != null)
          Padding(
            padding: EdgeInsets.only(top: agent.layout.rowGap + 4), // mt-3
            child: child,
          ),
      ],
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    required this.question,
    required this.answer,
    required this.busy,
    required this.reduce,
    required this.colors,
    required this.onChange,
    required this.onSingleSelect,
  });

  final BeuiApprovalCardQuestion question;
  final BeuiApprovalCardAnswer answer;
  final bool busy;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<BeuiApprovalCardAnswer> onChange;
  final VoidCallback onSingleSelect;

  @override
  Widget build(BuildContext context) {
    // AnimatePresence mode="wait" step swap — enter x:+8, exit x:−6, 200ms
    // EASE_OUT. DualTransitionBuilder gives asymmetric enter/exit offsets.
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : _stepDuration,
      switchInCurve: beuiEaseOut,
      switchOutCurve: beuiEaseOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        if (reduce) {
          return FadeTransition(opacity: animation, child: child);
        }
        return DualTransitionBuilder(
          animation: animation,
          forwardBuilder: (context, anim, child) {
            return FadeTransition(
              opacity: anim,
              child: AnimatedBuilder(
                animation: anim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(8 * (1 - anim.value), 0),
                  child: child,
                ),
                child: child,
              ),
            );
          },
          reverseBuilder: (context, anim, child) {
            // anim goes 0→1 during exit.
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) => Opacity(
                opacity: 1 - anim.value,
                child: Transform.translate(
                  offset: Offset(-6 * anim.value, 0),
                  child: child,
                ),
              ),
              child: child,
            );
          },
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(question.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (question.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  question.description!,
                  style: BeuiAgentTheme.of(context).typography.description
                      .copyWith(color: colors.mutedForeground),
                ),
              ),
            _QuestionOptions(
              question: question,
              answer: answer,
              disabled: busy,
              colors: colors,
              onChange: onChange,
              onSingleSelect: onSingleSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionOptions extends StatelessWidget {
  const _QuestionOptions({
    required this.question,
    required this.answer,
    required this.disabled,
    required this.colors,
    required this.onChange,
    required this.onSingleSelect,
  });

  final BeuiApprovalCardQuestion question;
  final BeuiApprovalCardAnswer answer;
  final bool disabled;
  final BeuiColors colors;
  final ValueChanged<BeuiApprovalCardAnswer> onChange;
  final VoidCallback onSingleSelect;

  @override
  Widget build(BuildContext context) {
    final options = question.options ?? const <BeuiApprovalCardOption>[];
    final hasOptions = options.isNotEmpty;
    final custom = answer.custom;

    return Padding(
      padding: const EdgeInsets.only(top: 12), // mt-3
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasOptions)
            question.multiple
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < options.length; i++) ...[
                        if (i > 0) const SizedBox(height: 2), // gap-0.5
                        _OptionRow(
                          child: BeuiCheckbox(
                            value: answer.selected.contains(options[i].value),
                            enabled: !disabled && options[i].enabled,
                            label: options[i].label,
                            onChanged: (checked) {
                              final next = List<String>.from(answer.selected);
                              if (checked) {
                                if (!next.contains(options[i].value)) {
                                  next.add(options[i].value);
                                }
                              } else {
                                next.remove(options[i].value);
                              }
                              onChange(answer.copyWith(selected: next));
                            },
                          ),
                        ),
                      ],
                    ],
                  )
                // Source gives every radio row the same `min-h-9 rounded-lg
                // px-1.5 py-1` box the checkbox rows get. `BeuiRadioGroup`
                // takes `List<BeuiRadioItem>` so the rows cannot be wrapped
                // individually; reproduce the source's rhythm with the group's
                // own insets — 8px above/below each 20px ring plus the
                // `gap-0.5` between rows gives the source's 38px row pitch.
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, // px-1.5
                      vertical: 8, // min-h-9 around a 20px ring
                    ),
                    child: BeuiRadioGroup<String>(
                      items: [
                        for (final o in options)
                          BeuiRadioItem<String>(
                            value: o.value,
                            label: o.label,
                            enabled: !disabled && o.enabled,
                          ),
                      ],
                      // Empty string keeps the group controlled with no match
                      // (source `value={answer.selected[0] ?? ""}`).
                      value: answer.selected.isEmpty
                          ? ''
                          : answer.selected.first,
                      onChanged: (value) {
                        onChange(
                          BeuiApprovalCardAnswer(selected: [value], custom: ''),
                        );
                        onSingleSelect();
                      },
                      spacing: 18, // 8 + gap-0.5 + 8
                    ),
                  ),
          if (question.allowCustom)
            Padding(
              // mt-1.5 on the wrapper, plus the wrapper's own `p-0.5` (2px)
              // gutter around the 40px field — the source passes
              // `className={cn("p-0.5", …)}`, so the slot is 44px tall.
              padding: EdgeInsets.fromLTRB(2, hasOptions ? 8 : 2, 2, 2),
              // source field classes: `h-10 rounded-xl border-0
              // bg-background/70`. BeuiInputStyle has no fill, so the capsule
              // is painted behind the (transparent-bordered) field.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.background.withValues(alpha: 0.7),
                  borderRadius: BeuiAgentTheme.of(context).shapes.nested,
                ),
                child: BeuiInput(
                  value: custom,
                  enabled: !disabled,
                  placeholder:
                      question.customPlaceholder ??
                      BeuiAgentTheme.of(
                        context,
                      ).strings.customAnswerPlaceholder,
                  onChanged: (value) {
                    onChange(
                      BeuiApprovalCardAnswer(
                        selected: question.multiple
                            ? answer.selected
                            : const [],
                        custom: value,
                      ),
                    );
                  },
                  style: BeuiInputStyle(
                    height: 40, // h-10
                    borderRadius: 12, // rounded-xl
                    borderColor: Colors.transparent,
                    focusedBorderColor: Colors.transparent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft padding around checkbox / radio rows (source `min-h-9 rounded-lg
/// px-1.5 py-1`).
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation / actions
// ---------------------------------------------------------------------------

class _QuestionNav extends StatelessWidget {
  const _QuestionNav({
    required this.currentStep,
    required this.questionCount,
    required this.questionIds,
    required this.busy,
    required this.answered,
    required this.reduce,
    required this.colors,
    required this.submitLabel,
    required this.onPrev,
    required this.onContinue,
    required this.spin,
  });

  final int currentStep;
  final int questionCount;
  final List<String> questionIds;
  final bool busy;
  final bool answered;
  final bool reduce;
  final BeuiColors colors;
  final String submitLabel;
  final VoidCallback onPrev;
  final VoidCallback onContinue;
  final AnimationController spin;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == questionCount - 1;
    final strings = BeuiAgentTheme.of(context).strings;
    return Row(
      children: [
        Tooltip(
          message: strings.previousQuestion,
          child: BeuiButton(
            variant: BeuiButtonVariant.ghost,
            size: BeuiButtonSize.icon,
            // Source: `className="rounded-full"` on the nav buttons, overriding
            // the icon size's default `rounded-lg`.
            borderRadius: BeuiAgentTheme.of(context).shapes.pill,
            onPressed: busy || currentStep == 0 ? null : onPrev,
            child: const Icon(LucideIcons.arrow_left, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        _ProgressDots(
          current: currentStep,
          ids: questionIds,
          colors: colors,
          reduce: reduce,
        ),
        const Spacer(),
        Tooltip(
          // On the last step the tooltip echoes the button's own (already
          // theme-resolved) label rather than a second literal that could
          // drift away from it.
          message: isLast ? submitLabel : strings.nextQuestion,
          child: BeuiButton(
            size: isLast ? BeuiButtonSize.sm : BeuiButtonSize.icon,
            borderRadius: BeuiAgentTheme.of(
              context,
            ).shapes.pill, // rounded-full
            onPressed: busy || !answered ? null : onContinue,
            child: busy
                ? _SpinIcon(
                    controller: spin,
                    color: colors.primaryForeground,
                    reduce: reduce,
                  )
                : isLast
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(submitLabel),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.arrow_right, size: 14),
                    ],
                  )
                : const Icon(LucideIcons.arrow_right, size: 16),
          ),
        ),
      ],
    );
  }
}

class _SimpleActions extends StatelessWidget {
  const _SimpleActions({
    required this.busy,
    required this.colors,
    required this.statusColors,
    required this.approveLabel,
    required this.requestChangesLabel,
    required this.rejectLabel,
    required this.onApprove,
    required this.onRequestChanges,
    required this.onReject,
  });

  final bool busy;
  final BeuiColors colors;
  final BeuiAgentStatusColors statusColors;
  final String approveLabel;
  final String requestChangesLabel;
  final String rejectLabel;
  final VoidCallback? onApprove;
  final VoidCallback? onRequestChanges;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return Wrap(
      // The 44px hit targets overhang their visuals, so the gap has to
      // clear the overhang or a tap near the edge of Approve lands on Request
      // changes.
      spacing: agent.layout.actionSpacing + 4,
      runSpacing: agent.layout.actionSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BeuiMinHitTarget(
          child: BeuiButton(
            size: BeuiButtonSize.sm,
            pressScale: beuiAgentPressScale,
            onPressed: busy ? null : onApprove,
            child: Text(approveLabel),
          ),
        ),
        if (onRequestChanges != null)
          BeuiMinHitTarget(
            child: BeuiButton(
              variant: BeuiButtonVariant.secondary,
              size: BeuiButtonSize.sm,
              pressScale: beuiAgentPressScale,
              onPressed: busy ? null : onRequestChanges,
              child: Text(requestChangesLabel),
            ),
          ),
        if (onReject != null)
          _RejectButton(
            busy: busy,
            colors: colors,
            statusColors: statusColors,
            label: rejectLabel,
            onReject: onReject!,
          ),
      ],
    );
  }
}

/// Ghost reject with muted → rose hover text (source
/// `hover:text-rose-600 dark:hover:text-rose-400`).
class _RejectButton extends StatefulWidget {
  const _RejectButton({
    required this.busy,
    required this.colors,
    required this.statusColors,
    required this.label,
    required this.onReject,
  });

  final bool busy;
  final BeuiColors colors;
  final BeuiAgentStatusColors statusColors;
  final String label;
  final VoidCallback onReject;

  @override
  State<_RejectButton> createState() => _RejectButtonState();
}

class _RejectButtonState extends State<_RejectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rose = widget.statusColors.denied.foreground;
    final color = _hovered ? rose : widget.colors.mutedForeground;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: BeuiMinHitTarget(
        child: BeuiButton(
          variant: BeuiButtonVariant.ghost,
          size: BeuiButtonSize.sm,
          pressScale: beuiAgentPressScale,
          onPressed: widget.busy ? null : widget.onReject,
          child: Text(widget.label, style: TextStyle(color: color)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress dots (SPRING_SWAP scale + opacity)
// ---------------------------------------------------------------------------

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.current,
    required this.ids,
    required this.colors,
    required this.reduce,
  });

  final int current;
  final List<String> ids;
  final BeuiColors colors;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final strings = BeuiAgentTheme.of(context).strings;
    return Semantics(
      label: strings.questionProgress(current + 1, ids.length),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < ids.length; i++) ...[
            if (i > 0) const SizedBox(width: 6), // gap-1.5
            _ProgressDot(
              key: ValueKey(ids[i]),
              active: i == current,
              filled: i <= current,
              color: colors.foreground,
              reduce: reduce,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({
    required this.active,
    required this.filled,
    required this.color,
    required this.reduce,
    super.key,
  });

  final bool active;
  final bool filled;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final scale = active ? 1.0 : 0.75;
    final opacity = filled ? 1.0 : 0.35;

    Widget dot = Container(
      width: 6, // size-1.5
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (reduce) {
      return Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: dot),
      );
    }

    // Scale (dx) + opacity (dy) on independent SPRING_SWAP channels via one
    // Offset-valued builder, rather than nesting two scalar builders.
    return MotionBuilder<Offset>(
      value: Offset(scale, opacity),
      motion: beuiSpringSwap,
      converter: const OffsetMotionConverter(),
      builder: (context, value, child) => Opacity(
        opacity: value.dy.clamp(0.0, 1.0),
        child: Transform.scale(scale: value.dx, child: child),
      ),
      child: dot,
    );
  }
}

// ---------------------------------------------------------------------------
// Spin icon
// ---------------------------------------------------------------------------

class _SpinIcon extends StatelessWidget {
  const _SpinIcon({
    required this.controller,
    required this.color,
    required this.reduce,
  });

  final AnimationController controller;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      BeuiAgentTheme.of(context).icons.spinner,
      size: BeuiAgentTheme.of(context).layout.iconSize,
      color: color,
    );
    if (reduce) return icon;
    return RotationTransition(turns: controller, child: icon);
  }
}

// ---------------------------------------------------------------------------
// Compact-to-expanded body
// ---------------------------------------------------------------------------

/// The chevron affordance. Purely visual now — the header row around it owns
/// the interaction (see [_HeaderTrigger]), so this must contribute no
/// semantics of its own or the row would announce twice.
class _ExpandChevron extends StatelessWidget {
  const _ExpandChevron({required this.expanded, required this.colors});

  final bool expanded;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = expanded ? 1.0 : 0.0;
    return SizedBox(
      width: 20,
      height: 20,
      child: SingleMotionBuilder(
        value: target,
        motion: reduce
            ? const NoMotion()
            : motionFor(context, beuiSpringSwap, isMovement: true),
        builder: (context, t, child) {
          // NoMotion *holds* whatever value it was first given, so reading
          // `t` under reduced motion freezes the chevron at its mount angle and
          // it never turns again. Snap to the target instead — the state still
          // reads, only the travel is dropped.
          return Transform.rotate(
            angle: (reduce ? target : t) * math.pi,
            child: child,
          );
        },
        child: Icon(
          agent.icons.expand,
          size: agent.layout.iconSize,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

class _ExpandableBody extends StatefulWidget {
  const _ExpandableBody({
    required this.expanded,
    required this.reduce,
    required this.compact,
    required this.expandedChild,
  });

  final bool expanded;
  final bool reduce;
  final Widget compact;
  final Widget expandedChild;

  @override
  State<_ExpandableBody> createState() => _ExpandableBodyState();
}

/// Cross-fades a compact summary into a detailed body, springing the height.
///
/// **Each child is built exactly once.** The previous implementation
/// rendered `compact` and `expandedChild` twice each: once inside two
/// `Offstage` subtrees purely to measure them, and again inside the animation
/// builder. For inert content that was merely wasteful; for anything stateful
/// it was a correctness bug. A `BeuiInput` in `expandedChild` became *two*
/// `EditableText`s with two `FocusNode`s and two independent buffers, so the
/// text the user could see was not necessarily the text the card would submit
/// — and the agent-theme demo does exactly this.
///
/// The fix is to measure the live subtree instead of a copy. Both children are
/// mounted once, in the animated stack; each is wrapped in a [_MeasureSize] so
/// it reports its own natural height. Two details make that work:
///
/// * While a height is being imposed, each child sits in an [OverflowBox] with
///   an unbounded max height, so it lays out at its *natural* size and the
///   measurement is not the clamped height we just imposed.
/// * At the rest poses the inactive child is `Offstage`, which still lays the
///   child out (so it keeps reporting its height) while contributing
///   `constraints.smallest` to the parent — which is what lets the unmeasured
///   first frame size itself to the active child rather than to the larger of
///   the two.
class _ExpandableBodyState extends State<_ExpandableBody> {
  double _compactH = 0;
  double _expandedH = 0;

  // `_MeasureSize` already reports from a post-frame callback, so setState
  // here is safe (and is what the previous implementation did).
  void _onCompactSize(Size size) {
    if ((_compactH - size.height).abs() < 0.5) return;
    setState(() => _compactH = size.height);
  }

  void _onExpandedSize(Size size) {
    if ((_expandedH - size.height).abs() < 0.5) return;
    setState(() => _expandedH = size.height);
  }

  /// One frame of the cross-fade.
  ///
  /// [height] null means "size to the active child" — used before either child
  /// has reported a height, and under reduced motion where there is no height
  /// animation to drive.
  Widget _frame({
    required double tt,
    required double? height,
    required Widget compact,
    required Widget expanded,
  }) {
    // Opacity 0 is still onstage; Offstage at the rest poses so finders,
    // focus, and screen readers only ever see the active body.
    final compactHidden = tt >= 0.999;
    final expandedHidden = tt <= 0.001;

    Widget slot({
      required Widget child,
      required double opacity,
      required bool hidden,
      required bool inert,
    }) {
      Widget content = ExcludeSemantics(
        excluding: inert,
        child: IgnorePointer(
          ignoring: inert,
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        ),
      );
      if (height != null) {
        content = OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: content,
        );
      }
      return Offstage(offstage: hidden, child: content);
    }

    final stack = Stack(
      alignment: Alignment.topCenter,
      children: [
        slot(
          child: compact,
          opacity: 1 - tt,
          hidden: compactHidden,
          inert: compactHidden || tt > 0.5,
        ),
        slot(
          child: expanded,
          opacity: tt,
          hidden: expandedHidden,
          inert: expandedHidden || tt < 0.5,
        ),
      ],
    );

    if (height == null) return stack;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(child: stack),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Built once per build, used once — this is the whole fix.
    final compact = _MeasureSize(
      onChange: _onCompactSize,
      child: widget.compact,
    );
    final expanded = _MeasureSize(
      onChange: _onExpandedSize,
      child: widget.expandedChild,
    );

    final target = widget.expanded ? 1.0 : 0.0;

    if (widget.reduce) {
      // Movement is dropped, but both children stay mounted so the swap does
      // not destroy focus, scroll offsets, or a half-typed answer.
      return _frame(
        tt: target,
        height: null,
        compact: compact,
        expanded: expanded,
      );
    }

    final measured = _compactH > 0 || _expandedH > 0;
    if (!measured) {
      return _frame(
        tt: target,
        height: null,
        compact: compact,
        expanded: expanded,
      );
    }

    final fromH = _compactH > 0
        ? _compactH
        : (_expandedH > 0 ? _expandedH : 0.0);
    final toH = _expandedH > 0 ? _expandedH : (_compactH > 0 ? _compactH : 0.0);

    return SingleMotionBuilder(
      value: target,
      // The shared layout spring, so reversing mid-flight continues from the
      // current height instead of restarting.
      motion: motionFor(context, beuiSpringLayout, isMovement: true),
      builder: (context, t, _) {
        final tt = t.clamp(0.0, 1.0);
        return _frame(
          tt: tt,
          height: fromH + (toH - fromH) * tt,
          compact: compact,
          expanded: expanded,
        );
      },
    );
  }
}

class _MeasureSize extends StatelessWidget {
  const _MeasureSize({required this.onChange, required this.child});

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) onChange(box.size);
    });
    return child;
  }
}

// ---------------------------------------------------------------------------
// Utils
// ---------------------------------------------------------------------------
