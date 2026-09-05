import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_status_colors.dart';
import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_disclosure.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
import 'action_swap.dart';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Task lifecycle for a [BeuiTodoItem] — the Flutter port of the source's
/// `TodoItemStatus`.
enum BeuiTodoItemStatus {
  /// Not started.
  pending,

  /// Currently running (optionally with [BeuiTodoItem.progress]).
  inProgress,

  /// Finished successfully.
  completed,

  /// Aborted / skipped.
  cancelled,
}

/// One row of a [BeuiTodoList] — the Flutter port of the source's `TodoItem`.
///
/// A data descriptor, not a widget. Pass a list of these to [BeuiTodoList.items].
@immutable
class BeuiTodoItem {
  /// Creates a todo row descriptor.
  const BeuiTodoItem({
    required this.id,
    required this.title,
    this.status = BeuiTodoItemStatus.pending,
    this.progress,
    this.detail,
  });

  /// Stable identity within the list (keys enter/exit + status morphs).
  final String id;

  /// Primary label. Accepts any widget (source `ReactNode`); demos typically
  /// pass a [Text].
  final Widget title;

  /// Lifecycle mark. Defaults to [BeuiTodoItemStatus.pending].
  final BeuiTodoItemStatus status;

  /// Optional 0–100 progress for [BeuiTodoItemStatus.inProgress]. When null
  /// while in-progress, the ring spins indefinitely (source default visual
  /// progress of ~68% with a continuous rotate).
  final double? progress;

  /// Compact trailing metadata (e.g. `"25%"`).
  final Widget? detail;
}

// ---------------------------------------------------------------------------
// Motion tokens (local curves mirroring the source's per-transition timings)
// ---------------------------------------------------------------------------

const _headerIconSwap = beuiSpringSwap;
const _layoutSpring = beuiSpringLayout;
const _checkDraw = CurvedMotion(Duration(milliseconds: 240), beuiEaseOut);
const _cancelDraw = CurvedMotion(Duration(milliseconds: 200), beuiEaseOut);
const _fillFade = CurvedMotion(Duration(milliseconds: 180), beuiEaseOut);

/// The completion strike drawing on, left to right (source 0.28s).
const _strikeMotion = CurvedMotion(Duration(milliseconds: 280), beuiEaseOut);

/// The strike retracting when a task leaves `completed`.
///
/// A19: the draw-on and the retract used to share one 280ms token, so the
/// undo was as slow as the commit. Exits are faster than entrances everywhere
/// else in the library; this is the pair that was missing one.
const _strikeRetractMotion = CurvedMotion(
  Duration(milliseconds: 160),
  beuiEaseOut,
);

const _strikeDelay = Duration(milliseconds: 60);

/// Header mark cross-fade in / out. A19 again: 280ms in, 180ms out.
const _headerMarkIn = Duration(milliseconds: 280);
const _headerMarkOut = Duration(milliseconds: 180);

// The disclosure's 220ms open / 140ms close now come from `_disclosure.dart`
// (beuiDisclosureOpenMotion / beuiDisclosureCloseMotion) — one declaration for
// every collapsible agent surface instead of five.
//
// The five Tailwind color literals that used to sit here (emerald-500/600/400,
// rose-600/400) are gone: every status color resolves from
// `BeuiAgentStatusColors` via [_statusTier]. See that function for the tier
// mapping and why `cancelled` takes `denied`.

/// Indefinite in-progress spin (source `duration: 1.1, repeat: Infinity`).
const _spinPeriod = Duration(milliseconds: 1100);

/// The shared status tier a [BeuiTodoItemStatus] paints from.
///
/// | row status     | tier                          | why                     |
/// |----------------|-------------------------------|-------------------------|
/// | `completed`    | [BeuiAgentStatus.success]     | finished well           |
/// | `inProgress`   | [BeuiAgentStatus.running]     | in flight               |
/// | `cancelled`    | [BeuiAgentStatus.denied]      | see below               |
/// | `pending`      | [BeuiAgentStatus.neutral]     | see below               |
///
/// **`cancelled` → `denied`, not `failed`.** Both default to the same rose, so
/// the stock pixels are unchanged either way; the difference is what a
/// consumer can express afterwards. A cancelled task was *called off* — by the
/// user or by the agent — and that is `denied`'s exact meaning ("refused",
/// distinct from `failed` "crashed") per its own documentation. Mapping it to
/// `failed` would mean retinting real errors and abandoned work together.
///
/// **`pending` → `neutral`, not `pending`.** The `pending` tier is amber and
/// means *awaiting a human decision* — an unstarted task is not waiting on
/// you, it is simply next. [BeuiAgentStatus.neutral]'s own documentation names
/// "unstarted todos" as its case, and its foreground is `mutedForeground`,
/// which is exactly what this row already painted.
BeuiAgentStatus _statusTier(BeuiTodoItemStatus status) => switch (status) {
  BeuiTodoItemStatus.pending => BeuiAgentStatus.neutral,
  BeuiTodoItemStatus.inProgress => BeuiAgentStatus.running,
  BeuiTodoItemStatus.completed => BeuiAgentStatus.success,
  BeuiTodoItemStatus.cancelled => BeuiAgentStatus.denied,
};

// ---------------------------------------------------------------------------
// BeuiTodoList
// ---------------------------------------------------------------------------

/// A collapsible agent task plan with morphing status marks, a completion
/// count, compact metadata, and smooth list updates — the Flutter port of
/// beUI's `todo-list`.
///
/// The header toggles a disclosure panel (source `AgentDisclosure`) that
/// clips/fades content open and closed. The count rolls via
/// [BeuiActionSwapText] (`roll`). Status icons morph between pending ring,
/// in-progress arc (optional determinate progress, otherwise a spinning
/// indeterminate ring), completed check, and cancelled X. Completing every
/// item optionally collapses the panel ([collapseOnComplete]).
///
/// Controlled when [open] is non-null (drive it from [onOpenChange]); otherwise
/// internal state seeded by [defaultOpen]. Reduced motion drops movement
/// (scale, translate, spin, path-draw) while keeping opacity/color transitions.
class BeuiTodoList extends StatefulWidget {
  /// Creates a collapsible agent todo list.
  const BeuiTodoList({
    required this.items,
    this.title,
    this.open,
    this.defaultOpen = true,
    this.onOpenChange,
    this.collapseOnComplete = true,
    this.maxHeight = 248,
    this.emptyState,
    this.emptyLabel,
    this.emptyDescription,
    this.semanticsLabel,
    super.key,
  });

  /// The task rows, top to bottom.
  final List<BeuiTodoItem> items;

  /// Header label. Defaults to [BeuiAgentStrings.todoListTitle] (`"To-dos"`).
  /// Accepts any widget (source `ReactNode`); demos typically pass a [Text] or
  /// rely on the string default.
  final Widget? title;

  /// Controlled open state. When non-null the list is *controlled* — keep it
  /// in sync via [onOpenChange]. Leave null for the uncontrolled pattern.
  final bool? open;

  /// Initial open state in the uncontrolled case (ignored when [open] is
  /// supplied).
  ///
  /// Defaults to `true`, and the cluster policy is why: **a surface that is
  /// still running or still asking opens; a historical record collapses.** A
  /// task list is live state — it is the agent telling you what it is about to
  /// do and how far along it is, and a plan you have to click to see is a plan
  /// you will not read. Compare `BeuiAgentActivity.defaultOpen`, which is
  /// `false` for exactly the opposite reason: a finished trace is an archive.
  ///
  /// The list is not left open forever: [collapseOnComplete] folds it away
  /// once every task is done, at which point it *has* become a record.
  final bool defaultOpen;

  /// Called with the new open state on every toggle / auto-collapse.
  final ValueChanged<bool>? onOpenChange;

  /// When true (default), the panel auto-collapses once every item is
  /// [BeuiTodoItemStatus.completed], and re-opens if any item leaves that
  /// state (source `collapseOnComplete`).
  final bool collapseOnComplete;

  /// Max height of the scrollable task viewport in logical pixels (source
  /// default `248`).
  final double maxHeight;

  /// Replaces the whole empty panel when [items] is empty.
  ///
  /// Takes precedence over [emptyLabel] and [emptyDescription]. Use it for an
  /// empty state that needs more than two lines of prose — a call to action, an
  /// illustration, a retry control.
  final Widget? emptyState;

  /// Headline of the built-in empty state. Defaults to
  /// [BeuiAgentStrings.todoEmpty].
  ///
  /// A28: "No tasks yet" alone is a shrug — it reports a fact the reader can
  /// already see and says nothing about whether that is normal, whether
  /// something is broken, or what would change it. Pair it with
  /// [emptyDescription] (or override both) so the panel orients: what will
  /// appear here, and when.
  final String? emptyLabel;

  /// Supporting line under [emptyLabel], explaining what will fill this panel
  /// and when. Defaults to [BeuiAgentStrings.todoEmptyDescription].
  final String? emptyDescription;

  /// Accessible name for the whole card. Defaults to
  /// [BeuiAgentStrings.todoListLabel] (`"Agent task list"`).
  final String? semanticsLabel;

  @override
  State<BeuiTodoList> createState() => _BeuiTodoListState();
}

class _BeuiTodoListState extends State<BeuiTodoList> {
  late bool _internalOpen = widget.defaultOpen;
  bool _previousAllComplete = false;
  final ScrollController _scroll = ScrollController();

  bool get _isControlled => widget.open != null;
  bool get _currentOpen => widget.open ?? _internalOpen;

  int get _completed => widget.items
      .where((i) => i.status == BeuiTodoItemStatus.completed)
      .length;

  bool get _allComplete =>
      widget.items.isNotEmpty && _completed == widget.items.length;

  @override
  void initState() {
    super.initState();
    _previousAllComplete = _allComplete;
  }

  @override
  void didUpdateWidget(BeuiTodoList old) {
    super.didUpdateWidget(old);

    // Auto-collapse when everything completes; re-open if work resumes.
    final allComplete = _allComplete;
    if (_previousAllComplete && !allComplete) {
      _setOpen(true);
    } else if (!_previousAllComplete &&
        allComplete &&
        widget.collapseOnComplete) {
      _setOpen(false);
    }
    _previousAllComplete = allComplete;

    // Smooth-scroll to the bottom when the list grows (source useLayoutEffect
    // on itemCount).
    if (widget.items.length != old.items.length && widget.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final reduce = MediaQuery.disableAnimationsOf(context);
        final target = _scroll.position.maxScrollExtent;
        if (target <= 0) return;
        if (reduce) {
          _scroll.jumpTo(target);
        } else {
          _scroll.animateTo(
            target,
            duration: const Duration(milliseconds: 280),
            curve: beuiEaseOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (next == _currentOpen) return;
    if (!_isControlled) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
  }

  void _toggle() => _setOpen(!_currentOpen);

  @override
  Widget build(BuildContext context) {
    // A40: this was a `!` null-assert, so a consumer who installed the widget
    // without also installing `BeuiColors` got a crash out of a published
    // package. Every sibling in the agent family already fell back like this.
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final strings = agent.strings;
    final statusColors = agent.statusColorsFor(colors.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    // A36: was `isDark ? emerald-400 : emerald-600`, two Tailwind literals.
    final completeCountColor = _allComplete
        ? statusColors.palette(BeuiAgentStatus.success).foreground
        : colors.mutedForeground;

    Widget shell = ClipRRect(
      borderRadius: agent.shapes.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            open: _currentOpen,
            allComplete: _allComplete,
            title:
                widget.title ??
                Text(
                  strings.todoListTitle,
                  style: agent.typography.description.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.foreground.withValues(alpha: 0.9),
                  ),
                ),
            completed: _completed,
            total: widget.items.length,
            countColor: completeCountColor,
            colors: colors,
            agent: agent,
            statusColors: statusColors,
            reduce: reduce,
            onToggle: _toggle,
          ),
          BeuiAgentDisclosureInternal(
            open: _currentOpen,
            reduce: reduce,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: widget.items.isEmpty
                  ? _EmptyState(
                      custom: widget.emptyState,
                      label: widget.emptyLabel ?? strings.todoEmpty,
                      description:
                          widget.emptyDescription ??
                          strings.todoEmptyDescription,
                      colors: colors,
                      agent: agent,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return _TodoRow(
                          key: ValueKey<String>(item.id),
                          item: item,
                          colors: colors,
                          agent: agent,
                          statusColors: statusColors,
                          reduce: reduce,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );

    // A38: `useGlassSurfaces` was dead across this whole cluster. Honouring it
    // through `decorateCard` picks up both the glass fill and its backdrop
    // blur; with the token at its `false` default this is a no-op and the card
    // keeps the source's transparent, hairline-bordered shell below.
    if (agent.structure.useGlassSurfaces) {
      shell = agent.decorateCard(colors: colors, child: shell);
    }

    return Semantics(
      container: true,
      // Without this the card's own name is concatenated into the header
      // button's label, so a screen reader reads the whole list — name, count
      // sentence, title, numerator, denominator — as one enormous button
      // label. Explicit children keep the card a named container with a
      // button inside it.
      explicitChildNodes: true,
      label: widget.semanticsLabel ?? strings.todoListLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: agent.shapes.card, // rounded-2xl
          border: Border.all(
            // Decorative chrome, not content — the alpha stays.
            color: colors.border.withValues(alpha: colors.border.a * 0.7),
            width: agent.structure.borderWidth,
          ),
        ),
        child: shell,
      ),
    );
  }
}

/// The empty panel: a headline plus an optional orienting line.
///
/// A28. The headline routes through [BeuiAgentStrings.todoEmpty] and the
/// orienting line through [BeuiAgentStrings.todoEmptyDescription], so both
/// stay localizable by default; [BeuiTodoList.emptyDescription] overrides the
/// latter per instance.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.custom,
    required this.label,
    required this.description,
    required this.colors,
    required this.agent,
  });

  final Widget? custom;
  final String label;
  final String? description;
  final BeuiColors colors;
  final BeuiAgentTheme agent;

  @override
  Widget build(BuildContext context) {
    final custom = this.custom;
    return Padding(
      padding: agent.layout.cardPadding.copyWith(top: 8),
      child:
          custom ??
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: agent.typography.description.copyWith(
                  color: colors.foreground.withValues(alpha: 0.9),
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  // Supporting copy, but still information — full muted
                  // contrast, no alpha multiplier (A8).
                  style: agent.typography.description.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatefulWidget {
  const _Header({
    required this.open,
    required this.allComplete,
    required this.title,
    required this.completed,
    required this.total,
    required this.countColor,
    required this.colors,
    required this.agent,
    required this.statusColors,
    required this.reduce,
    required this.onToggle,
  });

  final bool open;
  final bool allComplete;
  final Widget title;
  final int completed;
  final int total;
  final Color countColor;
  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final BeuiAgentStatusColors statusColors;
  final bool reduce;
  final VoidCallback onToggle;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final agent = widget.agent;
    // Decorative chrome — the alpha stays (A8 covers information, not glyphs).
    final chevronColor = (_hovered || _focused)
        ? colors.mutedForeground
        : colors.mutedForeground.withValues(alpha: 0.5);
    final countStyle = agent.typography.status.copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: widget.countColor,
    );

    Widget bar = SizedBox(
      height: 44, // h-11
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14), // px-3.5
        child: Row(
          children: [
            _TodoHeaderIcon(
              complete: widget.allComplete,
              reduce: widget.reduce,
              colors: colors,
              agent: agent,
              statusColors: widget.statusColors,
            ),
            const SizedBox(width: 10), // gap-2.5
            Expanded(
              child: DefaultTextStyle.merge(
                style: agent.typography.description.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.foreground.withValues(alpha: 0.9),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                child: widget.title,
              ),
            ),
            const SizedBox(width: 10),
            // Completion count with rolling numerator.
            DefaultTextStyle.merge(
              style: countStyle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiActionSwapText(
                    value: '${widget.completed}',
                    text: '${widget.completed}',
                    variant: BeuiActionSwapVariant.roll,
                    style: countStyle,
                  ),
                  Text(
                    agent.strings.todoCountDenominator(widget.total),
                    style: countStyle,
                  ),
                ],
              ),
            ),
            SizedBox(width: agent.layout.actionSpacing),
            _Chevron(
              open: widget.open,
              reduce: widget.reduce,
              color: chevronColor,
            ),
          ],
        ),
      ),
    );

    // The focus indicator used to be a 2px border inside the box model, with a
    // permanent transparent 2px border to stop it shifting the row. It is now
    // painted outside layout in the dedicated `focusRing` role, at the theme's
    // emphasis width — no reserved inset, and a ring that actually clears 3:1.
    bar = BeuiFocusRing(
      focused: _focused,
      borderRadius: agent.shapes.card,
      width: agent.structure.emphasisBorderWidth,
      child: bar,
    );

    // Already 44px tall, so the hit target is a no-op today — it is here so the
    // row cannot silently drop under the floor if the header is ever made
    // denser (the theme ships a `compact` preset that does exactly that). It
    // must be the outermost box to work at all: every proxy above it rejects an
    // out-of-bounds pointer in `RenderBox.hitTest` before the slop is read.
    return BeuiMinHitTarget(
      child: Semantics(
        // One node for the whole header: the count sentence below, then the
        // title and the n/N counter merged in from the row.
        container: true,
        button: true,
        expanded: widget.open,
        label: agent.strings.todoHeaderLabel(
          widget.completed,
          widget.total,
          widget.open,
        ),
        child: FocusableActionDetector(
          onShowFocusHighlight: (v) {
            if (mounted) setState(() => _focused = v);
          },
          onShowHoverHighlight: (v) {
            if (mounted) setState(() => _hovered = v);
          },
          mouseCursor: SystemMouseCursors.click,
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: bar,
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
    final icon = Icon(
      BeuiAgentTheme.of(context).icons.expand,
      size: 14,
      color: color,
    );
    if (reduce) {
      return Transform.rotate(angle: open ? math.pi : 0, child: icon);
    }
    return SingleMotionBuilder(
      value: open ? 180.0 : 0.0,
      motion: motionFor(context, _headerIconSwap, isMovement: true),
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180.0, child: child),
      child: icon,
    );
  }
}

// ---------------------------------------------------------------------------
// Header icon (list-todo ↔ complete check)
// ---------------------------------------------------------------------------

class _TodoHeaderIcon extends StatelessWidget {
  const _TodoHeaderIcon({
    required this.complete,
    required this.reduce,
    required this.colors,
    required this.agent,
    required this.statusColors,
  });

  final bool complete;
  final bool reduce;
  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final BeuiAgentStatusColors statusColors;

  @override
  Widget build(BuildContext context) {
    // AnimatePresence mode=popLayout — stack overlapping layers with swap spring.
    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedSwitcher(
        duration: _headerMarkIn,
        // A19: the outgoing mark used to take the full 280ms too.
        reverseDuration: _headerMarkOut,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          if (reduce) {
            return FadeTransition(opacity: animation, child: child);
          }
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: complete
            ? _CompleteHeaderMark(
                key: const ValueKey('complete'),
                reduce: reduce,
                palette: statusColors.palette(BeuiAgentStatus.success),
              )
            : KeyedSubtree(
                key: const ValueKey('todo'),
                child: Icon(
                  agent.icons.todo,
                  size: agent.layout.iconSize,
                  color: colors.mutedForeground,
                ),
              ),
      ),
    );
  }
}

class _CompleteHeaderMark extends StatefulWidget {
  const _CompleteHeaderMark({
    required this.reduce,
    required this.palette,
    super.key,
  });

  final bool reduce;

  /// The success tier. [BeuiAgentStatusPalette.solid] fills the disc,
  /// [BeuiAgentStatusPalette.onSolid] strokes the check — the two slots exist
  /// for exactly this mark.
  final BeuiAgentStatusPalette palette;

  @override
  State<_CompleteHeaderMark> createState() => _CompleteHeaderMarkState();
}

class _CompleteHeaderMarkState extends State<_CompleteHeaderMark> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _progress = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _progress = 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: _progress,
      motion: motionFor(context, _checkDraw, isMovement: false),
      builder: (context, t, _) {
        return CustomPaint(
          size: const Size.square(22),
          painter: _HeaderCheckPainter(
            color: widget.palette.solid,
            checkColor: widget.palette.onSolid,
            progress: t.clamp(0.0, 1.0),
          ),
        );
      },
    );
  }
}

/// Filled status-tier disc + check path (source header complete SVG).
class _HeaderCheckPainter extends CustomPainter {
  _HeaderCheckPainter({
    required this.color,
    required this.checkColor,
    required this.progress,
  });

  final Color color;

  /// A36: was a bare `Colors.white`. It is ink drawn on [color], which is what
  /// the palette's `onSolid` slot means — retinting the disc now retints the
  /// stroke with it.
  final Color checkColor;

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, Paint()..color = color);
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(7.5 * s, 12.25 * s)
      ..lineTo(10.5 * s, 15.25 * s)
      ..lineTo(16.75 * s, 8.75 * s);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HeaderCheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.checkColor != checkColor;
}

// The private `_AgentDisclosure` that used to live here is gone —
// `BeuiAgentDisclosureInternal` (`_disclosure.dart`) replaces it. The visible
// behaviour is identical except under reduced motion, where the old copy
// hard-cut (a static Offstage + heightFactor swap, no transition at all) and
// the shared one keeps a ~120ms opacity cross-fade, per the project rule that
// reduced motion drops *movement* and not opacity.

// ---------------------------------------------------------------------------
// Todo row
// ---------------------------------------------------------------------------

class _TodoRow extends StatefulWidget {
  const _TodoRow({
    required this.item,
    required this.colors,
    required this.agent,
    required this.statusColors,
    required this.reduce,
    super.key,
  });

  final BeuiTodoItem item;
  final BeuiColors colors;
  final BeuiAgentTheme agent;
  final BeuiAgentStatusColors statusColors;
  final bool reduce;

  @override
  State<_TodoRow> createState() => _TodoRowState();
}

/// The row entrance opacity: finishes at ~0.18s, well before the layout
/// spring settles. Extracted from the old inline `Curves.easeOut.transform(
/// min(1, t * 1.4))` so the same shaping can drive a [FadeTransition].
class _EnterOpacity extends Animatable<double> {
  const _EnterOpacity();

  @override
  double transform(double t) =>
      Curves.easeOut.transform(math.min(1.0, math.max(0.0, t) * 1.4));
}

class _TodoRowState extends State<_TodoRow>
    with SingleTickerProviderStateMixin {
  /// Enter progress 0→1 on first mount (source initial y:6 / opacity:0).
  late final SingleMotionController _enter;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enter = SingleMotionController(
      vsync: this,
      // Reduced motion starts settled: there is no movement to drop because
      // the row never travels.
      motion: widget.reduce ? const NoMotion() : _layoutSpring,
      initialValue: widget.reduce ? 1 : 0,
    );
    _fade = _enter.drive(const _EnterOpacity());
    if (!widget.reduce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enter.animateTo(1);
      });
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// A8: the task title is the content of this row. All three non-active
  /// states used to multiply `mutedForeground` by 0.55–0.65, putting the text
  /// under 3:1 while the information that distinguishes them — the mark and
  /// the strike-through — was already carrying that job redundantly.
  Color _titleColor(BeuiTodoItemStatus status, BeuiColors colors) {
    switch (status) {
      case BeuiTodoItemStatus.inProgress:
        return colors.foreground;
      case BeuiTodoItemStatus.pending:
      case BeuiTodoItemStatus.completed:
      case BeuiTodoItemStatus.cancelled:
        return colors.mutedForeground;
    }
  }

  String _statusLabel(BeuiTodoItemStatus status) {
    final strings = widget.agent.strings;
    switch (status) {
      case BeuiTodoItemStatus.pending:
        return strings.todoStatusPending;
      case BeuiTodoItemStatus.inProgress:
        return strings.todoStatusInProgress;
      case BeuiTodoItemStatus.completed:
        return strings.todoStatusCompleted;
      case BeuiTodoItemStatus.cancelled:
        return strings.todoStatusCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = widget.colors;
    final agent = widget.agent;
    final reduce = widget.reduce;
    final status = item.status;
    final completed = status == BeuiTodoItemStatus.completed;

    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36), // min-h-9
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            _TodoStatusIcon(
              status: status,
              progress: item.progress,
              colors: colors,
              statusColors: widget.statusColors,
              reduce: reduce,
            ),
            const SizedBox(width: 10), // gap-2.5
            Expanded(
              // Align loosens the incoming tight width, so the strike Stack
              // shrink-wraps the glyphs. Under a bare Expanded the Stack fills
              // the row and `Positioned.fill` rules straight past the title,
              // where the source strikes only the text.
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: agent.strings.todoRowLabel(_statusLabel(status)),
                  child: DefaultTextStyle.merge(
                    style: agent.typography.description.copyWith(
                      color: _titleColor(status, colors),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    child: _StrikethroughTitle(
                      completed: completed,
                      reduce: reduce,
                      child: item.title,
                    ),
                  ),
                ),
              ),
            ),
            if (item.detail != null) ...[
              SizedBox(width: agent.layout.actionSpacing),
              DefaultTextStyle.merge(
                // A8: "25%" is progress, not decoration.
                style: agent.typography.description.copyWith(
                  color: colors.mutedForeground,
                ),
                child: item.detail!,
              ),
            ],
          ],
        ),
      ),
    );

    if (reduce) return row;

    // A18: the entrance used to rebuild an `Opacity` widget over this whole
    // row — a `CustomPaint` mark, a `Stack`-composed strike, and the title —
    // on every frame. `FadeTransition` updates the opacity layer in place, and
    // the single `AnimatedBuilder` below passes `child` straight through, so
    // nothing under here rebuilds while the row settles.
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 6 * (1 - _enter.value.clamp(0.0, 1.0))),
          child: child,
        ),
        child: row,
      ),
    );
  }
}

/// Title with a left-origin strike that draws on when [completed].
class _StrikethroughTitle extends StatefulWidget {
  const _StrikethroughTitle({
    required this.completed,
    required this.reduce,
    required this.child,
  });

  final bool completed;
  final bool reduce;
  final Widget child;

  @override
  State<_StrikethroughTitle> createState() => _StrikethroughTitleState();
}

class _StrikethroughTitleState extends State<_StrikethroughTitle> {
  double _target = 0;

  @override
  void initState() {
    super.initState();
    _target = widget.completed ? 1.0 : 0.0;
    if (widget.completed && !widget.reduce) {
      // Source delay 0.06s before the strike begins.
      Future<void>.delayed(_strikeDelay, () {
        if (mounted && widget.completed) setState(() => _target = 1.0);
      });
      _target = 0;
    }
  }

  @override
  void didUpdateWidget(_StrikethroughTitle old) {
    super.didUpdateWidget(old);
    if (widget.completed != old.completed) {
      if (widget.completed && !widget.reduce) {
        setState(() => _target = 0);
        Future<void>.delayed(_strikeDelay, () {
          if (mounted && widget.completed) setState(() => _target = 1.0);
        });
      } else {
        setState(() => _target = widget.completed ? 1.0 : 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: SingleMotionBuilder(
              value: _target,
              motion: widget.reduce
                  ? const NoMotion()
                  : motionFor(
                      context,
                      // A19: draw on in 280ms, retract in 160ms.
                      _target > 0 ? _strikeMotion : _strikeRetractMotion,
                      isMovement: true,
                    ),
              builder: (context, t, _) {
                // `_target` is maintained correctly for both modes, but under
                // reduce the motion is `NoMotion`, which holds the builder's
                // `t` at its mount value forever. A task that completes while
                // already on screen therefore never got its strike drawn.
                final tt = widget.reduce
                    ? _target.clamp(0.0, 1.0)
                    : t.clamp(0.0, 1.0);
                if (tt <= 0) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: tt,
                    child: Container(
                      height: 1,
                      color: DefaultTextStyle.of(context).style.color,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status icon (morphing SVG marks)
// ---------------------------------------------------------------------------

class _TodoStatusIcon extends StatefulWidget {
  const _TodoStatusIcon({
    required this.status,
    required this.progress,
    required this.colors,
    required this.statusColors,
    required this.reduce,
  });

  final BeuiTodoItemStatus status;
  final double? progress;
  final BeuiColors colors;
  final BeuiAgentStatusColors statusColors;
  final bool reduce;

  @override
  State<_TodoStatusIcon> createState() => _TodoStatusIconState();
}

class _TodoStatusIconState extends State<_TodoStatusIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  bool get _shouldSpin =>
      widget.status == BeuiTodoItemStatus.inProgress &&
      widget.progress == null &&
      !widget.reduce;

  @override
  void initState() {
    super.initState();
    if (_shouldSpin) _startSpin();
  }

  @override
  void didUpdateWidget(_TodoStatusIcon old) {
    super.didUpdateWidget(old);
    if (_shouldSpin) {
      _startSpin();
    } else {
      _stopSpin();
    }
  }

  void _startSpin() {
    _spin ??= AnimationController(vsync: this, duration: _spinPeriod)..repeat();
    if (!_spin!.isAnimating) _spin!.repeat();
  }

  void _stopSpin() {
    _spin?.stop();
    _spin?.value = 0;
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  /// A36: was `isDark ? rose-400 : rose-600` for cancelled and bare
  /// `foreground` for in-progress. Every mark now takes its tier's foreground
  /// — see [_statusTier] for the mapping and the two deliberate choices in it.
  Color _strokeColor() =>
      widget.statusColors.palette(_statusTier(widget.status)).foreground;

  double get _normalizedProgress {
    final p = widget.progress;
    if (p == null) return 0.68; // source default visual fill
    return (p.clamp(0, 100)) / 100;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final reduce = widget.reduce;
    final color = _strokeColor();

    final fillTarget = status == BeuiTodoItemStatus.completed ? 0.06 : 0.0;
    final checkTarget = status == BeuiTodoItemStatus.completed ? 1.0 : 0.0;
    final cancelTarget = status == BeuiTodoItemStatus.cancelled ? 1.0 : 0.0;
    final ringTarget = status == BeuiTodoItemStatus.inProgress
        ? _normalizedProgress
        : 0.0;
    final ringOpacity = status == BeuiTodoItemStatus.inProgress ? 1.0 : 0.0;
    final pending = status == BeuiTodoItemStatus.pending;
    final inProgressBase =
        status == BeuiTodoItemStatus.inProgress; // dimmed base circle

    // A18: these four channels used to be four *nested* `SingleMotionBuilder`s
    // (plus a fifth for the ring opacity), so every row built a five-deep
    // animation tree and every frame of any one channel rebuilt the four
    // builders beneath it. They are one `MotionBuilder` now.
    //
    // The nesting existed because each channel has its own motion — a 180ms
    // fade, a 240ms check draw, a 200ms cancel draw, a layout spring — and a
    // single-motion builder cannot express that. `motionPerDimension` can:
    // four dimensions, four motions, four independent simulations, identical
    // timings to before. The `Rect` carrier is arbitrary (it is the widest
    // converter the engine facade exports); the field names below are the only
    // place its channel order matters.
    final channels = <Motion>[
      motionFor(context, _fillFade, isMovement: false),
      motionFor(
        context,
        reduce ? const NoMotion() : _checkDraw,
        isMovement: false,
      ),
      motionFor(
        context,
        reduce ? const NoMotion() : _cancelDraw,
        isMovement: false,
      ),
      motionFor(
        context,
        reduce ? const NoMotion() : _layoutSpring,
        isMovement: true,
      ),
    ];

    Widget animated(double spinTurns) {
      return SingleMotionBuilder(
        value: ringOpacity,
        motion: motionFor(context, _fillFade, isMovement: false),
        builder: (context, ringOp, _) {
          return MotionBuilder<Rect>.motionPerDimension(
            // left = fill, top = check, right = cancel, bottom = ring.
            value: Rect.fromLTRB(
              fillTarget,
              checkTarget,
              cancelTarget,
              ringTarget,
            ),
            motionPerDimension: channels,
            converter: const RectMotionConverter(),
            builder: (context, channel, _) {
              return CustomPaint(
                size: const Size.square(20),
                painter: _StatusPainter(
                  color: color,
                  fillOpacity: channel.left.clamp(0.0, 1.0),
                  // Every reduce-gated channel above is `NoMotion`, which holds
                  // its seeded value rather than snapping to the target, so
                  // each one has to be read straight off the target instead.
                  // `ringProgress` was the channel this compensation missed:
                  // a pending -> inProgress transition under reduced motion
                  // left the arc frozen at 0, i.e. no ring at all. Reading the
                  // targets uniformly also fixes the reverse direction, which
                  // the old `&& target == 1` form still froze.
                  checkProgress: reduce
                      ? checkTarget
                      : channel.top.clamp(0.0, 1.0),
                  cancelProgress: reduce
                      ? cancelTarget
                      : channel.right.clamp(0.0, 1.0),
                  ringProgress: reduce
                      ? ringTarget
                      : channel.bottom.clamp(0.0, 1.0),
                  ringOpacity: ringOp.clamp(0.0, 1.0),
                  baseOpacity: inProgressBase ? 0.2 : 1.0,
                  dashed: pending,
                  spinTurns: spinTurns,
                ),
              );
            },
          );
        },
      );
    }

    // Margin mx-0.5 → 2px horizontal padding.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _spin != null && _shouldSpin
          ? AnimatedBuilder(
              animation: _spin!,
              builder: (context, _) => animated(_spin!.value),
            )
          : animated(0),
    );
  }
}

/// Multi-layer 24-viewbox status mark: dashed pending ring, in-progress arc,
/// completed check, cancelled X.
class _StatusPainter extends CustomPainter {
  _StatusPainter({
    required this.color,
    required this.fillOpacity,
    required this.checkProgress,
    required this.cancelProgress,
    required this.ringProgress,
    required this.ringOpacity,
    required this.baseOpacity,
    required this.dashed,
    required this.spinTurns,
  });

  final Color color;
  final double fillOpacity;
  final double checkProgress;
  final double cancelProgress;
  final double ringProgress;
  final double ringOpacity;
  final double baseOpacity;
  final bool dashed;
  final double spinTurns;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final center = Offset(12 * s, 12 * s);
    final r = 9 * s;

    // Base circle.
    final basePaint = Paint()
      ..color = color.withValues(alpha: baseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..strokeCap = StrokeCap.round;

    if (fillOpacity > 0) {
      canvas.drawCircle(
        center,
        r,
        Paint()..color = color.withValues(alpha: fillOpacity),
      );
    }

    if (dashed) {
      // strokeDasharray "2 3" on the circle.
      _drawDashedCircle(canvas, center, r, basePaint, dash: 2 * s, gap: 3 * s);
    } else {
      canvas.drawCircle(center, r, basePaint);
    }

    // In-progress arc (starts at top, -90°).
    if (ringOpacity > 0 && ringProgress > 0) {
      canvas.save();
      // Source: rotate -90 resting, or continuous 360 when indeterminate.
      final deg = spinTurns > 0 ? spinTurns * 360.0 - 90.0 : -90.0;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(deg * math.pi / 180.0);
      canvas.translate(-center.dx, -center.dy);
      final sweep = 2 * math.pi * ringProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        0,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Check path: M7.5 12.25 L10.5 15.25 L16.75 8.75
    if (checkProgress > 0) {
      final path = Path()
        ..moveTo(7.5 * s, 12.25 * s)
        ..lineTo(10.5 * s, 15.25 * s)
        ..lineTo(16.75 * s, 8.75 * s);
      final metric = path.computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * checkProgress);
      canvas.drawPath(
        drawn,
        Paint()
          ..color = color.withValues(alpha: checkProgress.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Cancel X: M8.5 8.5 L15.5 15.5 + M15.5 8.5 L8.5 15.5
    if (cancelProgress > 0) {
      final xPath = Path()
        ..moveTo(8.5 * s, 8.5 * s)
        ..lineTo(15.5 * s, 15.5 * s)
        ..moveTo(15.5 * s, 8.5 * s)
        ..lineTo(8.5 * s, 15.5 * s);
      for (final metric in xPath.computeMetrics()) {
        final drawn = metric.extractPath(0, metric.length * cancelProgress);
        canvas.drawPath(
          drawn,
          Paint()
            ..color = color.withValues(alpha: cancelProgress.clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final circumference = 2 * math.pi * radius;
    final period = dash + gap;
    if (period <= 0) {
      canvas.drawCircle(center, radius, paint);
      return;
    }
    var drawn = 0.0;
    while (drawn < circumference) {
      final start = drawn / radius;
      final len = math.min(dash, circumference - drawn);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start - math.pi / 2,
        len / radius,
        false,
        paint,
      );
      drawn += period;
    }
  }

  @override
  bool shouldRepaint(_StatusPainter old) =>
      old.color != color ||
      old.fillOpacity != fillOpacity ||
      old.checkProgress != checkProgress ||
      old.cancelProgress != cancelProgress ||
      old.ringProgress != ringProgress ||
      old.ringOpacity != ringOpacity ||
      old.baseOpacity != baseOpacity ||
      old.dashed != dashed ||
      old.spinTurns != spinTurns;
}
