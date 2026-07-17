// The ⌘K search overlay — filters the catalog and navigates on select.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'catalog.dart';
import 'shell.dart';
import 'widgets.dart';

/// Opens the command-palette-style search over the shell.
void showExplorerSearch(BuildContext context) {
  final controller = ExplorerController.of(context);
  final colors = Theme.of(context).extension<BeuiColors>()!;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss search',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, _) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * -12),
          child: _SearchOverlay(
            colors: colors,
            onSelect: (e) {
              Navigator.of(context).pop();
              controller.openEntry(e);
            },
          ),
        ),
      );
    },
  );
}

class _SearchOverlay extends StatefulWidget {
  const _SearchOverlay({required this.colors, required this.onSelect});
  final BeuiColors colors;
  final ValueChanged<ExploreEntry> onSelect;

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  String _query = '';

  List<ExploreEntry> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kAllEntries;
    return kAllEntries
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.blurb.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final results = _results;
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(context).maybePop(),
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (results.isNotEmpty) widget.onSelect(results.first);
              },
            },
            child: Container(
              width: 560,
              constraints: const BoxConstraints(maxHeight: 440),
              decoration: BoxDecoration(
                color: colors.popover,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.search,
                          size: 18,
                          color: colors.mutedForeground,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            cursorColor: colors.foreground,
                            style: TextStyle(
                              fontSize: 16,
                              color: colors.foreground,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Search components and blocks…',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: colors.mutedForeground,
                              ),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  Flexible(
                    child: results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'No matches',
                              style: TextStyle(
                                color: colors.mutedForeground,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, i) => _ResultRow(
                              entry: results[i],
                              colors: colors,
                              onTap: () => widget.onSelect(results[i]),
                            ),
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

class _ResultRow extends StatefulWidget {
  const _ResultRow({
    required this.entry,
    required this.colors,
    required this.onTap,
  });
  final ExploreEntry entry;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? colors.foreground.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.foreground.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.entry.section.title,
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.entry.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.foreground,
                          ),
                        ),
                        if (widget.entry.isNew) ...[
                          const SizedBox(width: 8),
                          const NewBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.entry.blurb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hover)
                Icon(
                  LucideIcons.corner_down_left,
                  size: 14,
                  color: colors.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
