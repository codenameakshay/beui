import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiDock].
Widget dockDemo(BuildContext context) => const _DockDemo();

/// The dock: faithful by default (flat bar + gliding active pill), with an
/// opt-in `magnify: true` variant below showing the Flutter-only enhancement.
class _DockDemo extends StatefulWidget {
  const _DockDemo();

  @override
  State<_DockDemo> createState() => _DockDemoState();
}

class _DockDemoState extends State<_DockDemo> {
  String _active = 'home';

  static const _items = <(String, IconData)>[
    ('home', LucideIcons.house),
    ('mail', LucideIcons.mail),
    ('calendar', LucideIcons.calendar),
    ('music', LucideIcons.music),
    ('discover', LucideIcons.sparkles),
  ];

  List<BeuiDockItem> _buildItems() => [
    for (final (id, icon) in _items)
      BeuiDockItem(
        icon: icon,
        tooltip: id,
        active: _active == id,
        onTap: () => setState(() => _active = id),
      ),
    // Groups the settings action away from the five navigation actions
    // (source: DockSeparator).
    const BeuiDockItem.separator(),
    BeuiDockItem(
      icon: LucideIcons.settings,
      tooltip: 'settings',
      active: _active == 'settings',
      onTap: () => setState(() => _active = 'settings'),
    ),
    // Source: a trailing GitHub item that carries its own link, so it has no
    // active state and never joins the pill's selection. Lucide dropped brand
    // marks, so the source's inline `GithubIcon` svg ports to a CustomPaint
    // (hand-drawn marks are painted, never bundled as assets).
    const BeuiDockItem(child: _GithubMark(), tooltip: 'GitHub'),
  ];

  @override
  Widget build(BuildContext context) {
    // Mirrors DockPreview: a single, source-faithful dock, centred.
    return Center(child: BeuiDock(items: _buildItems()));
  }
}

/// The source's inline GitHub mark (`components/app/icons.tsx`), transcribed
/// from its 24x24 `fill-rule: evenodd` path. Painted rather than shipped as an
/// asset, and sized like the source's `h-5 w-5`.
class _GithubMark extends StatelessWidget {
  const _GithubMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GithubMarkPainter(colors.foreground),
    );
  }
}

class _GithubMarkPainter extends CustomPainter {
  const _GithubMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(12, 0.5)
      ..cubicTo(5.65, 0.5, 0.5, 5.65, 0.5, 12.02)
      ..cubicTo(0.5, 17.12, 3.79, 21.45, 8.36, 22.98)
      ..cubicTo(8.94, 23.08, 9.15, 22.73, 9.15, 22.42)
      ..lineTo(9.15, 20.41)
      ..cubicTo(5.95, 21.11, 5.28, 18.87, 5.28, 18.87)
      ..cubicTo(4.76, 17.54, 4.01, 17.19, 4.01, 17.19)
      ..cubicTo(2.97, 16.48, 4.09, 16.5, 4.09, 16.5)
      ..cubicTo(5.24, 16.58, 5.85, 17.68, 5.85, 17.68)
      ..cubicTo(6.87, 19.44, 8.53, 18.93, 9.19, 18.64)
      ..cubicTo(9.29, 17.9, 9.59, 17.39, 9.92, 17.1)
      ..cubicTo(7.37, 16.81, 4.68, 15.82, 4.68, 11.41)
      ..cubicTo(4.68, 10.15, 5.13, 9.12, 5.86, 8.31)
      ..cubicTo(5.74, 8.02, 5.35, 6.85, 5.97, 5.27)
      ..cubicTo(5.97, 5.27, 6.93, 4.96, 9.12, 6.45)
      ..cubicTo(10.03, 6.2, 11.01, 6.07, 11.99, 6.06)
      ..cubicTo(12.96, 6.06, 13.95, 6.19, 14.86, 6.45)
      ..cubicTo(17.05, 4.96, 18.01, 5.27, 18.01, 5.27)
      ..cubicTo(18.63, 6.85, 18.24, 8.02, 18.12, 8.31)
      ..cubicTo(18.86, 9.12, 19.3, 10.15, 19.3, 11.41)
      ..cubicTo(19.3, 15.83, 16.6, 16.81, 14.03, 17.09)
      ..cubicTo(14.45, 17.45, 14.81, 18.16, 14.81, 19.25)
      ..lineTo(14.81, 22.45)
      ..cubicTo(14.81, 22.76, 15.02, 23.12, 15.61, 23.01)
      ..cubicTo(20.18, 21.48, 23.46, 17.15, 23.46, 12.05)
      ..cubicTo(23.5, 5.65, 18.35, 0.5, 12, 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GithubMarkPainter old) => old.color != color;
}
