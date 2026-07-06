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
