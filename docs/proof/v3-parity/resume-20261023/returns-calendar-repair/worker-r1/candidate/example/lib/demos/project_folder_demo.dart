import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the project folder's source preview.
Widget projectFolderDemo(BuildContext context) => const _ProjectFolderDemo();

class _ProjectFolderDemo extends StatelessWidget {
  const _ProjectFolderDemo();

  static const _previewColors = [
    Color(0xffa7f3d0),
    Color(0xfffed7aa),
    Color(0xffbae6fd),
    Color(0xffddd6fe),
    Color(0xfffef3c7),
  ];

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 320),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(child: _FolderPreview()),
    ),
  );
}

class _FolderPreview extends StatelessWidget {
  const _FolderPreview();

  @override
  Widget build(BuildContext context) => BeuiProjectFolder(
    title: 'Brand direction',
    description: 'Updated recently',
    count: 5,
    previews: [
      for (var i = 0; i < _ProjectFolderDemo._previewColors.length; i++)
        BeuiProjectFolderPreview(
          id: 'project-folder-${'ABCDE'[i]}',
          content: ColoredBox(
            color: _ProjectFolderDemo._previewColors[i],
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    width: 32,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 32,
                  child: Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 44,
                  child: Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Text(
                    'ABCDE'[i],
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
