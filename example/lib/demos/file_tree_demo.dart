import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiFileTree].
Widget fileTreeDemo(BuildContext context) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 280),
    child: const BeuiFileTree(
      defaultValue: 'file-tree',
      defaultExpandedIds: ['app', 'components'],
      ariaLabel: 'Project files',
      children: [
        BeuiFileTreeFolder(
          value: 'app',
          name: 'app',
          icon: Icon(LucideIcons.folder_closed, color: Color(0xFF60A5FA)),
          children: [
            BeuiFileTreeFolder(
              value: 'components',
              name: 'components',
              icon: Icon(LucideIcons.folder_closed, color: Color(0xFF60A5FA)),
              children: [
                BeuiFileTreeFile(
                  value: 'file-tree',
                  name: 'file-tree.tsx',
                  icon: Icon(LucideIcons.file_code, color: Color(0xFF60A5FA)),
                ),
                BeuiFileTreeFile(
                  value: 'button',
                  name: 'button.tsx',
                  icon: Icon(LucideIcons.file_code, color: Color(0xFF60A5FA)),
                ),
              ],
            ),
            BeuiFileTreeFile(
              value: 'page',
              name: 'page.tsx',
              icon: Icon(LucideIcons.file_code, color: Color(0xFF60A5FA)),
            ),
            BeuiFileTreeFile(
              value: 'styles',
              name: 'globals.css',
              icon: Icon(LucideIcons.file_code, color: Color(0xFF38BDF8)),
            ),
          ],
        ),
        BeuiFileTreeFolder(
          value: 'public',
          name: 'public',
          icon: Icon(LucideIcons.folder_closed, color: Color(0xFF60A5FA)),
          children: [
            BeuiFileTreeFile(
              value: 'logo',
              name: 'logo.svg',
              icon: Icon(LucideIcons.file_image, color: Color(0xFFA78BFA)),
            ),
            BeuiFileTreeFile(
              value: 'grid',
              name: 'grid.svg',
              icon: Icon(LucideIcons.file_image, color: Color(0xFFA78BFA)),
            ),
          ],
        ),
        BeuiFileTreeFile(
          value: 'package',
          name: 'package.json',
          icon: Icon(LucideIcons.file_braces, color: Color(0xFFFBBF24)),
        ),
        BeuiFileTreeFile(
          value: 'readme',
          name: 'README.md',
          icon: Icon(LucideIcons.file_text, color: Color(0xFF9CA3AF)),
        ),
      ],
    ),
  ),
);
