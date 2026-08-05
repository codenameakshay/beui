import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
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
}

/// One parameter row inside the "View details" disclosure
/// (source `ToolApprovalParameter`).
@immutable
class BeuiToolApprovalParameter {
  /// Creates a parameter row.
  const BeuiToolApprovalParameter({
    required this.id,
    required this.label,
    required this.value,
  });

  /// Stable identity for the row (source `id`).
  final String id;

  /// Left-column label. Accepts a [String] or any [Widget].
  final Object label;

  /// Right-column value. Accepts a [String] or any [Widget] — typically
  /// [BeuiToolApprovalCode] for shell / request snippets.
  final Object value;
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------

const _disclosureOpen = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _disclosureClose = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);
const _actionsIn = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _actionsInReduced = CurvedMotion(
  Duration(milliseconds: 120),
  beuiEaseOut,
);
const _actionsOut = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _actionsOutReduced = CurvedMotion(
  Duration(milliseconds: 120),
  beuiEaseOut,
);
const _spinPeriod = Duration(milliseconds: 900);

// Status palette — Tailwind amber / blue / emerald / rose matching the source.
const _amber500 = Color(0xFFF59E0B);
const _amber600 = Color(0xFFD97706);
const _amber400 = Color(0xFFFBBF24);
const _blue500 = Color(0xFF3B82F6);
const _blue600 = Color(0xFF2563EB);
const _blue400 = Color(0xFF60A5FA);
const _emerald500 = Color(0xFF10B981);
const _emerald600 = Color(0xFF059669);
const _emerald400 = Color(0xFF34D399);
const _rose500 = Color(0xFFF43F5E);
const _rose600 = Color(0xFFE11D48);
const _rose400 = Color(0xFFFB7185);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _statusCopy(BeuiToolApprovalStatus status) => switch (status) {
  BeuiToolApprovalStatus.approving => 'Approving',
  BeuiToolApprovalStatus.approved => 'Approved',
  BeuiToolApprovalStatus.denied => 'Denied',
  BeuiToolApprovalStatus.running => 'Running',
  BeuiToolApprovalStatus.complete => 'Completed',
  BeuiToolApprovalStatus.error => 'Failed',
  BeuiToolApprovalStatus.pending => 'Approval required',
};

@immutable
class _BadgeScheme {
  const _BadgeScheme({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

_BadgeScheme _badgeScheme(BeuiToolApprovalStatus status, bool isLight) {
  switch (status) {
    case BeuiToolApprovalStatus.pending:
      return _BadgeScheme(
        background: _amber500.withValues(alpha: 0.10),
        border: _amber500.withValues(alpha: 0.30),
        foreground: isLight ? _amber600 : _amber400,
      );
    case BeuiToolApprovalStatus.approving:
    case BeuiToolApprovalStatus.running:
      return _BadgeScheme(
        background: _blue500.withValues(alpha: 0.10),
        border: _blue500.withValues(alpha: 0.30),
        foreground: isLight ? _blue600 : _blue400,
      );
    case BeuiToolApprovalStatus.approved:
    case BeuiToolApprovalStatus.complete:
      return _BadgeScheme(
        background: _emerald500.withValues(alpha: 0.10),
        border: _emerald500.withValues(alpha: 0.30),
        foreground: isLight ? _emerald600 : _emerald400,
      );
    case BeuiToolApprovalStatus.denied:
    case BeuiToolApprovalStatus.error:
      return _BadgeScheme(
        background: _rose500.withValues(alpha: 0.10),
        border: _rose500.withValues(alpha: 0.30),
        foreground: isLight ? _rose600 : _rose400,
      );
  }
}

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
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(8), // rounded-lg
        border: Border.all(color: colors.border.withValues(alpha: 0.50)),
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
/// row ("Allow once" / "Always allow" / "Deny").
///
/// **Open state.** Controlled when [open] is non-null (drive via
/// [onOpenChange]); otherwise internal state seeded by [defaultOpen]. Leaving
/// [BeuiToolApprovalStatus.pending] auto-collapses the details panel.
///
/// **Motion.** Chevron rotates on [beuiSpringSwap]; disclosure opens in 220ms
/// / closes in 140ms [beuiEaseOut]; pending actions fade/slide on [beuiEaseOut]
/// (0.22s enter / exit, 0.12s under reduced motion); allow buttons press-scale
/// to 0.97 on [beuiSpringPress]. Busy status spins the loader. Reduced motion
/// drops movement while keeping opacity / color.
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
    required this.tool,
    this.title = 'Allow this tool to run?',
    this.description,
    this.parameters = const [],
    this.status = BeuiToolApprovalStatus.pending,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.onApprove,
    this.onAlwaysAllow,
    this.onDeny,
    super.key,
  });

  /// Tool slug shown mono under the title (e.g. `terminal.run`).
  /// Accepts a [String] or any [Widget].
  final Object tool;

  /// Primary header label (source `title`, default
  /// `"Allow this tool to run?"`). Accepts a [String] or any [Widget].
  final Object title;

  /// Optional body copy under the title cluster. Accepts a [String] or
  /// any [Widget].
  final Object? description;

  /// Parameter rows revealed by "View details" (source `parameters`).
  final List<BeuiToolApprovalParameter> parameters;

  /// Approval lifecycle (source `status`, default `pending`).
  final BeuiToolApprovalStatus status;

  /// Controlled open state for the details disclosure. When non-null, the
  /// widget does not hold internal open state (source `open`).
  final bool? open;

  /// Initial open state when uncontrolled (source `defaultOpen`, default
  /// false).
  final bool defaultOpen;

  /// Fired whenever the details disclosure toggles (source `onOpenChange`).
  final ValueChanged<bool>? onOpenChange;

  /// Allow-once handler (source `onApprove`) — shows "Allow once" when set.
  final VoidCallback? onApprove;

  /// Remember-access handler (source `onAlwaysAllow`) — shows "Always allow"
  /// only when non-null.
  final VoidCallback? onAlwaysAllow;

  /// Deny handler (source `onDeny`).
  final VoidCallback? onDeny;

  @override
  State<BeuiToolApproval> createState() => _BeuiToolApprovalState();
}

class _BeuiToolApprovalState extends State<BeuiToolApproval>
    with SingleTickerProviderStateMixin {
  late bool _internalOpen;
  late BeuiToolApprovalStatus _previousStatus;
  late final AnimationController _spin;

  // Action-button press tracking.
  bool _allowPressed = false;
  bool _alwaysPressed = false;
  bool _denyHovered = false;
  bool _alwaysHovered = false;
  bool _detailsHovered = false;

  bool get _busy =>
      widget.status == BeuiToolApprovalStatus.approving ||
      widget.status == BeuiToolApprovalStatus.running;
  bool get _pending => widget.status == BeuiToolApprovalStatus.pending;
  bool get _error => widget.status == BeuiToolApprovalStatus.error;
  bool get _currentOpen => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    _internalOpen = widget.defaultOpen;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isLight = theme.brightness == Brightness.light;
    final badge = _badgeScheme(widget.status, isLight);

    return Semantics(
      container: true,
      liveRegion: _busy,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.muted.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(16), // rounded-2xl
            border: Border.all(color: colors.border.withValues(alpha: 0.60)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ----- header -----
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeadingGlyph(
                        status: widget.status,
                        busy: _busy,
                        error: _error,
                        reduce: reduce,
                        spin: _spin,
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
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
                                      DefaultTextStyle.merge(
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: colors.foreground,
                                        ),
                                        child: _asWidget(widget.title),
                                      ),
                                      const SizedBox(height: 2),
                                      DefaultTextStyle.merge(
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          color: colors.mutedForeground,
                                        ),
                                        child: _asWidget(
                                          widget.tool,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            color: colors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _StatusBadge(
                                  label: _statusCopy(widget.status),
                                  scheme: badge,
                                ),
                              ],
                            ),
                            if (widget.description != null) ...[
                              const SizedBox(height: 8),
                              DefaultTextStyle.merge(
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.25, // leading-5 at 14px ≈ 20px
                                  color: colors.mutedForeground,
                                ),
                                child: _asWidget(widget.description!),
                              ),
                            ],
                            if (widget.parameters.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _DetailsToggle(
                                open: _currentOpen,
                                hovered: _detailsHovered,
                                reduce: reduce,
                                colors: colors,
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
                  _AgentDisclosure(
                    open: _currentOpen,
                    reduce: reduce,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(12), // rounded-xl
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.50),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var i = 0;
                                i < widget.parameters.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _ParameterRow(
                                  parameter: widget.parameters[i],
                                  colors: colors,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ----- pending actions -----
                _ActionsPresence(
                  visible: _pending,
                  reduce: reduce,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colors.border.withValues(alpha: 0.60),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Source always renders Allow once / Deny; Always
                          // allow only when onAlwaysAllow is provided.
                          _PressButton(
                            label: 'Allow once',
                            pressed: _allowPressed,
                            reduce: reduce,
                            onPressed: (p) => setState(() => _allowPressed = p),
                            onTap: () => widget.onApprove?.call(),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.foreground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Allow once',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.background,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.onAlwaysAllow != null)
                            _PressButton(
                              label: 'Always allow',
                              pressed: _alwaysPressed,
                              reduce: reduce,
                              onPressed: (p) =>
                                  setState(() => _alwaysPressed = p),
                              onTap: widget.onAlwaysAllow!,
                              child: MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _alwaysHovered = true),
                                onExit: (_) =>
                                    setState(() => _alwaysHovered = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: _alwaysHovered
                                        ? colors.muted
                                        : colors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.border.withValues(
                                        alpha: 0.60,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    'Always allow',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _denyHovered = true),
                            onExit: (_) => setState(() => _denyHovered = false),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => widget.onDeny?.call(),
                              child: Semantics(
                                button: true,
                                label: 'Deny',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: _denyHovered
                                        ? colors.muted
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    'Deny',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _denyHovered
                                          ? colors.foreground
                                          : colors.mutedForeground,
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _LeadingGlyph extends StatelessWidget {
  const _LeadingGlyph({
    required this.status,
    required this.busy,
    required this.error,
    required this.reduce,
    required this.spin,
    required this.colors,
  });

  final BeuiToolApprovalStatus status;
  final bool busy;
  final bool error;
  final bool reduce;
  final AnimationController spin;
  final BeuiColors colors;

  IconData get _icon {
    if (busy) return LucideIcons.loader_circle;
    if (error) return LucideIcons.circle_alert;
    if (status == BeuiToolApprovalStatus.denied) return LucideIcons.x;
    if (status == BeuiToolApprovalStatus.approved ||
        status == BeuiToolApprovalStatus.complete) {
      return LucideIcons.check;
    }
    return LucideIcons.shield_check;
  }

  @override
  Widget build(BuildContext context) {
    final color = error ? colors.destructive : colors.mutedForeground;
    final icon = Icon(_icon, size: 16, color: color);
    final glyph = busy && !reduce
        ? RotationTransition(turns: spin, child: icon)
        : icon;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12), // rounded-xl
          border: Border.all(color: colors.border.withValues(alpha: 0.60)),
        ),
        child: SizedBox(width: 32, height: 32, child: Center(child: glyph)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.scheme});

  final String label;
  final _BadgeScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: scheme.foreground,
          ),
        ),
      ),
    );
  }
}

class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({
    required this.open,
    required this.hovered,
    required this.reduce,
    required this.colors,
    required this.onHover,
    required this.onTap,
  });

  final bool open;
  final bool hovered;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hovered ? colors.foreground : colors.mutedForeground;
    final chevron = Icon(LucideIcons.chevron_down, size: 14, color: color);
    final rotated = reduce
        ? Transform.rotate(angle: open ? math.pi : 0, child: chevron)
        : SingleMotionBuilder(
            value: open ? 180.0 : 0.0,
            motion: motionFor(context, beuiSpringSwap, isMovement: true),
            builder: (context, deg, child) =>
                Transform.rotate(angle: deg * math.pi / 180.0, child: child),
            child: chevron,
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          button: true,
          expanded: open,
          label: 'View details',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              rotated,
            ],
          ),
        ),
      ),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({required this.parameter, required this.colors});

  final BeuiToolApprovalParameter parameter;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112, // minmax(0, 7rem)
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
            child: _asWidget(
              parameter.label,
              style: TextStyle(fontSize: 12, color: colors.mutedForeground),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colors.foreground.withValues(alpha: 0.85),
            ),
            child: _asWidget(
              parameter.value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colors.foreground.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Press-scale button (source `whileTap={{ scale: 0.97 }}` + SPRING_PRESS).
class _PressButton extends StatelessWidget {
  const _PressButton({
    required this.label,
    required this.pressed,
    required this.reduce,
    required this.onPressed,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool pressed;
  final bool reduce;
  final ValueChanged<bool> onPressed;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pressTarget = (pressed && !reduce) ? 0.97 : 1.0;
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onExit: (_) => onPressed(false),
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
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Fade / slide presence for the pending actions row (source AnimatePresence
/// on the footer with EASE_OUT 0.22 / reduced 0.12).
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

    // Under reduced motion: opacity only (source initial { opacity: 0 }).
    if (reduce) {
      return SingleMotionBuilder(
        value: target,
        motion: motionFor(context, motion, isMovement: false),
        builder: (context, t, child) {
          final tt = t.clamp(0.0, 1.0);
          final hidden = tt < 0.01;
          return Offstage(
            offstage: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              child: ExcludeSemantics(
                excluding: hidden,
                child: Opacity(opacity: tt, child: child),
              ),
            ),
          );
        },
        child: child,
      );
    }

    // Full motion: opacity + y: 4 → 0 enter; exit opacity only (source).
    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, motion, isMovement: true),
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        final hidden = tt < 0.01;
        // Exit is opacity-only in the source; enter slides up from y: 4.
        // Driving both with the same t approximates AnimatePresence enter/exit.
        final y = visible ? 4 * (1 - tt) : 0.0;
        return Offstage(
          offstage: hidden,
          child: IgnorePointer(
            ignoring: hidden,
            child: ExcludeSemantics(
              excluding: hidden,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: tt,
                  child: Opacity(
                    opacity: tt,
                    child: Transform.translate(
                      offset: Offset(0, y),
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

/// Shared transform-only reveal for collapsible agent content — the Flutter
/// port of the source's `AgentDisclosure` (height + opacity + y: -4).
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
