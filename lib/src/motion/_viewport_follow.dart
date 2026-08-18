/// Live-edge following for streamed content viewports — the reader wins.
///
/// Package-internal. Not exported from `lib/beui.dart`.
///
/// The audit (`R7`, and `C5` in the conversation cluster) found every streaming
/// viewport in the library yanking itself to `maxScrollExtent` on *every*
/// content change, with no way for a reader who has scrolled up to stay where
/// they put themselves. Scrolling back to re-read the line the agent just
/// changed is the single most likely thing a reader does while a diff streams,
/// and the widget fought them for it.
///
/// [BeuiLiveEdgeFollower] adds the missing state: once the reader is more than
/// [beuiLiveEdgeSlack] away from the bottom they are *pinned*, and following
/// stops until they come back. [BeuiJumpToLatest] is the affordance that lets
/// them come back in one tap, in the library's own visual language.
///
/// Also here because it belongs with the follower: [BeuiHiddenContentFooter],
/// the "N more lines" + bottom-fade pair for capped viewports (`R12`). Those
/// viewports disable scrollbars for fidelity, so without a cue a 400-line file
/// reads as 14 lines that stop mid-statement.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_hit_target.dart';

/// How far from the live edge the reader may drift before following stops, in
/// logical pixels.
///
/// 24 is a little over one 20px code line: a stray trackpad nudge does not
/// unpin, but a deliberate scroll of one row does.
const double beuiLiveEdgeSlack = 24;

/// Follow duration, matching the 220ms the viewports already used.
const Duration beuiLiveEdgeFollowDuration = Duration(milliseconds: 220);

/// Owns a [ScrollController] and tracks whether the reader has scrolled away
/// from the live edge.
///
/// Create one per streaming viewport, [attach] it in `initState`, [dispose] it,
/// and call [follow] where the old code called `animateTo(maxScrollExtent)`.
///
/// ```dart
/// late final _follow = BeuiLiveEdgeFollower(onPinnedChanged: () {
///   if (mounted) setState(() {});
/// });
/// ```
///
/// The [pinned] flag is what the "jump to latest" affordance is bound to; it is
/// only ever set from a *user* scroll, because [follow]'s own animation is
/// bracketed by an internal guard.
class BeuiLiveEdgeFollower {
  /// Creates a follower. [onPinnedChanged] fires whenever [pinned] flips, and
  /// is normally a `setState`.
  BeuiLiveEdgeFollower({
    required this.onPinnedChanged,
    this.slack = beuiLiveEdgeSlack,
  });

  /// Fires whenever [pinned] flips. Normally a `setState`.
  final VoidCallback onPinnedChanged;

  /// Drift tolerance in logical pixels. Defaults to [beuiLiveEdgeSlack].
  final double slack;

  /// The controller to hand to the viewport's scroll view.
  final ScrollController controller = ScrollController();

  bool _pinned = false;
  bool _programmatic = false;
  bool _attached = false;

  final ValueNotifier<double> _extentBelow = ValueNotifier<double>(0);

  /// Whether the reader has scrolled away from the live edge.
  ///
  /// While true, [follow] is a no-op — the content keeps growing underneath and
  /// the viewport stays exactly where the reader left it.
  bool get pinned => _pinned;

  /// How many logical pixels of content sit below the fold.
  ///
  /// A [ValueListenable] rather than widget state on purpose: the hidden-content
  /// cue has to track the scroll position, and routing that through `setState`
  /// would rebuild the whole highlighted code subtree on every scroll frame.
  /// Bind [BeuiHiddenContentFooter] to this instead and only the cue repaints.
  ValueListenable<double> get extentBelow => _extentBelow;

  /// Starts listening. Call once, from `initState`.
  void attach() {
    if (_attached) return;
    _attached = true;
    controller.addListener(_onScroll);
  }

  /// Stops listening and disposes the controller.
  void dispose() {
    if (_attached) controller.removeListener(_onScroll);
    controller.dispose();
    _extentBelow.dispose();
  }

  void _onScroll() {
    if (!controller.hasClients) return;
    final position = controller.position;
    _extentBelow.value = (position.maxScrollExtent - position.pixels).clamp(
      0.0,
      double.infinity,
    );
    // Our own animateTo walks the whole distance to the bottom, passing through
    // "far from the edge" on the way. Without this guard the follower would
    // pin itself on the first frame of every follow it started.
    if (_programmatic) return;
    _setPinned(position.maxScrollExtent - position.pixels > slack);
  }

  /// Recomputes [extentBelow] after a content change, which moves
  /// `maxScrollExtent` without producing a scroll notification.
  ///
  /// Safe to call from `build` — the read is deferred to after the frame, so it
  /// never observes a stale layout and never writes during build.
  void syncMetrics() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final position = controller.position;
      _extentBelow.value = (position.maxScrollExtent - position.pixels).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _setPinned(bool next) {
    if (_pinned == next) return;
    _pinned = next;
    onPinnedChanged();
  }

  /// Scrolls to the live edge, unless the reader is [pinned] away from it.
  ///
  /// Runs after the current frame, so the caller can invoke it straight from
  /// `initState` or `didUpdateWidget`, before the new content has been laid
  /// out. Pass [force] for an explicit "jump to latest" activation, which also
  /// unpins.
  ///
  /// [context] is read *inside* the post-frame callback — deliberately, because
  /// the reduced-motion query is an inherited-widget dependency and callers
  /// invoke this from `initState`, where reading one is illegal.
  void follow(BuildContext context, {bool force = false}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!controller.hasClients) return;
      if (_pinned && !force) return;
      final position = controller.position;
      final max = position.maxScrollExtent;
      if (max <= 0) {
        _setPinned(false);
        return;
      }
      if (position.pixels >= max - 0.5) {
        _setPinned(false);
        return;
      }
      final reduce = MediaQuery.disableAnimationsOf(context);
      _programmatic = true;
      if (reduce) {
        controller.jumpTo(max);
        _programmatic = false;
        _setPinned(false);
      } else {
        controller
            .animateTo(
              max,
              duration: beuiLiveEdgeFollowDuration,
              curve: beuiEaseOut,
            )
            .whenComplete(() {
              _programmatic = false;
              _setPinned(false);
            });
      }
    });
  }
}

/// The "jump to latest" pill shown while the reader is pinned away from a
/// streaming live edge.
///
/// One affordance, one shape, in both [BeuiCodeBlock] and [BeuiFileDiff] — the
/// audit's `R7` asks for the language to be consistent across the two, and
/// `C4` asks for the same thing one cluster over.
///
/// Entrance 180ms / exit 120ms (exit faster, per the repo motion rules); the
/// 4px rise is the movement channel and drops under reduced motion while the
/// fade survives. Press scales to 0.97, the library's press token. The visual
/// is 24px tall but carries a 44px hit target.
class BeuiJumpToLatest extends StatefulWidget {
  /// Creates a jump-to-latest pill.
  const BeuiJumpToLatest({
    required this.visible,
    required this.onTap,
    this.label = 'Jump to latest',
    super.key,
  });

  /// Whether the pill is shown. False animates it out and unmounts it.
  final bool visible;

  /// Activation handler — normally `follower.follow(force: true)`.
  final VoidCallback onTap;

  /// Accessible name and visible text. Defaults to `"Jump to latest"`.
  final String label;

  @override
  State<BeuiJumpToLatest> createState() => _BeuiJumpToLatestState();
}

class _BeuiJumpToLatestState extends State<BeuiJumpToLatest> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final pill = BeuiMinHitTarget(
      child: Semantics(
        container: true,
        button: true,
        label: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: SingleMotionBuilder(
              value: (_pressed && !reduce) ? 0.97 : 1.0,
              motion: motionFor(context, beuiSpringPress, isMovement: true),
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: beuiEaseOut,
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _hovered ? colors.foreground : colors.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colors.foreground.withValues(alpha: 0.12),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.arrow_down,
                      size: 12,
                      color: _hovered ? colors.background : colors.foreground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        height: 1,
                        color: _hovered ? colors.background : colors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Opacity is kept under reduced motion; only the 4px rise is dropped.
    return SingleMotionBuilder(
      value: widget.visible ? 1.0 : 0.0,
      motion: motionFor(
        context,
        CurvedMotion(
          widget.visible
              ? const Duration(milliseconds: 180)
              : const Duration(milliseconds: 120),
          beuiEaseOut,
        ),
        isMovement: false,
      ),
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        if (v <= 0.001) return const SizedBox.shrink();
        Widget out = Opacity(opacity: v, child: child);
        if (!reduce) {
          out = Transform.translate(offset: Offset(0, 4 * (1 - v)), child: out);
        }
        return IgnorePointer(ignoring: v < 0.5, child: out);
      },
      child: pill,
    );
  }
}

/// Bottom fade + "N more lines" footer for a viewport that caps its height.
///
/// The code block and the file diff both switch scrollbars off to match the
/// source, which leaves a capped viewport with *no* signal that content
/// continues past the fold (`R12`). This is the pattern `agent_activity`
/// already uses one file over, generalised: a short gradient wash so the last
/// row visibly continues, plus an honest count.
///
/// Purely decorative — [ExcludeSemantics]'d and non-interactive, because the
/// scroll view underneath is the real affordance and a screen reader already
/// reports scroll extent.
///
/// Stack it over the bottom of the viewport (`Positioned(left/right/bottom: 0)`)
/// so it costs no layout and the capped height stays exactly what the consumer
/// asked for.
class BeuiHiddenContentFooter extends StatelessWidget {
  /// Creates a hidden-content cue driven by [extentBelow]
  /// (`BeuiLiveEdgeFollower.extentBelow`).
  const BeuiHiddenContentFooter({
    required this.extentBelow,
    required this.rowExtent,
    required this.surface,
    this.noun = 'line',
    this.fadeHeight = 28,
    super.key,
  });

  /// Logical pixels of content below the fold.
  final ValueListenable<double> extentBelow;

  /// Height of one row, used to turn pixels into a count. Pass the code line
  /// height; a wrapped viewport's count is then a lower bound, which is why the
  /// copy says "more", not "remaining".
  final double rowExtent;

  /// The viewport's own background, which the fade resolves to.
  final Color surface;

  /// Singular noun for the count, pluralised with a bare `s`. Defaults to
  /// `"line"`.
  final String noun;

  /// Height of the gradient wash in logical pixels.
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return ExcludeSemantics(
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: extentBelow,
          builder: (context, below, _) {
            if (below <= 0.5) return const SizedBox.shrink();
            final hidden = rowExtent > 0 ? (below / rowExtent).ceil() : 0;
            final plural = hidden == 1 ? noun : '${noun}s';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: fadeHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [surface, surface.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                if (hidden > 0)
                  DecoratedBox(
                    decoration: BoxDecoration(color: surface),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4, top: 1),
                      child: Text(
                        '$hidden more $plural',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          height: 1.2,
                          // Full-strength muted foreground: this is
                          // information, not decoration (the audit's
                          // alpha-multiplication theme, T3).
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
