import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Hard ceiling on how many copies of the track a marquee will lay out. A
/// degenerate tiny track (one small chip in a very wide viewport) would
/// otherwise multiply into hundreds of Rows.
const int _maxCopies = 32;

/// Scroll direction for a [BeuiMarquee].
enum BeuiMarqueeDirection {
  /// Scrolls right→left (default).
  left,

  /// Scrolls left→right.
  right,

  /// Scrolls bottom→top.
  up,

  /// Scrolls top→bottom.
  down,
}

/// An infinitely scrolling marquee — the Flutter port of beUI's `marquee`.
///
/// Lays [children] in a track (separated by [gap]), duplicates it enough to
/// fill the viewport, and scrolls seamlessly in [direction] — one track length
/// every [duration]. Pauses on hover ([pauseOnHover]); [fade] masks the leading
/// and trailing edges. Reduced motion holds it static.
class BeuiMarquee extends StatefulWidget {
  /// Creates a marquee over [children].
  const BeuiMarquee({
    required this.children,
    this.direction = BeuiMarqueeDirection.left,
    this.duration = const Duration(seconds: 30),
    this.pauseOnHover = true,
    this.gap = 16,
    this.fade = true,
    super.key,
  });

  /// The repeating content.
  final List<Widget> children;

  /// Scroll direction.
  final BeuiMarqueeDirection direction;

  /// Time to scroll one track length.
  final Duration duration;

  /// Pause while hovered.
  final bool pauseOnHover;

  /// Gap between items.
  final double gap;

  /// Fade (mask) the leading/trailing edges.
  final bool fade;

  @override
  State<BeuiMarquee> createState() => _BeuiMarqueeState();
}

class _BeuiMarqueeState extends State<BeuiMarquee>
    with SingleTickerProviderStateMixin {
  final GlobalKey _trackKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  double? _trackExtent;
  bool _paused = false;
  bool _reduce = false;

  bool get _vertical =>
      widget.direction == BeuiMarqueeDirection.up ||
      widget.direction == BeuiMarqueeDirection.down;
  bool get _reverse =>
      widget.direction == BeuiMarqueeDirection.right ||
      widget.direction == BeuiMarqueeDirection.down;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(BeuiMarquee old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) _controller.duration = widget.duration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure() {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final extent = _vertical ? box.size.height : box.size.width;
    if (extent > 0 && extent != _trackExtent) {
      setState(() => _trackExtent = extent);
      _sync();
    }
  }

  void _sync() {
    final shouldRun = _trackExtent != null && !_reduce && !_paused;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  List<Widget> _trackChildren() => [
    for (final child in widget.children) ...[
      child,
      _vertical ? SizedBox(height: widget.gap) : SizedBox(width: widget.gap),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    Widget track({Key? key}) => _vertical
        ? Column(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: _trackChildren(),
          )
        : Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: _trackChildren(),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = _vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final extent = _trackExtent;

        final Widget inner;
        if (extent == null || extent <= 0) {
          // Measure pass: render one keyed track (static until measured).
          inner = track(key: _trackKey);
        } else {
          final fill = viewport.isFinite ? (viewport / extent).ceil() + 1 : 2;
          // Guard the degenerate tiny-track case (e.g. one small chip in a
          // very wide viewport), which would otherwise explode into hundreds
          // of track copies. Capped hard; asserts in debug so the consumer
          // hears about it rather than silently shipping a gappy marquee.
          assert(
            fill <= _maxCopies,
            'BeuiMarquee: track extent ($extent px) is too short for the '
            'viewport ($viewport px) — needs $fill copies (max $_maxCopies). '
            'Give the marquee longer content.',
          );
          final copies = math.max(2, math.min(fill, _maxCopies));
          final tracks = <Widget>[
            track(key: _trackKey),
            for (var i = 1; i < copies; i++) track(),
          ];
          final strip = _vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: tracks)
              : Row(mainAxisSize: MainAxisSize.min, children: tracks);
          inner = AnimatedBuilder(
            animation: _controller,
            child: strip,
            builder: (context, child) {
              final progress = _reverse
                  ? 1 - _controller.value
                  : _controller.value;
              final shift = -progress * extent;
              return Transform.translate(
                offset: _vertical ? Offset(0, shift) : Offset(shift, 0),
                child: child,
              );
            },
          );
        }

        // A never-scrollable viewport gives the strip an unbounded main axis
        // (so it lays out at its natural length instead of overflowing), sizes
        // its cross axis to the content, and clips the overflow for us.
        Widget result = SingleChildScrollView(
          scrollDirection: _vertical ? Axis.vertical : Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          clipBehavior: Clip.hardEdge,
          child: inner,
        );

        if (widget.fade) {
          result = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: _vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: _vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: const [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: const [0.0, 0.12, 0.88, 1.0],
            ).createShader(rect),
            child: result,
          );
        }

        // RepaintBoundary isolates the strip's permanent 60fps repaint (and
        // the fade mask's per-frame saveLayer) from the host page's layer.
        result = RepaintBoundary(child: result);

        if (widget.pauseOnHover) {
          result = MouseRegion(
            onEnter: (_) {
              _paused = true;
              _sync();
            },
            onExit: (_) {
              _paused = false;
              _sync();
            },
            child: result,
          );
        }

        return result;
      },
    );
  }
}
