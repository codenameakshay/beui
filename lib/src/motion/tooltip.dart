import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';

/// Which side of the trigger the tooltip appears on.
enum BeuiTooltipSide {
  /// Above the trigger (default).
  top,

  /// To the right.
  right,

  /// Below.
  bottom,

  /// To the left.
  left,
}

/// A hover/focus tooltip with a spring spawn and blur enter/exit — the Flutter
/// port of beUI's `tooltip`, built on [BeuiOverlay].
///
/// Opens on pointer hover (hover-capable only — `MouseRegion` never fires on
/// touch) and on keyboard focus, after a short [delay]; a global **warm window**
/// makes neighbouring tooltips open instantly once one has just closed. On touch
/// it reveals on long-press. The surface anchors to the trigger via the overlay
/// [LayerLink] and rises into place from near the trigger (offset + scale from
/// the trigger-facing edge + blur), driven by the source's 380/30/0.7 spring
/// (approximated with an eased curve here). Reduced motion fades opacity only.
class BeuiTooltip extends StatefulWidget {
  /// Creates a tooltip around [child].
  const BeuiTooltip({
    required this.content,
    required this.child,
    this.side = BeuiTooltipSide.top,
    this.delay = const Duration(milliseconds: 120),
    super.key,
  });

  /// The tooltip body (usually a [Text]).
  final Widget content;

  /// The trigger.
  final Widget child;

  /// Which side to show on.
  final BeuiTooltipSide side;

  /// Delay before opening on hover/focus (skipped within the warm window).
  final Duration delay;

  @override
  State<BeuiTooltip> createState() => _BeuiTooltipState();
}

class _BeuiTooltipState extends State<BeuiTooltip> {
  static const int _warmWindowMs = 300;
  static int _lastHiddenAtMs = 0;

  bool _open = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show({bool immediate = false}) {
    _timer?.cancel();
    final warm =
        DateTime.now().millisecondsSinceEpoch - _lastHiddenAtMs < _warmWindowMs;
    final delay = immediate || warm ? Duration.zero : widget.delay;
    _timer = Timer(delay, () {
      if (mounted) setState(() => _open = true);
    });
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    if (_open) {
      _lastHiddenAtMs = DateTime.now().millisecondsSinceEpoch;
      setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeuiOverlay(
      open: _open,
      barrier: false,
      trapFocus: false,
      onDismiss: _hide,
      enterDuration: const Duration(milliseconds: 280),
      exitDuration: const Duration(milliseconds: 140),
      overlayBuilder: _buildTooltip,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => focused ? _show() : _hide(),
          child: GestureDetector(
            onLongPressStart: (_) => _show(immediate: true),
            onLongPressEnd: (_) => _hide(),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final spec = _spec(widget.side);

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: spec.targetAnchor,
      followerAnchor: spec.followerAnchor,
      offset: spec.gap,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value.clamp(0.0, 1.0);
            final opacity = Curves.easeOut.transform(t);
            final surface = _surface(colors);
            if (reduce) {
              return Opacity(opacity: opacity, child: surface);
            }
            final e = Curves.easeOutCubic.transform(t);
            final scale = 0.85 + 0.15 * e;
            final blur = (1 - Curves.easeOut.transform(t)) * 10;
            final offset = spec.away * (1 - e);
            return Transform.translate(
              offset: offset,
              child: Transform.scale(
                scale: scale,
                alignment: spec.origin,
                child: Opacity(
                  opacity: opacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: surface,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _surface(BeuiColors colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8), // rounded-lg
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // backdrop-blur-xl
          child: Container(
            decoration: BoxDecoration(
              color: colors.popover.withValues(alpha: 0.85),
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.popoverForeground,
              ),
              child: widget.content,
            ),
          ),
        ),
      ),
    );
  }

  _TooltipSpec _spec(BeuiTooltipSide side) => switch (side) {
    BeuiTooltipSide.top => const _TooltipSpec(
      targetAnchor: Alignment.topCenter,
      followerAnchor: Alignment.bottomCenter,
      gap: Offset(0, -8),
      away: Offset(0, 10),
      origin: Alignment.bottomCenter,
    ),
    BeuiTooltipSide.bottom => const _TooltipSpec(
      targetAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      gap: Offset(0, 8),
      away: Offset(0, -10),
      origin: Alignment.topCenter,
    ),
    BeuiTooltipSide.left => const _TooltipSpec(
      targetAnchor: Alignment.centerLeft,
      followerAnchor: Alignment.centerRight,
      gap: Offset(-8, 0),
      away: Offset(10, 0),
      origin: Alignment.centerRight,
    ),
    BeuiTooltipSide.right => const _TooltipSpec(
      targetAnchor: Alignment.centerRight,
      followerAnchor: Alignment.centerLeft,
      gap: Offset(8, 0),
      away: Offset(-10, 0),
      origin: Alignment.centerLeft,
    ),
  };
}

class _TooltipSpec {
  const _TooltipSpec({
    required this.targetAnchor,
    required this.followerAnchor,
    required this.gap,
    required this.away,
    required this.origin,
  });
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Offset gap;
  final Offset away;
  final Alignment origin;
}
