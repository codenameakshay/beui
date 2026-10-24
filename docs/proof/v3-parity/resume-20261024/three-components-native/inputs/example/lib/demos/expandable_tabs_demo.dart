import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiExpandableTabs] — mirrors
/// `expandable-tabs.preview.tsx`: five icon tabs, each blooming a menu of
/// icon + label + chevron rows.
Widget expandableTabsDemo(BuildContext context) => const _ExpandableTabsDemo();

/// One `Row` from the source preview: `gap-3 rounded-xl px-3 py-2.5 text-sm`
/// with a muted leading icon and a trailing chevron.
class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? colors.muted : null,
          borderRadius: BorderRadius.circular(12), // rounded-xl
        ),
        child: Row(
          spacing: 12, // gap-3
          children: [
            Icon(widget.icon, size: 16, color: colors.mutedForeground),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0, // tracking-normal
                  color: colors.foreground,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevron_right,
              size: 16,
              color: colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// The source `Menu`: `w-[17.125rem] flex-col gap-0.5`.
Widget _menu(List<(IconData, String)> rows) => SizedBox(
  width: 274,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 2, // gap-0.5
    children: [
      for (final (icon, label) in rows) _MenuRow(icon: icon, label: label),
    ],
  ),
);

class _ExpandableTabsDemo extends StatelessWidget {
  const _ExpandableTabsDemo();

  @override
  Widget build(BuildContext context) => Align(
    // Source wrapper: `flex min-h-88 w-full items-end justify-center`.
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 352), // min-h-88
      child: Align(
        alignment: Alignment.bottomCenter,
        child: BeuiExpandableTabs(
          items: [
            BeuiExpandableTabsItem(
              id: 'launch',
              label: 'Launch',
              icon: LucideIcons.rocket,
              content: _menu(const [
                (LucideIcons.file_text, 'Release Brief'),
                (LucideIcons.clipboard_check, 'Launch Checklist'),
                (LucideIcons.megaphone, 'Campaign Notes'),
                (LucideIcons.calendar_clock, 'Rollout Calendar'),
                (LucideIcons.cloud_upload, 'Ship Build'),
              ]),
            ),
            BeuiExpandableTabsItem(
              id: 'inbox',
              label: 'Inbox',
              icon: LucideIcons.inbox,
              content: _menu(const [
                (LucideIcons.message_circle, 'Client Feedback'),
                (LucideIcons.users, 'Team Requests'),
                (LucideIcons.badge_check, 'Approval Notes'),
              ]),
            ),
            BeuiExpandableTabsItem(
              id: 'flows',
              label: 'Flows',
              icon: LucideIcons.workflow,
              content: _menu(const [
                (LucideIcons.git_branch, 'Trigger Map'),
                (LucideIcons.webhook, 'Webhook Runs'),
                (LucideIcons.refresh_cw, 'Retry Queue'),
              ]),
            ),
            BeuiExpandableTabsItem(
              id: 'assets',
              label: 'Assets',
              icon: LucideIcons.package_open,
              content: _menu(const [
                (LucideIcons.swatch_book, 'Brand Kit'),
                (LucideIcons.images, 'Mockup Library'),
                (LucideIcons.brush, 'Design Tokens'),
                (LucideIcons.cloud_upload, 'Export Queue'),
              ]),
            ),
            BeuiExpandableTabsItem(
              id: 'status',
              label: 'Status',
              icon: LucideIcons.chart_spline,
              content: _menu(const [
                (LucideIcons.gauge, 'Activation'),
                (LucideIcons.chart_spline, 'Conversion'),
                (LucideIcons.siren, 'Incidents'),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}
