part of 'table.dart';

/// One entry in a [_TableMenu] (source `TableMenuItem`).
@immutable
class _TableMenuEntry {
  const _TableMenuEntry({
    required this.label,
    required this.icon,
    required this.onSelect,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelect;
  final bool destructive;
}

const double _menuWidth = 188;

/// The small handle-triggered dropdown shared by the row and column handles —
/// the Flutter port of `table-menu.tsx`.
///
/// The trigger is a tiny primary pill; the panel opens through [BeuiOverlay]
/// (transparent barrier, Esc / tap-outside dismiss, root overlay so it escapes
/// the table's scroll clip) and springs in on `SPRING_PANEL` (source
/// `SPRING_PANEL`: scale 0.96 → 1, y -4 → 0, opacity). Reduced motion drops the
/// scale and slide. Its entrance is immediate, matching the source.
class _TableMenu extends StatefulWidget {
  const _TableMenu({
    required this.label,
    required this.onOpenChanged,
    required this.colors,
    required this.width,
    required this.height,
    required this.icon,
    required this.items,
  });

  final BeuiColors colors;
  final String label;
  final ValueChanged<bool> onOpenChanged;
  final double width;
  final double height;
  final IconData icon;
  final List<_TableMenuEntry> items;

  @override
  State<_TableMenu> createState() => _TableMenuState();
}

class _TableMenuState extends State<_TableMenu> {
  bool _open = false;
  final FocusNode _firstItemFocus = FocusNode();
  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: (_, event) {
      if (_open &&
          event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _firstItemFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    _focusNode.dispose();
    _firstItemFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool v) {
    widget.onOpenChanged(v);
    setState(() => _open = v);
    if (!v) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      barrier: true,
      barrierColor: const Color(0x00000000),
      trapFocus: false,
      enterDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      exitDuration: Duration.zero,
      overlayBuilder: _buildMenu,
      child: Semantics(
        button: true,
        label: widget.label,
        child: FocusableActionDetector(
          focusNode: _focusNode,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _setOpen(!_open);
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focusNode.requestFocus();
                _setOpen(!_open);
              },
              child: Container(
                width: widget.width,
                height: widget.height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 12,
                  color: colors.primaryForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final panel = Material(
      color: Colors.transparent,
      child: Container(
        width: _menuWidth,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, item) in widget.items.indexed)
              _MenuItem(
                focusNode: index == 0 ? _firstItemFocus : null,
                item: item,
                colors: colors,
                onClose: () => _setOpen(false),
              ),
          ],
        ),
      ),
    );

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topRight,
        child: SingleMotionBuilder(
          value: _open ? 1.0 : 0.0,
          from: 0,
          motion: motionFor(
            context,
            beuiSpringPanel,
            isMovement: true,
            reducedFallback: const CurvedMotion(
              Duration(milliseconds: 120),
              beuiEaseOut,
            ),
          ),
          builder: (context, t, child) {
            final clamped = t.clamp(0.0, 1.0);
            // Opacity rides the overlay's own enter/exit clock so close always
            // completes; the spring drives the scale + slide.
            return FadeTransition(
              opacity: animation,
              child: reduce
                  ? child
                  : Transform.translate(
                      offset: Offset(0, -4 * (1 - t)),
                      child: Transform.scale(
                        scale: 0.96 + 0.04 * clamped,
                        alignment: Alignment.topRight,
                        child: child,
                      ),
                    ),
            );
          },
          child: panel,
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    this.focusNode,
    required this.item,
    required this.colors,
    required this.onClose,
  });

  final _TableMenuEntry item;
  final BeuiColors colors;
  final VoidCallback onClose;
  final FocusNode? focusNode;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  void _select() {
    widget.onClose();
    widget.item.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = widget.colors;
    final fg = item.destructive ? colors.destructive : colors.foreground;
    final hoverBg = item.destructive
        ? colors.destructive.withValues(alpha: 0.1)
        : colors.muted;

    return Semantics(
      button: true,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _select();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _select,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _hovered ? hoverBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(item.icon, size: 16, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(fontSize: 14, color: fg),
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
