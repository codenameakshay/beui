import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCombobox].
Widget comboboxDemo(BuildContext context) => const _ComboboxDemo();

const _workspaces =
    <({String value, String label, String detail, String group})>[
      (
        value: 'studio',
        label: 'Design studio',
        detail: '12 projects',
        group: 'Recent',
      ),
      (
        value: 'product',
        label: 'Product team',
        detail: '8 projects',
        group: 'Recent',
      ),
      (
        value: 'playground',
        label: 'Playground',
        detail: '24 experiments',
        group: 'Workspaces',
      ),
      (
        value: 'archive',
        label: 'Component archive',
        detail: '41 components',
        group: 'Workspaces',
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
  Widget build(BuildContext context) => SizedBox(
    width: 288,
    child: BeuiCombobox(
      value: _value,
      onValueChange: (value) => setState(() => _value = value),
      trigger: const BeuiComboboxTrigger(
        child: BeuiComboboxInput(label: 'Search workspaces'),
      ),
      content: BeuiComboboxContent(
        child: BeuiComboboxList(
          ariaLabel: 'Workspaces',
          children: <Widget>[
            const BeuiComboboxEmpty(),
            for (final group in <String>['Recent', 'Workspaces'])
              BeuiComboboxGroup(
                label: group,
                children: <Widget>[
                  if (group == 'Workspaces') const BeuiComboboxSeparator(),
                  for (final workspace in _workspaces.where(
                    (item) => item.group == group,
                  ))
                    BeuiComboboxItem(
                      value: workspace.value,
                      textValue: workspace.label,
                      keywords: <String>[workspace.detail, workspace.group],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            workspace.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            workspace.detail,
                            style: const TextStyle(fontSize: 11),
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
  );
}
