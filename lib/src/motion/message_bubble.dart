import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
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
    this.animateIn = true,
    super.key,
  });

  /// Bubble body — typically a [BeuiMessageBubbleContent].
  final Widget child;

  /// Visual tone (source `variant`, default `soft`).
  final BeuiMessageBubbleVariant variant;

  /// Alignment. Defaults to the surrounding [BeuiMessageSideScope], then
  /// [BeuiMessageBubbleSide.start].
  final BeuiMessageBubbleAlign? align;

  /// Plays the surface pop once when this bubble mounts.
  ///
  /// Defaults to **true**. The source defaults it off, and the audit
  /// found the consequence: nothing in the library animated out of the box and
  /// the flagship preview opted assistant rows out entirely, so the port's
  /// best asset — its entrance motion — was invisible unless you knew to ask
  /// for it.
  ///
  /// "New" is derived from key identity, not from this flag: the entrance is
  /// seeded once at mount and never replays, so a bubble whose content streams
  /// pops exactly once. Give rows stable keys and this does the right thing.
  /// Reduced motion drops the scale and keeps the fade.
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
        // Bubbles align to the *logical* end/start, so the bubble and the
        // column it lives in can no longer disagree about sides in RTL.
        alignment: resolved == BeuiMessageBubbleSide.end
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
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
    this.semanticLabel,
    super.key,
  });

  /// Bubble body content (text, markdown, nested widgets).
  final Widget child;

  /// When non-null the bubble is interactive (cursor, press scale, focus ring)
  /// — the port of the source `render={<button/>|<a/>}` path.
  final VoidCallback? onTap;

  /// Max width as a fraction of the parent (source `max-w-[82%]`).
  /// Ignored for [BeuiMessageBubbleVariant.ghost] (full width).
  /// Null uses the theme's `layout.maxBubbleWidthFactor`.
  ///
  /// The resolved width is clamped to never fall below the bubble's own
  /// minimum, so a narrow shell can no longer produce impossible constraints
  ///.
  final double? maxWidthFactor;

  /// Accessible name for an interactive bubble.
  ///
  /// Only meaningful when [onTap] is set — the bubble then reports itself as a
  /// button, and this is what a screen reader announces. Defaults to the
  /// bubble's own text content, which is usually what you want; pass something
  /// shorter when the body is long.
  final String? semanticLabel;

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
    final wants = _BubbleScope.maybeOf(context)?.animateIn ?? false;

    if (!_seeded) {
      _seeded = true;
      _animateIn = wants;
      _progress = _animateIn ? 0.0 : 1.0;
      if (_animateIn) _scheduleEnter();
      return;
    }

    // The seed used to be strictly one-shot, so a later prop change was
    // silently ignored. Turning the entrance *off* mid-flight now settles the
    // bubble immediately — a caller disabling animation should not leave a
    // half-scaled surface on screen. Turning it *on* after mount is
    // deliberately ignored: the entrance is mount-only by contract, and
    // retro-animating an already-visible bubble would replay it on every
    // streamed token.
    if (!wants && _animateIn) {
      _animateIn = false;
      if (_progress < 1.0) _progress = 1.0;
    }
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
    final colors = BeuiColors.resolve(context);
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

    // `danger` was `colors.destructive` on a 10% wash — 3.43:1, and colour
    // was its *only* signal. It now uses the themeable destructive status tier
    // (a 700/300 foreground) and gains a leading `triangle_alert`, so the state
    // survives both a contrast check and a colourblind reader.
    final danger = variant == BeuiMessageBubbleVariant.danger;
    final dangerPalette = agent
        .statusColorsFor(Theme.of(context).brightness)
        .destructive;

    final textColor = switch (variant) {
      BeuiMessageBubbleVariant.solid => colors.background,
      BeuiMessageBubbleVariant.danger => dangerPalette.foreground,
      _ => colors.foreground,
    };

    final surfaceColor = switch (variant) {
      BeuiMessageBubbleVariant.solid => colors.foreground,
      BeuiMessageBubbleVariant.soft => colors.muted,
      BeuiMessageBubbleVariant.tint => colors.primary.withValues(alpha: 0.1),
      // `outline` was `background` behind a border multiplied down to
      // ~1.1:1 — an invisible bubble on an invisible edge. A `card` fill gives
      // it a surface you can actually see even where the hairline cannot carry
      // the shape alone.
      BeuiMessageBubbleVariant.outline => colors.card,
      BeuiMessageBubbleVariant.danger => dangerPalette.background,
      BeuiMessageBubbleVariant.ghost => Colors.transparent,
    };

    final border = switch (variant) {
      // Full-strength `borderStrong`, not `border × 0.7`.
      BeuiMessageBubbleVariant.outline => Border.all(
        color: colors.borderStrong,
        width: agent.structure.borderWidth,
      ),
      BeuiMessageBubbleVariant.danger => Border.all(
        color: dangerPalette.border,
        width: agent.structure.borderWidth,
      ),
      _ => null,
    };

    Widget inner = widget.child;
    if (danger) {
      // Redundant encoding: shape as well as colour.
      inner = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
            child: Icon(
              LucideIcons.triangle_alert,
              size: 14,
              color: dangerPalette.foreground,
            ),
          ),
          Flexible(child: widget.child),
        ],
      );
    }

    final content = DefaultTextStyle.merge(
      style: agent.bodyStyle(user: user).copyWith(color: textColor),
      child: IconTheme.merge(
        data: IconThemeData(size: agent.layout.iconSize, color: textColor),
        child: inner,
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

    // `min-w-9` against `0.82 × available` asserts in debug the moment the
    // shell gets narrower than ~44px — reachable through a `BeuiChatApp` whose
    // 272px sidebar left the body 28px on a 300px window. Clamp rather than
    // crash: a bubble narrower than its own minimum is simply the minimum.
    const minW = 36.0; // min-w-9

    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = ghost
            ? constraints.maxWidth
            : (constraints.maxWidth.isFinite
                  ? constraints.maxWidth * widthFactor
                  : double.infinity);
        if (!ghost && maxW.isFinite && maxW < minW) maxW = minW;

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
                        // The pop grows out of the bubble's own corner,
                        // which is the trailing corner in LTR and the leading
                        // one in RTL.
                        alignment: align == BeuiMessageBubbleSide.end
                            ? AlignmentDirectional.bottomEnd
                            : AlignmentDirectional.bottomStart,
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
            minWidth: ghost ? 0 : minW,
            maxWidth: maxW.isFinite ? maxW : double.infinity,
          ),
          child: shell,
        );

        if (!interactive) return shell;

        // An interactive bubble is a button and must say so. Before this
        // it carried a tap handler, no role, and no name — its own rail tick
        // twenty files away had the complete contract.
        return Semantics(
          button: true,
          label: widget.semanticLabel,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) => setState(() => _focused = v),
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
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
                // 0.99 is imperceptible. 0.97 is the library's press
                // scale.
                scale: _pressed && !reduce ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: beuiEaseOut,
                // The ring used to be a `Border` inside a `BoxDecoration`,
                // so focusing both inset the child by 2px — the "indicator"
                // was a layout jitter — and painted in `colors.ring`, a 12%
                // hairline token that composites to 1.29:1 against 3:1
                // required. This paints outside layout in the dedicated
                // `focusRing` role.
                child: BeuiFocusRing(
                  focused: _focused,
                  borderRadius: radius,
                  width: agent.structure.emphasisBorderWidth,
                  child: shell,
                ),
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

  /// This was a bare `Future.delayed` with only a `mounted` guard, so a
  /// bubble disposed inside the 40ms window left a pending callback holding
  /// the State alive. A cancellable timer, cancelled in `dispose`.
  Timer? _delay;

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
    // The entrance was switched off mid-flight — settle rather than hold a
    // half-faded body.
    if (!widget.animateIn && oldWidget.animateIn) {
      _delay?.cancel();
      _delay = null;
      _started = true;
      if (_value != 1) _value = 1;
      return;
    }
    if (widget.progress >= 1.0 && !_started) _kick();
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _kick() {
    if (_started) return;
    _started = true;
    final delay = widget.reduce ? Duration.zero : _contentRevealDelay;
    _delay?.cancel();
    _delay = Timer(delay, () {
      _delay = null;
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
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final chevronMotion = motionFor(context, beuiSpringSwap, isMovement: true);

    final more = widget.moreLabel ?? const Text('Show more');
    final less = widget.lessLabel ?? const Text('Show less');

    // The collapsed height was always measured with the *assistant* body
    // style, so a user-side bubble whose type ramp differs clipped at the
    // wrong line. Read the side the bubble actually renders on.
    final user =
        _BubbleScope.maybeOf(context)?.align == BeuiMessageBubbleSide.end;
    final body = agent.bodyStyle(user: user);
    final lineH = (body.height ?? 24 / 14) * (body.fontSize ?? 14);
    final collapsedH = widget.collapsedLines * lineH;

    // Expanding used to snap: the chevron sprang while the content
    // popped to full height in one frame. Height now rides the same
    // 220ms/140ms disclosure curve as the rest of the library, and the fade
    // mask dissolves with it rather than switching off.
    final target = _open ? 1.0 : 0.0;
    // Reduced motion drops *movement*, not the transition: the height snaps
    // but a short opacity ramp survives, matching `_disclosure.dart`. Crucially
    // this must be a motion that actually ARRIVES — `const NoMotion()` here
    // holds its seeded value forever (see
    // `test/motion/_no_motion_semantics_test.dart`), which froze the reveal at
    // 0 and left "Show more" swapping its label while the body stayed clipped.
    final motion = reduce
        ? motionFor(
            context,
            const CurvedMotion(Duration(milliseconds: 120), beuiEaseOut),
            isMovement: false,
          )
        : motionFor(
            context,
            _open
                ? const CurvedMotion(Duration(milliseconds: 220), beuiEaseOut)
                : const CurvedMotion(Duration(milliseconds: 140), beuiEaseOut),
            isMovement: true,
          );

    final content = SingleMotionBuilder(
      value: target,
      motion: motion,
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        // The channel split, exactly as `_disclosure.dart` does it: the height
        // is movement and snaps under reduced motion, the mask fade rides the
        // 120ms curve. The `v > 0.01` term holds the height open while a
        // fade-out runs — snap it to 0 on the first frame instead and the fade
        // is invisible, because a zero-height box cannot be seen fading.
        final h = reduce ? ((_open || v > 0.01) ? 1.0 : 0.0) : v;
        return _CollapseBox(
          collapsedHeight: collapsedH,
          t: h,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              // source: linear-gradient(to bottom, #000 68%, transparent 100%)
              // The stop travels to 1.0 and the tail turns opaque as the panel
              // opens, so the mask cross-fades out instead of vanishing.
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Color.lerp(Colors.transparent, Colors.black, v)!,
                ],
                stops: [0.0, lerpDouble(0.68, 1.0, v)!, 1.0],
              ).createShader(bounds);
            },
            child: child,
          ),
        );
      },
      child: SizedBox(width: double.infinity, child: widget.child),
    );

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

/// Animates between a clamped height and the child's natural height.
///
/// Lays the child out unconstrained vertically, then sizes itself to
/// `lerp(collapsedHeight, naturalHeight, t)` and clips. No offstage measuring
/// pass and no second instantiation of the child — the layout it already
/// performs is the measurement.
class _CollapseBox extends SingleChildRenderObjectWidget {
  const _CollapseBox({
    required this.collapsedHeight,
    required this.t,
    required Widget super.child,
  });

  /// Height shown at `t == 0`. Ignored when the child is shorter than it.
  final double collapsedHeight;

  /// 0 = collapsed, 1 = fully expanded.
  final double t;

  @override
  _RenderCollapseBox createRenderObject(BuildContext context) =>
      _RenderCollapseBox(collapsedHeight: collapsedHeight, t: t);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCollapseBox renderObject,
  ) {
    renderObject
      ..collapsedHeight = collapsedHeight
      ..t = t;
  }
}

class _RenderCollapseBox extends RenderProxyBox {
  _RenderCollapseBox({required double collapsedHeight, required double t})
    : this._(collapsedHeight, t);

  _RenderCollapseBox._(this._collapsedHeight, this._t);

  double _collapsedHeight;
  double get collapsedHeight => _collapsedHeight;
  set collapsedHeight(double value) {
    if (_collapsedHeight == value) return;
    _collapsedHeight = value;
    markNeedsLayout();
  }

  double _t;
  double get t => _t;
  set t(double value) {
    if (_t == value) return;
    _t = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
      parentUsesSize: true,
    );
    final natural = child.size.height;
    final collapsed = math.min(_collapsedHeight, natural);
    size = constraints.constrain(
      Size(child.size.width, lerpDouble(collapsed, natural, _t)!),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (child.size.height <= size.height + 0.01) {
      context.paintChild(child, offset);
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => context.paintChild(child, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Clipped-away content is not tappable.
    if (!(Offset.zero & size).contains(position)) return false;
    return super.hitTestChildren(result, position: position);
  }
}

class _CollapsibleTrigger extends StatefulWidget {
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
  State<_CollapsibleTrigger> createState() => _CollapsibleTriggerState();
}

class _CollapsibleTriggerState extends State<_CollapsibleTrigger> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final colors = widget.colors;

    // The trigger reported `button` (via InkWell) but never `expanded`,
    // so a screen-reader user could not tell whether the body was open — the
    // one fact this control exists to change.
    // Outermost, so the 44px slop is actually reachable — an ancestor
    // RenderBox rejects a pointer outside its own box before any child's
    // hitTest runs.
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        expanded: widget.open,
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
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: BeuiFocusRing(
              focused: _focused,
              borderRadius: agent.shapes.pill,
              child: SingleMotionBuilder(
                value: (_pressed && !widget.reduce) ? 0.97 : 1.0, // C31
                motion: motionFor(context, beuiSpringPress, isMovement: true),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: beuiEaseOut,
                  decoration: BoxDecoration(
                    color: _hovered ? colors.muted : Colors.transparent,
                    borderRadius: agent.shapes.pill,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: SizedBox(
                    height: 28, // h-7
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle.merge(
                          style: agent.typography.action.copyWith(
                            color: colors.mutedForeground,
                          ),
                          child: widget.open ? widget.less : widget.more,
                        ),
                        const SizedBox(width: 4), // gap-1
                        SingleMotionBuilder(
                          value: widget.open ? 1.0 : 0.0,
                          motion: widget.reduce
                              ? const NoMotion()
                              : widget.chevronMotion,
                          builder: (context, t, child) {
                            // NoMotion holds its seeded value, so the frozen
                            // `t` pinned the chevron at its mount angle. Read
                            // the target directly under reduce — the same
                            // snap branch every other chevron in the family
                            // uses.
                            final a = widget.reduce
                                ? (widget.open ? 1.0 : 0.0)
                                : t;
                            return Transform.rotate(
                              angle: a * math.pi, // 0 → 180°
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
            ),
          ),
        ),
      ),
    );
  }
}
