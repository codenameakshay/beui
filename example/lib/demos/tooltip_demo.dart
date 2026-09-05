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
          for (final (side, content, icon) in const [
            (BeuiTooltipSide.top, 'Like this post', LucideIcons.heart),
            (BeuiTooltipSide.bottom, 'Share', LucideIcons.share),
            (BeuiTooltipSide.left, 'Open settings', LucideIcons.settings),
            (BeuiTooltipSide.right, 'Move to trash', LucideIcons.trash),
          ])
            BeuiTooltip(
              side: side,
              content: Text(content),
              child: _TooltipTrigger(icon: icon, semanticLabel: content),
            ),
        ],
      ),
      const SizedBox(height: 48), // gap-12
      Text(
        'Hover or focus each button. Content fades and un-blurs in.',
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
  const _TooltipTrigger({required this.icon, required this.semanticLabel});

  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 40, // w-10
          height: 40, // h-10
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: colors.foreground), // h-4 w-4
        ),
      ),
    );
  }
}
