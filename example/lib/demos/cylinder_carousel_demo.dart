import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCylinderCarousel] — shows both cylinder faces.
///
/// Drag, scroll or use the arrow keys (once focused) to roll each wall. The top
/// carousel is [BeuiCylinderCurve.concave] (centre ball smallest, dipped); the
/// bottom is [BeuiCylinderCurve.convex] (centre ball biggest, raised).
Widget cylinderCarouselDemo(BuildContext context) => const _CylinderDemo();

class _CylinderDemo extends StatelessWidget {
  const _CylinderDemo();

  static const List<List<Color>> _palette = [
    [Color(0xFFB98CFF), Color(0xFF1A1030)],
    [Color(0xFFFF6A3D), Color(0xFFB31A57)],
    [Color(0xFFC8FF00), Color(0xFF3A5A00)],
    [Color(0xFF6A7BFF), Color(0xFF00114D)],
    [Color(0xFFFFD1A8), Color(0xFFB31A57)],
    [Color(0xFF47A6FF), Color(0xFF0A1A2A)],
    [Color(0xFFFFE53D), Color(0xFFFF8247)],
  ];

  List<Widget> _balls() => [
    for (final c in _palette)
      DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c,
          ),
          boxShadow: [
            BoxShadow(
              color: c.first.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _label(colors, 'Concave — inside of the cylinder'),
          _stage(
            colors,
            BeuiCylinderCarousel(
              curve: BeuiCylinderCurve.concave,
              itemSize: 150,
              height: 200,
              children: _balls(),
            ),
          ),
          const SizedBox(height: 32),
          _label(colors, 'Convex — outside of the cylinder'),
          _stage(
            colors,
            BeuiCylinderCarousel(
              curve: BeuiCylinderCurve.convex,
              itemSize: 150,
              height: 200,
              autoRotate: true,
              children: _balls(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Drag, scroll or use arrow keys to roll',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _label(BeuiColors colors, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.mutedForeground,
      ),
    ),
  );

  Widget _stage(BeuiColors colors, Widget child) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: colors.muted.withValues(alpha: 0.2),
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: child,
  );
}
