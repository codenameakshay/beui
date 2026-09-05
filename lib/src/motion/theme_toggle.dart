import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import '../tokens/icons.dart';
import '../tokens/motion.dart' show beuiEaseOut;
import '_engine.dart' show CurvedMotion, Motion, SingleMotionController;
import 'action_swap.dart' show BeuiActionSwapIcon, BeuiActionSwapVariant;

/// How a [BeuiThemeSwitcher] reveals the new theme — the Flutter port of beUI's
/// `ThemeVariant`. The source drives these with the web-only **View Transition
/// API**; this port reimplements them as a uniform `ClipPath` animation that
/// runs on every platform (a snapshot of the old theme is clipped away as the
/// new theme is revealed underneath).
enum BeuiThemeRevealVariant {
  /// An inset rectangle wipes the new theme in (source `rectangle`, 400ms).
  rectangle,

  /// A circle expands from the origin (source `circle`, 700ms).
  circle,

  /// A circle expands from the origin, the seam softened with a fading blur
  /// (source `circle-blur`, 700ms + `blur(8px)`→0).
  circleBlur,

  /// Vertical slats open across the whole surface like a shutter — the source's
  /// `blinds` (700ms `EASE_OUT`). The source masks the incoming view with a
  /// repeating 72px-tiled `linear-gradient(90deg, …)` whose opaque band widens
  /// from `-20px` to `72px`; this port clips the same widening band per tile.
  ///
  /// The slats sweep the entire surface, so [BeuiThemeRevealStart] is
  /// **ignored** for this variant — matching the source, which sets no
  /// `--beui-vt-origin` for `blinds` ("there is no origin point to set").
  blinds,
}

/// Origin the reveal grows from (source `RectStart`).
///
/// Ignored by [BeuiThemeRevealVariant.blinds], whose slats open across the
/// whole surface rather than growing from a point.
enum BeuiThemeRevealStart {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
  bottomUp,
}

/// The reveal's duration **and** easing for [variant], as the single [Motion]
/// token the reveal controller runs on — the two things the source's `VT_CSS`
/// sets per View Transition, folded into one value.
///
/// Durations are the source's verbatim: rectangle 400ms; circle, circle-blur
/// and blinds 700ms. Curves likewise:
/// - rectangle → the CSS `ease-out` *keyword*, cubic-bezier(0, 0, 0.58, 1)
///   (NOT Flutter's Curves.easeOut, which is Material's (0, 0, 0.2, 1));
/// - circle / circle-blur → cubic-bezier(.4, 0, .2, 1);
/// - blinds → `${EASE_OUT_CSS}`, i.e. the shared [beuiEaseOut] token.
///
/// Carrying the curve in the motion (rather than reading a linear controller
/// through `Curve.transform` at paint time) is what lets the reveal run on the
/// `_engine.dart` facade's [SingleMotionController]: the eased progress the
/// clipper wants comes straight off `controller.value`.
Motion _revealMotion(BeuiThemeRevealVariant variant) => switch (variant) {
  BeuiThemeRevealVariant.rectangle => const CurvedMotion(
    Duration(milliseconds: 400),
    Curves.easeOut,
  ),
  BeuiThemeRevealVariant.circle || BeuiThemeRevealVariant.circleBlur =>
    const CurvedMotion(Duration(milliseconds: 700), Curves.fastOutSlowIn),
  BeuiThemeRevealVariant.blinds => const CurvedMotion(
    Duration(milliseconds: 700),
    beuiEaseOut,
  ),
};

/// Handle a [BeuiThemeToggle] uses to read the current brightness and request a
/// switch. Obtain it with `BeuiThemeSwitcher.of(context)`.
@immutable
class BeuiThemeSwitcherController {
  const BeuiThemeSwitcherController(this._onToggle, {required this.brightness});

  /// The brightness the switcher is currently showing.
  final Brightness brightness;

  final void Function({
    required BeuiThemeRevealVariant variant,
    required BeuiThemeRevealStart start,
  })
  _onToggle;

  /// Whether the current brightness is dark.
  bool get isDark => brightness == Brightness.dark;

  /// Flips the brightness, animating the reveal (unless reduced motion).
  void toggle({
    BeuiThemeRevealVariant variant = BeuiThemeRevealVariant.rectangle,
    BeuiThemeRevealStart start = BeuiThemeRevealStart.bottomUp,
  }) => _onToggle(variant: variant, start: start);
}

/// Wraps a subtree and switches its [Brightness] with a full-surface clip-path
/// reveal — the Flutter port of beUI's `theme-toggle` (the View-Transition
/// flourish), reimplemented with a snapshot + animated [ClipPath] so it runs
/// everywhere, not just on the web.
///
/// [builder] receives the current [Brightness]; build your theme from it (e.g.
/// `Theme(data: ThemeData.from(brightness: b), child: ...)`). A descendant
/// [BeuiThemeToggle] flips it. On toggle the old theme is captured to an image,
/// the subtree rebuilds with the new brightness, and the snapshot is clipped
/// away from the chosen origin so the new theme is revealed underneath. Reduced
/// motion switches instantly (the source's `useReducedMotion` branch).
class BeuiThemeSwitcher extends StatefulWidget {
  /// Creates a theme switcher around [builder].
  const BeuiThemeSwitcher({
    required this.builder,
    this.initialBrightness = Brightness.light,
    super.key,
  });

  /// Builds the themed subtree for the current brightness.
  final Widget Function(BuildContext context, Brightness brightness) builder;

  /// Brightness shown before the first toggle.
  final Brightness initialBrightness;

  /// The nearest switcher's controller (brightness + toggle). Asserts one
  /// exists above [context].
  static BeuiThemeSwitcherController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ThemeScope>();
    assert(scope != null, 'BeuiThemeToggle must be below a BeuiThemeSwitcher.');
    return scope!.controller;
  }

  @override
  State<BeuiThemeSwitcher> createState() => _BeuiThemeSwitcherState();
}

class _BeuiThemeSwitcherState extends State<BeuiThemeSwitcher>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();

  /// Drives the reveal 0 → 1 through the `_engine.dart` motor facade. Its
  /// [Motion] is swapped per toggle ([_revealMotion]), so `value` is already the
  /// eased progress the clipper consumes.
  late final SingleMotionController _reveal;

  late Brightness _brightness = widget.initialBrightness;
  ui.Image? _oldImage; // snapshot of the outgoing theme
  ui.Image? _newImage; // snapshot of the incoming theme (circle-blur only)
  BeuiThemeRevealVariant _variant = BeuiThemeRevealVariant.rectangle;
  BeuiThemeRevealStart _start = BeuiThemeRevealStart.bottomUp;
  double _dpr = 1;

  @override
  void initState() {
    super.initState();
    // Eager (not lazy) so a reduced-motion toggle that never animates still has
    // a constructed controller to dispose without a deactivated-element lookup.
    // The motion passed here is only a placeholder — every toggle assigns the
    // variant's own before starting.
    _reveal =
        SingleMotionController(
          motion: _revealMotion(BeuiThemeRevealVariant.rectangle),
          vsync: this,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _clearOverlay();
        });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _oldImage?.dispose();
    _newImage?.dispose();
    super.dispose();
  }

  void _clearOverlay() {
    final old = _oldImage;
    final incoming = _newImage;
    if (old == null && incoming == null) return;
    setState(() {
      _oldImage = null;
      _newImage = null;
    });
    _disposeAfterFrame(old);
    _disposeAfterFrame(incoming);
  }

  /// Frees a snapshot only after the next frame, so it outlives any in-flight
  /// rasterisation (`toImageSync` rasterises on first draw) and is never disposed
  /// while still referenced by a `RawImage` in the current tree.
  void _disposeAfterFrame(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  ui.Image? _snapshot() {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    return boundary.toImageSync(pixelRatio: _dpr);
  }

  void _toggle({
    required BeuiThemeRevealVariant variant,
    required BeuiThemeRevealStart start,
  }) {
    // While a reveal plays the viewport is frozen — a toggle can't re-enter.
    // Mirrors the source: the View Transition snapshot locks out interaction
    // until the animation settles. (`AbsorbPointer` blocks user taps; this
    // guards programmatic calls too.) `_oldImage != null` for the whole reveal
    // window, including circle-blur's one-frame incoming-snapshot capture where
    // the controller is briefly idle.
    if (_oldImage != null || _reveal.isAnimating) return;

    final next = _brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    // Reduced motion (or no rendered surface to snapshot): switch instantly.
    if (MediaQuery.disableAnimationsOf(context) ||
        boundary == null ||
        !boundary.hasSize) {
      setState(() => _brightness = next);
      return;
    }

    _dpr = MediaQuery.devicePixelRatioOf(context);
    // Snapshot the outgoing theme (the boundary wraps only the live surface, so
    // this is always the settled theme — a reveal can't be in flight here).
    final outgoing = boundary.toImageSync(pixelRatio: _dpr);
    // Load the variant's timing + easing, then rewind to 0 so the frame that
    // paints the new brightness is still fully covered by the outgoing snapshot
    // (no flash of the settled theme). Rewinding *here*, while `_oldImage` is
    // still null, also keeps the end-of-reveal `completed` status the only one
    // `_clearOverlay` can act on: the rewind reports `completed` too (an
    // unbounded MotionController is `completed` whenever it sits stopped away
    // from its initial value), but with no overlay up that call is a no-op.
    _reveal
      ..motion = _revealMotion(variant)
      ..value = 0;
    setState(() {
      _brightness = next;
      _oldImage = outgoing;
      _newImage = null;
      _variant = variant;
      _start = start;
    });

    if (variant == BeuiThemeRevealVariant.circleBlur) {
      // The blur reveals the *incoming* theme, so capture it once the new
      // brightness has painted, then start. Blurring a static snapshot (cached
      // in build) is far cheaper than a per-frame `BackdropFilter` — the live
      // blur was the profile-build hang.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _newImage = _snapshot());
        _reveal.animateTo(1, from: 0);
      });
    } else {
      _reveal.animateTo(1, from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = BeuiThemeSwitcherController(
      _toggle,
      brightness: _brightness,
    );

    // The boundary wraps ONLY the live surface, so snapshotting it (outgoing at
    // toggle time, incoming a frame later) captures the clean theme, never the
    // reveal overlay layered on top.
    final live = RepaintBoundary(
      key: _boundaryKey,
      child: _ThemeScope(
        controller: controller,
        child: Builder(builder: (c) => widget.builder(c, _brightness)),
      ),
    );

    if (_oldImage == null) return live;

    return Stack(
      children: [
        live, // live new theme (revealed as the overlay clips away)
        Positioned.fill(
          // Absorb (not ignore) pointers: while the reveal plays the surface is
          // frozen and unclickable — the source relies on the View Transition
          // snapshot doing the same to the whole viewport.
          child: AbsorbPointer(
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) => _RevealOverlay(
                oldImage: _oldImage!,
                newImage: _newImage,
                scale: _dpr,
                // Already eased: the curve lives in the controller's motion
                // ([_revealMotion]), not in a transform applied per frame.
                progress: _reveal.value,
                variant: _variant,
                start: _start,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeScope extends InheritedWidget {
  const _ThemeScope({required this.controller, required super.child});

  final BeuiThemeSwitcherController controller;

  @override
  bool updateShouldNotify(_ThemeScope old) =>
      old.controller.brightness != controller.brightness;
}

/// A theme-toggle button — a Sun/Moon icon (swapped with the action-swap `blur`
/// transition) that flips the nearest [BeuiThemeSwitcher]'s brightness, playing
/// the [variant] reveal from [start]. Bare by design (style it with a parent
/// border/padding, as the source does via `className`).
class BeuiThemeToggle extends StatelessWidget {
  /// Creates a theme-toggle button.
  const BeuiThemeToggle({
    this.variant = BeuiThemeRevealVariant.rectangle,
    this.start = BeuiThemeRevealStart.bottomUp,
    this.size = 20,
    this.color,
    super.key,
  });

  /// Reveal variant played on toggle.
  final BeuiThemeRevealVariant variant;

  /// Reveal origin.
  final BeuiThemeRevealStart start;

  /// Icon size.
  final double size;

  /// Icon colour. Defaults to the ambient [IconTheme] colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final controller = BeuiThemeSwitcher.of(context);
    final isDark = controller.isDark;
    final iconColor =
        color ??
        IconTheme.of(context).color ??
        (isDark ? Colors.white : Colors.black);

    return Semantics(
      button: true,
      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.toggle(variant: variant, start: start),
          child: IconTheme.merge(
            data: IconThemeData(color: iconColor, size: size),
            child: BeuiActionSwapIcon(
              value: isDark ? 'dark' : 'light',
              icon: isDark ? LucideIcons.sun : LucideIcons.moon,
              variant: BeuiActionSwapVariant.blur,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the captured outgoing-theme snapshot clipped to *everything except*
/// the growing reveal shape, so the **live** new theme shows through the shape.
///
/// For circle-blur the new theme is *also* snapshotted ([newImage]) but only to
/// drive a **fading blurred layer** inside the circle — the live surface still
/// shows through beneath it, so its icon swaps in real time just like the other
/// variants. The blur is computed **once** (cached in a [RepaintBoundary]) and
/// merely faded by opacity, so there is no per-frame Gaussian — unlike a live
/// `BackdropFilter`, which stalled profile builds. Mirrors the source's
/// `::view-transition-new { filter: blur(8px)→0 }`.
class _RevealOverlay extends StatelessWidget {
  const _RevealOverlay({
    required this.oldImage,
    required this.newImage,
    required this.scale,
    required this.progress,
    required this.variant,
    required this.start,
  });

  final ui.Image oldImage;
  final ui.Image? newImage;
  final double scale;
  final double progress;
  final BeuiThemeRevealVariant variant;
  final BeuiThemeRevealStart start;

  @override
  Widget build(BuildContext context) {
    // The outgoing snapshot, shown everywhere EXCEPT the reveal shape (never
    // blurred — the source's `::view-transition-old` layer is static). The live
    // new theme shows through the shape.
    final outgoing = ClipPath(
      clipper: _RevealClipper(
        progress: progress,
        variant: variant,
        start: start,
      ),
      child: RawImage(image: oldImage, scale: scale, fit: BoxFit.fill),
    );

    // Non-blur variants (and the one frame before the incoming snapshot is
    // ready): just clip the outgoing away and let the live surface show.
    if (variant != BeuiThemeRevealVariant.circleBlur || newImage == null) {
      return outgoing;
    }

    final incoming = newImage!;
    final blurOpacity = (1 - progress).clamp(0.0, 1.0);
    // Blur gone → nothing to overlay inside the circle; the live surface (which
    // shows through) already reads sharp.
    if (blurOpacity <= 0.001) return outgoing;
    return Stack(
      children: [
        outgoing,
        // Only the *fading* blurred incoming snapshot, clipped to the circle.
        // Critically there is NO sharp snapshot beneath it — the live surface
        // shows through, so its icon (and everything else) swaps the instant the
        // toggle fires, exactly like the other variants; the blur just masks the
        // first frames. A static snapshot is blurred (cached once) only because
        // blurring the moving live content per frame is what hung profile builds.
        ClipPath(
          clipper: _RevealClipper(
            progress: progress,
            variant: variant,
            start: start,
            inside: true,
          ),
          child: Opacity(
            opacity: blurOpacity,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 4,
                  sigmaY: 4,
                  tileMode: TileMode.decal,
                ),
                child: RawImage(
                  image: incoming,
                  scale: scale,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({
    required this.progress,
    required this.variant,
    required this.start,
    this.inside = false,
  });

  final double progress;
  final BeuiThemeRevealVariant variant;
  final BeuiThemeRevealStart start;

  /// When true, clip *to* the reveal shape (used to blur the incoming theme
  /// inside the circle); otherwise clip to everything *except* it (the old image).
  final bool inside;

  @override
  Path getClip(Size size) {
    final reveal = _revealPath(size);
    if (inside) return reveal;
    // Old image shows everywhere EXCEPT the reveal → the new theme shows inside.
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      reveal,
    );
  }

  Path _revealPath(Size size) {
    if (variant == BeuiThemeRevealVariant.blinds) return _blindsPath(size);
    if (variant == BeuiThemeRevealVariant.rectangle) {
      final f = _rectFrom(start); // (top, right, bottom, left) fractions
      final t = f[0] * (1 - progress);
      final r = f[1] * (1 - progress);
      final b = f[2] * (1 - progress);
      final l = f[3] * (1 - progress);
      return Path()..addRect(
        Rect.fromLTRB(
          l * size.width,
          t * size.height,
          size.width * (1 - r),
          size.height * (1 - b),
        ),
      );
    }
    final o = _circleOrigin(start);
    final center = Offset(o.dx * size.width, o.dy * size.height);
    return Path()..addOval(
      Rect.fromCircle(center: center, radius: progress * _endRadius(size)),
    );
  }

  /// Width of one shutter tile — source `mask-size: 72px 100%`.
  static const double blindsTile = 72;

  /// Soft trailing edge of each slat — source's `+ 20px` gradient stop.
  static const double blindsFeather = 20;

  /// One widening slat per 72px tile, so the new theme opens across the surface
  /// like a shutter (source `beui-blinds-reveal`).
  ///
  /// The source animates a registered custom property `--beui-vt-slat` from
  /// `-20px` → `72px` and masks the incoming view with
  /// `linear-gradient(90deg, #000 0 var(--slat), transparent calc(var(--slat) + 20px))`
  /// repeated every 72px. A [ClipPath] has no soft edge, so the hard clip is
  /// placed at the mask's **50%-alpha boundary** (`slat + 20/2`) — the closest
  /// single-edge equivalent of the feathered band, and the reason the slats
  /// still start closed at t=0 and land fully open at t=1.
  Path _blindsPath(Size size) {
    // slat = lerp(-20, 72, progress); edge = slat + feather / 2.
    const span = blindsTile + blindsFeather; // -20 → 72
    final edge = (-blindsFeather + span * progress + blindsFeather / 2).clamp(
      0.0,
      blindsTile,
    );
    final path = Path();
    if (edge <= 0) return path;
    final tiles = (size.width / blindsTile).ceil();
    for (var i = 0; i < tiles; i++) {
      final left = i * blindsTile;
      path.addRect(
        Rect.fromLTWH(left, 0, math.min(edge, size.width - left), size.height),
      );
    }
    return path;
  }

  /// The source grows the clip to `circle(150%)`, and CSS resolves a circle()
  /// percentage against diagonal/√2 of the reference box. The end radius is
  /// therefore 1.5 × (diagonal/√2) — always past the farthest corner (which is
  /// at most one full diagonal away), so full coverage lands *before* t = 1,
  /// early in the eased timeline, exactly like the source.
  static double _endRadius(Size s) =>
      1.5 * math.sqrt(s.width * s.width + s.height * s.height) / math.sqrt2;

  static List<double> _rectFrom(BeuiThemeRevealStart s) => switch (s) {
    BeuiThemeRevealStart.topLeft => [0, 1, 1, 0],
    BeuiThemeRevealStart.topRight => [0, 0, 1, 1],
    BeuiThemeRevealStart.bottomLeft => [1, 1, 0, 0],
    BeuiThemeRevealStart.bottomRight => [1, 0, 0, 1],
    BeuiThemeRevealStart.center => [0.5, 0.5, 0.5, 0.5],
    BeuiThemeRevealStart.bottomUp => [1, 0, 0, 0],
  };

  static Offset _circleOrigin(BeuiThemeRevealStart s) => switch (s) {
    BeuiThemeRevealStart.topLeft => const Offset(0, 0),
    BeuiThemeRevealStart.topRight => const Offset(1, 0),
    BeuiThemeRevealStart.bottomLeft => const Offset(0, 1),
    BeuiThemeRevealStart.bottomRight => const Offset(1, 1),
    BeuiThemeRevealStart.center => const Offset(0.5, 0.5),
    BeuiThemeRevealStart.bottomUp => const Offset(0.5, 1),
  };

  @override
  bool shouldReclip(_RevealClipper old) =>
      old.progress != progress ||
      old.variant != variant ||
      old.start != start ||
      old.inside != inside;
}
