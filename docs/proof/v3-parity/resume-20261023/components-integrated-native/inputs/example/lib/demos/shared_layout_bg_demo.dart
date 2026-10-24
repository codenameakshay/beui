import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSharedLayoutBg].
Widget sharedLayoutDemo(BuildContext context) {
  const items = [
    ('Inbox', '12 unread threads, 3 mentions today.'),
    ('Drafts', '4 posts waiting for a final pass.'),
    ('Releases', 'Last shipped 2 days ago, v0.4.1.'),
    ('Billing', 'Plan renews on the 1st of next month.'),
  ];
  // Mirrors SharedLayoutBgPreview: `w-full max-w-lg px-2` (512px cap, 8px
  // horizontal padding) around the row list.
  //
  // Align first: SizedBox enforces its width against the incoming constraints,
  // so under a tight full-stage width it is widened past 512 rather than
  // capped. Align loosens, and is a no-op when the parent is already loose.
  return Align(
    child: SizedBox(
      width: 512,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: BeuiSharedLayoutBg(
          children: [
            for (final (title, body) in items)
              _SharedRow(title: title, body: body),
          ],
        ),
      ),
    ),
  );
}

/// A list row whose trailing arrow nudges up-right on hover (the source's
/// `group-hover:translate-x-0.5 -translate-y-0.5`).
class _SharedRow extends StatefulWidget {
  const _SharedRow({required this.title, required this.body});
  final String title;
  final String body;

  @override
  State<_SharedRow> createState() => _SharedRowState();
}

class _SharedRowState extends State<_SharedRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14, // text-sm — 20px line box
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
                AnimatedSlide(
                  offset: _hovered ? const Offset(0.14, -0.14) : Offset.zero,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Icon(
                    LucideIcons.arrow_up_right,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
            // Two stacked text-sm line boxes and `py-3` make the row 64px on
            // beui.dev (12 + 20 + 20 + 12), which is what the hover pill
            // measures there. Relying on Geist's natural ~19px line height
            // plus a 4px spacer put the row at 68 and the title-to-body step
            // at 23px instead of the site's 20.
            Text(
              widget.body,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
