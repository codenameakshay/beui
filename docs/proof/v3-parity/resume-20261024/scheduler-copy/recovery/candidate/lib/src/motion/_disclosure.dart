/// The shared agent disclosure — one reveal for every collapsible agent
/// surface, replacing eight near-identical private copies.
///
/// Package-internal. Not exported from `lib/beui.dart`; components import it
/// directly. The public disclosure API stays each component's own `open` /
/// `defaultOpen` parameter.
///
/// The Flutter port of the source's `AgentDisclosure`: a clipped height reveal
/// carrying opacity and a 4px settle, 220ms open / 140ms close on `EASE_OUT`
/// (exit faster than entrance, per the repo motion rules).
library;

import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// Disclosure open, 220ms `EASE_OUT` (source `AgentDisclosure`).
const beuiDisclosureOpenMotion = CurvedMotion(
  Duration(milliseconds: 220),
  beuiEaseOut,
);

/// Disclosure close, 140ms `EASE_OUT` — deliberately faster than the entrance.
const beuiDisclosureCloseMotion = CurvedMotion(
  Duration(milliseconds: 140),
  beuiEaseOut,
);

/// The reduced-motion cross-fade. Movement is dropped, but the opacity channel
/// is kept and shortened — see [BeuiAgentDisclosureInternal].
const beuiDisclosureReducedMotion = CurvedMotion(
  Duration(milliseconds: 120),
  beuiEaseOut,
);

/// The vertical settle, in logical pixels: the panel starts 4px high and
/// arrives at 0 (source `y: open ? 0 : -4`).
const double _settleY = 4;

/// Transform-only reveal for collapsible agent content.
///
/// Drive it with [open]; it animates `heightFactor`, opacity, and a -4→0
/// translate, and unmounts the subtree from hit testing and semantics once the
/// exit finishes. It is fully interruptible — a close mid-open reverses from
/// wherever the animation is, because the gate is derived from the animated
/// value rather than from [open].
///
/// ## Reduced motion keeps the fade
///
/// A hard cut to a static `Offstage` + `heightFactor: open ? 1 : 0` under
/// reduced motion would blink the panel in and out with no transition at all,
/// violating the project rule (drop *movement*, keep opacity/color — see
/// [motionFor]).
///
/// Here the reduce branch keeps a ~120ms opacity cross-fade and snaps only the
/// height and the translate. The channel split is expressed the way
/// `lib/src/tokens/motion.dart` intends: the movement channel goes through
/// `motionFor(..., isMovement: true)` and collapses to `NoMotion`, while the
/// opacity channel goes through `motionFor(..., isMovement: false)` and
/// survives untouched.
///
/// ## [openHeight]
///
/// Leave it null for the ordinary case — the panel measures itself and the
/// reveal rides `Align.heightFactor`.
///
/// Pass a height when the child must *not* reflow during the reveal (the
/// streaming viewport in `agent_activity.dart` is the one such caller: its
/// content scrolls, so re-laying it out at a fraction of its height each frame
/// would reflow the text). The child is then laid out at the full [openHeight]
/// inside an [OverflowBox] and clipped to the animated fraction.
class BeuiAgentDisclosureInternal extends StatelessWidget {
  /// Creates a disclosure. [reduce], when given, is threaded in by the parent
  /// rather than read from the media query here, matching most call sites in
  /// the library (parents already resolve it once per build for their other
  /// channels). Left null, it falls back to the ambient media query.
  const BeuiAgentDisclosureInternal({
    required this.open,
    this.reduce,
    required this.child,
    this.openHeight,
    this.openMotion = beuiDisclosureOpenMotion,
    this.closeMotion = beuiDisclosureCloseMotion,
    this.reducedMotion = beuiDisclosureReducedMotion,
    super.key,
  });

  /// Whether the panel is revealed.
  final bool open;

  /// Whether the platform asked for reduced motion. Movement snaps; the
  /// opacity cross-fade is kept. Null resolves against the ambient
  /// [MediaQuery.disableAnimationsOf].
  final bool? reduce;

  /// The revealed content.
  final Widget child;

  /// Fixed content height, for children that must not reflow mid-reveal. Null
  /// (the default) measures the child and reveals via `Align.heightFactor`.
  final double? openHeight;

  /// Entrance motion. Defaults to [beuiDisclosureOpenMotion].
  final Motion openMotion;

  /// Exit motion. Defaults to [beuiDisclosureCloseMotion].
  final Motion closeMotion;

  /// Reduced-motion cross-fade. Defaults to [beuiDisclosureReducedMotion].
  final Motion reducedMotion;

  @override
  Widget build(BuildContext context) {
    final target = open ? 1.0 : 0.0;
    final base = open ? openMotion : closeMotion;

    // The channel split, routed through the one resolver (never a bare
    // MediaQuery check here — see `lib/src/tokens/motion.dart`). The movement
    // token collapses to NoMotion exactly when the platform asked for reduced
    // motion, which is also how we detect that case; `reduce` lets a caller
    // (or a test) force it independently.
    final movement = motionFor(context, base, isMovement: true);
    final effectiveReduce = reduce ?? MediaQuery.disableAnimationsOf(context);
    final reduced = effectiveReduce || movement is NoMotion;

    if (reduced) {
      // Movement snaps, the fade survives — shortened to ~120ms. The eight
      // copies this replaces cut here with no transition at all.
      return SingleMotionBuilder(
        value: target,
        motion: motionFor(context, reducedMotion, isMovement: false),
        builder: (context, t, child) {
          final fadeT = t.clamp(0.0, 1.0);
          // Hold the height open while the fade-out runs, then drop it. Snap
          // the height to 0 on the first frame of a close instead and the
          // fade is invisible — a zero-height box cannot be seen fading, so
          // "keep opacity" would collapse right back into the hard cut this
          // branch exists to fix. The height change is still instantaneous;
          // it just happens at the end rather than the start.
          final revealed = open || fadeT > 0.01;
          return _frame(
            fade: fadeT,
            reveal: revealed ? 1.0 : 0.0,
            shift: 0,
            child: child!,
          );
        },
        child: child,
      );
    }

    // One builder drives all three channels off a single curve, so height,
    // opacity, and the settle can never drift apart.
    return SingleMotionBuilder(
      value: target,
      motion: movement,
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        return _frame(
          fade: v,
          reveal: v,
          shift: -_settleY * (1 - v),
          child: child!,
        );
      },
      child: child,
    );
  }

  /// One frame of the reveal. [reveal] drives height, [fade] drives opacity,
  /// [shift] is the vertical settle — separated so the reduce branch can hold
  /// [reveal] at its endpoint while [fade] still animates.
  Widget _frame({
    required double fade,
    required double reveal,
    required double shift,
    required Widget child,
  }) {
    // Gate on both channels: the panel stays mounted for the whole exit (the
    // fade outlives the height snap under reduced motion) and drops out only
    // once nothing is left to see. Hit testing and semantics follow the same
    // gate, so a collapsed panel is neither tappable nor announced — the port
    // of the source's `inert` + `aria-hidden`.
    final closed = reveal < 0.01 && fade < 0.01;

    Widget content = child;
    if (shift != 0) {
      content = Transform.translate(offset: Offset(0, shift), child: content);
    }
    if (fade < 1) {
      content = Opacity(opacity: fade, child: content);
    }

    final Widget revealed;
    if (openHeight == null) {
      revealed = ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: reveal,
          child: content,
        ),
      );
    } else {
      final height = openHeight! * reveal;
      revealed = SizedBox(
        height: height < 0 ? 0 : height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: openHeight! > 0 ? openHeight : null,
            maxHeight: openHeight! > 0 ? openHeight : null,
            child: content,
          ),
        ),
      );
    }

    return Offstage(
      offstage: closed,
      child: IgnorePointer(
        ignoring: closed,
        child: ExcludeSemantics(excluding: closed, child: revealed),
      ),
    );
  }
}
