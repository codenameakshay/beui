/// User-facing copy for the AI-agent widget family.
///
/// The five agent widgets between them hardcode ~40 English literals — button
/// labels, status words, semantics labels, tooltips, and assembled summary
/// sentences. That made the cluster unusable outside English. This role moves
/// every one of them onto [BeuiAgentTheme] so a consumer can supply their own
/// (from `intl`, an `.arb` bundle, or plain strings) without forking a widget.
///
/// Every field defaults to the string the widget paints today, so installing
/// nothing changes nothing.
///
/// ## Count-bearing copy is a function, not a template
///
/// Anything that interpolates a number or assembles a sentence is a
/// `String Function(...)` rather than a format string with `$1`-style holes,
/// because word order, pluralization, and separators all move between
/// languages. Wiring `intl` in is then a one-liner per field:
///
/// ```dart
/// BeuiAgentStrings(
///   ranTools: (n) => Intl.plural(n, one: 'Ran 1 tool', other: 'Ran $n tools'),
/// );
/// ```
///
/// ## Refusal vocabulary
///
/// The audit flagged three refusal words in sibling components. Two survive on
/// purpose, because they name genuinely different acts:
///
/// * **Deny / Denied** ([deny], [statusDenied]) — a *permission* refusal. The
///   user withholds a capability from the agent (`BeuiToolApproval`). Nothing
///   was judged; a grant was refused, and the agent may ask again.
/// * **Reject / Rejected** ([reject], [statusRejected]) — a *review* verdict.
///   The user read submitted work or an answer and turned it down
///   (`BeuiApprovalCard`). The act is terminal and it judges the content.
///
/// **Cancelled** ([statusCancelled], [todoStatusCancelled]) is not a refusal at
/// all — it means the run stopped before finishing, by either party — so it
/// stays distinct from both.
///
/// A consumer who disagrees can collapse them in one line:
/// `BeuiAgentStrings(reject: 'Deny', statusRejected: 'Denied')`.
library;

import 'package:flutter/foundation.dart';

/// The copy every agent widget reads.
///
/// Resolve with `BeuiAgentTheme.of(context).strings`. Override selectively:
///
/// ```dart
/// BeuiAgentTheme(
///   strings: const BeuiAgentStrings().copyWith(
///     allowOnce: 'Autoriser une fois',
///     deny: 'Refuser',
///   ),
/// );
/// ```
@immutable
class BeuiAgentStrings {
  /// Creates a copy set. Every field defaults to the current English string.
  const BeuiAgentStrings({
    // Tool approval.
    this.toolApprovalTitle = 'Allow this tool to run?',
    this.allowOnce = 'Allow once',
    this.alwaysAllow = 'Always allow',
    this.deny = 'Deny',
    this.viewDetails = 'View details',
    // Shared status words.
    this.statusApprovalRequired = 'Approval required',
    this.statusApproving = 'Approving',
    this.statusApproved = 'Approved',
    this.statusDenied = 'Denied',
    this.statusRunning = 'Running',
    this.statusCompleted = 'Completed',
    this.statusFailed = 'Failed',
    this.statusCancelled = 'Cancelled',
    this.statusSubmitting = 'Submitting',
    this.statusRejected = 'Rejected',
    this.statusChangesRequested = 'Changes requested',
    this.statusResponseSubmitted = 'Response submitted',
    this.statusInputRequired = 'Input required',
    // Approval card.
    this.approvalCardTitle = 'Approval required',
    this.approve = 'Approve',
    this.requestChanges = 'Request changes',
    this.reject = 'Reject',
    this.submitResponse = 'Submit response',
    this.dismiss = 'Dismiss',
    this.showDetails = 'Show details',
    this.hideDetails = 'Hide details',
    this.previousQuestion = 'Previous question',
    this.nextQuestion = 'Next question',
    this.customAnswerPlaceholder = 'Add another response…',
    this.stepCounter = _stepCounter,
    this.questionProgress = _questionProgress,
    // Tool result.
    this.copyResult = 'Copy result',
    this.copied = 'Copied',
    this.runAgain = 'Run again',
    // Todo list.
    this.todoListLabel = 'Agent task list',
    this.todoListTitle = 'To-dos',
    this.todoEmpty = 'No tasks yet',
    this.todoStatusPending = 'Pending',
    this.todoStatusInProgress = 'In progress',
    this.todoStatusCompleted = 'Completed',
    this.todoStatusCancelled = 'Cancelled',
    this.todoCountDenominator = _todoCountDenominator,
    this.todoHeaderLabel = _todoHeaderLabel,
    this.todoRowLabel = _todoRowLabel,
    // Agent activity — live labels.
    this.activitySearching = 'Searching the web…',
    this.activityRunningTools = 'Running tools…',
    this.activityWorkingThroughRun = 'Working through the run…',
    this.activityWorking = 'Working through it…',
    this.activityThinking = 'Thinking…',
    // Agent activity — summaries and formatters.
    this.activitySearchedWeb = 'Searched the web',
    this.activityThoughtFor = _activityThoughtFor,
    this.activityRanTools = _activityRanTools,
    this.activityToolCallsAndMessages = _activityToolCallsAndMessages,
    this.activityCompletedSteps = _activityCompletedSteps,
    this.activityMoreResults = _activityMoreResults,
    this.durationSeconds = _durationSeconds,
    this.durationMinutes = _durationMinutes,
    this.durationMinutesSeconds = _durationMinutesSeconds,
    this.diffAdditions = _diffAdditions,
    this.diffDeletions = _diffDeletions,
  });

  // ── Tool approval ─────────────────────────────────────────────────────────

  /// Default question on `BeuiToolApproval` ("Allow this tool to run?").
  final String toolApprovalTitle;

  /// Grant for this call only.
  final String allowOnce;

  /// Standing grant for every future call.
  final String alwaysAllow;

  /// Refuse the grant. A *permission* refusal — see the class docs on why this
  /// stays distinct from [reject].
  final String deny;

  /// Expands the collapsed parameter panel.
  final String viewDetails;

  // ── Shared status words ───────────────────────────────────────────────────

  /// Badge text while a tool waits on a decision.
  final String statusApprovalRequired;

  /// Badge text between the tap and the grant landing.
  final String statusApproving;

  /// Badge text once granted.
  final String statusApproved;

  /// Badge text once the grant was refused.
  final String statusDenied;

  /// Badge text while the tool executes.
  final String statusRunning;

  /// Badge text once execution finished successfully.
  final String statusCompleted;

  /// Badge text once execution errored.
  final String statusFailed;

  /// Badge text when a run stopped before finishing. Not a refusal.
  final String statusCancelled;

  /// `BeuiApprovalCard` badge while a response is in flight.
  final String statusSubmitting;

  /// `BeuiApprovalCard` badge once the review verdict was negative. A *review*
  /// verdict — see the class docs on why this stays distinct from
  /// [statusDenied].
  final String statusRejected;

  /// `BeuiApprovalCard` badge once changes were requested.
  final String statusChangesRequested;

  /// `BeuiApprovalCard` badge once a question was answered.
  final String statusResponseSubmitted;

  /// `BeuiApprovalCard` badge while a question awaits an answer.
  final String statusInputRequired;

  // ── Approval card ─────────────────────────────────────────────────────────

  /// Default `BeuiApprovalCard` title.
  final String approvalCardTitle;

  /// Accept the submitted work.
  final String approve;

  /// Send it back for revision.
  final String requestChanges;

  /// Turn it down. See the class docs on [deny] versus this.
  final String reject;

  /// Submit the answers to a question card.
  final String submitResponse;

  /// Semantics label on the card's close control.
  final String dismiss;

  /// Semantics label on the expand control when collapsed.
  final String showDetails;

  /// Semantics label on the expand control when expanded.
  final String hideDetails;

  /// Tooltip on the back control in a stepped question card.
  final String previousQuestion;

  /// Tooltip on the forward control in a stepped question card.
  final String nextQuestion;

  /// Placeholder in the free-form answer field.
  final String customAnswerPlaceholder;

  /// The `2/5` step counter. Separate from [questionProgress] because one is
  /// glanceable chrome and the other is read aloud.
  final String Function(int step, int total) stepCounter;

  /// Semantics label on the question progress dots ("Question 2 of 5").
  final String Function(int current, int total) questionProgress;

  // ── Tool result ───────────────────────────────────────────────────────────

  /// Copies the tool's output. Doubles as tooltip and semantics label.
  final String copyResult;

  /// Confirmation shown for ~1.6s after [copyResult].
  final String copied;

  /// Re-runs the tool.
  final String runAgain;

  // ── Todo list ─────────────────────────────────────────────────────────────

  /// Semantics container label on `BeuiTodoList`.
  final String todoListLabel;

  /// Default visible title.
  final String todoListTitle;

  /// Empty state.
  final String todoEmpty;

  /// Semantics word for an unstarted row.
  final String todoStatusPending;

  /// Semantics word for the active row.
  final String todoStatusInProgress;

  /// Semantics word for a finished row.
  final String todoStatusCompleted;

  /// Semantics word for an abandoned row.
  final String todoStatusCancelled;

  /// The denominator half of the header counter, e.g. `/7`. The numerator is a
  /// bare rolling number, so only the separator needs localizing.
  final String Function(int total) todoCountDenominator;

  /// Semantics label on the header, combining progress with the toggle action.
  /// [open] is the *current* state, so the verb is the one that will happen.
  final String Function(int completed, int total, bool open) todoHeaderLabel;

  /// Semantics prefix on a row, given the row's already-localized status word.
  final String Function(String statusLabel) todoRowLabel;

  // ── Agent activity: live labels ───────────────────────────────────────────

  /// Shimmer text while a web search runs.
  final String activitySearching;

  /// Shimmer text while tools run.
  final String activityRunningTools;

  /// Shimmer text for a mixed run.
  final String activityWorkingThroughRun;

  /// Shimmer text fallback.
  final String activityWorking;

  /// Shimmer text while the model reasons.
  final String activityThinking;

  // ── Agent activity: summaries ─────────────────────────────────────────────

  /// Collapsed summary for a search-only run.
  final String activitySearchedWeb;

  /// Collapsed summary for a reasoning run, given the already-formatted
  /// duration from [durationSeconds] / [durationMinutes] /
  /// [durationMinutesSeconds].
  final String Function(String duration) activityThoughtFor;

  /// Collapsed summary for a tool run.
  final String Function(int count) activityRanTools;

  /// Collapsed summary for a mixed run.
  final String Function(int tools, int messages) activityToolCallsAndMessages;

  /// Collapsed summary for a stepped run.
  final String Function(int count) activityCompletedSteps;

  /// Overflow row under truncated search results ("+3 more").
  final String Function(int count) activityMoreResults;

  /// Sub-minute duration ("42s").
  final String Function(int seconds) durationSeconds;

  /// Whole-minute duration ("3m").
  final String Function(int minutes) durationMinutes;

  /// Mixed duration ("3m 12s").
  final String Function(int minutes, int seconds) durationMinutesSeconds;

  /// Added-line counter on a tool row ("+42").
  final String Function(int count) diffAdditions;

  /// Removed-line counter on a tool row ("−7" — U+2212, not a hyphen).
  final String Function(int count) diffDeletions;

  // ── Defaults ──────────────────────────────────────────────────────────────
  //
  // Declared as static methods rather than inline closures so the tear-offs are
  // canonicalized: `const BeuiAgentStrings() == const BeuiAgentStrings()` holds,
  // which `ThemeData` extension equality depends on.

  static String _stepCounter(int step, int total) => '$step/$total';

  static String _questionProgress(int current, int total) =>
      'Question $current of $total';

  static String _todoCountDenominator(int total) => '/$total';

  static String _todoHeaderLabel(int completed, int total, bool open) =>
      '$completed of $total tasks completed. '
      '${open ? 'Collapse' : 'Expand'} task list';

  static String _todoRowLabel(String statusLabel) => '$statusLabel: ';

  static String _activityThoughtFor(String duration) => 'Thought for $duration';

  static String _activityRanTools(int count) =>
      'Ran $count ${count == 1 ? 'tool' : 'tools'}';

  static String _activityToolCallsAndMessages(int tools, int messages) =>
      '$tools ${tools == 1 ? 'tool call' : 'tool calls'}, '
      '$messages ${messages == 1 ? 'message' : 'messages'}';

  static String _activityCompletedSteps(int count) =>
      'Completed $count ${count == 1 ? 'step' : 'steps'}';

  static String _activityMoreResults(int count) => '+$count more';

  static String _durationSeconds(int seconds) => '${seconds}s';

  static String _durationMinutes(int minutes) => '${minutes}m';

  static String _durationMinutesSeconds(int minutes, int seconds) =>
      '${minutes}m ${seconds}s';

  static String _diffAdditions(int count) => '+$count';

  // U+2212 MINUS SIGN, matching the tabular figures beside it.
  static String _diffDeletions(int count) => '−$count';

  /// Returns a copy with the given strings replaced.
  BeuiAgentStrings copyWith({
    String? toolApprovalTitle,
    String? allowOnce,
    String? alwaysAllow,
    String? deny,
    String? viewDetails,
    String? statusApprovalRequired,
    String? statusApproving,
    String? statusApproved,
    String? statusDenied,
    String? statusRunning,
    String? statusCompleted,
    String? statusFailed,
    String? statusCancelled,
    String? statusSubmitting,
    String? statusRejected,
    String? statusChangesRequested,
    String? statusResponseSubmitted,
    String? statusInputRequired,
    String? approvalCardTitle,
    String? approve,
    String? requestChanges,
    String? reject,
    String? submitResponse,
    String? dismiss,
    String? showDetails,
    String? hideDetails,
    String? previousQuestion,
    String? nextQuestion,
    String? customAnswerPlaceholder,
    String Function(int step, int total)? stepCounter,
    String Function(int current, int total)? questionProgress,
    String? copyResult,
    String? copied,
    String? runAgain,
    String? todoListLabel,
    String? todoListTitle,
    String? todoEmpty,
    String? todoStatusPending,
    String? todoStatusInProgress,
    String? todoStatusCompleted,
    String? todoStatusCancelled,
    String Function(int total)? todoCountDenominator,
    String Function(int completed, int total, bool open)? todoHeaderLabel,
    String Function(String statusLabel)? todoRowLabel,
    String? activitySearching,
    String? activityRunningTools,
    String? activityWorkingThroughRun,
    String? activityWorking,
    String? activityThinking,
    String? activitySearchedWeb,
    String Function(String duration)? activityThoughtFor,
    String Function(int count)? activityRanTools,
    String Function(int tools, int messages)? activityToolCallsAndMessages,
    String Function(int count)? activityCompletedSteps,
    String Function(int count)? activityMoreResults,
    String Function(int seconds)? durationSeconds,
    String Function(int minutes)? durationMinutes,
    String Function(int minutes, int seconds)? durationMinutesSeconds,
    String Function(int count)? diffAdditions,
    String Function(int count)? diffDeletions,
  }) {
    return BeuiAgentStrings(
      toolApprovalTitle: toolApprovalTitle ?? this.toolApprovalTitle,
      allowOnce: allowOnce ?? this.allowOnce,
      alwaysAllow: alwaysAllow ?? this.alwaysAllow,
      deny: deny ?? this.deny,
      viewDetails: viewDetails ?? this.viewDetails,
      statusApprovalRequired:
          statusApprovalRequired ?? this.statusApprovalRequired,
      statusApproving: statusApproving ?? this.statusApproving,
      statusApproved: statusApproved ?? this.statusApproved,
      statusDenied: statusDenied ?? this.statusDenied,
      statusRunning: statusRunning ?? this.statusRunning,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusFailed: statusFailed ?? this.statusFailed,
      statusCancelled: statusCancelled ?? this.statusCancelled,
      statusSubmitting: statusSubmitting ?? this.statusSubmitting,
      statusRejected: statusRejected ?? this.statusRejected,
      statusChangesRequested:
          statusChangesRequested ?? this.statusChangesRequested,
      statusResponseSubmitted:
          statusResponseSubmitted ?? this.statusResponseSubmitted,
      statusInputRequired: statusInputRequired ?? this.statusInputRequired,
      approvalCardTitle: approvalCardTitle ?? this.approvalCardTitle,
      approve: approve ?? this.approve,
      requestChanges: requestChanges ?? this.requestChanges,
      reject: reject ?? this.reject,
      submitResponse: submitResponse ?? this.submitResponse,
      dismiss: dismiss ?? this.dismiss,
      showDetails: showDetails ?? this.showDetails,
      hideDetails: hideDetails ?? this.hideDetails,
      previousQuestion: previousQuestion ?? this.previousQuestion,
      nextQuestion: nextQuestion ?? this.nextQuestion,
      customAnswerPlaceholder:
          customAnswerPlaceholder ?? this.customAnswerPlaceholder,
      stepCounter: stepCounter ?? this.stepCounter,
      questionProgress: questionProgress ?? this.questionProgress,
      copyResult: copyResult ?? this.copyResult,
      copied: copied ?? this.copied,
      runAgain: runAgain ?? this.runAgain,
      todoListLabel: todoListLabel ?? this.todoListLabel,
      todoListTitle: todoListTitle ?? this.todoListTitle,
      todoEmpty: todoEmpty ?? this.todoEmpty,
      todoStatusPending: todoStatusPending ?? this.todoStatusPending,
      todoStatusInProgress: todoStatusInProgress ?? this.todoStatusInProgress,
      todoStatusCompleted: todoStatusCompleted ?? this.todoStatusCompleted,
      todoStatusCancelled: todoStatusCancelled ?? this.todoStatusCancelled,
      todoCountDenominator: todoCountDenominator ?? this.todoCountDenominator,
      todoHeaderLabel: todoHeaderLabel ?? this.todoHeaderLabel,
      todoRowLabel: todoRowLabel ?? this.todoRowLabel,
      activitySearching: activitySearching ?? this.activitySearching,
      activityRunningTools: activityRunningTools ?? this.activityRunningTools,
      activityWorkingThroughRun:
          activityWorkingThroughRun ?? this.activityWorkingThroughRun,
      activityWorking: activityWorking ?? this.activityWorking,
      activityThinking: activityThinking ?? this.activityThinking,
      activitySearchedWeb: activitySearchedWeb ?? this.activitySearchedWeb,
      activityThoughtFor: activityThoughtFor ?? this.activityThoughtFor,
      activityRanTools: activityRanTools ?? this.activityRanTools,
      activityToolCallsAndMessages:
          activityToolCallsAndMessages ?? this.activityToolCallsAndMessages,
      activityCompletedSteps:
          activityCompletedSteps ?? this.activityCompletedSteps,
      activityMoreResults: activityMoreResults ?? this.activityMoreResults,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationMinutesSeconds:
          durationMinutesSeconds ?? this.durationMinutesSeconds,
      diffAdditions: diffAdditions ?? this.diffAdditions,
      diffDeletions: diffDeletions ?? this.diffDeletions,
    );
  }

  /// Copy does not interpolate — [ThemeExtension.lerp] snaps it at the
  /// midpoint, like [BeuiColors.colorTheme].
  static BeuiAgentStrings lerp(
    BeuiAgentStrings a,
    BeuiAgentStrings b,
    double t,
  ) => t < 0.5 ? a : b;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentStrings &&
        other.toolApprovalTitle == toolApprovalTitle &&
        other.allowOnce == allowOnce &&
        other.alwaysAllow == alwaysAllow &&
        other.deny == deny &&
        other.viewDetails == viewDetails &&
        other.statusApprovalRequired == statusApprovalRequired &&
        other.statusApproving == statusApproving &&
        other.statusApproved == statusApproved &&
        other.statusDenied == statusDenied &&
        other.statusRunning == statusRunning &&
        other.statusCompleted == statusCompleted &&
        other.statusFailed == statusFailed &&
        other.statusCancelled == statusCancelled &&
        other.statusSubmitting == statusSubmitting &&
        other.statusRejected == statusRejected &&
        other.statusChangesRequested == statusChangesRequested &&
        other.statusResponseSubmitted == statusResponseSubmitted &&
        other.statusInputRequired == statusInputRequired &&
        other.approvalCardTitle == approvalCardTitle &&
        other.approve == approve &&
        other.requestChanges == requestChanges &&
        other.reject == reject &&
        other.submitResponse == submitResponse &&
        other.dismiss == dismiss &&
        other.showDetails == showDetails &&
        other.hideDetails == hideDetails &&
        other.previousQuestion == previousQuestion &&
        other.nextQuestion == nextQuestion &&
        other.customAnswerPlaceholder == customAnswerPlaceholder &&
        other.stepCounter == stepCounter &&
        other.questionProgress == questionProgress &&
        other.copyResult == copyResult &&
        other.copied == copied &&
        other.runAgain == runAgain &&
        other.todoListLabel == todoListLabel &&
        other.todoListTitle == todoListTitle &&
        other.todoEmpty == todoEmpty &&
        other.todoStatusPending == todoStatusPending &&
        other.todoStatusInProgress == todoStatusInProgress &&
        other.todoStatusCompleted == todoStatusCompleted &&
        other.todoStatusCancelled == todoStatusCancelled &&
        other.todoCountDenominator == todoCountDenominator &&
        other.todoHeaderLabel == todoHeaderLabel &&
        other.todoRowLabel == todoRowLabel &&
        other.activitySearching == activitySearching &&
        other.activityRunningTools == activityRunningTools &&
        other.activityWorkingThroughRun == activityWorkingThroughRun &&
        other.activityWorking == activityWorking &&
        other.activityThinking == activityThinking &&
        other.activitySearchedWeb == activitySearchedWeb &&
        other.activityThoughtFor == activityThoughtFor &&
        other.activityRanTools == activityRanTools &&
        other.activityToolCallsAndMessages == activityToolCallsAndMessages &&
        other.activityCompletedSteps == activityCompletedSteps &&
        other.activityMoreResults == activityMoreResults &&
        other.durationSeconds == durationSeconds &&
        other.durationMinutes == durationMinutes &&
        other.durationMinutesSeconds == durationMinutesSeconds &&
        other.diffAdditions == diffAdditions &&
        other.diffDeletions == diffDeletions;
  }

  @override
  int get hashCode => Object.hashAll([
    toolApprovalTitle,
    allowOnce,
    alwaysAllow,
    deny,
    viewDetails,
    statusApprovalRequired,
    statusApproving,
    statusApproved,
    statusDenied,
    statusRunning,
    statusCompleted,
    statusFailed,
    statusCancelled,
    statusSubmitting,
    statusRejected,
    statusChangesRequested,
    statusResponseSubmitted,
    statusInputRequired,
    approvalCardTitle,
    approve,
    requestChanges,
    reject,
    submitResponse,
    dismiss,
    showDetails,
    hideDetails,
    previousQuestion,
    nextQuestion,
    customAnswerPlaceholder,
    stepCounter,
    questionProgress,
    copyResult,
    copied,
    runAgain,
    todoListLabel,
    todoListTitle,
    todoEmpty,
    todoStatusPending,
    todoStatusInProgress,
    todoStatusCompleted,
    todoStatusCancelled,
    todoCountDenominator,
    todoHeaderLabel,
    todoRowLabel,
    activitySearching,
    activityRunningTools,
    activityWorkingThroughRun,
    activityWorking,
    activityThinking,
    activitySearchedWeb,
    activityThoughtFor,
    activityRanTools,
    activityToolCallsAndMessages,
    activityCompletedSteps,
    activityMoreResults,
    durationSeconds,
    durationMinutes,
    durationMinutesSeconds,
    diffAdditions,
    diffDeletions,
  ]);
}
