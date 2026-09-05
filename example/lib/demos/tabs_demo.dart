import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTabs].
Widget tabsDemo(BuildContext context) => const _TabsDemo();

/// Exercises all three tab variants and a fading content panel.
class _TabsDemo extends StatefulWidget {
  const _TabsDemo();

  @override
  State<_TabsDemo> createState() => _TabsDemoState();
}

class _TabsDemoState extends State<_TabsDemo> {
  // Mirrors TabsPreview: three independently-stated groups, one per variant,
  // each under an uppercase section label.
  String _pill = 'overview';
  String _segment = 'day';
  String _underline = 'all';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // `text-sm text-muted-foreground` — 14px on a 20px line box.
    final body = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: colors.mutedForeground,
    );

    // Outer `flex w-full max-w-md flex-col gap-8` (448px wide, 32px gaps).
    //
    // Align first: SizedBox narrows to the parent only when the incoming
    // constraints are loose. Under a tight full-stage width it enforces the
    // other way and is widened past 448, which is not what `max-w-md` means.
    // Align loosens; it is a no-op when the parent is already loose.
    return Align(
      child: SizedBox(
        width: 448,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _tabsSection(
              colors,
              'Pill',
              BeuiTabs<String>(
                variant: BeuiTabsVariant.pill,
                value: _pill,
                onChanged: (v) => setState(() => _pill = v),
                tabs: [
                  BeuiTab(
                    value: 'overview',
                    label: const Text('Overview'),
                    content: Text('High-level summary.', style: body),
                  ),
                  BeuiTab(
                    value: 'activity',
                    label: const Text('Activity'),
                    content: Text('Recent events.', style: body),
                  ),
                  BeuiTab(
                    value: 'settings',
                    label: const Text('Settings'),
                    content: Text('Preferences.', style: body),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _tabsSection(
              colors,
              'Segment',
              BeuiTabs<String>(
                variant: BeuiTabsVariant.segment,
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
                tabs: const [
                  BeuiTab(value: 'day', label: Text('Day')),
                  BeuiTab(value: 'week', label: Text('Week')),
                  BeuiTab(value: 'month', label: Text('Month')),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _tabsSection(
              colors,
              'Underline',
              BeuiTabs<String>(
                variant: BeuiTabsVariant.underline,
                value: _underline,
                onChanged: (v) => setState(() => _underline = v),
                tabs: const [
                  BeuiTab(value: 'all', label: Text('All')),
                  BeuiTab(value: 'open', label: Text('Open')),
                  BeuiTab(value: 'closed', label: Text('Closed')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `flex flex-col gap-2` under a `text-[10px] font-semibold uppercase
  /// tracking-wider text-muted-foreground` caption.
  Widget _tabsSection(BeuiColors colors, String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5, // tracking-wider (0.05em)
          // `text-[10px]` sets font-size only; the 1.5 line-height is
          // inherited, giving a 15px line box (not Roboto's default 12).
          height: 1.5,
          color: colors.mutedForeground,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}
