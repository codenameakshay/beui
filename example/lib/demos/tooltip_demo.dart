import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTooltip].
///
/// Mirrors `TooltipPreview`: four labeled triggers arranged as a cross.
Widget tooltipDemo(BuildContext context) {
  final colors = Theme.of(context).extension<BeuiColors>()!;
  return BeuiTooltipProvider(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(
              _emptyCell(),
              _tooltip(BeuiTooltipSide.top, 'Top', LucideIcons.arrow_up),
              _emptyCell(),
            ),
            const SizedBox(height: 20),
            _row(
              _tooltip(BeuiTooltipSide.left, 'Left', LucideIcons.arrow_left),
              _emptyCell(),
              _tooltip(BeuiTooltipSide.right, 'Right', LucideIcons.arrow_right),
            ),
            const SizedBox(height: 20),
            _row(
              _emptyCell(),
              _tooltip(
                BeuiTooltipSide.bottom,
                'Bottom',
                LucideIcons.arrow_down,
              ),
              _emptyCell(),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Hover or focus. Press Esc to dismiss.',
          style: TextStyle(
            fontSize: 12, // text-xs
            color: colors.mutedForeground,
          ),
        ),
      ],
    ),
  );
}

Widget _emptyCell() => const SizedBox(width: 80, height: 40);

Widget _row(Widget left, Widget middle, Widget right) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    left,
    const SizedBox(width: 12),
    middle,
    const SizedBox(width: 12),
    right,
  ],
);

Widget _tooltip(BeuiTooltipSide side, String label, IconData icon) =>
    BeuiTooltip(
      side: side,
      arrow: true,
      content: const Text('More context'),
      child: _TooltipTrigger(icon: icon, semanticLabel: label, label: label),
    );

/// The source preview's 80 by 40 trigger with a 14-pixel icon.
class _TooltipTrigger extends StatelessWidget {
  const _TooltipTrigger({
    required this.icon,
    required this.semanticLabel,
    required this.label,
  });

  final IconData icon;
  final String semanticLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            hoverColor: colors.muted,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: colors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
