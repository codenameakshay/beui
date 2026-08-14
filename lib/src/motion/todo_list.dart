import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
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
const _strikeMotion = CurvedMotion(Duration(milliseconds: 280), beuiEaseOut);
const _strikeDelay = Duration(milliseconds: 60);
const _disclosureOpen = CurvedMotion(Duration(milliseconds: 220), beuiEaseOut);
const _disclosureClose = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);

/// Tailwind `emerald-500` — matches the source's complete header glyph.
const _emerald500 = Color(0xFF00BC7D);

/// Tailwind `emerald-600` (light) for the completion count.
const _emerald600 = Color(0xFF009966);

/// Tailwind `emerald-400` (dark) for the completion count.
const _emerald400 = Color(0xFF00D492);

/// Tailwind `rose-600` (light) for cancelled marks.
const _rose600 = Color(0xFFEC003F);

/// Tailwind `rose-400` (dark) for cancelled marks.
const _rose400 = Color(0xFFFF637E);

/// Indefinite in-progress spin (source `duration: 1.1, repeat: Infinity`).
const _spinPeriod = Duration(milliseconds: 1100);

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
    super.key,
  });

  /// The task rows, top to bottom.
  final List<BeuiTodoItem> items;

  /// Header label. Defaults to `"To-dos"`. Accepts any widget (source
  /// `ReactNode`); demos typically pass a [Text] or rely on the string default.
  final Widget? title;

  /// Controlled open state. When non-null the list is *controlled* — keep it
  /// in sync via [onOpenChange]. Leave null for the uncontrolled pattern.
  final bool? open;

  /// Initial open state in the uncontrolled case (ignored when [open] is
  /// supplied).
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
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isDark = colors.brightness == Brightness.dark;
    final completeCountColor = _allComplete
        ? (isDark ? _emerald400 : _emerald600)
        : colors.mutedForeground;

    return Semantics(
      container: true,
      label: 'Agent task list',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: agent.shapes.card, // rounded-2xl
          border: Border.all(
            color: colors.border.withValues(alpha: colors.border.a * 0.7),
            width: agent.structure.borderWidth,
          ),
        ),
        child: ClipRRect(
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
                      'To-dos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.foreground.withValues(alpha: 0.9),
                      ),
                    ),
                completed: _completed,
                total: widget.items.length,
                countColor: completeCountColor,
                colors: colors,
                reduce: reduce,
                onToggle: _toggle,
              ),
              _AgentDisclosure(
                open: _currentOpen,
                reduce: reduce,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxHeight),
                  child: widget.items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                          child: Text(
                            'No tasks yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.mutedForeground,
                            ),
                          ),
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
                              reduce: reduce,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
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
    final chevronColor = (_hovered || _focused)
        ? colors.mutedForeground
        : colors.mutedForeground.withValues(alpha: 0.5);

    return Semantics(
      button: true,
      expanded: widget.open,
      label:
          '${widget.completed} of ${widget.total} tasks completed. '
          '${widget.open ? 'Collapse' : 'Expand'} task list',
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) {
          if (mounted) setState(() => _focused = v);
        },
        onShowHoverHighlight: (v) {
          if (mounted) setState(() => _hovered = v);
        },
        mouseCursor: SystemMouseCursors.click,
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 44, // h-11
            padding: const EdgeInsets.symmetric(horizontal: 14), // px-3.5
            decoration: BoxDecoration(
              borderRadius: BeuiAgentTheme.of(context).shapes.card,
              border: _focused
                  ? Border.all(color: colors.ring, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                _TodoHeaderIcon(
                  complete: widget.allComplete,
                  reduce: widget.reduce,
                  colors: colors,
                ),
                const SizedBox(width: 10), // gap-2.5
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 14,
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: widget.countColor,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BeuiActionSwapText(
                        value: '${widget.completed}',
                        text: '${widget.completed}',
                        variant: BeuiActionSwapVariant.roll,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: widget.countColor,
                        ),
                      ),
                      Text(
                        '/${widget.total}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: widget.countColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Chevron(
                  open: widget.open,
                  reduce: widget.reduce,
                  color: chevronColor,
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
  });

  final bool complete;
  final bool reduce;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    // AnimatePresence mode=popLayout — stack overlapping layers with swap spring.
    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
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
              )
            : KeyedSubtree(
                key: const ValueKey('todo'),
                child: Icon(
                  BeuiAgentTheme.of(context).icons.todo,
                  size: 16,
                  color: colors.mutedForeground,
                ),
              ),
      ),
    );
  }
}

class _CompleteHeaderMark extends StatefulWidget {
  const _CompleteHeaderMark({required this.reduce, super.key});

  final bool reduce;

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
            color: _emerald500,
            progress: t.clamp(0.0, 1.0),
          ),
        );
      },
    );
  }
}

/// Filled emerald circle + white check path (source header complete SVG).
class _HeaderCheckPainter extends CustomPainter {
  _HeaderCheckPainter({required this.color, required this.progress});

  final Color color;
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
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HeaderCheckPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Agent disclosure (height + opacity + y clip reveal)
// ---------------------------------------------------------------------------

/// Shared transform-only reveal for collapsible agent content — the Flutter
/// port of the source's `AgentDisclosure`.
class _AgentDisclosure extends StatefulWidget {
  const _AgentDisclosure({
    required this.open,
    required this.reduce,
    required this.child,
  });

  final bool open;
  final bool reduce;
  final Widget child;

  @override
  State<_AgentDisclosure> createState() => _AgentDisclosureState();
}

class _AgentDisclosureState extends State<_AgentDisclosure> {
  @override
  Widget build(BuildContext context) {
    final target = widget.open ? 1.0 : 0.0;
    final motion = widget.open ? _disclosureOpen : _disclosureClose;

    // heightFactor clips the panel; Offstage when fully closed so finders and
    // semantics skip the hidden rows (mirrors source `inert` + aria-hidden).
    if (widget.reduce) {
      return Offstage(
        offstage: !widget.open,
        child: IgnorePointer(
          ignoring: !widget.open,
          child: ExcludeSemantics(
            excluding: !widget.open,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: widget.open ? 1.0 : 0.0,
                child: widget.child,
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
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Todo row
// ---------------------------------------------------------------------------

class _TodoRow extends StatefulWidget {
  const _TodoRow({
    required this.item,
    required this.colors,
    required this.reduce,
    super.key,
  });

  final BeuiTodoItem item;
  final BeuiColors colors;
  final bool reduce;

  @override
  State<_TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<_TodoRow> {
  // Enter progress 0→1 on first mount (source initial y:6 / opacity:0).
  double _enter = 0;

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _enter = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _enter = 1);
      });
    }
  }

  Color _titleColor(BeuiTodoItemStatus status, BeuiColors colors) {
    switch (status) {
      case BeuiTodoItemStatus.pending:
        return colors.mutedForeground.withValues(alpha: 0.65);
      case BeuiTodoItemStatus.inProgress:
        return colors.foreground;
      case BeuiTodoItemStatus.completed:
        return colors.mutedForeground.withValues(alpha: 0.6);
      case BeuiTodoItemStatus.cancelled:
        return colors.mutedForeground.withValues(alpha: 0.55);
    }
  }

  String _statusLabel(BeuiTodoItemStatus status) {
    switch (status) {
      case BeuiTodoItemStatus.pending:
        return 'Pending';
      case BeuiTodoItemStatus.inProgress:
        return 'In progress';
      case BeuiTodoItemStatus.completed:
        return 'Completed';
      case BeuiTodoItemStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = widget.colors;
    final reduce = widget.reduce;
    final status = item.status;
    final completed = status == BeuiTodoItemStatus.completed;

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36), // min-h-9
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            _TodoStatusIcon(
              status: status,
              progress: item.progress,
              colors: colors,
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
                  label: '${_statusLabel(status)}: ',
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
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
              const SizedBox(width: 8),
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14,
                  color: colors.mutedForeground.withValues(alpha: 0.55),
                ),
                child: item.detail!,
              ),
            ],
          ],
        ),
      ),
    );

    if (reduce) return row;

    return SingleMotionBuilder(
      value: _enter,
      // Opacity rides a short ease; y rides layout spring — approximate with
      // the layout spring for the combined enter (source splits them).
      motion: motionFor(context, _layoutSpring, isMovement: true),
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        // Opacity finishes faster (≈0.18s) than the spring settle.
        final opacity = Curves.easeOut.transform(math.min(1.0, tt * 1.4));
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - tt)),
            child: child,
          ),
        );
      },
      child: row,
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
                  : motionFor(context, _strikeMotion, isMovement: true),
              builder: (context, t, _) {
                final tt = t.clamp(0.0, 1.0);
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
    required this.reduce,
  });

  final BeuiTodoItemStatus status;
  final double? progress;
  final BeuiColors colors;
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

  Color _strokeColor(BeuiColors colors) {
    final isDark = colors.brightness == Brightness.dark;
    switch (widget.status) {
      case BeuiTodoItemStatus.inProgress:
        return colors.foreground;
      case BeuiTodoItemStatus.cancelled:
        return isDark ? _rose400 : _rose600;
      case BeuiTodoItemStatus.pending:
      case BeuiTodoItemStatus.completed:
        return colors.mutedForeground;
    }
  }

  double get _normalizedProgress {
    final p = widget.progress;
    if (p == null) return 0.68; // source default visual fill
    return (p.clamp(0, 100)) / 100;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final status = widget.status;
    final reduce = widget.reduce;
    final color = _strokeColor(colors);

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

    Widget paint({
      required double fillOpacity,
      required double checkProgress,
      required double cancelProgress,
      required double ringProgress,
      required double ringOp,
      required double spinTurns,
    }) {
      return CustomPaint(
        size: const Size.square(20),
        painter: _StatusPainter(
          color: color,
          fillOpacity: fillOpacity,
          checkProgress: checkProgress,
          cancelProgress: cancelProgress,
          ringProgress: ringProgress,
          ringOpacity: ringOp,
          baseOpacity: inProgressBase ? 0.2 : 1.0,
          dashed: pending,
          spinTurns: spinTurns,
        ),
      );
    }

    // Spin turns ride the continuous controller; everything else is spring/ease.
    Widget animated(double spinTurns) {
      return SingleMotionBuilder(
        value: fillTarget,
        motion: motionFor(context, _fillFade, isMovement: false),
        builder: (context, fill, _) {
          return SingleMotionBuilder(
            value: checkTarget,
            motion: motionFor(
              context,
              reduce ? const NoMotion() : _checkDraw,
              isMovement: false,
            ),
            builder: (context, check, _) {
              return SingleMotionBuilder(
                value: cancelTarget,
                motion: motionFor(
                  context,
                  reduce ? const NoMotion() : _cancelDraw,
                  isMovement: false,
                ),
                builder: (context, cancel, _) {
                  return SingleMotionBuilder(
                    value: ringTarget,
                    motion: motionFor(
                      context,
                      reduce ? const NoMotion() : _layoutSpring,
                      isMovement: true,
                    ),
                    builder: (context, ring, _) {
                      return SingleMotionBuilder(
                        value: ringOpacity,
                        motion: motionFor(
                          context,
                          _fillFade,
                          isMovement: false,
                        ),
                        builder: (context, rOp, _) {
                          return paint(
                            fillOpacity: fill.clamp(0.0, 1.0),
                            checkProgress: reduce && checkTarget == 1
                                ? 1.0
                                : check.clamp(0.0, 1.0),
                            cancelProgress: reduce && cancelTarget == 1
                                ? 1.0
                                : cancel.clamp(0.0, 1.0),
                            ringProgress: ring.clamp(0.0, 1.0),
                            ringOp: rOp.clamp(0.0, 1.0),
                            spinTurns: spinTurns,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    // Margin mx-0.5 → 2px horizontal padding.
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _spin != null && _shouldSpin
          ? AnimatedBuilder(
              animation: _spin!,
              builder: (context, _) => animated(_spin!.value),
            )
          : animated(0),
    );

    return body;
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
