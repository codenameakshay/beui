import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPopover] — mirrors the source `popover.preview.tsx`:
/// a click popover (bottom/start) carrying the Dimensions form, beside a hover
/// popover (top) carrying a short note.
Widget popoverDemo(BuildContext context) => const _PopoverDemo();

class _PopoverDemo extends StatelessWidget {
  const _PopoverDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // Source: h-8 w-32 rounded-lg border bg-background px-2.5 text-sm.
    Widget field(String value) => Container(
      height: 32,
      width: 128,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(fontSize: 14, color: colors.foreground),
      ),
    );

    Widget labelledField(String label, String value) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.mutedForeground),
        ),
        const SizedBox(width: 12),
        field(value),
      ],
    );

    // Tailwind widths are border-box: the source's `w-72` panel is 288px
    // *including* its own `p-4`. BeuiPopover adds that 16px padding around the
    // child, so the child asks for 288 - 32.
    final dimensions = SizedBox(
      width: 256, // w-72 (288) less the panel's p-4 gutters
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dimensions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4), // mt-1
          Text(
            'Set the width and height for the layer.',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
          const SizedBox(height: 12), // mt-3
          labelledField('Width', '100%'),
          const SizedBox(height: 8), // gap-2
          labelledField('Height', 'auto'),
        ],
      ),
    );

    final hoverNote = SizedBox(
      width: 192, // w-56 (224) less the panel's p-4 gutters
      child: Text(
        'Opens on hover, with a grace window so you can move into the panel.',
        style: TextStyle(fontSize: 14, height: 1.45, color: colors.foreground),
      ),
    );

    return Center(
      child: Wrap(
        spacing: 16, // gap-4
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          BeuiPopover(
            align: BeuiPopoverAlign.start,
            content: dimensions,
            child: const BeuiButton(
              variant: BeuiButtonVariant.secondary,
              child: Text('Edit profile'),
            ),
          ),
          BeuiPopover(
            trigger: BeuiPopoverTrigger.hover,
            side: BeuiPopoverSide.top,
            content: hoverNote,
            child: const BeuiButton(
              variant: BeuiButtonVariant.outline,
              child: Text('Hover me'),
            ),
          ),
        ],
      ),
    );
  }
}
