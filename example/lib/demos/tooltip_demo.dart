import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTooltip].
///
/// Mirrors `TooltipPreview`: four labeled triggers arranged as a cross.
Widget tooltipDemo(BuildContext context) {
  if (Uri.base.queryParameters['example'] == 'toolbar') {
    return const _TooltipToolbar();
  }
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

class _TooltipToolbar extends StatefulWidget {
  const _TooltipToolbar();
  @override
  State<_TooltipToolbar> createState() => _TooltipToolbarState();
}

class _TooltipToolbarState extends State<_TooltipToolbar> {
  final _active = <String>{'Bold'};
  static const _actions = [
    (label: 'Bold', shortcut: '⌘B', icon: LucideIcons.bold),
    (label: 'Italic', shortcut: '⌘I', icon: LucideIcons.italic),
    (label: 'Underline', shortcut: '⌘U', icon: LucideIcons.underline),
    (label: 'Strikethrough', shortcut: '⌘⇧X', icon: LucideIcons.strikethrough),
  ];
  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return BeuiTooltipProvider(
      delay: const Duration(milliseconds: 300),
      skipDelay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  for (final action in _actions)
                    BeuiTooltip.composed(
                      asLabel: true,
                      semanticLabel: action.label,
                      trigger: BeuiTooltipTrigger(
                        child: Semantics(
                          toggled: _active.contains(action.label),
                          child: IconButton(
                            onPressed: () => setState(() {
                              if (!_active.remove(action.label)) {
                                _active.add(action.label);
                              }
                            }),
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: _active.contains(action.label)
                                  ? colors.muted
                                  : Colors.transparent,
                              foregroundColor: _active.contains(action.label)
                                  ? colors.foreground
                                  : colors.mutedForeground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(action.icon, size: 16),
                          ),
                        ),
                      ),
                      tooltip: BeuiTooltipContent(
                        side: BeuiTooltipSide.bottom,
                        arrow: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(action.label),
                            const SizedBox(width: 8),
                            ExcludeSemantics(
                              child: Text(
                                action.shortcut,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      height: 20,
                      width: 1,
                      child: ColoredBox(color: colors.border),
                    ),
                  ),
                  BeuiTooltip(
                    asLabel: true,
                    semanticLabel: 'Insert link',
                    disabled: _active.isEmpty,
                    side: BeuiTooltipSide.bottom,
                    align: BeuiTooltipAlign.end,
                    arrow: true,
                    content: const Text('Insert link'),
                    child: IconButton(
                      onPressed: _active.isEmpty ? null : () {},
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        LucideIcons.link_2,
                        size: 16,
                        color: colors.mutedForeground.withValues(
                          alpha: _active.isEmpty ? .4 : 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 320,
              child: Text(
                'The first label waits, the next ones open instantly. Click hides it until the pointer leaves.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            onTap: () {},
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
