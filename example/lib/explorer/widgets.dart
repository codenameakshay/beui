// Small shared chrome widgets used across the explorer pages.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'theme_scope.dart';

/// The teal uppercase "NEW" pill, matching the source badge.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = newAccent(brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: accent,
        ),
      ),
    );
  }
}

/// An uppercase muted section label used above index grids ("NEW", "ALL") and
/// above the sub-sections of an agent-surface demo. [note] adds an optional
/// sentence of muted body text underneath, for demos that need to explain
/// what a section shows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: colors.mutedForeground,
      ),
    );
    if (note == null) return label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 4),
        Text(
          note!,
          style: TextStyle(
            fontSize: 12,
            height: 18 / 12,
            color: colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// The breadcrumb trail, e.g. "Components › Switch".
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.crumbs});

  /// (label, onTap) pairs. A null onTap renders the current (non-clickable) leaf.
  final List<(String, VoidCallback?)> crumbs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final (label, onTap) = crumbs[i];
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              LucideIcons.chevron_right,
              size: 14,
              color: colors.mutedForeground.withValues(alpha: 0.6),
            ),
          ),
        );
      }
      final style = TextStyle(
        fontSize: 14,
        color: onTap == null ? colors.foreground : colors.mutedForeground,
        fontWeight: onTap == null ? FontWeight.w500 : FontWeight.w400,
      );
      children.add(
        onTap == null
            ? Text(label, style: style)
            : InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onTap,
                child: Text(label, style: style),
              ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// A grid card for one catalog entry (title + optional NEW + blurb).
class ExplorerCard extends StatefulWidget {
  const ExplorerCard({super.key, required this.entry, required this.onTap});
  final ExploreEntry entry;
  final VoidCallback onTap;

  @override
  State<ExplorerCard> createState() => _ExplorerCardState();
}

class _ExplorerCardState extends State<ExplorerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hover ? colors.borderStrong : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  if (widget.entry.isNew) ...[
                    const SizedBox(width: 8),
                    const NewBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  widget.entry.blurb,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bordered surface that frames a live demo on a detail page.
class PreviewSurface extends StatelessWidget {
  const PreviewSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 360),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Ghost "Replay" control used across the agent-surface demos to restart a
/// run.
class ReplayButton extends StatelessWidget {
  const ReplayButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        LucideIcons.rotate_ccw,
        size: 12,
        color: colors.mutedForeground,
      ),
      label: Text(
        'Replay',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.mutedForeground,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colors.mutedForeground,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// `Number.prototype.toLocaleString()` for the en-US grouping demos use.
String groupThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// A big page heading (H1) matching the source's 30px / -0.75 tracking.
class PageHeading extends StatelessWidget {
  const PageHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Text(
      text,
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.75,
        height: 1.1,
        color: colors.foreground,
      ),
    );
  }
}
