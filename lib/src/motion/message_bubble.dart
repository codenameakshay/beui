import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'message.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Visual tone of a [BeuiMessageBubble] (source `MessageBubbleVariant`).
enum BeuiMessageBubbleVariant {
  /// Inverted solid fill (`bg-foreground` / `text-background`) — typical user.
  solid,

  /// Soft muted fill (`bg-muted`) — typical assistant.
  soft,

  /// Primary tint fill (`bg-primary/10`).
  tint,

  /// Outlined surface (`border` + `bg-background`).
  outline,

  /// No surface chrome — full-width, zero padding (markdown / rich content).
  ghost,

  /// Destructive tint (`bg-destructive/10` / `text-destructive`).
  danger,
}

/// Bubble alignment (source `MessageBubbleAlign` / `MessageSide`).
///
/// Alias of [BeuiMessageBubbleSide] so bubble consumers and message rows share
/// one enum.
typedef BeuiMessageBubbleAlign = BeuiMessageBubbleSide;

/// Vertical spacing inside a [BeuiMessageBubbleGroup]
/// (source `MessageBubbleGroup` `spacing`).
enum BeuiMessageBubbleSpacing {
  /// Tight stack (source `compact` → `gap-1.5` = 6px).
  compact,

  /// Open stack (source `default` → `gap-3` = 12px).
  standard,
}

// ---------------------------------------------------------------------------
// Component-local motion (source message-bubble.tsx)
// ---------------------------------------------------------------------------

/// Sent-bubble surface pop (source `BUBBLE_POP`:
/// stiffness 520 · damping 27 · mass 0.52).
const _bubblePop = SpringMotion(
  SpringDescription(mass: 0.52, stiffness: 520, damping: 27),
);

/// Content opacity reveal after the surface starts popping
/// (source `BUBBLE_CONTENT_REVEAL`: 0.12s EASE_OUT, delay 0.04s).
const _contentReveal = CurvedMotion(Duration(milliseconds: 120), beuiEaseOut);
const Duration _contentRevealDelay = Duration(milliseconds: 40);

// ---------------------------------------------------------------------------
// Inherited bubble context
// ---------------------------------------------------------------------------

class _BubbleScope extends InheritedWidget {
  const _BubbleScope({
    required this.align,
    required this.animateIn,
    required this.variant,
    required this.notifyLayout,
    required super.child,
  });

  final BeuiMessageBubbleAlign align;
  final bool animateIn;
  final BeuiMessageBubbleVariant variant;
  final VoidCallback notifyLayout;

  static _BubbleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BubbleScope>();

  @override
  bool updateShouldNotify(_BubbleScope oldWidget) =>
      align != oldWidget.align ||
      animateIn != oldWidget.animateIn ||
      variant != oldWidget.variant;
}

// ---------------------------------------------------------------------------
// BeuiMessageBubble
// ---------------------------------------------------------------------------

/// A conversational surface with visual tones, independent alignment, grouped
/// messages, expandable content, and interactive link/button support — the
/// Flutter port of beUI's `MessageBubble`.
///
/// Compose with [BeuiMessageBubbleContent] (and optionally
/// [BeuiMessageBubbleCollapsible] / [BeuiMessageBubbleGroup]) as children.
///
/// **Motion.** When [animateIn] is true the content surface plays a mount-only
/// pop (scale 0.92→1 on `_bubblePop`, opacity 0→1) and the text fades in on a
/// short delayed ease-out. Reduced motion drops the scale and keeps the fade.
/// Exit motion is owned by the parent list/scroller (matching the source's
/// `exit` prop on the outer shell).
///
/// **API mapping** (source → Flutter):
/// * `variant` / `align` / `animateIn` → same
/// * `MessageBubbleContent` → [BeuiMessageBubbleContent]
/// * `MessageBubbleGroup` → [BeuiMessageBubbleGroup]
/// * `MessageBubbleCollapsible` → [BeuiMessageBubbleCollapsible]
/// * `render={<button/>|<a/>}` interactive → [BeuiMessageBubbleContent.onTap]
/// * ambient `MessageSideContext` → [BeuiMessageSideScope] from [BeuiMessage]
class BeuiMessageBubble extends StatefulWidget {
  /// Creates a message bubble shell.
  const BeuiMessageBubble({
    required this.child,
    this.variant = BeuiMessageBubbleVariant.soft,
    this.align,
    this.animateIn = false,
    super.key,
  });

  /// Bubble body — typically a [BeuiMessageBubbleContent].
  final Widget child;

  /// Visual tone (source `variant`, default `soft`).
  final BeuiMessageBubbleVariant variant;

  /// Alignment. Defaults to the surrounding [BeuiMessageSideScope], then
  /// [BeuiMessageBubbleSide.start].
  final BeuiMessageBubbleAlign? align;

  /// Plays the surface pop once when this bubble mounts (source `animateIn`,
  /// default `false`).
  final bool animateIn;

  @override
  State<BeuiMessageBubble> createState() => _BeuiMessageBubbleState();
}

class _BeuiMessageBubbleState extends State<BeuiMessageBubble> {
  /// Called when collapsible content resizes (source `layoutDependency` on the
  /// surface). Triggers a rebuild so the surface re-lays-out without remounting
  /// children.
  void _notifyLayout() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final resolved =
        widget.align ??
        BeuiMessageSideScope.maybeOf(context) ??
        BeuiMessageBubbleSide.start;

    return _BubbleScope(
      align: resolved,
      animateIn: widget.animateIn,
      variant: widget.variant,
      notifyLayout: _notifyLayout,
      child: Align(
        alignment: resolved == BeuiMessageBubbleSide.end
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: resolved == BeuiMessageBubbleSide.end
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [widget.child],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageBubbleContent
// ---------------------------------------------------------------------------

/// Styled bubble body with the animated surface layer
/// (source `MessageBubbleContent`).
///
/// Renders a rounded surface behind [child] (except
/// [BeuiMessageBubbleVariant.ghost]), with optional [onTap] for interactive
/// button/link bubbles.
class BeuiMessageBubbleContent extends StatefulWidget {
  /// Creates bubble content.
  const BeuiMessageBubbleContent({
    required this.child,
    this.onTap,
    this.maxWidthFactor,
    super.key,
  });

  /// Bubble body content (text, markdown, nested widgets).
  final Widget child;

  /// When non-null the bubble is interactive (cursor, press scale, focus ring)
  /// — the port of the source `render={<button/>|<a/>}` path.
  final VoidCallback? onTap;

  /// Max width as a fraction of the parent (source `max-w-[82%]`).
  /// Ignored for [BeuiMessageBubbleVariant.ghost] (full width).
  /// Null uses [BeuiAgentLayout.maxBubbleWidthFactor].
  final double? maxWidthFactor;

  @override
  State<BeuiMessageBubbleContent> createState() =>
      _BeuiMessageBubbleContentState();
}

class _BeuiMessageBubbleContentState extends State<BeuiMessageBubbleContent> {
  double _progress = 1.0;
  bool _seeded = false;
  bool _scheduled = false;
  bool _pressed = false;
  bool _focused = false;
  bool _animateIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _animateIn = _BubbleScope.maybeOf(context)?.animateIn ?? false;
    _progress = _animateIn ? 0.0 : 1.0;
    if (_animateIn) _scheduleEnter();
  }

  void _scheduleEnter() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _progress = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final agent = BeuiAgentTheme.of(context);
    final scope = _BubbleScope.maybeOf(context);
    final variant = scope?.variant ?? BeuiMessageBubbleVariant.soft;
    final align = scope?.align ?? BeuiMessageBubbleSide.start;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final interactive = widget.onTap != null;
    final ghost = variant == BeuiMessageBubbleVariant.ghost;
    final user = align == BeuiMessageBubbleSide.end;
    final radius = agent.bubbleRadius(user: user);
    final widthFactor =
        widget.maxWidthFactor ?? agent.layout.maxBubbleWidthFactor;

    final textColor = switch (variant) {
      BeuiMessageBubbleVariant.solid => colors.background,
      BeuiMessageBubbleVariant.danger => colors.destructive,
      _ => colors.foreground,
    };

    final surfaceColor = switch (variant) {
      BeuiMessageBubbleVariant.solid => colors.foreground,
      BeuiMessageBubbleVariant.soft => colors.muted,
      BeuiMessageBubbleVariant.tint => colors.primary.withValues(alpha: 0.1),
      BeuiMessageBubbleVariant.outline => colors.background,
      BeuiMessageBubbleVariant.danger => colors.destructive.withValues(
        alpha: 0.1,
      ),
      BeuiMessageBubbleVariant.ghost => Colors.transparent,
    };

    final border = variant == BeuiMessageBubbleVariant.outline
        ? Border.all(
            color: colors.border.withValues(alpha: colors.border.a * 0.7),
            width: agent.structure.borderWidth,
          )
        : null;

    final content = DefaultTextStyle.merge(
      style: agent.bodyStyle(user: user).copyWith(color: textColor),
      child: IconTheme.merge(
        data: IconThemeData(size: agent.layout.iconSize, color: textColor),
        child: widget.child,
      ),
    );

    final surfaceMotion = motionFor(
      context,
      _bubblePop,
      isMovement: true,
      reducedFallback: const NoMotion(),
    );
    final opacityMotion = motionFor(
      context,
      const CurvedMotion(Duration(milliseconds: 120), beuiEaseOut),
      isMovement: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = ghost
            ? constraints.maxWidth
            : (constraints.maxWidth.isFinite
                  ? constraints.maxWidth * widthFactor
                  : double.infinity);

        Widget shell = Stack(
          children: [
            if (!ghost)
              Positioned.fill(
                child: SingleMotionBuilder(
                  value: _progress,
                  from: _animateIn ? 0.0 : 1.0,
                  motion: reduce ? opacityMotion : surfaceMotion,
                  builder: (context, t, child) {
                    final tt = t.clamp(0.0, 1.0);
                    final scale = reduce || !_animateIn
                        ? 1.0
                        : 0.92 + 0.08 * tt;
                    return Opacity(
                      opacity: tt,
                      child: Transform.scale(
                        scale: scale,
                        alignment: align == BeuiMessageBubbleSide.end
                            ? Alignment.bottomRight
                            : Alignment.bottomLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            border: border,
                            borderRadius: radius, // rounded-2xl
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            _ContentReveal(
              progress: _progress,
              animateIn: _animateIn,
              reduce: reduce,
              child: Padding(
                padding: ghost ? EdgeInsets.zero : agent.layout.bubblePadding,
                child: content,
              ),
            ),
          ],
        );

        shell = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: ghost ? 0 : 36, // min-w-9
            maxWidth: maxW.isFinite ? maxW : double.infinity,
          ),
          child: shell,
        );

        if (!interactive) return shell;

        return FocusableActionDetector(
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.99 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: beuiEaseOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: _focused
                      ? Border.all(
                          color: colors.ring,
                          width: agent.structure.emphasisBorderWidth,
                        )
                      : null,
                ),
                child: shell,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Content opacity that starts its reveal after [_contentRevealDelay].
class _ContentReveal extends StatefulWidget {
  const _ContentReveal({
    required this.progress,
    required this.animateIn,
    required this.reduce,
    required this.child,
  });

  final double progress;
  final bool animateIn;
  final bool reduce;
  final Widget child;

  @override
  State<_ContentReveal> createState() => _ContentRevealState();
}

class _ContentRevealState extends State<_ContentReveal> {
  double _value = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animateIn) {
      _value = 1;
      _started = true;
    } else if (widget.progress >= 1.0) {
      _kick();
    }
  }

  @override
  void didUpdateWidget(covariant _ContentReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress >= 1.0 && !_started) _kick();
  }

  void _kick() {
    if (_started) return;
    _started = true;
    final delay = widget.reduce ? Duration.zero : _contentRevealDelay;
    Future<void>.delayed(delay, () {
      if (mounted) setState(() => _value = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animateIn) return widget.child;
    return SingleMotionBuilder(
      value: _value,
      from: 0,
      motion: _contentReveal,
      builder: (context, t, child) =>
          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageBubbleGroup
// ---------------------------------------------------------------------------

/// Vertical stack of bubbles inside one message (source `MessageBubbleGroup`).
class BeuiMessageBubbleGroup extends StatelessWidget {
  /// Creates a bubble group.
  const BeuiMessageBubbleGroup({
    required this.children,
    this.spacing = BeuiMessageBubbleSpacing.compact,
    super.key,
  });

  /// Bubble children.
  final List<Widget> children;

  /// Vertical gap between bubbles.
  final BeuiMessageBubbleSpacing spacing;

  @override
  Widget build(BuildContext context) {
    final layout = BeuiAgentTheme.of(context).layout;
    final gap = switch (spacing) {
      BeuiMessageBubbleSpacing.compact => layout.groupedMessageSpacing,
      BeuiMessageBubbleSpacing.standard => layout.groupedMessageSpacingRelaxed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageBubbleCollapsible
// ---------------------------------------------------------------------------

/// Expandable long content inside a bubble (source `MessageBubbleCollapsible`).
///
/// Controlled when [open] is non-null; otherwise seeds from [defaultOpen].
/// Collapsed state clamps to [collapsedLines] with a bottom fade mask.
class BeuiMessageBubbleCollapsible extends StatefulWidget {
  /// Creates a collapsible bubble section.
  const BeuiMessageBubbleCollapsible({
    required this.child,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.collapsedLines = 4,
    this.moreLabel,
    this.lessLabel,
    super.key,
  }) : assert(
         collapsedLines >= 2 && collapsedLines <= 6,
         'collapsedLines must be 2–6 (source union)',
       );

  /// The (potentially long) content.
  final Widget child;

  /// Controlled open state. Null → uncontrolled.
  final bool? open;

  /// Initial open state when uncontrolled (source `defaultOpen`).
  final bool defaultOpen;

  /// Called whenever open is toggled.
  final ValueChanged<bool>? onOpenChange;

  /// Lines shown when collapsed (source `collapsedLines`, 2–6, default 4).
  final int collapsedLines;

  /// "Show more" label. Defaults to a `Show more` text.
  final Widget? moreLabel;

  /// "Show less" label. Defaults to a `Show less` text.
  final Widget? lessLabel;

  @override
  State<BeuiMessageBubbleCollapsible> createState() =>
      _BeuiMessageBubbleCollapsibleState();
}

class _BeuiMessageBubbleCollapsibleState
    extends State<BeuiMessageBubbleCollapsible> {
  late bool _internalOpen = widget.defaultOpen;

  bool get _isControlled => widget.open != null;
  bool get _open => widget.open ?? _internalOpen;

  void _setOpen(bool next) {
    // Notify parent bubble to re-layout surface (source notifyLayout).
    _BubbleScope.maybeOf(context)?.notifyLayout();
    if (!_isControlled) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final chevronMotion = motionFor(context, beuiSpringSwap, isMovement: true);

    final more = widget.moreLabel ?? const Text('Show more');
    final less = widget.lessLabel ?? const Text('Show less');
    final body = agent.typography.assistantBody;
    final lineH = (body.height ?? 24 / 14) * (body.fontSize ?? 14);
    final collapsedH = widget.collapsedLines * lineH;

    Widget content = widget.child;
    if (!_open) {
      content = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          // source: linear-gradient(to bottom, #000 68%, transparent 100%)
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.68, 1.0],
          ).createShader(bounds);
        },
        child: SizedBox(
          height: collapsedH,
          width: double.infinity,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: double.infinity,
              child: widget.child,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(height: 8), // mt-2
        _CollapsibleTrigger(
          open: _open,
          more: more,
          less: less,
          colors: colors,
          reduce: reduce,
          chevronMotion: chevronMotion,
          onPressed: () => _setOpen(!_open),
        ),
      ],
    );
  }
}

class _CollapsibleTrigger extends StatelessWidget {
  const _CollapsibleTrigger({
    required this.open,
    required this.more,
    required this.less,
    required this.colors,
    required this.reduce,
    required this.chevronMotion,
    required this.onPressed,
  });

  final bool open;
  final Widget more;
  final Widget less;
  final BeuiColors colors;
  final bool reduce;
  final Motion chevronMotion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: agent.shapes.pill,
        hoverColor: colors.muted,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            height: 28, // h-7
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: agent.typography.action.copyWith(
                    color: colors.mutedForeground,
                  ),
                  child: open ? less : more,
                ),
                const SizedBox(width: 4), // gap-1
                SingleMotionBuilder(
                  value: open ? 1.0 : 0.0,
                  motion: reduce ? const NoMotion() : chevronMotion,
                  builder: (context, t, child) {
                    return Transform.rotate(
                      angle: t * math.pi, // 0 → 180°
                      child: child,
                    );
                  },
                  child: Icon(
                    agent.icons.expand,
                    size: 14, // size-3.5
                    color: colors.mutedForeground,
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
