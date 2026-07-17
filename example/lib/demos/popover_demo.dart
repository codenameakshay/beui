import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPopover] — the gooey popover oozing a panel out of
/// the trigger on click and on hover.
Widget popoverDemo(BuildContext context) => const _PopoverDemo();

class _PopoverDemo extends StatelessWidget {
  const _PopoverDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget triggerPill(String label) => Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.popover,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.popoverForeground,
        ),
      ),
    );

    Widget panel() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share this page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.popoverForeground,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 200,
          child: Text(
            'Anyone with the link can view. The panel oozes out of the trigger.',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Click to open (tap outside or Esc to close):'),
        const SizedBox(height: 24),
        BeuiPopover(content: panel(), child: triggerPill('Click me')),
        const SizedBox(height: 80),
        const Text('Opens above, end-aligned:'),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: BeuiPopover(
            side: BeuiPopoverSide.top,
            align: BeuiPopoverAlign.end,
            content: panel(),
            child: triggerPill('Above'),
          ),
        ),
      ],
    );
  }
}
