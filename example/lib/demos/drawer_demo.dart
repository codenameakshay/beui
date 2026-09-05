import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiDrawer].
Widget drawerDemo(BuildContext context) => const _DrawerDemo();

/// Exercises the modal drawer from either edge.
class _DrawerDemo extends StatefulWidget {
  const _DrawerDemo();

  @override
  State<_DrawerDemo> createState() => _DrawerDemoState();
}

class _DrawerDemoState extends State<_DrawerDemo> {
  bool _open = false;
  BeuiDrawerSide _side = BeuiDrawerSide.right;

  void _show(BeuiDrawerSide side) => setState(() {
    _side = side;
    _open = true;
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Stack(
      children: [
        // DrawerPreview: `flex items-center gap-3` — "Open left" is the
        // bordered card pill, "Open right" the filled primary one.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiButton(
              variant: BeuiButtonVariant.secondary,
              onPressed: () => _show(BeuiDrawerSide.left),
              child: const Text('Open left'),
            ),
            BeuiButton(
              onPressed: () => _show(BeuiDrawerSide.right),
              child: const Text('Open right'),
            ),
          ],
        ),
        BeuiDrawer(
          open: _open,
          side: _side,
          label: 'Menu',
          onOpenChange: (v) => setState(() => _open = v),
          // The source panel is `className="gap-4 p-6"` holding just a
          // `text-sm font-semibold` heading and a `text-sm text-muted-
          // foreground` paragraph — not a nav list.
          child: Padding(
            padding: const EdgeInsets.all(24), // p-6
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Drawer',
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 16), // gap-4
                Text(
                  'Slides in from the ${_side == BeuiDrawerSide.left ? 'left' : 'right'}. '
                  'Press Esc or click outside to close.',
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    height: 20 / 14,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
