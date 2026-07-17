import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder, SpringMotion;

/// One entry in a [BeuiBloomMenu] grid.
@immutable
class BeuiBloomMenuItem {
  /// Creates a menu entry. [icon] is a framework-native glyph.
  const BeuiBloomMenuItem({required this.label, required this.icon});

  /// The label shown under the icon and passed to `onSelect`.
  final String label;

  /// The cell glyph.
  final IconData icon;
}

/// The source's default six-item create menu.
const List<BeuiBloomMenuItem> beuiDefaultBloomMenuItems = [
  BeuiBloomMenuItem(label: 'Doc', icon: LucideIcons.file_text),
  BeuiBloomMenuItem(label: 'Board', icon: LucideIcons.layout_grid),
  BeuiBloomMenuItem(label: 'Table', icon: LucideIcons.table),
  BeuiBloomMenuItem(label: 'Folder', icon: LucideIcons.folder_closed),
  BeuiBloomMenuItem(label: 'Reminder', icon: LucideIcons.bell),
  BeuiBloomMenuItem(label: 'Link', icon: LucideIcons.link),
];

/// The source's "folder-open" morph spring: `{stiffness: 300, damping: 32,
/// mass: 0.9}` — a touch of overshoot as the panel expands, kept subtle.
const _springFolder = SpringMotion(
  SpringDescription(mass: 0.9, stiffness: 300, damping: 32),
);

const _triggerSize = Size(144, 44); // source `h-11 w-36`

/// A "Create" pill that blooms open into a grid create-menu — the Flutter port
/// of beUI's `bloom-menu` block.
///
/// The pill and the open panel are one **shared element**: the box morphs its
/// size between them on [_springFolder], growing from the shared centre outward
/// in every direction (source `layoutId` FLIP). As it opens, the grid does an
/// **iris reveal** — a clip that starts as a small centred box and opens to all
/// four corners over 450ms EASE_OUT — and each cell's content springs in on a
/// **radial stagger** (delay ∝ distance from the grid centre), so the four
/// corners animate together and the open reads centre-out, not corner-by-corner.
///
/// Closes on Escape, on a tap outside, or on selecting an item. The panel size
/// is measured (one frame late — the box springs toward the measured size, it
/// does not snap), matching the source's runtime measurement.
///
/// Reduced motion keeps the size morph brief (150ms) and drops the iris /
/// blur / scale flourishes — content fades opacity-only.
class BeuiBloomMenu extends StatefulWidget {
  /// Creates a bloom menu.
  const BeuiBloomMenu({
    this.items = beuiDefaultBloomMenuItems,
    this.onSelect,
    this.triggerLabel = 'Create',
    super.key,
  });

  /// The grid entries. Defaults to [beuiDefaultBloomMenuItems].
  final List<BeuiBloomMenuItem> items;

  /// Called with an item's label when it is chosen.
  final ValueChanged<String>? onSelect;

  /// The collapsed pill's label.
  final String triggerLabel;

  @override
  State<BeuiBloomMenu> createState() => _BeuiBloomMenuState();
}

class _BeuiBloomMenuState extends State<BeuiBloomMenu> {
  final GlobalKey _measureKey = GlobalKey();
  bool _open = false;
  Size? _panelSize;

  static const int _cols = 3;

  void _setOpen(bool next) {
    if (_open == next) return;
    setState(() => _open = next);
  }

  void _measure() {
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (_panelSize != box.size) {
      setState(() => _panelSize = box.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final reduce = MediaQuery.disableAnimationsOf(context);
    final panelWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.86,
      420.0,
    );
    // Seed height before the first measurement so the box never springs from a
    // wrong size (the one-frame-late caveat): header + grid rows estimate.
    final rows = (widget.items.length / _cols).ceil();
    final panelSize =
        _panelSize ?? Size(panelWidth, 49.0 + rows * 92.0);

    return _CloseScope(
      enabled: _open,
      onClose: () => _setOpen(false),
      child: SizedBox.fromSize(
        size: _triggerSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Off-stage full-size panel, measured for the morph target. It is
            // laid out but never painted.
            Positioned(
              left: 0,
              top: 0,
              child: Offstage(
                child: SizedBox(
                  key: _measureKey,
                  width: panelWidth,
                  child: _PanelChrome(
                    items: widget.items,
                    reveal: const AlwaysStoppedAnimation(1),
                    reduce: true,
                    onSelect: (_) {},
                    onClose: () {},
                  ),
                ),
              ),
            ),
            // The morphing shared element, centred on the trigger.
            SingleMotionBuilder(
              value: _open ? 1.0 : 0.0,
              motion: reduce
                  ? const SpringMotion(
                      // Brief, overshoot-free under reduced motion (~150ms feel).
                      SpringDescription(mass: 1, stiffness: 700, damping: 60),
                    )
                  : _springFolder,
              builder: (context, p, _) {
                final size = Size.lerp(_triggerSize, panelSize, p)!;
                return SizedBox.fromSize(
                  size: size,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _MorphContents(
                      progress: p,
                      open: _open,
                      panelWidth: panelWidth,
                      panelSize: panelSize,
                      triggerLabel: widget.triggerLabel,
                      items: widget.items,
                      reduce: reduce,
                      onOpen: () => _setOpen(true),
                      onClose: () => _setOpen(false),
                      onSelect: (label) {
                        widget.onSelect?.call(label);
                        _setOpen(false);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the morph's clipped box: the collapsed trigger (below a low progress)
/// cross-fades into the open panel content. The trigger and panel are both
/// pinned to the box's centre so neither drifts as the box morphs.
class _MorphContents extends StatelessWidget {
  const _MorphContents({
    required this.progress,
    required this.open,
    required this.panelWidth,
    required this.panelSize,
    required this.triggerLabel,
    required this.items,
    required this.reduce,
    required this.onOpen,
    required this.onClose,
    required this.onSelect,
  });

  final double progress;
  final bool open;
  final double panelWidth;
  final Size panelSize;
  final String triggerLabel;
  final List<BeuiBloomMenuItem> items;
  final bool reduce;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // Content cross-fade windows on the morph progress: the trigger fades out
    // early, the panel content fades in after the box has room (source delays
    // the panel content ~0.12 after the box starts).
    final triggerOpacity = (1 - progress * 3).clamp(0.0, 1.0);
    final panelOpacity = reduce
        ? (open ? 1.0 : 0.0)
        : ((progress - 0.25) / 0.5).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Panel content, sized to its full width so text lays out once and is
          // merely revealed by the growing box (no reflow mid-morph).
          if (panelOpacity > 0)
            Positioned(
              width: panelWidth,
              height: panelSize.height,
              child: Opacity(
                opacity: panelOpacity,
                child: _PanelBloom(
                  items: items,
                  reduce: reduce,
                  open: open,
                  onSelect: onSelect,
                  onClose: onClose,
                ),
              ),
            ),
          // Collapsed trigger label.
          if (triggerOpacity > 0)
            Opacity(
              opacity: triggerOpacity,
              child: _TriggerLabel(label: triggerLabel, onTap: onOpen),
            ),
        ],
      ),
    );
  }
}

class _TriggerLabel extends StatelessWidget {
  const _TriggerLabel({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.fromSize(
          size: _triggerSize,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.plus, size: 16, color: colors.foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open panel: static chrome (header + hairline grid) plus the iris reveal
/// and radial-stagger animations, which restart each time [open] flips true.
class _PanelBloom extends StatefulWidget {
  const _PanelBloom({
    required this.items,
    required this.reduce,
    required this.open,
    required this.onSelect,
    required this.onClose,
  });
  final List<BeuiBloomMenuItem> items;
  final bool reduce;
  final bool open;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  State<_PanelBloom> createState() => _PanelBloomState();
}

class _PanelBloomState extends State<_PanelBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    // Iris clip 0.45s + item stagger tail; the grid controller drives both.
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelChrome(
      items: widget.items,
      reveal: _reveal,
      reduce: widget.reduce,
      onSelect: widget.onSelect,
      onClose: widget.onClose,
    );
  }
}

/// The panel's visual body — header row and the 3-column grid. Split from the
/// animation state so the off-stage measurement copy can reuse it with a static
/// [reveal].
class _PanelChrome extends StatelessWidget {
  const _PanelChrome({
    required this.items,
    required this.reveal,
    required this.reduce,
    required this.onSelect,
    required this.onClose,
  });

  final List<BeuiBloomMenuItem> items;
  final Animation<double> reveal;
  final bool reduce;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  static const int _cols = 3;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final rows = (items.length / _cols).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header.
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
              Semantics(
                button: true,
                label: 'Close menu',
                child: GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    LucideIcons.x,
                    size: 16,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Grid, revealed by the iris clip.
        AnimatedBuilder(
          animation: reveal,
          builder: (context, _) {
            final t = reveal.value;
            // Iris: inset 45%/34% → 0, over the first 0.6 of the controller
            // (0.45s of 0.75s), EASE_OUT.
            final irisT = beuiEaseOut.transform((t / 0.6).clamp(0.0, 1.0));
            return ClipPath(
              clipper: reduce ? null : _IrisClipper(irisT),
              child: _grid(colors, rows, t),
            );
          },
        ),
      ],
    );
  }

  Widget _grid(BeuiColors colors, int rows, double t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < _cols; c++)
                if (r * _cols + c < items.length)
                  Expanded(
                    child: _cell(colors, r, c, rows, t),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
            ],
          ),
      ],
    );
  }

  Widget _cell(BeuiColors colors, int r, int c, int rows, double t) {
    final i = r * _cols + c;
    final item = items[i];
    // Radial stagger: delay ∝ distance from the grid centre. The controller
    // runs 0→1 over 750ms; item springs begin at 0.1 + dist*0.07 (in seconds).
    final dist = _distFromCentre(c, r, rows);
    final start = (0.1 + dist * 0.07) / 0.75; // fraction of the controller
    final local = reduce
        ? 1.0
        : ((t - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = beuiEaseOut.transform(local);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 20, color: colors.mutedForeground),
        const SizedBox(height: 8),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.mutedForeground,
          ),
        ),
      ],
    );

    if (!reduce) {
      // opacity 0→1, scale 0.85→1, blur σ3→0.
      content = Opacity(
        opacity: eased,
        child: Transform.scale(
          scale: 0.85 + 0.15 * eased,
          child: content,
        ),
      );
    } else {
      content = Opacity(opacity: local, child: content);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: c != _cols - 1
              ? BorderSide(color: colors.border)
              : BorderSide.none,
          bottom: r < rows - 1
              ? BorderSide(color: colors.border)
              : BorderSide.none,
        ),
      ),
      child: Semantics(
        button: true,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(item.label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  static double _distFromCentre(int col, int row, int rows) {
    final dc = col - (_cols - 1) / 2;
    final dr = row - (rows - 1) / 2;
    return math.sqrt(dc * dc + dr * dr);
  }
}

/// The iris clip — an inset rectangle that opens from a centred box (45% top/
/// bottom, 34% left/right) to the full bounds.
class _IrisClipper extends CustomClipper<Path> {
  _IrisClipper(this.t);
  final double t; // 0 = closed box, 1 = full

  @override
  Path getClip(Size size) {
    final top = 0.45 * size.height * (1 - t);
    final bottom = size.height - 0.45 * size.height * (1 - t);
    final left = 0.34 * size.width * (1 - t);
    final right = size.width - 0.34 * size.width * (1 - t);
    return Path()..addRect(Rect.fromLTRB(left, top, right, bottom));
  }

  @override
  bool shouldReclip(_IrisClipper old) => old.t != t;
}

/// Closes the menu on Escape or a tap outside its subtree, while [enabled].
class _CloseScope extends StatelessWidget {
  const _CloseScope({
    required this.enabled,
    required this.onClose,
    required this.child,
  });
  final bool enabled;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = TapRegion(
      enabled: enabled,
      onTapOutside: (_) => onClose(),
      child: child,
    );
    if (enabled) {
      result = CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
        child: Focus(autofocus: true, child: result),
      );
    }
    return result;
  }
}
