import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiBreadcrumb].
Widget breadcrumbDemo(BuildContext context) => const _BreadcrumbDemo();

class _BreadcrumbDemo extends StatefulWidget {
  const _BreadcrumbDemo();

  @override
  State<_BreadcrumbDemo> createState() => _BreadcrumbDemoState();
}

class _BreadcrumbDemoState extends State<_BreadcrumbDemo> {
  static const _path = [
    'Workspace',
    'Projects',
    'Website',
    'Design system',
    'Components',
    'Navigation',
    'Breadcrumb',
  ];
  int _depth = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeuiBreadcrumb(
          child: BeuiBreadcrumbList(
            maxItems: 3,
            children: [
              for (var index = 0; index <= _depth; index++)
                BeuiBreadcrumbItem(
                  key: ValueKey(_path[index]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) const BeuiBreadcrumbSeparator(),
                      if (index == _depth)
                        BeuiBreadcrumbPage(child: Text(_path[index]))
                      else
                        BeuiBreadcrumbLink(
                          onPressed: () => setState(() => _depth = index),
                          child: Text(_path[index]),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_depth < _path.length - 1)
          OutlinedButton.icon(
            onPressed: () => setState(() => _depth++),
            icon: const Icon(LucideIcons.folder_closed, size: 16),
            label: Text('Open ${_path[_depth + 1]}'),
          )
        else
          const Text('Choose a parent path to go back.'),
      ],
    );
  }
}
