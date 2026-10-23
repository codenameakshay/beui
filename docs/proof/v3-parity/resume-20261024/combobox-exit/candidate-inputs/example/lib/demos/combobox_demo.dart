import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCombobox].
Widget comboboxDemo(BuildContext context) => const _ComboboxDemo();

const _workspaces =
    <
      ({
        String value,
        String label,
        String detail,
        String group,
        Color mark,
        Color light,
        Color dark,
        IconData icon,
      })
    >[
      (
        value: 'studio',
        label: 'Design studio',
        detail: '12 projects',
        group: 'Recent',
        mark: Color(0xFFFBBF24),
        light: Color(0xFFB45309),
        dark: Color(0xFFFCD34D),
        icon: LucideIcons.component,
      ),
      (
        value: 'product',
        label: 'Product team',
        detail: '8 projects',
        group: 'Recent',
        mark: Color(0xFF38BDF8),
        light: Color(0xFF0369A1),
        dark: Color(0xFF7DD3FC),
        icon: LucideIcons.layers,
      ),
      (
        value: 'playground',
        label: 'Playground',
        detail: '24 experiments',
        group: 'Workspaces',
        mark: Color(0xFF34D399),
        light: Color(0xFF047857),
        dark: Color(0xFF6EE7B7),
        icon: LucideIcons.blocks,
      ),
      (
        value: 'archive',
        label: 'Component archive',
        detail: '41 components',
        group: 'Workspaces',
        mark: Color(0xFFFB7185),
        light: Color(0xFFBE123C),
        dark: Color(0xFFFDA4AF),
        icon: LucideIcons.box,
      ),
    ];

class _ComboboxDemo extends StatefulWidget {
  const _ComboboxDemo();

  @override
  State<_ComboboxDemo> createState() => _ComboboxDemoState();
}

class _ComboboxDemoState extends State<_ComboboxDemo> {
  String? _value = 'studio';

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 288,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workspace',
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: BeuiColors.resolve(context).mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          BeuiCombobox(
            value: _value,
            onValueChange: (value) => setState(() => _value = value),
            trigger: const BeuiComboboxTrigger(
              height: 48,
              radius: 16,
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: BeuiComboboxInput(
                label: 'Search workspaces',
                hintText: 'Search workspaces…',
              ),
            ),
            content: BeuiComboboxContent(
              child: BeuiComboboxList(
                ariaLabel: 'Workspaces',
                children: <Widget>[
                  const BeuiComboboxEmpty(child: Text('No workspaces found.')),
                  for (final group in <String>['Recent', 'Workspaces'])
                    BeuiComboboxGroup(
                      label: group,
                      children: <Widget>[
                        if (group == 'Workspaces')
                          const BeuiComboboxSeparator(),
                        for (final workspace in _workspaces.where(
                          (item) => item.group == group,
                        ))
                          BeuiComboboxItem(
                            value: workspace.value,
                            textValue: workspace.label,
                            keywords: <String>[
                              workspace.detail,
                              workspace.group,
                            ],
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: workspace.mark.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    workspace.icon,
                                    size: 14,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? workspace.dark
                                        : workspace.light,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        workspace.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          height: 20 / 14,
                                        ),
                                      ),
                                      Text(
                                        workspace.detail,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 16 / 12,
                                          color: BeuiColors.resolve(
                                            context,
                                          ).mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
