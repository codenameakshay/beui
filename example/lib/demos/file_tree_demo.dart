import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiFileTree].
Widget fileTreeDemo(BuildContext context) => const BeuiFileTree(
  defaultValue: 'file-tree',
  defaultExpandedIds: ['app', 'components'],
  ariaLabel: 'Project files',
  children: [
    BeuiFileTreeFolder(
      value: 'app',
      name: 'app',
      children: [
        BeuiFileTreeFolder(
          value: 'components',
          name: 'components',
          children: [
            BeuiFileTreeFile(value: 'file-tree', name: 'file_tree.dart'),
            BeuiFileTreeFile(value: 'button', name: 'button.dart'),
          ],
        ),
        BeuiFileTreeFile(value: 'page', name: 'page.dart'),
        BeuiFileTreeFile(value: 'styles', name: 'globals.css'),
      ],
    ),
    BeuiFileTreeFolder(
      value: 'public',
      name: 'public',
      children: [
        BeuiFileTreeFile(value: 'logo', name: 'logo.svg'),
        BeuiFileTreeFile(value: 'grid', name: 'grid.svg'),
      ],
    ),
    BeuiFileTreeFile(value: 'package', name: 'package.json'),
    BeuiFileTreeFile(value: 'readme', name: 'README.md'),
  ],
);
