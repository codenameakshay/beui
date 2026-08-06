import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiContextMenu] — right-click / long-press area with
/// mixed actions, checkbox, radio, and a destructive row.
Widget contextMenuDemo(BuildContext context) => const _ContextMenuDemo();

class _ContextMenuDemo extends StatefulWidget {
  const _ContextMenuDemo();

  @override
  State<_ContextMenuDemo> createState() => _ContextMenuDemoState();
}

class _ContextMenuDemoState extends State<_ContextMenuDemo> {
  String? _message;
  bool _offline = false;

  void _setMessage(String message) => setState(() => _message = message);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: BeuiContextMenu(
        semanticLabel: 'Folder actions',
        items: [
          const BeuiContextMenuItem.label('Project files'),
          BeuiContextMenuItem(
            label: 'Open',
            icon: LucideIcons.eye,
            shortcut: '↵',
            onSelect: () => _setMessage('Folder opened'),
          ),
          BeuiContextMenuItem(
            label: 'Rename',
            icon: LucideIcons.pencil,
            shortcut: 'R',
            onSelect: () => _setMessage('Ready to rename'),
          ),
          BeuiContextMenuItem(
            label: 'Duplicate',
            icon: LucideIcons.copy,
            shortcut: '⌘D',
            onSelect: () => _setMessage('Folder duplicated'),
          ),
          BeuiContextMenuItem(
            label: 'Download',
            icon: LucideIcons.download,
            onSelect: () => _setMessage('Download started'),
          ),
          const BeuiContextMenuItem.separator(),
          BeuiContextMenuItem.checkbox(
            label: 'Keep offline',
            checked: _offline,
            onCheckedChange: (v) {
              setState(() => _offline = v);
              _setMessage(v ? 'Available offline' : 'Online only');
            },
          ),
          const BeuiContextMenuItem.separator(),
          BeuiContextMenuItem(
            label: 'Move to trash',
            icon: LucideIcons.trash_2,
            shortcut: '⌘⌫',
            tone: BeuiContextMenuTone.destructive,
            onSelect: () => _setMessage('Moved to trash'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FolderGlyph(colors: colors),
            const SizedBox(height: 16),
            Text(
              'Right click on me',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            // Source: `mt-1 h-4` slot swapping the hint for a checked message.
            SizedBox(
              height: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _message == null
                    ? Text(
                        'or long-press · Shift + F10',
                        key: const ValueKey('hint'),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.mutedForeground,
                        ),
                      )
                    : Row(
                        key: ValueKey(_message),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.check,
                            size: 12,
                            color: colors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _message!,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.mutedForeground,
                            ),
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
}

/// Decorative folder mark matching the source preview silhouette.
class _FolderGlyph extends StatelessWidget {
  const _FolderGlyph({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tab = isDark ? const Color(0xFFA77D2F) : const Color(0xFFD4A84F);
    final body = isDark ? const Color(0xFFBD8D36) : const Color(0xFFE7BB61);
    final face = isDark ? const Color(0xFFCB9A41) : const Color(0xFFEFC86F);

    return SizedBox(
      width: 128,
      height: 96,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              width: 56,
              height: 28,
              decoration: BoxDecoration(
                color: tab,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 20,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: body,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5A3A08).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 36,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: face,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Container(
              height: 1,
              color: colors.foreground.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
