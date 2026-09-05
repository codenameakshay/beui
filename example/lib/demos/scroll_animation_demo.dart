import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the scroll-animation group.
///
/// The source page ships five separate previews, one per widget, each a small
/// contained card rather than one composite page — so this mirrors them in
/// order: SmoothScrollPreview, ScrollProgressPreview, ParallaxPreview,
/// ScrollToPreview, ScrollRevealPreview.
Widget scrollAnimationDemo(BuildContext context) => const _ScrollDemo();

/// Source `max-w-lg`.
const double _lg = 512;

/// Source `max-w-2xl`.
const double _xl2 = 672;

class _ScrollDemo extends StatelessWidget {
  const _ScrollDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // Every source preview carries `scrollbar-hide` on its scroll area; the
    // Flutter analogue is a scroll behaviour, not a per-scrollable prop.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SmoothScrollPreview(colors: colors),
          const SizedBox(height: 48),
          _ScrollProgressPreview(colors: colors),
          const SizedBox(height: 48),
          _ParallaxPreview(colors: colors),
          const SizedBox(height: 48),
          _ScrollToPreview(colors: colors),
          const SizedBox(height: 48),
          _ScrollRevealPreview(colors: colors),
        ],
      ),
    );
  }
}

/// Source `rounded-2xl border border-border bg-card`.
BoxDecoration _cardBox(BeuiColors colors) => BoxDecoration(
  color: colors.card,
  border: Border.all(color: colors.border),
  borderRadius: BorderRadius.circular(16),
);

/// Source row: `rounded-lg bg-muted/60 px-3 py-4 text-sm text-muted-foreground`.
Widget _sectionRow(BeuiColors colors, int n) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  decoration: BoxDecoration(
    color: colors.muted.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    'Section $n',
    style: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: colors.mutedForeground,
    ),
  ),
);

// ---------------------------------------------------------------------------
// 1 — SmoothScroll
// ---------------------------------------------------------------------------

/// Source `SmoothScrollPreview`: `root={false}` over an
/// `h-64 w-full max-w-lg rounded-2xl border bg-card` box holding 16 sections
/// and a sticky scroll-to-top button.
class _SmoothScrollPreview extends StatelessWidget {
  const _SmoothScrollPreview({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _lg,
      height: 256, // h-64
      child: DecoratedBox(
        decoration: _cardBox(colors),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BeuiSmoothScroll(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16), // p-4
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var n = 1; n <= 16; n++) ...[
                        if (n > 1) const SizedBox(height: 12), // space-y-3
                        _sectionRow(colors, n),
                      ],
                    ],
                  ),
                ),
                // Source `sticky bottom-3 left-[calc(100%-3rem)] size-9
                // rounded-full border bg-background/80 backdrop-blur`.
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: BeuiScrollTo(
                    to: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.background.withValues(alpha: 0.8),
                        border: Border.all(color: colors.border),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.arrow_up,
                        size: 16,
                        color: colors.foreground,
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// 2 — ScrollProgress
// ---------------------------------------------------------------------------

/// Source `ScrollProgressPreview`: a `max-w-lg` card whose `h-64` scroll area
/// drives a `height={3}` bar pinned to the top and a `size={36}` ring in a
/// `right-3 top-3 rounded-full bg-background/70 p-1` pill.
class _ScrollProgressPreview extends StatelessWidget {
  const _ScrollProgressPreview({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _lg,
      height: 256,
      child: DecoratedBox(
        decoration: _cardBox(colors),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BeuiSmoothScroll(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var n = 1; n <= 18; n++) ...[
                        if (n > 1) const SizedBox(height: 12),
                        _sectionRow(colors, n),
                      ],
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.topCenter,
                  child: BeuiScrollProgress.bar(height: 3),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4), // p-1
                    decoration: BoxDecoration(
                      color: colors.background.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const BeuiScrollProgress.circle(size: 36),
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

// ---------------------------------------------------------------------------
// 3 — Parallax
// ---------------------------------------------------------------------------

/// Source `ParallaxPreview`: an `h-[600px] max-w-2xl` scroll box with an
/// `h-80` spacer, an `h-96` stage carrying three drifting layers at
/// speed -0.6 / 0.5 / 0.9, and a closing `h-80` spacer.
///
/// The source's two layers are remote `picsum.photos` photographs. The package
/// ships no assets, so they are drawn here — a gradient for the
/// backdrop, a solid disc for the avatar. Geometry and drift are the port; the
/// photograph is not reproducible and is not meant to be.
class _ParallaxPreview extends StatelessWidget {
  const _ParallaxPreview({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _xl2,
      height: 600,
      child: DecoratedBox(
        decoration: _cardBox(colors),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BeuiSmoothScroll(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _spacer(colors, 'Scroll down ↓'),
                  SizedBox(
                    height: 384, // h-96
                    child: ClipRect(
                      child: Stack(
                        children: [
                          // Source `absolute inset-x-0 -top-1/4 h-[150%]`.
                          Positioned(
                            left: 0,
                            right: 0,
                            top: -96,
                            height: 576,
                            child: BeuiParallax(
                              speed: -0.6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colors.muted,
                                      colors.foreground.withValues(alpha: 0.28),
                                      colors.muted,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: BeuiParallax(
                              speed: 0.5,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20, // px-5
                                    vertical: 8, // py-2
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.background.withValues(
                                      alpha: 0.85,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Parallax',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: BeuiParallax(
                              speed: 0.9,
                              child: Container(
                                width: 48, // size-12
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colors.mutedForeground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.background,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _spacer(colors, '↑ Scroll up'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _spacer(BeuiColors colors, String label) => SizedBox(
    height: 320, // h-80
    child: Center(
      child: Text(
        label,
        style: TextStyle(fontSize: 14, color: colors.mutedForeground),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 4 — ScrollTo
// ---------------------------------------------------------------------------

/// Source `ScrollToPreview`: an `h-80 max-w-lg` contained SmoothScroll with a
/// sticky nav of four `ScrollTo` pills (`offset={-48}`) over four `h-64`
/// sections.
class _ScrollToPreview extends StatefulWidget {
  const _ScrollToPreview({required this.colors});

  final BeuiColors colors;

  @override
  State<_ScrollToPreview> createState() => _ScrollToPreviewState();
}

class _ScrollToPreviewState extends State<_ScrollToPreview> {
  static const _labels = ['Intro', 'Features', 'Pricing', 'FAQ'];
  final _keys = List.generate(_labels.length, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return SizedBox(
      width: _lg,
      height: 320, // h-80
      child: DecoratedBox(
        decoration: _cardBox(colors),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BeuiSmoothScroll(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // The sticky nav's own height, so section 1 clears it.
                      const SizedBox(height: 45),
                      for (var i = 0; i < _labels.length; i++)
                        SizedBox(
                          key: _keys[i],
                          height: 256, // h-64
                          child: Center(
                            child: Text(
                              _labels[i],
                              style: TextStyle(
                                fontSize: 18, // text-lg
                                fontWeight: FontWeight.w500,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Source `sticky top-0 flex gap-1.5 border-b bg-background/80
                // p-2 backdrop-blur`.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8), // p-2
                    decoration: BoxDecoration(
                      color: colors.background.withValues(alpha: 0.8),
                      border: Border(bottom: BorderSide(color: colors.border)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _labels.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6), // gap-1.5
                          BeuiScrollTo(
                            targetKey: _keys[i],
                            offset: -48,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, // px-3
                                vertical: 4, // py-1
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _labels[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 20 / 14,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// 5 — ScrollReveal
// ---------------------------------------------------------------------------

/// Source `ScrollRevealPreview`: an `h-80 max-w-lg` scroll box, `gap-16 p-6`,
/// four `once={false}` reveals staggered by `i * 0.05`s.
class _ScrollRevealPreview extends StatelessWidget {
  const _ScrollRevealPreview({required this.colors});

  final BeuiColors colors;

  static const _cards = [
    'Spring slide',
    'Blur in',
    'Staggered by delay',
    'Reveal once',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _lg,
      height: 320,
      child: DecoratedBox(
        decoration: _cardBox(colors),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BeuiSmoothScroll(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24), // p-6
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hint('Scroll ↓'),
                  for (var i = 0; i < _cards.length; i++) ...[
                    const SizedBox(height: 64), // gap-16
                    BeuiScrollReveal(
                      once: false,
                      delay: Duration(milliseconds: i * 50),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, // px-4
                          vertical: 64, // py-16
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.muted.withValues(alpha: 0.5),
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(12), // rounded-xl
                        ),
                        child: Text(
                          _cards[i],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 64),
                  _hint('End'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(String label) => Text(
    label,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 14, color: colors.mutedForeground),
  );
}
