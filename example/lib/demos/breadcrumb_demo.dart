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
  final _pageFocus = <int, FocusNode>{};
  FocusNode get _currentFocus => _pageFocus.putIfAbsent(
    _depth,
    () => FocusNode(debugLabel: 'Current breadcrumb page $_depth'),
  );

  @override
  void dispose() {
    for (final focus in _pageFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  void _navigate(int depth) {
    setState(() => _depth = depth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _currentFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).width < 640 ? 68 : 32,
                ),
                child: BeuiBreadcrumb(
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
                                Focus(
                                  focusNode: _currentFocus,
                                  skipTraversal: true,
                                  child: BeuiBreadcrumbPage(
                                    child: _crumbLabel(index),
                                  ),
                                )
                              else
                                BeuiBreadcrumbLink(
                                  onPressed: () => _navigate(index),
                                  child: _crumbLabel(index),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                constraints: const BoxConstraints(minHeight: 80),
                padding: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: BeuiColors.resolve(
                        context,
                      ).border.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: _depth < _path.length - 1
                    ? _NextPathButton(
                        label: _path[_depth + 1],
                        onPressed: () => _navigate(_depth + 1),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Choose a parent path to go back.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: BeuiColors.resolve(context).mutedForeground,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crumbLabel(int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index == 0) ...[
          const Icon(LucideIcons.house, size: 14),
          const SizedBox(width: 6),
        ],
        Text(_path[index]),
      ],
    );
  }
}

class _NextPathButton extends StatefulWidget {
  const _NextPathButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_NextPathButton> createState() => _NextPathButtonState();
}

class _NextPathButtonState extends State<_NextPathButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? colors.muted.withValues(alpha: 0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.folder_closed,
                  size: 16,
                  color: colors.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: colors.foreground,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.arrow_up_right,
                  size: 14,
                  color: colors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
