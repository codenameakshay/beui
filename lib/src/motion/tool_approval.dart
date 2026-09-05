import 'package:flutter/material.dart';

import '../theme/beui_agent_status_colors.dart';
import '../theme/beui_agent_strings.dart';
import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_chevron.dart';
import '_disclosure.dart';
import '_engine.dart';
import '_hit_target.dart';
import 'button/base.dart';
import 'code_block.dart' show BeuiCodeLanguage;
import 'tool_result.dart' show BeuiToolResultOutput;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiToolApproval] surface (source `ToolApprovalStatus`).
enum BeuiToolApprovalStatus {
  /// Waiting for the user to allow / deny.
  pending,

  /// Allow action accepted; brief intermediate state before approved.
  approving,

  /// Explicitly approved for this run.
  approved,

  /// User denied execution.
  denied,

  /// Tool is executing after approval.
  running,

  /// Tool finished successfully.
  complete,

  /// Tool failed.
  error,

  /// The request lapsed without a decision — the agent gave up waiting.
  ///
  /// A *terminal* state, distinct from [timedOut]: nothing ran, and the agent
  /// is no longer holding the turn open. Renders greyed with no action row.
  expired,

  /// The request was granted but the tool exceeded its execution budget.
  ///
  /// Distinct from [expired] (which never ran) and from [error] (which failed
  /// on its own terms): the run was cut off from outside.
  timedOut,
}

/// How consequential the requested capability is — the risk tier that drives
/// [BeuiToolApproval]'s glyph, border, badge, and action emphasis.
///
/// The audit's A3: `rm -rf ~/project` and `ls` rendered byte-identically, so
/// the card could not warn. Severity is *declared by the caller*, never
/// inferred from the tool slug — guessing risk from a string is exactly the
/// kind of silent heuristic a permission prompt must not have.
enum BeuiToolApprovalSeverity {
  /// Ordinary read-or-write capability. Allow-once leads; the card is neutral.
  normal,

  /// Worth a second look — the card takes an amber emphasis border and the
  /// badge warms, but the action hierarchy is unchanged.
  elevated,

  /// Irreversible or destructive. The shield becomes a warning triangle, the
  /// card takes a destructive emphasis border, `Deny` is promoted to the solid
  /// lead action, `Allow once` is demoted to outlined, and `Always allow` is
  /// suppressed by default (see [BeuiToolApproval.allowAlways]) — a standing
  /// grant for a destructive capability is not something to offer in passing.
  destructive,
}

/// Which grant a [BeuiToolApproval] was approved under.
///
/// The audit's A43: after the fact, "approved once" and "always allowed" were
/// indistinguishable, so a user could not tell whether they had handed over a
/// standing permission. Pass it back on the approved/complete states and the
/// badge says which — and, with [BeuiToolApproval.onRevoke], offers a way out.
enum BeuiToolApprovalGrant {
  /// Approved for this call only.
  once,

  /// A standing grant — the agent may run this tool again without asking.
  always,
}

/// One parameter row inside the "View details" disclosure
/// (source `ToolApprovalParameter`).
@immutable
class BeuiToolApprovalParameter {
  /// Creates a parameter row.
  ///
  /// [label] and [value] each accept a [String] or a [Widget]; anything else
  /// is a debug assertion failure (the audit's A41 — `value: 42` used to
  /// compile and render `"42"` through `toString()`). Prefer the typed
  /// [BeuiToolApprovalParameter.text] and [BeuiToolApprovalParameter.widget]
  /// constructors in new code.
  const BeuiToolApprovalParameter({
    required this.id,
    required this.label,
    required this.value,
  }) : assert(
         label is String || label is Widget,
         'BeuiToolApprovalParameter.label must be a String or a Widget.',
       ),
       assert(
         value is String || value is Widget,
         'BeuiToolApprovalParameter.value must be a String or a Widget.',
       );

  /// Creates a plain text parameter row — the statically-typed path.
  const BeuiToolApprovalParameter.text({
    required this.id,
    required String this.label,
    required String this.value,
  });

  /// Creates a parameter row whose value is a widget (typically a
  /// [BeuiToolApprovalCode]) — the statically-typed path.
  const BeuiToolApprovalParameter.widget({
    required this.id,
    required String this.label,
    required Widget this.value,
  });

  /// Stable identity for the row (source `id`).
  final String id;

  /// Left-column label. A [String] or a [Widget].
  final Object label;

  /// Right-column value. A [String] or a [Widget] — typically
  /// [BeuiToolApprovalCode] for shell / request snippets.
  final Object value;
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _actionsIn = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _actionsInReduced = CurvedMotion(
  Duration(milliseconds: 120),
  beuiEaseOut,
);
// Exit is faster than the entrance, per the repo motion rules.
const _actionsOut = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);
const _actionsOutReduced = CurvedMotion(
  Duration(milliseconds: 100),
  beuiEaseOut,
);
const _spinPeriod = Duration(milliseconds: 900);

/// Press scale for every control in the agent cluster (the audit's A17 — this
/// file used 0.97, `tool_result` used 0.9, `message_bubble` 0.99).
const double beuiAgentPressScale = 0.97;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Maps an approval status onto the themeable status role.
///
/// [expired] and [timedOut] deliberately land on `neutral` rather than
/// `failed`: nothing went wrong, the window simply closed. Colouring a lapsed
/// request rose would cry wolf next to a genuine failure.
BeuiAgentStatus _statusRole(BeuiToolApprovalStatus status) => switch (status) {
  BeuiToolApprovalStatus.pending => BeuiAgentStatus.pending,
  BeuiToolApprovalStatus.approving => BeuiAgentStatus.running,
  BeuiToolApprovalStatus.running => BeuiAgentStatus.running,
  BeuiToolApprovalStatus.approved => BeuiAgentStatus.success,
  BeuiToolApprovalStatus.complete => BeuiAgentStatus.success,
  BeuiToolApprovalStatus.denied => BeuiAgentStatus.denied,
  BeuiToolApprovalStatus.error => BeuiAgentStatus.failed,
  BeuiToolApprovalStatus.expired => BeuiAgentStatus.neutral,
  BeuiToolApprovalStatus.timedOut => BeuiAgentStatus.neutral,
};

Widget _asWidget(Object value, {TextStyle? style, int? maxLines}) {
  if (value is Widget) return value;
  return Text(
    value.toString(),
    style: style,
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : null,
    softWrap: maxLines == null,
  );
}

// ---------------------------------------------------------------------------
// BeuiToolApprovalCode
// ---------------------------------------------------------------------------

/// Syntax-tinted mono snippet for a [BeuiToolApproval] parameter value —
/// the Flutter port of the source's `ToolApprovalCode` (backed by
/// `AgentCode` / [BeuiToolResultOutput]).
///
/// Renders [code] inside a rounded bordered muted surface matching the
/// source classes `rounded-lg border border-border/50 bg-muted/30 px-2.5 py-2`.
class BeuiToolApprovalCode extends StatelessWidget {
  /// Creates a bordered mono code chip.
  const BeuiToolApprovalCode({
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
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.30),
        borderRadius: agent.shapes.control, // rounded-lg
        border: Border.all(
          color: colors.border.withValues(alpha: colors.border.a * 0.50),
          width: agent.structure.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: BeuiToolResultOutput(code: code, language: language),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiToolApproval
// ---------------------------------------------------------------------------

/// A human-in-the-loop permission card for reviewing tool details, allowing
/// once, remembering access, or denying execution — the Flutter port of
/// beUI's `tool-approval`.
///
/// **Layout.** Leading status glyph · title / tool / status badge · optional
/// description · "View details" disclosure of [parameters] · pending action
/// row.
///
/// **This is the trust surface.** Four properties are load-bearing and are
/// tested as such:
///
/// 1. *The command is visible when there is one.* [defaultOpen] is null by
///    default, which resolves to `parameters.isNotEmpty` — a card that has
///    something to show shows it. Being asked to allow `terminal.run` with the
///    command folded away is not consent. Parameterless approvals still start
///    collapsed, because there is nothing behind the chevron.
/// 2. *Every action is keyboard-reachable.* [BeuiButton] backs Allow once /
///    Always allow / Deny and the details toggle, so Tab reaches them,
///    Enter/Space activates, and the focus ring is visible. `Deny` is in the
///    traversal order like everything else — the previous implementation had
///    no keyboard path to *refuse*.
/// 3. *Risk is declarable.* See [severity] and [BeuiToolApprovalSeverity].
/// 4. *A decision fires once.* The exiting action row stops hit-testing the
///    moment the decision lands, not 220ms later when the fade finishes.
///
/// **Open state.** Controlled when [open] is non-null (drive via
/// [onOpenChange]); otherwise internal state seeded by [defaultOpen]. Leaving
/// [BeuiToolApprovalStatus.pending] auto-collapses the details panel — the
/// decision is made, so the evidence folds away.
///
/// **`defaultOpen` policy.** Across the transcript the rule
/// is: *a surface that is still asking or still running opens; a historical
/// record collapses.* This card is asking, so it opens whenever it has
/// parameters. [BeuiToolResult] force-opens while running and collapses on
/// completion for the same reason.
///
/// **Motion.** Chevron rotates on [beuiSpringSwap]; the disclosure opens in
/// 220ms / closes in 140ms [beuiEaseOut] via [BeuiAgentDisclosureInternal];
/// pending actions fade/slide on [beuiEaseOut] (0.22s enter, 0.14s exit);
/// buttons press-scale to [beuiAgentPressScale] on [beuiSpringPress]. Busy
/// status spins the loader. Reduced motion drops movement while keeping
/// opacity / colour on every channel.
///
/// **API mapping** (source → Flutter):
/// * `tool` / `title` / `description` → [tool] / [title] / [description]
/// * `parameters` → [parameters] ([BeuiToolApprovalParameter])
/// * `status` → [status]
/// * `open` / `defaultOpen` / `onOpenChange` → same
/// * `onApprove` / `onAlwaysAllow` / `onDeny` → same
class BeuiToolApproval extends StatefulWidget {
  /// Creates a tool-approval permission card.
  const BeuiToolApproval({
    this.tool,
    this.toolWidget,
    this.title,
    this.titleWidget,
    this.description,
    this.descriptionWidget,
    this.parameters = const [],
    this.status = BeuiToolApprovalStatus.pending,
    this.severity = BeuiToolApprovalSeverity.normal,
    this.grant,
    this.open,
    this.defaultOpen,
    this.detailsMaxHeight = 240,
    this.allowAlways,
    this.onOpenChange,
    this.onApprove,
    this.onAlwaysAllow,
    this.onDeny,
    this.onRevoke,
    this.allowOnceLabel,
    this.alwaysAllowLabel,
    this.denyLabel,
    this.viewDetailsLabel,
    this.revokeLabel,
    this.alwaysAllowedLabel,
    this.expiredLabel,
    this.timedOutLabel,
    super.key,
  }) : assert(
         tool == null || toolWidget == null,
         'Pass either tool or toolWidget, not both.',
       ),
       assert(
         title == null || titleWidget == null,
         'Pass either title or titleWidget, not both.',
       ),
       assert(
         description == null || descriptionWidget == null,
         'Pass either description or descriptionWidget, not both.',
       );

  /// Tool slug shown mono under the title (e.g. `terminal.run`).
  ///
  /// This is the string that says *what will run*, so it is rendered at full
  /// foreground contrast rather than as muted metadata.
  /// For a non-text slug use [toolWidget].
  final String? tool;

  /// Widget form of [tool], for callers that need more than a string.
  final Widget? toolWidget;

  /// Primary header label. Defaults to
  /// [BeuiAgentStrings.toolApprovalTitle] ("Allow this tool to run?").
  final String? title;

  /// Widget form of [title].
  final Widget? titleWidget;

  /// Optional body copy under the title cluster.
  final String? description;

  /// Widget form of [description].
  final Widget? descriptionWidget;

  /// Parameter rows revealed by "View details" (source `parameters`).
  final List<BeuiToolApprovalParameter> parameters;

  /// Approval lifecycle (source `status`, default `pending`).
  final BeuiToolApprovalStatus status;

  /// Risk tier. See [BeuiToolApprovalSeverity]; defaults to
  /// [BeuiToolApprovalSeverity.normal].
  final BeuiToolApprovalSeverity severity;

  /// Which grant produced the current approved/complete state.
  ///
  /// Null (the default) leaves the badge as a plain "Approved". Pass
  /// [BeuiToolApprovalGrant.always] and the badge says so — and, with
  /// [onRevoke], the card grows a "Revoke" affordance.
  final BeuiToolApprovalGrant? grant;

  /// Controlled open state for the details disclosure. When non-null, the
  /// widget does not hold internal open state (source `open`).
  final bool? open;

  /// Initial open state when uncontrolled.
  ///
  /// **Null (the default) means "open when there is something to show"** —
  /// it resolves to `parameters.isNotEmpty`. Pass `false` to force a card with
  /// parameters to start collapsed; pass `true` to open a parameterless one.
  final bool? defaultOpen;

  /// Height cap on the details panel before it scrolls. Defaults to 240.
  ///
  /// Without a cap a 300-line diff expanded the card indefinitely inside a
  /// transcript. Pass [double.infinity] for the old
  /// unbounded behaviour.
  final double detailsMaxHeight;

  /// Whether to offer "Always allow" at all.
  ///
  /// Null (the default) resolves to `severity != destructive` — a standing
  /// grant is suppressed on the destructive tier. The button additionally
  /// requires [onAlwaysAllow] to be non-null, as before.
  final bool? allowAlways;

  /// Fired whenever the details disclosure toggles (source `onOpenChange`).
  final ValueChanged<bool>? onOpenChange;

  /// Allow-once handler (source `onApprove`).
  ///
  /// Null renders the button disabled and dimmed rather than live-but-inert
  ///, and trips a debug assertion while the card is pending —
  /// a pending approval with no way to approve is a wiring bug.
  final VoidCallback? onApprove;

  /// Remember-access handler (source `onAlwaysAllow`) — shows "Always allow"
  /// only when non-null and [allowAlways] resolves true.
  final VoidCallback? onAlwaysAllow;

  /// Deny handler (source `onDeny`). Null renders disabled and dimmed.
  final VoidCallback? onDeny;

  /// Revokes a standing grant. When non-null and [grant] is
  /// [BeuiToolApprovalGrant.always], the approved card grows an
  /// "Always allowed · Revoke" row.
  final VoidCallback? onRevoke;

  /// Overrides [BeuiAgentStrings.allowOnce] for this card.
  final String? allowOnceLabel;

  /// Overrides [BeuiAgentStrings.alwaysAllow] for this card.
  final String? alwaysAllowLabel;

  /// Overrides [BeuiAgentStrings.deny] for this card.
  ///
  /// "Deny" is a *permission* refusal and is deliberately not "Reject", which
  /// [BeuiApprovalCard] uses for a *review* verdict. See [BeuiAgentStrings].
  final String? denyLabel;

  /// Overrides [BeuiAgentStrings.viewDetails] for this card.
  final String? viewDetailsLabel;

  /// Label for the revoke control. Overrides [BeuiAgentStrings.revoke] for
  /// this card.
  final String? revokeLabel;

  /// Badge copy for an always-allowed grant. Overrides
  /// [BeuiAgentStrings.statusAlwaysAllowed] for this card.
  final String? alwaysAllowedLabel;

  /// Badge copy for [BeuiToolApprovalStatus.expired]. Overrides
  /// [BeuiAgentStrings.statusExpired] for this card.
  final String? expiredLabel;

  /// Badge copy for [BeuiToolApprovalStatus.timedOut]. Overrides
  /// [BeuiAgentStrings.statusTimedOut] for this card.
  final String? timedOutLabel;

  @override
  State<BeuiToolApproval> createState() => _BeuiToolApprovalState();
}

class _BeuiToolApprovalState extends State<BeuiToolApproval>
    with SingleTickerProviderStateMixin {
  late bool _internalOpen;
  late BeuiToolApprovalStatus _previousStatus;
  late final AnimationController _spin;

  bool _detailsHovered = false;

  bool get _busy =>
      widget.status == BeuiToolApprovalStatus.approving ||
      widget.status == BeuiToolApprovalStatus.running;
  bool get _pending => widget.status == BeuiToolApprovalStatus.pending;
  bool get _currentOpen => widget.open ?? _internalOpen;

  /// A card with something to show, shows it.
  bool get _resolvedDefaultOpen =>
      widget.defaultOpen ?? widget.parameters.isNotEmpty;

  bool get _showAlwaysAllow =>
      (widget.allowAlways ??
          widget.severity != BeuiToolApprovalSeverity.destructive) &&
      widget.onAlwaysAllow != null;

  @override
  void initState() {
    super.initState();
    _internalOpen = _resolvedDefaultOpen;
    _previousStatus = widget.status;
    _spin = AnimationController(vsync: this, duration: _spinPeriod);
    if (_busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant BeuiToolApproval oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Leaving pending collapses details (source useEffect on status).
    if (widget.status != _previousStatus) {
      if (_previousStatus == BeuiToolApprovalStatus.pending &&
          widget.status != BeuiToolApprovalStatus.pending) {
        _setOpen(false);
      }
      _previousStatus = widget.status;
    }

    final wasBusy =
        oldWidget.status == BeuiToolApprovalStatus.approving ||
        oldWidget.status == BeuiToolApprovalStatus.running;
    if (_busy != wasBusy) {
      if (_busy) {
        _spin.repeat();
      } else {
        _spin
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (widget.open == null && _internalOpen != next) {
      setState(() => _internalOpen = next);
    }
    widget.onOpenChange?.call(next);
  }

  void _toggleDetails() => _setOpen(!_currentOpen);

  String _statusCopy(BeuiAgentStrings strings) {
    switch (widget.status) {
      case BeuiToolApprovalStatus.approving:
        return strings.statusApproving;
      case BeuiToolApprovalStatus.approved:
      case BeuiToolApprovalStatus.complete:
        // Say *which* grant was used, so a standing permission is never
        // silently indistinguishable from a one-off.
        if (widget.grant == BeuiToolApprovalGrant.always) {
          return widget.alwaysAllowedLabel ?? strings.statusAlwaysAllowed;
        }
        return widget.status == BeuiToolApprovalStatus.approved
            ? strings.statusApproved
            : strings.statusCompleted;
      case BeuiToolApprovalStatus.denied:
        return strings.statusDenied;
      case BeuiToolApprovalStatus.running:
        return strings.statusRunning;
      case BeuiToolApprovalStatus.error:
        return strings.statusFailed;
      case BeuiToolApprovalStatus.expired:
        return widget.expiredLabel ?? strings.statusExpired;
      case BeuiToolApprovalStatus.timedOut:
        return widget.timedOutLabel ?? strings.statusTimedOut;
      case BeuiToolApprovalStatus.pending:
        return strings.statusApprovalRequired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final strings = agent.strings;
    final statusColors = agent.statusColorsFor(theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final destructive = widget.severity == BeuiToolApprovalSeverity.destructive;
    final elevated = widget.severity == BeuiToolApprovalSeverity.elevated;

    // A pending card that cannot be acted on is a wiring bug, not a
    // design. Surfaced in debug; in release the buttons simply render
    // disabled, which is at least honest.
    assert(
      !_pending || widget.onApprove != null || widget.onDeny != null,
      'BeuiToolApproval is pending but has neither onApprove nor onDeny — the '
      'user is being asked a question with no way to answer it.',
    );

    // The badge tracks status, except that a pending destructive request is
    // coloured by its *risk*, not by its lifecycle.
    final badge = destructive && _pending
        ? statusColors.destructive
        : statusColors.palette(_statusRole(widget.status));

    // Emphasis border: the card itself carries the risk tier, so the warning
    // survives even when the badge scrolls out of view.
    final BeuiAgentStatusPalette? emphasis = destructive
        ? statusColors.destructive
        : elevated
        ? statusColors.pending
        : null;

    final titleWidget =
        widget.titleWidget ?? Text(widget.title ?? strings.toolApprovalTitle);
    final toolWidget = widget.toolWidget;
    final descriptionWidget = widget.descriptionWidget;

    return Semantics(
      container: true,
      child: DefaultTextStyle.merge(
        style: agent.typography.assistantBody,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.muted.withValues(alpha: 0.20),
            borderRadius: agent.shapes.card, // rounded-2xl
            border: Border.all(
              color:
                  emphasis?.border ??
                  colors.border.withValues(alpha: colors.border.a * 0.60),
              width: emphasis != null
                  ? agent.structure.emphasisBorderWidth
                  : agent.structure.borderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: agent.shapes.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ----- header -----
                Padding(
                  padding: agent.layout.cardPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeadingGlyph(
                        status: widget.status,
                        severity: widget.severity,
                        reduce: reduce,
                        spin: _spin,
                        colors: colors,
                        palette: badge,
                      ),
                      SizedBox(width: agent.layout.rowGap + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // The tool identity leads. It is
                                      // the answer to "what am I allowing?",
                                      // so it is the first and most legible
                                      // line, not muted metadata underneath.
                                      DefaultTextStyle.merge(
                                        style: agent.typography.mono.copyWith(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colors.foreground,
                                        ),
                                        child:
                                            toolWidget ??
                                            Text(
                                              widget.tool ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      DefaultTextStyle.merge(
                                        style: agent.typography.title.copyWith(
                                          color: colors.mutedForeground,
                                        ),
                                        child: titleWidget,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: agent.layout.rowGap + 4),
                                // The badge is the live region, and it is
                                // live for every non-pending state — the old
                                // code gated it on `busy`, i.e. switched it off
                                // exactly when "Denied" / "Failed" arrived.
                                Semantics(
                                  container: true,
                                  liveRegion: !_pending,
                                  label: _statusCopy(strings),
                                  child: ExcludeSemantics(
                                    child: _StatusBadge(
                                      label: _statusCopy(strings),
                                      palette: badge,
                                      agent: agent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.description != null ||
                                descriptionWidget != null) ...[
                              const SizedBox(height: 8),
                              DefaultTextStyle.merge(
                                style: agent.typography.description.copyWith(
                                  color: colors.mutedForeground,
                                ),
                                child:
                                    descriptionWidget ??
                                    Text(widget.description!),
                              ),
                            ],
                            if (widget.parameters.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              // A real control, not a caption-styled row.
                              _DetailsToggle(
                                open: _currentOpen,
                                hovered: _detailsHovered,
                                reduce: reduce,
                                colors: colors,
                                agent: agent,
                                label:
                                    widget.viewDetailsLabel ??
                                    strings.viewDetails,
                                onHover: (h) =>
                                    setState(() => _detailsHovered = h),
                                onTap: _toggleDetails,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ----- details disclosure -----
                if (widget.parameters.isNotEmpty)
                  BeuiAgentDisclosureInternal(
                    open: _currentOpen,
                    reduce: reduce,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: 0.70),
                          borderRadius: agent.shapes.nested, // rounded-xl
                          border: Border.all(
                            color: colors.border.withValues(
                              alpha: colors.border.a * 0.50,
                            ),
                            width: agent.structure.borderWidth,
                          ),
                        ),
                        child: _DetailsPanel(
                          parameters: widget.parameters,
                          colors: colors,
                          agent: agent,
                          maxHeight: widget.detailsMaxHeight,
                        ),
                      ),
                    ),
                  ),

                // ----- revocation row (standing grant) -----
                if (!_pending &&
                    widget.grant == BeuiToolApprovalGrant.always &&
                    widget.onRevoke != null)
                  _RevokeRow(
                    colors: colors,
                    agent: agent,
                    grantLabel:
                        widget.alwaysAllowedLabel ??
                        strings.statusAlwaysAllowed,
                    revokeLabel: widget.revokeLabel ?? strings.revoke,
                    onRevoke: widget.onRevoke!,
                  ),

                // ----- pending actions -----
                _ActionsPresence(
                  visible: _pending,
                  reduce: reduce,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colors.border.withValues(
                            alpha: colors.border.a * 0.60,
                          ),
                          width: agent.structure.borderWidth,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Wrap(
                        // Real spacing, not just hit-slop overhang — the
                        // 44px targets overhang their siblings, so the gap has
                        // to be wide enough that the slop does not steal the
                        // neighbour's taps.
                        spacing: agent.layout.actionSpacing + 4,
                        runSpacing: agent.layout.actionSpacing,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _buildActions(
                          colors: colors,
                          agent: agent,
                          strings: strings,
                          statusColors: statusColors,
                          destructive: destructive,
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
    );
  }

  /// The action row.
  ///
  /// **A6 — visual weight follows safety.** The old row put the maximum-
  /// emphasis solid on `Allow once`, outlined the *most consequential* grant
  /// (`Always allow`), and left `Deny` as a ghost, last and faintest: the
  /// safest exit was the hardest thing on the card to see. Now `Deny` always
  /// has a container, and on the destructive tier it leads as the solid
  /// action while `Allow once` is demoted to outlined.
  List<Widget> _buildActions({
    required BeuiColors colors,
    required BeuiAgentTheme agent,
    required BeuiAgentStrings strings,
    required BeuiAgentStatusColors statusColors,
    required bool destructive,
  }) {
    final radius = agent.shapes.control;

    Widget button({
      required String label,
      required BeuiButtonVariant variant,
      required VoidCallback? onPressed,
      Color? textColor,
    }) {
      // A 44px touch target over the 32px pill.
      //
      // The `SizedBox` is load-bearing, not decoration. `BeuiMinHitTarget`
      // widens hit testing by accepting out-of-bounds points, but a parent
      // only ever dispatches points inside *its own* box — so in a `Wrap`
      // sized exactly to its 32px children the slop was unreachable and the
      // wrapper did nothing at all. Giving the row real height is what makes
      // the extra 12px actually touchable; the pill still paints at 32.
      return SizedBox(
        height: 44,
        // `widthFactor: 1` shrink-wraps horizontally. Without it the Center
        // expands to the Wrap's full width and the row reads as centred.
        child: Center(
          widthFactor: 1,
          child: BeuiMinHitTarget(
            child: BeuiButton(
              variant: variant,
              size: BeuiButtonSize.sm,
              pressScale: beuiAgentPressScale,
              borderRadius: radius,
              // A4 belt-and-braces: a null handler is a disabled button, which
              // BeuiButton renders dimmed and refuses to activate.
              onPressed: onPressed,
              child: Text(
                label,
                style: textColor == null ? null : TextStyle(color: textColor),
              ),
            ),
          ),
        ),
      );
    }

    final allowOnce = button(
      label: widget.allowOnceLabel ?? strings.allowOnce,
      variant: destructive
          ? BeuiButtonVariant.outline
          : BeuiButtonVariant.primary,
      onPressed: widget.onApprove,
    );

    final deny = button(
      label: widget.denyLabel ?? strings.deny,
      // Never ghost. On the destructive tier the safe exit is the solid lead.
      variant: destructive
          ? BeuiButtonVariant.primary
          : BeuiButtonVariant.outline,
      onPressed: widget.onDeny,
    );

    final alwaysAllow = _showAlwaysAllow
        ? button(
            label: widget.alwaysAllowLabel ?? strings.alwaysAllow,
            variant: BeuiButtonVariant.outline,
            onPressed: widget.onAlwaysAllow,
          )
        : null;

    if (destructive) {
      // Deny leads. `Always allow` is suppressed by default here, but a caller
      // who explicitly passes `allowAlways: true` gets it back — last, and
      // behind the safe exit.
      return [deny, allowOnce, ?alwaysAllow];
    }

    return [allowOnce, ?alwaysAllow, deny];
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _LeadingGlyph extends StatelessWidget {
  const _LeadingGlyph({
    required this.status,
    required this.severity,
    required this.reduce,
    required this.spin,
    required this.colors,
    required this.palette,
  });

  final BeuiToolApprovalStatus status;
  final BeuiToolApprovalSeverity severity;
  final bool reduce;
  final AnimationController spin;
  final BeuiColors colors;
  final BeuiAgentStatusPalette palette;

  bool get busy =>
      status == BeuiToolApprovalStatus.approving ||
      status == BeuiToolApprovalStatus.running;
  bool get error => status == BeuiToolApprovalStatus.error;
  bool get lapsed =>
      status == BeuiToolApprovalStatus.expired ||
      status == BeuiToolApprovalStatus.timedOut;

  IconData _icon(BeuiAgentIcons icons) {
    if (busy) return icons.spinner;
    if (error) return icons.warning;
    if (status == BeuiToolApprovalStatus.denied) return icons.rejected;
    if (status == BeuiToolApprovalStatus.approved ||
        status == BeuiToolApprovalStatus.complete) {
      return icons.approved;
    }
    if (lapsed) return LucideIcons.clock;
    // The destructive tier swaps the reassuring shield for a warning
    // triangle while the decision is still open.
    if (severity == BeuiToolApprovalSeverity.destructive) return icons.warning;
    return icons.shield;
  }

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    // The glyph carries status colour too, so the card still reads at a glance
    // when the badge is clipped — and colour is never the only channel (the
    // shape changes with it).
    final color = lapsed ? colors.mutedForeground : palette.foreground;
    final icon = Icon(
      _icon(agent.icons),
      size: agent.layout.iconSize,
      color: color,
    );
    final glyph = busy && !reduce
        ? RotationTransition(turns: spin, child: icon)
        : icon;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: agent.shapes.nested, // rounded-xl
          border: Border.all(
            color: colors.border.withValues(alpha: colors.border.a * 0.60),
            width: agent.structure.borderWidth,
          ),
        ),
        child: SizedBox(width: 32, height: 32, child: Center(child: glyph)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.palette,
    required this.agent,
  });

  final String label;
  final BeuiAgentStatusPalette palette;
  final BeuiAgentTheme agent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: agent.shapes.pill,
        border: Border.all(
          color: palette.border,
          width: agent.structure.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: agent.typography.status.copyWith(color: palette.foreground),
        ),
      ),
    );
  }
}

/// The "View details" gateway.
///
/// This used to be a 12px caption row with a chevron and no affordance
/// beyond a hover colour — the single control standing between the user and
/// the command they are approving. It is now a real ghost button: focusable,
/// Enter/Space-activatable, 44px of hit target, and it reports its expanded
/// state to assistive technology.
class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({
    required this.open,
    required this.hovered,
    required this.reduce,
    required this.colors,
    required this.agent,
    required this.label,
    required this.onHover,
    required this.onTap,
  });

  final bool open;
  final bool hovered;
  final bool reduce;
  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final String label;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rotated = BeuiDisclosureChevron(
      open: open,
      color: colors.foreground,
      reduce: reduce,
    );

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        expanded: open,
        child: MouseRegion(
          onEnter: (_) => onHover(true),
          onExit: (_) => onHover(false),
          child: BeuiMinHitTarget(
            child: BeuiButton(
              variant: BeuiButtonVariant.outline,
              size: BeuiButtonSize.sm,
              pressScale: beuiAgentPressScale,
              borderRadius: agent.shapes.control,
              onPressed: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(label), const SizedBox(width: 4), rotated],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The capped, scrollable parameter list.
class _DetailsPanel extends StatefulWidget {
  const _DetailsPanel({
    required this.parameters,
    required this.colors,
    required this.agent,
    required this.maxHeight,
  });

  final List<BeuiToolApprovalParameter> parameters;
  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final double maxHeight;

  @override
  State<_DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<_DetailsPanel> {
  // The scrollbar needs a controller it shares with the view; falling back to
  // the PrimaryScrollController would attach it to the enclosing transcript.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parameters = widget.parameters;
    final colors = widget.colors;
    final agent = widget.agent;
    final maxHeight = widget.maxHeight;

    final rows = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          for (final parameter in parameters)
            _ParameterRow(parameter: parameter, colors: colors, agent: agent),
        ],
      ),
    );

    if (!maxHeight.isFinite) return rows;

    // Cap the panel and scroll it, with a visible thumb — the sibling
    // surfaces that hide their scrollbars are exactly the T6 complaint, so
    // this one shows its.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(controller: _scroll, child: rows),
      ),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({
    required this.parameter,
    required this.colors,
    required this.agent,
  });

  final BeuiToolApprovalParameter parameter;
  final BeuiColors colors;
  final BeuiAgentTheme agent;

  @override
  Widget build(BuildContext context) {
    final labelStyle = agent.typography.metadata.copyWith(
      color: colors.mutedForeground,
    );
    // The value is information-bearing — it is the argument the tool will
    // run with — so it is no longer multiplied down to 0.85 alpha.
    final valueStyle = agent.typography.mono.copyWith(
      fontSize: 12,
      color: colors.foreground,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112, // minmax(0, 7rem)
          child: DefaultTextStyle.merge(
            style: labelStyle,
            child: _asWidget(parameter.label, style: labelStyle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle.merge(
            style: valueStyle,
            child: _asWidget(parameter.value, style: valueStyle),
          ),
        ),
      ],
    );
  }
}

/// "Always allowed · Revoke".
///
/// A standing grant that cannot be taken back is a trap. This row is the
/// minimum honest affordance: it states that the permission persists, and puts
/// the way out one keystroke away.
class _RevokeRow extends StatelessWidget {
  const _RevokeRow({
    required this.colors,
    required this.agent,
    required this.grantLabel,
    required this.revokeLabel,
    required this.onRevoke,
  });

  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final String grantLabel;
  final String revokeLabel;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.border.withValues(alpha: colors.border.a * 0.60),
            width: agent.structure.borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                grantLabel,
                style: agent.typography.metadata.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            BeuiMinHitTarget(
              child: BeuiButton(
                variant: BeuiButtonVariant.ghost,
                size: BeuiButtonSize.sm,
                pressScale: beuiAgentPressScale,
                borderRadius: agent.shapes.control,
                onPressed: onRevoke,
                child: Text(revokeLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade / slide presence for the pending actions row (source AnimatePresence
/// on the footer with EASE_OUT 0.22 enter / 0.14 exit).
class _ActionsPresence extends StatelessWidget {
  const _ActionsPresence({
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
    final motion = visible
        ? (reduce ? _actionsInReduced : _actionsIn)
        : (reduce ? _actionsOutReduced : _actionsOut);

    // A4 — the double-fire fix, and the reason it is spelled `!visible ||
    // hidden` rather than `hidden` alone.
    //
    // The gate used to be driven purely by the animation value, so for the
    // ~220ms the row spent fading out it was still fully hit-testable: a fast
    // double-tap on "Allow once" fired `onApprove` twice, the second time
    // *after* the decision had already been taken. Deriving it from `visible`
    // makes the row inert on the very frame the decision lands, while the
    // animated value keeps it inert for the whole tail of a re-entry.
    Widget frame(double t, Widget child, {required bool movement}) {
      final tt = t.clamp(0.0, 1.0);
      final hidden = tt < 0.01;
      final inert = !visible || hidden;
      final y = movement && visible ? 4 * (1 - tt) : 0.0;

      Widget content = Opacity(opacity: tt, child: child);
      if (y != 0) {
        content = Transform.translate(offset: Offset(0, y), child: content);
      }
      if (movement) {
        content = ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: tt,
            // `Align` loosens, so without this the action row shrink-wraps to
            // its buttons and `topCenter` centres it — the source's row is
            // `flex … px-4` with no `justify-*`, i.e. full width and
            // flex-start.
            child: SizedBox(width: double.infinity, child: content),
          ),
        );
      }

      return Offstage(
        offstage: hidden,
        child: IgnorePointer(
          ignoring: inert,
          child: ExcludeSemantics(excluding: inert, child: content),
        ),
      );
    }

    // Under reduced motion: opacity only (source initial { opacity: 0 }).
    if (reduce) {
      return SingleMotionBuilder(
        value: target,
        motion: motionFor(context, motion, isMovement: false),
        builder: (context, t, child) => frame(t, child!, movement: false),
        child: child,
      );
    }

    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, motion, isMovement: true),
      builder: (context, t, child) => frame(t, child!, movement: true),
      child: child,
    );
  }
}
