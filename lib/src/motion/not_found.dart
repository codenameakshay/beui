import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'magnetic.dart';
import 'text_reveal.dart';

/// Shared copy defaults (source `NOT_FOUND_DEFAULTS`). Hrefs become
/// callbacks — Flutter navigation is the consumer's.
const _kCode = '404';
const _kTitle = 'Page not found';
const _kDescription =
    'The page you are looking for moved, vanished, or never existed.';
const _kHomeLabel = 'Back home';
const _kBrowseLabel = 'Browse components';

/// Centers a variant with the source's minimum stage height and gap.
class _Stage extends StatelessWidget {
  const _Stage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 32, // gap-8
        children: children,
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8, // gap-2
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18, // text-lg
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
        ),
      ],
    );
  }
}

/// The shared dual CTA (source `NotFoundActions`): a primary "Back home" and
/// a secondary "Browse", press 0.96 / hover 1.02 on `SPRING_PRESS`.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.homeLabel,
    required this.browseLabel,
    this.onHome,
    this.onBrowse,
  });

  final String homeLabel;
  final String browseLabel;
  final VoidCallback? onHome;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Wrap(
      spacing: 12, // gap-3
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _ActionPill(
          label: homeLabel,
          background: colors.primary,
          foreground: colors.primaryForeground,
          onPressed: onHome,
        ),
        _ActionPill(
          label: browseLabel,
          background: colors.card,
          foreground: colors.foreground,
          border: colors.border,
          onPressed: onBrowse,
        ),
      ],
    );
  }
}

class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
    this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onPressed;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget pill = Container(
      height: 44, // h-11
      padding: const EdgeInsets.symmetric(horizontal: 24), // px-6
      decoration: BoxDecoration(
        color: widget.background,
        border: widget.border != null
            ? Border.all(color: widget.border!)
            : null,
        borderRadius: BorderRadius.circular(999),
      ),
      // `inline-flex`: the pill hugs its label. A bare `alignment:` on the
      // Container would let it expand to the row's full width instead, which
      // stacked the two CTAs full-bleed one per line.
      child: Center(
        widthFactor: 1,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 14, // text-sm
            height: 20 / 14, // …/20
            fontWeight: FontWeight.w500,
            color: widget.foreground,
          ),
        ),
      ),
    );

    pill = SingleMotionBuilder(
      value: reduce
          ? 1.0
          : _pressed
          ? 0.96
          : _hovered
          ? 1.02
          : 1.0,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: pill,
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: pill,
        ),
      ),
    );
  }
}

double _bigCode(BuildContext context, {double vw = 0.18, double max = 176}) =>
    (MediaQuery.sizeOf(context).width * vw).clamp(80.0, max);

/// 404 with a character scramble on mount and chromatic ghost layers on hover
/// — the Flutter port of the source `NotFoundGlitch`.
class BeuiNotFoundGlitch extends StatelessWidget {
  /// Creates the glitch variant.
  const BeuiNotFoundGlitch({
    this.code = _kCode,
    this.title = _kTitle,
    this.description = _kDescription,
    this.homeLabel = _kHomeLabel,
    this.browseLabel = _kBrowseLabel,
    this.onHome,
    this.onBrowse,
    super.key,
  });

  /// The big status code.
  final String code;

  /// Headline.
  final String title;

  /// Byline.
  final String description;

  /// Primary CTA label.
  final String homeLabel;

  /// Secondary CTA label.
  final String browseLabel;

  /// Primary CTA callback (the source's `homeHref`).
  final VoidCallback? onHome;

  /// Secondary CTA callback (the source's `browseHref`).
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return _Stage(
      children: [
        _GlitchCode(code: code, fontSize: _bigCode(context)),
        _Copy(title: title, description: description),
        _Actions(
          homeLabel: homeLabel,
          browseLabel: browseLabel,
          onHome: onHome,
          onBrowse: onBrowse,
        ),
      ],
    );
  }
}

class _GlitchCode extends StatefulWidget {
  const _GlitchCode({required this.code, required this.fontSize});

  final String code;
  final double fontSize;

  @override
  State<_GlitchCode> createState() => _GlitchCodeState();
}

class _GlitchCodeState extends State<_GlitchCode>
    with SingleTickerProviderStateMixin {
  static const _glyphs = r'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&@$?/\';
  static const _scrambleMs = 700;
  static const _tickMs = 45;

  late final AnimationController _clock;
  final math.Random _random = math.Random();
  String _display = '';
  int _lastTickMs = -_tickMs;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _display = widget.code;
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _scrambleMs),
    )..addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scramble is a pure enhancement; reduced motion sees the code as-is.
    if (!MediaQuery.disableAnimationsOf(context) &&
        !_clock.isAnimating &&
        _clock.value == 0) {
      _clock.forward();
    }
  }

  void _tick() {
    final elapsed = (_clock.value * _scrambleMs).round();
    if (elapsed - _lastTickMs < _tickMs && _clock.value < 1) return;
    _lastTickMs = elapsed;
    final chars = widget.code.split('');
    final settled = _clock.value >= 1
        ? chars.length
        : (_clock.value * chars.length).floor();
    setState(() {
      _display = [
        for (var i = 0; i < chars.length; i++)
          i < settled || chars[i] == ' '
              ? chars[i]
              : _glyphs[_random.nextInt(_glyphs.length)],
      ].join();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final style = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -widget.fontSize * 0.04, // tracking-tighter
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colors.foreground,
    );
    final text = reduce ? widget.code : _display;

    Widget ghost(Color color, double dx) => AnimatedSlide(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      offset: Offset(_hovered ? dx / widget.fontSize : 0, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _hovered ? 0.7 : 0,
        child: Text(text, style: style.copyWith(color: color)),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          // Chromatic ghosts, nudged ±3px apart on hover (screen-blend
          // approximated with translucent layers).
          if (!reduce) ...[
            ghost(const Color(0xFFFF0040), 3),
            ghost(const Color(0xFF00E5FF), -3),
          ],
          Semantics(
            header: true,
            label: widget.code,
            child: ExcludeSemantics(child: Text(text, style: style)),
          ),
        ],
      ),
    );
  }
}

/// 404 whose glyphs are cursor-attracted [BeuiMagnetic] wrappers — the
/// Flutter port of the source `NotFoundMagnetic`.
class BeuiNotFoundMagnetic extends StatelessWidget {
  /// Creates the magnetic variant.
  const BeuiNotFoundMagnetic({
    this.code = _kCode,
    this.title = _kTitle,
    this.description = _kDescription,
    this.homeLabel = _kHomeLabel,
    this.browseLabel = _kBrowseLabel,
    this.onHome,
    this.onBrowse,
    super.key,
  });

  /// The big status code.
  final String code;

  /// Headline.
  final String title;

  /// Byline.
  final String description;

  /// Primary CTA label.
  final String homeLabel;

  /// Secondary CTA label.
  final String browseLabel;

  /// Primary CTA callback.
  final VoidCallback? onHome;

  /// Secondary CTA callback.
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final fontSize = _bigCode(context, max: 192);
    return _Stage(
      children: [
        Semantics(
          header: true,
          label: code,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ch in code.split(''))
                  BeuiMagnetic(
                    strength: 0.6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ch,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -fontSize * 0.04,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _Copy(title: title, description: description),
        _Actions(
          homeLabel: homeLabel,
          browseLabel: browseLabel,
          onHome: onHome,
          onBrowse: onBrowse,
        ),
      ],
    );
  }
}

/// 404 revealed by a cursor spotlight over a dark panel — the Flutter port of
/// the source `NotFoundSpotlight`.
class BeuiNotFoundSpotlight extends StatefulWidget {
  /// Creates the spotlight variant.
  const BeuiNotFoundSpotlight({
    this.code = _kCode,
    this.title = _kTitle,
    this.description = _kDescription,
    this.homeLabel = _kHomeLabel,
    this.browseLabel = _kBrowseLabel,
    this.onHome,
    this.onBrowse,
    super.key,
  });

  /// The big status code.
  final String code;

  /// Headline.
  final String title;

  /// Byline.
  final String description;

  /// Primary CTA label.
  final String homeLabel;

  /// Secondary CTA label.
  final String browseLabel;

  /// Primary CTA callback.
  final VoidCallback? onHome;

  /// Secondary CTA callback.
  final VoidCallback? onBrowse;

  @override
  State<BeuiNotFoundSpotlight> createState() => _BeuiNotFoundSpotlightState();
}

class _BeuiNotFoundSpotlightState extends State<BeuiNotFoundSpotlight> {
  Alignment _pointer = Alignment.center;
  bool _inside = false;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final fontSize = _bigCode(context, vw: 0.16, max: 160);
    final codeStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -fontSize * 0.04,
      color: Colors.white,
    );

    return _Stage(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: MouseRegion(
              onEnter: (_) => setState(() => _inside = true),
              onExit: (_) => setState(() => _inside = false),
              onHover: reduce
                  ? null
                  : (event) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final local = box.globalToLocal(event.position);
                      setState(() {
                        _pointer = Alignment(
                          (local.dx / box.size.width) * 2 - 1,
                          (local.dy / box.size.height) * 2 - 1,
                        );
                      });
                    },
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A), // neutral-950
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dim base layer.
                    Text(
                      widget.code,
                      style: codeStyle.copyWith(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    // Bright layer, masked to a 220px circle at the pointer
                    // (static white/90 when the effect is off).
                    if (reduce || !_inside)
                      Text(
                        widget.code,
                        style: codeStyle.copyWith(
                          color: Colors.white.withValues(
                            alpha: reduce ? 0.9 : 0.0,
                          ),
                        ),
                      )
                    else
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => RadialGradient(
                          center: _pointer,
                          radius: 220 / bounds.shortestSide,
                          colors: const [Colors.black, Colors.transparent],
                          stops: const [0.25, 0.72],
                        ).createShader(bounds),
                        child: Text(widget.code, style: codeStyle),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _Copy(title: widget.title, description: widget.description),
        _Actions(
          homeLabel: widget.homeLabel,
          browseLabel: widget.browseLabel,
          onHome: widget.onHome,
          onBrowse: widget.onBrowse,
        ),
      ],
    );
  }
}

/// 404 card that fans out of a deck on hover — the Flutter port of the source
/// `NotFoundStacked` (`SPRING_PANEL` throughout).
class BeuiNotFoundStacked extends StatefulWidget {
  /// Creates the stacked variant.
  const BeuiNotFoundStacked({
    this.code = _kCode,
    this.title = _kTitle,
    this.description = _kDescription,
    this.homeLabel = _kHomeLabel,
    this.browseLabel = _kBrowseLabel,
    this.onHome,
    this.onBrowse,
    super.key,
  });

  /// The big status code.
  final String code;

  /// Headline.
  final String title;

  /// Byline.
  final String description;

  /// Primary CTA label.
  final String homeLabel;

  /// Secondary CTA label.
  final String browseLabel;

  /// Primary CTA callback.
  final VoidCallback? onHome;

  /// Secondary CTA callback.
  final VoidCallback? onBrowse;

  @override
  State<BeuiNotFoundStacked> createState() => _BeuiNotFoundStackedState();
}

class _BeuiNotFoundStackedState extends State<BeuiNotFoundStacked> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    BoxDecoration card([List<BoxShadow>? shadow]) => BoxDecoration(
      color: colors.card,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(24),
      boxShadow:
          shadow ??
          const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
    );

    final deck = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: 256, // w-64
        height: 176, // h-44
        // The fan rides one SPRING_PANEL progress (source variants).
        child: SingleMotionBuilder(
          value: _hovered && !reduce ? 1.0 : 0.0,
          motion: motionFor(context, beuiSpringPanel, isMovement: true),
          builder: (context, t, _) => Stack(
            fit: StackFit.expand,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(-28 * t, 8 * t, 0, 1)
                  ..rotateZ(-9 * t * math.pi / 180),
                child: DecoratedBox(decoration: card()),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(28 * t, 8 * t, 0, 1)
                  ..rotateZ(9 * t * math.pi / 180),
                child: DecoratedBox(decoration: card()),
              ),
              Transform.translate(
                offset: Offset(0, -6 * t),
                child: Container(
                  decoration: card(const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        widget.code,
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -2,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        'OUT OF THE DECK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return _Stage(
      children: [
        deck,
        _Copy(title: widget.title, description: widget.description),
        _Actions(
          homeLabel: widget.homeLabel,
          browseLabel: widget.browseLabel,
          onHome: widget.onHome,
          onBrowse: widget.onBrowse,
        ),
      ],
    );
  }
}

/// 404 typed out in a terminal window — the Flutter port of the source
/// `NotFoundTerminal`, composed from [BeuiTextReveal].
class BeuiNotFoundTerminal extends StatelessWidget {
  /// Creates the terminal variant.
  const BeuiNotFoundTerminal({
    this.code = _kCode,
    this.title = _kTitle,
    this.description = _kDescription,
    this.homeLabel = _kHomeLabel,
    this.browseLabel = _kBrowseLabel,
    this.onHome,
    this.onBrowse,
    super.key,
  });

  /// The big status code.
  final String code;

  /// Headline.
  final String title;

  /// Byline.
  final String description;

  /// Primary CTA label.
  final String homeLabel;

  /// Secondary CTA label.
  final String browseLabel;

  /// Primary CTA callback.
  final VoidCallback? onHome;

  /// Secondary CTA callback.
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontSize: 14, height: 1.6, fontFamily: 'monospace');

    Widget dot(Color color) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return _Stage(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448), // max-w-md
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A), // neutral-950
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    spacing: 6,
                    children: [
                      dot(const Color(0xFFFF5F57)),
                      dot(const Color(0xFFFEBC2E)),
                      dot(const Color(0xFF28C840)),
                      const SizedBox(width: 2),
                      Text(
                        '~/beui',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      BeuiTextReveal(
                        r'$ cd /page',
                        split: BeuiTextRevealSplit.char,
                        stagger: const Duration(milliseconds: 18),
                        blur: 6,
                        yOffset: 0,
                        style: mono.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      BeuiTextReveal(
                        'cd: no such file or directory: /page',
                        split: BeuiTextRevealSplit.char,
                        stagger: const Duration(milliseconds: 12),
                        delay: const Duration(milliseconds: 450),
                        blur: 6,
                        yOffset: 0,
                        style: mono.copyWith(color: const Color(0xFFFF5F57)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BeuiTextReveal(
                            '\$ status $code',
                            split: BeuiTextRevealSplit.char,
                            stagger: const Duration(milliseconds: 18),
                            delay: const Duration(milliseconds: 1100),
                            blur: 6,
                            yOffset: 0,
                            style: mono.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: _Cursor(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _Copy(title: title, description: description),
        _Actions(
          homeLabel: homeLabel,
          browseLabel: browseLabel,
          onHome: onHome,
          onBrowse: onBrowse,
        ),
      ],
    );
  }
}

/// The blinking block cursor (source `animate-pulse`: opacity breathing).
/// Static under reduced motion.
class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: 0.4,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 16,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}
