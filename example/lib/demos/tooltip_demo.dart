import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTooltip].
///
/// Mirrors `TooltipPreview`: four round icon buttons, one per side, above a
/// caption. `flex flex-col items-center gap-12` (48px) wrapping a
/// `flex flex-wrap items-center justify-center gap-4` (16px) row.
Widget tooltipDemo(BuildContext context) {
  final colors = Theme.of(context).extension<BeuiColors>()!;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16, // gap-4
        runSpacing: 16,
        children: [
          for (final (side, label, icon) in const [
            (BeuiTooltipSide.top, 'Top', LucideIcons.arrow_up),
            (BeuiTooltipSide.left, 'Left', LucideIcons.arrow_left),
            (BeuiTooltipSide.right, 'Right', LucideIcons.arrow_right),
            (BeuiTooltipSide.bottom, 'Bottom', LucideIcons.arrow_down),
          ])
            BeuiTooltip(
              side: side,
              arrow: true,
              content: const Text('More context'),
              child: _TooltipTrigger(
                icon: icon,
                semanticLabel: label,
                label: label,
              ),
            ),
        ],
      ),
      const SizedBox(height: 48), // gap-12
      Text(
        'Hover or focus. Press Esc to dismiss.',
        style: TextStyle(
          fontSize: 12, // text-xs
          color: colors.mutedForeground,
        ),
      ),
    ],
  );
}

/// The tooltip preview's trigger — preview chrome, not a beUI component:
/// `h-10 w-10 rounded-full border border-border bg-card` around an `h-4 w-4`
/// icon.
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
        child: Container(
          width: 80,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.card,
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
    );
  }
}
