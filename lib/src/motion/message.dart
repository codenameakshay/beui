import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Who authored a [BeuiMessage] row (source `MessageFrom`).
enum BeuiMessageFrom {
  /// Human-authored message — aligns to the trailing (end) edge.
  user,

  /// Assistant / agent message — aligns to the leading (start) edge.
  assistant,
}

/// Vertical spacing between items in a [BeuiMessageGroup]
/// (source `MessageGroup` `spacing`).
enum BeuiMessageSpacing {
  /// Tight stack (source `compact` → `gap-1.5` = 6px).
  compact,

  /// Open stack (source `default` → `gap-4` = 16px).
  standard,
}

/// Alignment side shared with message-bubble (source `MessageSide`).
///
/// Declared here so [BeuiMessage] can publish a side without importing the
/// bubble file (avoids a circular dep). [BeuiMessageBubbleAlign] in
/// `message_bubble.dart` is a typedef alias of this enum.
enum BeuiMessageBubbleSide {
  /// Leading edge (assistant / LTR left).
  start,

  /// Trailing edge (user / LTR right).
  end,
}

// ---------------------------------------------------------------------------
// Component-local springs — mount-only trailing-edge pop-up
// (source `MESSAGE_POP_UP`: stiffness 480 · damping 32 · mass 0.62).
// ---------------------------------------------------------------------------

/// Message row entrance spring (source `MESSAGE_POP_UP`).
const _messagePopUp = SpringMotion(
  SpringDescription(mass: 0.62, stiffness: 480, damping: 32),
);

/// Typing-dot ease period (source `duration: 1.05` + `EASE_OUT`).
const Duration _typingPeriod = Duration(milliseconds: 1050);

/// Typing-dot stagger between dots (source `delay: index * 0.14`).
const Duration _typingStagger = Duration(milliseconds: 140);

// ---------------------------------------------------------------------------
// Inherited contexts (source MessageContext + MessageSideContext)
// ---------------------------------------------------------------------------

/// Ambient message side — `"start"` / `"end"` — consumed by
/// [BeuiMessageBubble] when its own align is omitted.
///
/// Set by [BeuiMessage] from [BeuiMessageFrom]. Exposed as a public
/// [InheritedWidget] so custom layouts can also seed bubble alignment without
/// wrapping a full message row.
class BeuiMessageSideScope extends InheritedWidget {
  /// Creates a side scope. Prefer wrapping with [BeuiMessage] in normal use.
  const BeuiMessageSideScope({
    required this.side,
    required super.child,
    super.key,
  });

  /// Alignment side for descendant bubbles (`start` or `end`).
  final BeuiMessageBubbleSide side;

  /// The nearest ambient side, or null if none is in the tree.
  static BeuiMessageBubbleSide? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeuiMessageSideScope>()?.side;

  @override
  bool updateShouldNotify(BeuiMessageSideScope oldWidget) =>
      side != oldWidget.side;
}

/// Ambient author of the surrounding [BeuiMessage] row.
class BeuiMessageScope extends InheritedWidget {
  /// Creates a message scope. Prefer wrapping with [BeuiMessage].
  const BeuiMessageScope({required this.from, required super.child, super.key});

  /// Who authored this message row.
  final BeuiMessageFrom from;

  /// The nearest ambient author, or null if none is in the tree.
  static BeuiMessageFrom? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeuiMessageScope>()?.from;

  /// The nearest ambient author; throws if missing.
  static BeuiMessageFrom of(BuildContext context) {
    final from = maybeOf(context);
    assert(from != null, 'BeuiMessageScope.of() called outside BeuiMessage');
    return from!;
  }

  @override
  bool updateShouldNotify(BeuiMessageScope oldWidget) => from != oldWidget.from;
}

// ---------------------------------------------------------------------------
// BeuiMessage — row
// ---------------------------------------------------------------------------

/// A single conversation row — the Flutter port of beUI's `Message`.
///
/// Layout: a full-width flex row that reverses for [BeuiMessageFrom.user]
/// (`flex-row-reverse`) so avatars sit on the trailing edge. Children are
/// typically [BeuiMessageAvatar] + [BeuiMessageContent] (which itself holds
/// header / bubble / footer).
///
/// **Motion.** When [animateIn] is true the row plays a **mount-only**
/// trailing-edge pop-up: opacity 0→1, translateY 8→0, scale 0.95→1 on the
/// bespoke `_messagePopUp` spring, origin bottom-right for user rows and
/// bottom-left for assistant rows. Subsequent rebuilds (streaming content
/// updates) do **not** re-fire the entrance — only the first mount does,
/// matching the source. Reduced motion keeps the opacity fade and drops the
/// translate/scale.
///
/// **API mapping** (source → Flutter):
/// * `from` → [from]
/// * `animateIn` → [animateIn]
/// * children compound slots → [children] of [BeuiMessageAvatar],
///   [BeuiMessageContent], …
/// * `MessageSideContext` → [BeuiMessageSideScope] (inherited)
///
/// Bubbles ([BeuiMessageBubble]) inherit alignment from this row when their
/// own `align` is omitted.
class BeuiMessage extends StatefulWidget {
  /// Creates a message row.
  const BeuiMessage({
    required this.from,
    required this.children,
    this.animateIn = false,
    this.semanticLabel,
    super.key,
  });

  /// Who authored the row. Drives layout direction and ambient side.
  final BeuiMessageFrom from;

  /// Plays the trailing-edge pop-up once when this row mounts
  /// (source `animateIn`, default `false`).
  final bool animateIn;

  /// Row slots — typically [BeuiMessageAvatar] + [BeuiMessageContent], laid
  /// out with an 8px gap (source `gap-2`).
  final List<Widget> children;

  /// Accessible label. Defaults to `"user message"` / `"assistant message"`.
  final String? semanticLabel;

  @override
  State<BeuiMessage> createState() => _BeuiMessageState();
}

class _BeuiMessageState extends State<BeuiMessage> {
  /// 0 = entrance start, 1 = settled. Seeded to 0 when [BeuiMessage.animateIn]
  /// is true so the first frame paints the enter pose, then we flip to 1.
  late double _progress = widget.animateIn ? 0.0 : 1.0;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.animateIn) _scheduleEnter();
  }

  void _scheduleEnter() {
    if (_scheduled) return;
    _scheduled = true;
    // Post-frame so the first paint lands on the enter pose, then the spring
    // drives to settled — same "mount-only" contract as the source.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _progress = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final side = widget.from == BeuiMessageFrom.user
        ? BeuiMessageBubbleSide.end
        : BeuiMessageBubbleSide.start;
    final label =
        widget.semanticLabel ??
        (widget.from == BeuiMessageFrom.user
            ? 'user message'
            : 'assistant message');

    // Source: `flex w-full items-start gap-2` + `flex-row-reverse` for user.
    // Reverse the child list (not textDirection) so text stays LTR/ambient.
    final ordered = widget.from == BeuiMessageFrom.user
        ? widget.children.reversed.toList(growable: false)
        : widget.children;
    final slots = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0) slots.add(const SizedBox(width: 8)); // gap-2
      slots.add(ordered[i]);
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slots,
    );

    // Drive entrance with a single progress value; translate + scale share the
    // spring, opacity rides the same curve (kept under reduced motion).
    final motion = motionFor(
      context,
      _messagePopUp,
      isMovement: true,
      reducedFallback: const CurvedMotion(
        Duration(milliseconds: 120),
        beuiEaseOut,
      ),
    );
    final opacityMotion = motionFor(
      context,
      const CurvedMotion(Duration(milliseconds: 120), beuiEaseOut),
      isMovement: false,
    );

    final body = SingleMotionBuilder(
      value: _progress,
      from: widget.animateIn ? 0.0 : 1.0,
      motion: reduce ? opacityMotion : motion,
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        Widget out = child!;
        if (!reduce && widget.animateIn) {
          // translateY(8→0), scale(0.95→1)
          final dy = (1 - tt) * 8;
          final scale = 0.95 + 0.05 * tt;
          out = Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              alignment: widget.from == BeuiMessageFrom.user
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: out,
            ),
          );
        }
        return Opacity(opacity: tt, child: out);
      },
      child: row,
    );

    return Semantics(
      container: true,
      label: label,
      explicitChildNodes: true,
      child: BeuiMessageSideScope(
        side: side,
        child: BeuiMessageScope(from: widget.from, child: body),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageGroup
// ---------------------------------------------------------------------------

/// A vertical stack of [BeuiMessage] rows (source `MessageGroup`).
///
/// Pure layout — no motion of its own. Spacing maps the source
/// `compact` / `default` gap tokens.
class BeuiMessageGroup extends StatelessWidget {
  /// Creates a message group.
  const BeuiMessageGroup({
    required this.children,
    this.spacing = BeuiMessageSpacing.compact,
    super.key,
  });

  /// Message rows (and optional [BeuiMessageMarker]s).
  final List<Widget> children;

  /// Vertical gap between rows.
  final BeuiMessageSpacing spacing;

  double get _gap => switch (spacing) {
    BeuiMessageSpacing.compact => 6, // gap-1.5
    BeuiMessageSpacing.standard => 16, // gap-4
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: _gap),
          children[i],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageAvatar
// ---------------------------------------------------------------------------

/// Circular 28px avatar slot for a [BeuiMessage] row (source `MessageAvatar`).
///
/// Pass any [child] (icon, image, initials). When [placeholder] is true the
/// slot stays reserved but invisible so grouped rows remain aligned.
class BeuiMessageAvatar extends StatelessWidget {
  /// Creates a message avatar.
  const BeuiMessageAvatar({this.child, this.placeholder = false, super.key});

  /// Avatar content (icon, image, text). Ignored visually when [placeholder].
  final Widget? child;

  /// Keep an empty avatar slot so grouped messages remain aligned
  /// (source `placeholder`).
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final avatar = SizedBox(
      width: 28, // size-7
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.muted, shape: BoxShape.circle),
        child: ClipOval(
          child: Center(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12, // text-xs
                fontWeight: FontWeight.w500,
                color: colors.mutedForeground,
                height: 1,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 14,
                  color: colors.mutedForeground,
                ), // 3.5
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      excludeSemantics: placeholder,
      child: Visibility(
        visible: !placeholder,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: avatar,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageContent / Header / Footer
// ---------------------------------------------------------------------------

/// Main content column of a [BeuiMessage] (source `MessageContent`).
///
/// Aligns children to the end for user rows and the start for assistant rows
/// via the ambient [BeuiMessageScope].
class BeuiMessageContent extends StatelessWidget {
  /// Creates a message content column.
  const BeuiMessageContent({required this.children, super.key});

  /// Content slots — header, bubble(s), footer, etc.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final from = BeuiMessageScope.maybeOf(context) ?? BeuiMessageFrom.assistant;
    final align = from == BeuiMessageFrom.user
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Flexible(
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 6), // gap-1.5
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Metadata row above the bubble (source `MessageHeader`) — name, timestamp.
class BeuiMessageHeader extends StatelessWidget {
  /// Creates a message header.
  const BeuiMessageHeader({required this.children, super.key});

  /// Header chips (name, status, time…).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final from = BeuiMessageScope.maybeOf(context) ?? BeuiMessageFrom.assistant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4), // px-1
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 11, // text-[11px]
          height: 1,
          color: colors.mutedForeground,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: from == BeuiMessageFrom.user
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 6), // gap-1.5
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Metadata row below the bubble (source `MessageFooter`) — "Sent", actions.
class BeuiMessageFooter extends StatelessWidget {
  /// Creates a message footer.
  const BeuiMessageFooter({required this.children, super.key});

  /// Footer chips / actions.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final from = BeuiMessageScope.maybeOf(context) ?? BeuiMessageFrom.assistant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20), // min-h-5
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4), // px-1
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 11, // text-[11px]
            color: colors.mutedForeground,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: from == BeuiMessageFrom.user
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 4), // gap-1
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageMarker
// ---------------------------------------------------------------------------

/// Centered system/live marker chip between rows (source `MessageMarker`) —
/// "Today", "New messages", etc.
class BeuiMessageMarker extends StatelessWidget {
  /// Creates a message marker.
  const BeuiMessageMarker({required this.child, super.key});

  /// Marker content (usually a short [Text]).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400), // ~88% soft cap
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.muted.withValues(alpha: 0.7), // bg-muted/70
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10, // px-2.5
              vertical: 4, // py-1
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12, // text-xs
                color: colors.mutedForeground,
              ),
              textAlign: TextAlign.center,
              child: IconTheme.merge(
                data: IconThemeData(size: 14, color: colors.mutedForeground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageTyping
// ---------------------------------------------------------------------------

/// Three bouncing dots indicating an in-progress response
/// (source `MessageTyping`).
///
/// Reduced motion freezes the dots at a calm mid-opacity (source
/// `{ opacity: 0.45 }`) with no vertical movement.
class BeuiMessageTyping extends StatefulWidget {
  /// Creates a typing indicator.
  const BeuiMessageTyping({this.label = 'Responding', super.key});

  /// Screen-reader label (source `label`, default `"Responding"`).
  final String label;

  @override
  State<BeuiMessageTyping> createState() => _BeuiMessageTypingState();
}

class _BeuiMessageTypingState extends State<BeuiMessageTyping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _typingPeriod)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final color =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).extension<BeuiColors>()!.mutedForeground;

    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: SizedBox(
        height: 20, // h-5
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4), // gap-1
              _TypingDot(
                index: i,
                controller: _controller,
                color: color,
                reduce: reduce,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({
    required this.index,
    required this.controller,
    required this.color,
    required this.reduce,
  });

  final int index;
  final AnimationController controller;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    if (reduce) {
      return Container(
        width: 4, // size-1
        height: 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
      );
    }

    // Staggered opacity [0.28, 0.85, 0.28] + y [0, -2, 0] over 1.05s EASE_OUT.
    final delay =
        index * _typingStagger.inMilliseconds / _typingPeriod.inMilliseconds;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Local phase in [0, 1) after delay wrap.
        var t = (controller.value - delay) % 1.0;
        if (t < 0) t += 1.0;
        // Triangle wave peaking at mid-cycle, eased lightly via beuiEaseOut
        // envelope approximation: rise 0→0.5, fall 0.5→1.
        final tri = t < 0.5 ? t * 2 : (1 - t) * 2;
        final eased = beuiEaseOut.transform(tri.clamp(0.0, 1.0));
        final opacity = 0.28 + 0.57 * eased;
        final dy = -2.0 * eased;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
