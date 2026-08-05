import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the scroll-animation group: a smooth-scroll page with a
/// progress bar + ring, parallax layers, scroll reveals, and scroll-to
/// buttons.
Widget scrollAnimationDemo(BuildContext context) => const _ScrollDemo();

class _ScrollDemo extends StatefulWidget {
  const _ScrollDemo();

  @override
  State<_ScrollDemo> createState() => _ScrollDemoState();
}

class _ScrollDemoState extends State<_ScrollDemo> {
  final GlobalKey _revealSection = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return BeuiSmoothScroll(
      child: Builder(
        builder: (context) => Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 420,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Scroll down',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 16),
                          BeuiScrollTo(
                            targetKey: _revealSection,
                            offset: -24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Glide to the reveals',
                                style: TextStyle(
                                  color: colors.primaryForeground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  BeuiParallax(
                    speed: -0.25,
                    child: _card(colors, 'Parallax (background, speed -0.25)'),
                  ),
                  const SizedBox(height: 120),
                  BeuiParallax(
                    speed: 0.3,
                    child: _card(colors, 'Parallax (foreground, speed 0.3)'),
                  ),
                  const SizedBox(height: 120),
                  _HorizontalStrip(colors: colors),
                  const SizedBox(height: 240),
                  KeyedSubtree(
                    key: _revealSection,
                    child: Column(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: BeuiScrollReveal(
                              delay: Duration(milliseconds: 80 * i),
                              child: _card(colors, 'Scroll reveal #${i + 1}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 160),
                  BeuiScrollTo(
                    to: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 240),
                      child: Text(
                        'Back to top ↑',
                        style: TextStyle(
                          color: colors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: BeuiScrollProgress.bar(),
            ),
            const Positioned(
              right: 16,
              bottom: 16,
              child: BeuiScrollProgress.circle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BeuiColors colors, String label) => Container(
    width: 320,
    height: 96,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colors.card,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: TextStyle(color: colors.foreground, fontSize: 14),
    ),
  );
}

/// A horizontal [BeuiSmoothScroll] nested inside the vertical page.
///
/// Shows the three knobs that only exist off the default axis: the provider
/// binds to the horizontal scrollable (so the ring/bar inside it report *this*
/// strip's progress, not the page's), a plain vertical mouse wheel scrolls it
/// via `orientation`, `wheelMultiplier` speeds that up, and `touch` routes the
/// fling through the lerp settle instead of platform friction.
class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return BeuiSmoothScroll(
      orientation: BeuiSmoothScrollOrientation.horizontal,
      wheelMultiplier: 1.6,
      touch: true,
      lerp: 0.08,
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HORIZONTAL · wheel over the strip',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => Container(
                  width: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.card,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Frame ${i + 1}',
                    style: TextStyle(color: colors.foreground, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // No `progress` override: it reads the enclosing horizontal
            // provider, proving the axis binding.
            const BeuiScrollProgress.bar(spring: false),
          ],
        ),
      ),
    );
  }
}
