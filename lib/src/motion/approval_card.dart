import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'action_swap.dart';
import 'button/base.dart';
import 'checkbox.dart';
import 'input.dart';
import 'radio.dart';

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
          _listEq(selected, other.selected) &&
          custom == other.custom;

  @override
  int get hashCode => Object.hash(Object.hashAll(selected), custom);
}

/// Map of question id → answer — the Flutter port of `ApprovalCardAnswers`.
typedef BeuiApprovalCardAnswers = Map<String, BeuiApprovalCardAnswer>;

// ---------------------------------------------------------------------------
// Status helpers / palette
// ---------------------------------------------------------------------------

String _statusLabel(BeuiApprovalCardStatus status) {
  return switch (status) {
    BeuiApprovalCardStatus.submitting => 'Submitting',
    BeuiApprovalCardStatus.approved => 'Approved',
    BeuiApprovalCardStatus.rejected => 'Rejected',
    BeuiApprovalCardStatus.changesRequested => 'Changes requested',
    BeuiApprovalCardStatus.answered => 'Response submitted',
    BeuiApprovalCardStatus.pending => 'Input required',
  };
}

// Tailwind status accents (light / dark), matching the source classes.
const _emerald600 = Color(0xFF009966);
const _emerald400 = Color(0xFF00D492);
const _rose600 = Color(0xFFEC003F);
const _rose400 = Color(0xFFFF637E);
const _amber600 = Color(0xFFE17100);
const _amber400 = Color(0xFFFFB900);
const _amber500 = Color(0xFFFE9A00);
const _blue600 = Color(0xFF155DFC);
const _blue400 = Color(0xFF51A2FF);
const _blue500 = Color(0xFF2B7FFF);
const _rose500 = Color(0xFFFF2056);

Color _statusIconColor(BeuiApprovalCardStatus status, bool dark) {
  return switch (status) {
    BeuiApprovalCardStatus.approved ||
    BeuiApprovalCardStatus.answered => dark ? _emerald400 : _emerald600,
    BeuiApprovalCardStatus.rejected => dark ? _rose400 : _rose600,
    BeuiApprovalCardStatus.changesRequested => dark ? _amber400 : _amber600,
    BeuiApprovalCardStatus.pending || BeuiApprovalCardStatus.submitting =>
      Colors.transparent, // resolved from theme muted/busy separately
  };
}

({Color fg, Color bg, Color border}) _statusBadgePalette(
  BeuiApprovalCardStatus status,
  bool dark,
) {
  if (status == BeuiApprovalCardStatus.pending ||
      status == BeuiApprovalCardStatus.changesRequested) {
    final fg = dark ? _amber400 : _amber600;
    return (
      fg: fg,
      bg: _amber500.withValues(alpha: 0.10),
      border: _amber500.withValues(alpha: 0.30),
    );
  }
  if (status == BeuiApprovalCardStatus.submitting) {
    final fg = dark ? _blue400 : _blue600;
    return (
      fg: fg,
      bg: _blue500.withValues(alpha: 0.10),
      border: _blue500.withValues(alpha: 0.30),
    );
  }
  if (status == BeuiApprovalCardStatus.approved ||
      status == BeuiApprovalCardStatus.answered) {
    final fg = dark ? _emerald400 : _emerald600;
    return (
      fg: fg,
      bg: const Color(0xFF00BC7D).withValues(alpha: 0.10),
      border: const Color(0xFF00BC7D).withValues(alpha: 0.30),
    );
  }
  // rejected
  final fg = dark ? _rose400 : _rose600;
  return (
    fg: fg,
    bg: _rose500.withValues(alpha: 0.10),
    border: _rose500.withValues(alpha: 0.30),
  );
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _disclosureOpen = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _disclosureClose = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);
const _stepDuration = Duration(milliseconds: 200);
const _autoAdvanceDelay = Duration(milliseconds: 240);
const _spinPeriod = Duration(milliseconds: 900);

/// Compact-to-expanded height uses the shared layout spring so reversing
/// mid-flight continues from the current height instead of restarting.
const _expandSpring = beuiSpringLayout;

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
    this.title = 'Approval required',
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
    this.approveLabel = 'Approve',
    this.submitLabel = 'Submit response',
    this.result,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChanged,
    this.headerAction,
    this.compactChild,
    this.expandedChild,
    super.key,
  });

  /// Header title when not in a question step (or when the step has no title).
  final String title;

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
  final String approveLabel;

  /// Label on the final Submit button of a question flow.
  final String submitLabel;

  /// Collapsed result copy shown when the card is no longer interactive.
  /// Falls back to the status label when null.
  final Widget? result;

  /// Controlled compact-to-expanded state. Null → uncontrolled.
  /// Ignored when [expandedChild] is null.
  final bool? expanded;

  /// Uncontrolled seed when [expanded] is null.
  final bool defaultExpanded;

  /// Called whenever compact/expanded changes.
  final ValueChanged<bool>? onExpandedChanged;

  /// Optional trailing header control (for example an edit glyph). Rendered
  /// before the dismiss button; it does not toggle expansion.
  final Widget? headerAction;

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
    final reduce =
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations ||
        false;
    // MediaQuery is not available in initState; also re-checked in build.
    if (_busy && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
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
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dark = theme.brightness == Brightness.dark;

    // Keep spin in sync with reduced-motion (MediaQuery only available here).
    if (_busy && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating || _spin.value != 0) {
      _spin
        ..stop()
        ..value = 0;
    }

    final question = _question;
    final displayTitle = question?.title ?? widget.title;
    final titleKey = question?.id ?? widget.status.name;
    final statusLabel = _statusLabel(widget.status);
    final answer = _currentAnswer;

    final iconColor = _resolveIconColor(colors, dark);
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
      liveRegion: _busy,
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
                      dark: dark,
                      onDismiss: widget.onDismiss,
                      headerAction: widget.headerAction,
                      expandable: _expandable,
                      expanded: _expanded,
                      onToggleExpanded: _expandable
                          ? () => _setExpanded(!_expanded)
                          : null,
                    ),
                    _AgentDisclosure(
                      open: _interactive,
                      reduce: reduce,
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
                              submitLabel: widget.submitLabel,
                              onPrev: () => _setStep(_currentStep - 1),
                              onContinue: _continueQuestion,
                              spin: _spin,
                            )
                          else
                            _SimpleActions(
                              busy: _busy,
                              colors: colors,
                              dark: dark,
                              approveLabel: widget.approveLabel,
                              onApprove: widget.onApprove,
                              onRequestChanges: widget.onRequestChanges,
                              onReject: widget.onReject,
                            ),
                        ],
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

  Color _resolveIconColor(BeuiColors colors, bool dark) {
    if (_busy) return colors.mutedForeground;
    if (_interactive) return colors.mutedForeground;
    final accent = _statusIconColor(widget.status, dark);
    if (accent.a == 0) return colors.mutedForeground;
    return accent;
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
    required this.dark,
    required this.onDismiss,
    this.headerAction,
    this.expandable = false,
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
  final bool dark;
  final VoidCallback? onDismiss;
  final Widget? headerAction;
  final bool expandable;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return Row(
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
            '${currentStep + 1}/$questionCount',
            style: agent.typography.status.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.mutedForeground.withValues(alpha: 0.65),
            ),
          )
        else
          _StatusBadge(
            label: statusLabel,
            palette: _statusBadgePalette(status, dark),
          ),
        if (expandable && onToggleExpanded != null) ...[
          SizedBox(width: agent.layout.actionSpacing),
          _ExpandToggle(
            expanded: expanded,
            onToggle: onToggleExpanded!,
            colors: colors,
          ),
        ],
        if (headerAction != null) ...[
          SizedBox(width: agent.layout.actionSpacing),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.palette});

  final String label;
  final ({Color fg, Color bg, Color border}) palette;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bg,
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
          color: palette.fg,
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
      label: 'Dismiss',
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
                      question.customPlaceholder ?? 'Add another response…',
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
    return Row(
      children: [
        Tooltip(
          message: 'Previous question',
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
          message: isLast ? 'Submit response' : 'Next question',
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
    required this.dark,
    required this.approveLabel,
    required this.onApprove,
    required this.onRequestChanges,
    required this.onReject,
  });

  final bool busy;
  final BeuiColors colors;
  final bool dark;
  final String approveLabel;
  final VoidCallback? onApprove;
  final VoidCallback? onRequestChanges;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, // gap-2
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BeuiButton(
          size: BeuiButtonSize.sm,
          onPressed: busy ? null : onApprove,
          child: Text(approveLabel),
        ),
        if (onRequestChanges != null)
          BeuiButton(
            variant: BeuiButtonVariant.secondary,
            size: BeuiButtonSize.sm,
            onPressed: busy ? null : onRequestChanges,
            child: const Text('Request changes'),
          ),
        if (onReject != null)
          _RejectButton(
            busy: busy,
            colors: colors,
            dark: dark,
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
    required this.dark,
    required this.onReject,
  });

  final bool busy;
  final BeuiColors colors;
  final bool dark;
  final VoidCallback onReject;

  @override
  State<_RejectButton> createState() => _RejectButtonState();
}

class _RejectButtonState extends State<_RejectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rose = widget.dark ? _rose400 : _rose600;
    final color = _hovered ? rose : widget.colors.mutedForeground;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: BeuiButton(
        variant: BeuiButtonVariant.ghost,
        size: BeuiButtonSize.sm,
        onPressed: widget.busy ? null : widget.onReject,
        child: Text('Reject', style: TextStyle(color: color)),
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
    return Semantics(
      label: 'Question ${current + 1} of ${ids.length}',
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

    // Drive scale + opacity with SPRING_SWAP via a packed value.
    // Pack: scale in integer part * 100 + opacity * 100 → decode in builder.
    // Simpler: two SingleMotionBuilders nested, or one MotionBuilder.
    // Nested is fine for 6px dots.
    return SingleMotionBuilder(
      value: scale,
      motion: motionFor(context, beuiSpringSwap, isMovement: true),
      builder: (context, s, child) {
        return SingleMotionBuilder(
          value: opacity,
          motion: motionFor(context, beuiSpringSwap, isMovement: false),
          builder: (context, o, child) {
            return Opacity(
              opacity: o.clamp(0.0, 1.0),
              child: Transform.scale(scale: s, child: child),
            );
          },
          child: child,
        );
      },
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

class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.expanded,
    required this.onToggle,
    required this.colors,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final label = expanded ? 'Hide details' : 'Show details';
    return Semantics(
      button: true,
      label: label,
      expanded: expanded,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onToggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: const ValueKey<String>('beui-approval-expand'),
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: SizedBox(
            width: 20,
            height: 20,
            child: SingleMotionBuilder(
              value: expanded ? 1.0 : 0.0,
              motion: reduce
                  ? const NoMotion()
                  : motionFor(context, beuiSpringSwap, isMovement: true),
              builder: (context, t, child) {
                return Transform.rotate(angle: t * 3.1415926535, child: child);
              },
              child: Icon(
                agent.icons.expand,
                size: agent.layout.iconSize,
                color: colors.mutedForeground,
              ),
            ),
          ),
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

class _ExpandableBodyState extends State<_ExpandableBody> {
  double _compactH = 0;
  double _expandedH = 0;

  void _onCompactSize(Size size) {
    if ((_compactH - size.height).abs() < 0.5) return;
    setState(() => _compactH = size.height);
  }

  void _onExpandedSize(Size size) {
    if ((_expandedH - size.height).abs() < 0.5) return;
    setState(() => _expandedH = size.height);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) {
      return widget.expanded ? widget.expandedChild : widget.compact;
    }

    final target = widget.expanded ? 1.0 : 0.0;
    final measured = _compactH > 0 || _expandedH > 0;
    final fromH = _compactH > 0
        ? _compactH
        : (_expandedH > 0 ? _expandedH : 0.0);
    final toH = _expandedH > 0 ? _expandedH : (_compactH > 0 ? _compactH : 0.0);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Offstage(
          offstage: true,
          child: ExcludeSemantics(
            child: _MeasureSize(
              onChange: _onCompactSize,
              child: widget.compact,
            ),
          ),
        ),
        Offstage(
          offstage: true,
          child: ExcludeSemantics(
            child: _MeasureSize(
              onChange: _onExpandedSize,
              child: widget.expandedChild,
            ),
          ),
        ),
        if (!measured)
          widget.expanded ? widget.expandedChild : widget.compact
        else
          SingleMotionBuilder(
            value: target,
            motion: motionFor(context, _expandSpring, isMovement: true),
            builder: (context, t, child) {
              final tt = t.clamp(0.0, 1.0);
              final height = fromH + (toH - fromH) * tt;
              // Opacity 0 is still onstage; Offstage at the rest poses so
              // finders, focus, and screen readers only see the active body.
              final compactHidden = tt >= 0.999;
              final expandedHidden = tt <= 0.001;
              return SizedBox(
                height: height,
                width: double.infinity,
                child: ClipRect(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Offstage(
                        offstage: compactHidden,
                        child: IgnorePointer(
                          ignoring: compactHidden || tt > 0.5,
                          child: ExcludeSemantics(
                            excluding: compactHidden || tt > 0.5,
                            child: Opacity(
                              opacity: (1 - tt).clamp(0.0, 1.0),
                              child: widget.compact,
                            ),
                          ),
                        ),
                      ),
                      Offstage(
                        offstage: expandedHidden,
                        child: IgnorePointer(
                          ignoring: expandedHidden || tt < 0.5,
                          child: ExcludeSemantics(
                            excluding: expandedHidden || tt < 0.5,
                            child: Opacity(
                              opacity: tt,
                              child: widget.expandedChild,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
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
// Utils
// ---------------------------------------------------------------------------

bool _listEq(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
