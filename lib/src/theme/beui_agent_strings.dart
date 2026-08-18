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
    this.revoke = 'Revoke',
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
    this.statusExpired = 'Expired',
    this.statusTimedOut = 'Timed out',
    this.statusAlwaysAllowed = 'Always allowed',
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
    // Code block and file diff.
    this.copyCode = 'Copy code',
    this.copyDiff = 'Copy diff',
    this.hiddenLines = _hiddenLines,
    this.hiddenLinesCollapsed = _hiddenLinesCollapsed,
    this.expandHiddenLines = _expandHiddenLines,
    // Todo list.
    this.todoListLabel = 'Agent task list',
    this.todoListTitle = 'To-dos',
    this.todoEmpty = 'No tasks yet',
    this.todoEmptyDescription =
        'Tasks will appear here as the agent plans its work.',
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
    this.activityFailedSummary = _activityFailedSummary,
    this.activityCancelledSummary = _activityCancelledSummary,
    this.activityMoreResults = _activityMoreResults,
    this.durationSeconds = _durationSeconds,
    this.durationMinutes = _durationMinutes,
    this.durationMinutesSeconds = _durationMinutesSeconds,
    this.diffAdditions = _diffAdditions,
    this.diffDeletions = _diffDeletions,
    // Streaming response.
    this.copy = 'Copy response',
    this.retry = 'Retry',
    this.continueAction = 'Continue',
    this.helpful = 'Helpful',
    this.notHelpful = 'Not helpful',
    this.showSources = _showSources,
    this.responseFailed = 'Response failed',
    this.responseStopped = 'Response stopped',
    this.responseSemantics = 'Response',
    this.responseBusySemantics = 'Response, busy',
    this.responseFailedSemantics = 'Response, failed',
    this.responseStoppedSemantics = 'Response, stopped',
    // Message scroller.
    this.jumpToLatest = 'Jump to latest',
    this.conversation = 'Conversation',
    this.messageNavigation = 'Message navigation',
    // Image generation.
    this.stopGenerating = 'Stop generating',
    // Prompt input.
    this.promptPlaceholder = 'Ask the agent to do something…',
    this.promptSemanticLabel = 'Prompt',
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

  /// Withdraws a standing [BeuiToolApprovalGrant.always] grant. Shown on the
  /// "Always allowed · Revoke" row once a tool has a standing permission.
  final String revoke;

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

  /// `BeuiToolApproval` badge for [BeuiToolApprovalStatus.expired] — the
  /// request lapsed with nothing having run.
  final String statusExpired;

  /// `BeuiToolApproval` badge for [BeuiToolApprovalStatus.timedOut] — the
  /// request was granted but execution exceeded its budget.
  final String statusTimedOut;

  /// `BeuiToolApproval` badge for an approved/complete card whose
  /// [BeuiToolApprovalGrant] is [BeuiToolApprovalGrant.always] — says *which*
  /// grant was used, so a standing permission is never silently
  /// indistinguishable from a one-off (the audit's A43).
  final String statusAlwaysAllowed;

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

  // ── Code block and file diff ──────────────────────────────────────────────

  /// Copies a `BeuiCodeBlock`'s source. Doubles as tooltip and semantics label.
  /// Distinct from [copyResult] and [copy], which name different payloads.
  final String copyCode;

  /// Copies a `BeuiFileDiff`'s patch. Confirmed state reuses [copied].
  final String copyDiff;

  /// The capped-viewport overflow cue — "3 more lines" under a code block, a
  /// diff, or a tool result whose body continues past the fold.
  ///
  /// The count is a *lower* bound when rows wrap, which is why the default says
  /// "more" rather than "remaining".
  final String Function(int count) hiddenLines;

  /// A diff hunk the consumer elided, with no way to expand it — read-only
  /// context ("12 hidden lines"). Distinct from [hiddenLines] because this
  /// counts lines that were never sent, not lines below the fold.
  final String Function(int count) hiddenLinesCollapsed;

  /// The same hunk when [BeuiFileDiff.onExpandContext] makes it a button
  /// ("Expand 12 hidden lines"). A separate field rather than a prefix on
  /// [hiddenLinesCollapsed] because the verb does not always lead.
  final String Function(int count) expandHiddenLines;

  // ── Todo list ─────────────────────────────────────────────────────────────

  /// Semantics container label on `BeuiTodoList`.
  final String todoListLabel;

  /// Default visible title.
  final String todoListTitle;

  /// Empty state headline.
  final String todoEmpty;

  /// Supporting line under [todoEmpty] explaining what will fill the panel and
  /// when. `BeuiTodoList.emptyDescription` (a per-instance override) wins over
  /// this when supplied; this wins over rendering no supporting line at all.
  final String todoEmptyDescription;

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

  /// Whole summary line for [BeuiAgentActivityStatus.failed], given the
  /// already-composed detail text ("Ran 3 tools"). Default composes
  /// `"Failed · <detail>"`. `BeuiAgentActivity.failedSummary` (a per-instance
  /// override) wins over this.
  final String Function(String detail) activityFailedSummary;

  /// Whole summary line for [BeuiAgentActivityStatus.cancelled]. Default
  /// composes `"Cancelled · <detail>"`. `BeuiAgentActivity.cancelledSummary`
  /// (a per-instance override) wins over this.
  final String Function(String detail) activityCancelledSummary;

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

  // ── Streaming response ────────────────────────────────────────────────────

  /// Copies the response text. Doubles as tooltip and semantics label.
  /// Distinct from [copyResult] ("Copy result"), which is `BeuiToolResult`'s
  /// own copy action.
  final String copy;

  /// Re-runs a failed or unsatisfactory response. Distinct from [runAgain]
  /// ("Run again"), which is `BeuiToolResult`'s own retry action.
  final String retry;

  /// Resumes a [BeuiStreamingResponseStatus.stopped] response. Named
  /// `continueAction` because `continue` is a reserved word.
  final String continueAction;

  /// Thumbs-up feedback control.
  final String helpful;

  /// Thumbs-down feedback control.
  final String notHelpful;

  /// The sources-disclosure toggle label, given the citation count
  /// ("1 source" / "3 sources").
  final String Function(int count) showSources;

  /// Message beside the destructive icon when [BeuiStreamingResponse.status]
  /// is [BeuiStreamingResponseStatus.error].
  final String responseFailed;

  /// Message beside the neutral icon when [BeuiStreamingResponse.status] is
  /// [BeuiStreamingResponseStatus.stopped].
  final String responseStopped;

  /// Screen-reader name for a settled `BeuiStreamingResponse`.
  ///
  /// The four `*Semantics` labels are whole strings, not a stem plus a
  /// modifier, because "Response, busy" is one clause and languages that
  /// inflect the noun for state cannot be served by concatenation. They are
  /// never painted — Flutter has no `Semantics.busy`, so the state rides in the
  /// label.
  final String responseSemantics;

  /// Screen-reader name while tokens are still arriving (`aria-busy`).
  final String responseBusySemantics;

  /// Screen-reader name once the response errored. Distinct from
  /// [responseFailed], which is the *visible* message beside the error icon.
  final String responseFailedSemantics;

  /// Screen-reader name once the response was truncated. Distinct from
  /// [responseStopped], which is the visible message.
  final String responseStoppedSemantics;

  // ── Message scroller ──────────────────────────────────────────────────────

  /// Label and tooltip for the "jump to latest" pill, shown once the reader has
  /// scrolled away from a streaming live edge. Shared by
  /// `BeuiMessageScroller`, `BeuiCodeBlock`, `BeuiFileDiff` and
  /// `BeuiToolResult`.
  final String jumpToLatest;

  /// Semantics container label on `BeuiMessageScroller`'s transcript.
  final String conversation;

  /// Semantics label on the scroller's navigation slot.
  final String messageNavigation;

  // ── Image generation ──────────────────────────────────────────────────────

  /// Cancels an in-flight `BeuiImageGeneration` render.
  final String stopGenerating;

  // ── Prompt input ──────────────────────────────────────────────────────────

  /// Placeholder in `BeuiPromptInput`'s empty field.
  final String promptPlaceholder;

  /// Semantics label on the same field, which the placeholder does not supply
  /// once the reader has typed.
  final String promptSemanticLabel;

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

  static String _activityFailedSummary(String detail) => 'Failed · $detail';

  static String _activityCancelledSummary(String detail) =>
      'Cancelled · $detail';

  static String _activityMoreResults(int count) => '+$count more';

  static String _durationSeconds(int seconds) => '${seconds}s';

  static String _durationMinutes(int minutes) => '${minutes}m';

  static String _durationMinutesSeconds(int minutes, int seconds) =>
      '${minutes}m ${seconds}s';

  static String _diffAdditions(int count) => '+$count';

  // U+2212 MINUS SIGN, matching the tabular figures beside it.
  static String _diffDeletions(int count) => '−$count';

  static String _showSources(int count) =>
      count == 1 ? '1 source' : '$count sources';

  static String _hiddenLines(int count) =>
      '$count more ${count == 1 ? 'line' : 'lines'}';

  static String _hiddenLinesCollapsed(int count) =>
      '$count hidden ${count == 1 ? 'line' : 'lines'}';

  static String _expandHiddenLines(int count) =>
      'Expand $count hidden ${count == 1 ? 'line' : 'lines'}';

  /// Returns a copy with the given strings replaced.
  BeuiAgentStrings copyWith({
    String? toolApprovalTitle,
    String? allowOnce,
    String? alwaysAllow,
    String? deny,
    String? viewDetails,
    String? revoke,
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
    String? statusExpired,
    String? statusTimedOut,
    String? statusAlwaysAllowed,
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
    String? copyCode,
    String? copyDiff,
    String Function(int count)? hiddenLines,
    String Function(int count)? hiddenLinesCollapsed,
    String Function(int count)? expandHiddenLines,
    String? todoListLabel,
    String? todoListTitle,
    String? todoEmpty,
    String? todoEmptyDescription,
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
    String Function(String detail)? activityFailedSummary,
    String Function(String detail)? activityCancelledSummary,
    String Function(int count)? activityMoreResults,
    String Function(int seconds)? durationSeconds,
    String Function(int minutes)? durationMinutes,
    String Function(int minutes, int seconds)? durationMinutesSeconds,
    String Function(int count)? diffAdditions,
    String Function(int count)? diffDeletions,
    String? copy,
    String? retry,
    String? continueAction,
    String? helpful,
    String? notHelpful,
    String Function(int count)? showSources,
    String? responseFailed,
    String? responseStopped,
    String? responseSemantics,
    String? responseBusySemantics,
    String? responseFailedSemantics,
    String? responseStoppedSemantics,
    String? jumpToLatest,
    String? conversation,
    String? messageNavigation,
    String? stopGenerating,
    String? promptPlaceholder,
    String? promptSemanticLabel,
  }) {
    return BeuiAgentStrings(
      toolApprovalTitle: toolApprovalTitle ?? this.toolApprovalTitle,
      allowOnce: allowOnce ?? this.allowOnce,
      alwaysAllow: alwaysAllow ?? this.alwaysAllow,
      deny: deny ?? this.deny,
      viewDetails: viewDetails ?? this.viewDetails,
      revoke: revoke ?? this.revoke,
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
      statusExpired: statusExpired ?? this.statusExpired,
      statusTimedOut: statusTimedOut ?? this.statusTimedOut,
      statusAlwaysAllowed: statusAlwaysAllowed ?? this.statusAlwaysAllowed,
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
      copyCode: copyCode ?? this.copyCode,
      copyDiff: copyDiff ?? this.copyDiff,
      hiddenLines: hiddenLines ?? this.hiddenLines,
      hiddenLinesCollapsed: hiddenLinesCollapsed ?? this.hiddenLinesCollapsed,
      expandHiddenLines: expandHiddenLines ?? this.expandHiddenLines,
      todoListLabel: todoListLabel ?? this.todoListLabel,
      todoListTitle: todoListTitle ?? this.todoListTitle,
      todoEmpty: todoEmpty ?? this.todoEmpty,
      todoEmptyDescription: todoEmptyDescription ?? this.todoEmptyDescription,
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
      activityFailedSummary:
          activityFailedSummary ?? this.activityFailedSummary,
      activityCancelledSummary:
          activityCancelledSummary ?? this.activityCancelledSummary,
      activityMoreResults: activityMoreResults ?? this.activityMoreResults,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationMinutesSeconds:
          durationMinutesSeconds ?? this.durationMinutesSeconds,
      diffAdditions: diffAdditions ?? this.diffAdditions,
      diffDeletions: diffDeletions ?? this.diffDeletions,
      copy: copy ?? this.copy,
      retry: retry ?? this.retry,
      continueAction: continueAction ?? this.continueAction,
      helpful: helpful ?? this.helpful,
      notHelpful: notHelpful ?? this.notHelpful,
      showSources: showSources ?? this.showSources,
      responseFailed: responseFailed ?? this.responseFailed,
      responseStopped: responseStopped ?? this.responseStopped,
      responseSemantics: responseSemantics ?? this.responseSemantics,
      responseBusySemantics:
          responseBusySemantics ?? this.responseBusySemantics,
      responseFailedSemantics:
          responseFailedSemantics ?? this.responseFailedSemantics,
      responseStoppedSemantics:
          responseStoppedSemantics ?? this.responseStoppedSemantics,
      jumpToLatest: jumpToLatest ?? this.jumpToLatest,
      conversation: conversation ?? this.conversation,
      messageNavigation: messageNavigation ?? this.messageNavigation,
      stopGenerating: stopGenerating ?? this.stopGenerating,
      promptPlaceholder: promptPlaceholder ?? this.promptPlaceholder,
      promptSemanticLabel: promptSemanticLabel ?? this.promptSemanticLabel,
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
        other.revoke == revoke &&
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
        other.statusExpired == statusExpired &&
        other.statusTimedOut == statusTimedOut &&
        other.statusAlwaysAllowed == statusAlwaysAllowed &&
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
        other.copyCode == copyCode &&
        other.copyDiff == copyDiff &&
        other.hiddenLines == hiddenLines &&
        other.hiddenLinesCollapsed == hiddenLinesCollapsed &&
        other.expandHiddenLines == expandHiddenLines &&
        other.todoListLabel == todoListLabel &&
        other.todoListTitle == todoListTitle &&
        other.todoEmpty == todoEmpty &&
        other.todoEmptyDescription == todoEmptyDescription &&
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
        other.activityFailedSummary == activityFailedSummary &&
        other.activityCancelledSummary == activityCancelledSummary &&
        other.activityMoreResults == activityMoreResults &&
        other.durationSeconds == durationSeconds &&
        other.durationMinutes == durationMinutes &&
        other.durationMinutesSeconds == durationMinutesSeconds &&
        other.diffAdditions == diffAdditions &&
        other.diffDeletions == diffDeletions &&
        other.copy == copy &&
        other.retry == retry &&
        other.continueAction == continueAction &&
        other.helpful == helpful &&
        other.notHelpful == notHelpful &&
        other.showSources == showSources &&
        other.responseFailed == responseFailed &&
        other.responseStopped == responseStopped &&
        other.responseSemantics == responseSemantics &&
        other.responseBusySemantics == responseBusySemantics &&
        other.responseFailedSemantics == responseFailedSemantics &&
        other.responseStoppedSemantics == responseStoppedSemantics &&
        other.jumpToLatest == jumpToLatest &&
        other.conversation == conversation &&
        other.messageNavigation == messageNavigation &&
        other.stopGenerating == stopGenerating &&
        other.promptPlaceholder == promptPlaceholder &&
        other.promptSemanticLabel == promptSemanticLabel;
  }

  @override
  int get hashCode => Object.hashAll([
    toolApprovalTitle,
    allowOnce,
    alwaysAllow,
    deny,
    viewDetails,
    revoke,
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
    statusExpired,
    statusTimedOut,
    statusAlwaysAllowed,
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
    copyCode,
    copyDiff,
    hiddenLines,
    hiddenLinesCollapsed,
    expandHiddenLines,
    todoListLabel,
    todoListTitle,
    todoEmpty,
    todoEmptyDescription,
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
    activityFailedSummary,
    activityCancelledSummary,
    activityMoreResults,
    durationSeconds,
    durationMinutes,
    durationMinutesSeconds,
    diffAdditions,
    diffDeletions,
    copy,
    retry,
    continueAction,
    helpful,
    notHelpful,
    showSources,
    responseFailed,
    responseStopped,
    responseSemantics,
    responseBusySemantics,
    responseFailedSemantics,
    responseStoppedSemantics,
    jumpToLatest,
    conversation,
    messageNavigation,
    stopGenerating,
    promptPlaceholder,
    promptSemanticLabel,
  ]);
}
