import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Dot diameter in logical pixels (source `DOT_SIZE` / `h-1.5 w-1.5`).
const _dotSize = 6.0;

/// Horizontal inset of the indicator from the list's left edge (source `left-3`).
const _dotLeft = 12.0;

/// List padding-left that reserves the rail for the bouncing dot (source `pl-6`).
const _listPadLeft = 24.0;

/// Gap between rows (source `gap-1.5`).
const _itemGap = 6.0;

/// Minimum row height (source `min-h-9`).
const _itemMinHeight = 36.0;

/// Compact, lightly underdamped spring for the curved jump (source
/// `BOUNCE_SPRING`: stiffness 280 · damping 18 · mass 0.3). Component-local —
/// intentionally snappier than [beuiSpringLayout].
const _bounceSpringBase = SpringMotion(
  SpringDescription(mass: 0.3, stiffness: 280, damping: 18),
);

/// Test handle on the bouncing indicator dot.
@visibleForTesting
const beuiBounceSidebarIndicatorKey = ValueKey<String>(
  'beui_bounce_sidebar_indicator',
);

// ---------------------------------------------------------------------------
// Quadratic Bézier (source `quadraticBezier`)
// ---------------------------------------------------------------------------

double _quadraticBezier(
  double start,
  double control,
  double end,
  double progress,
) {
  final remaining = 1 - progress;
  return remaining * remaining * start +
      2 * remaining * progress * control +
      progress * progress * end;
}

/// One destination in a [BeuiBounceSidebar].
@immutable
class BeuiBounceSidebarItem {
  /// Creates a sidebar item.
  const BeuiBounceSidebarItem({
    required this.id,
    required this.label,
    this.icon,
    this.disabled = false,
  });

  /// Stable identity used for selection ([BeuiBounceSidebar.value]).
  final String id;

  /// Row label (usually a [Text]).
  final Widget label;

  /// Optional leading glyph / custom content.
  final Widget? icon;

  /// When true the row is non-interactive and dimmed.
  final bool disabled;
}

/// A vertical sidebar whose active dot jumps between destinations on a curved,
/// spring-loaded path — the Flutter port of beUI's `bounce-sidebar`.
///
/// **Curved bounce.** Unlike a shared-layout pill that glides in a straight
/// line, the indicator animates a progress spring (`0 → 1`) and samples a
/// quadratic Bézier: x bows leftward then returns to the rail, y arcs toward
/// the destination. Long jumps soften the spring and deepen the sideways arc
/// (source `longJumpProgress` / `controlX` / `controlY`).
///
/// **Controlled or uncontrolled**: pass [value] + [onChanged], or seed
/// [defaultValue] (falls back to the first item). Reduced motion snaps the
/// dot with no curve. Colours come from [BeuiColors].
class BeuiBounceSidebar extends StatefulWidget {
  /// Creates a bounce sidebar from [items].
  const BeuiBounceSidebar({
    required this.items,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.semanticLabel = 'Sidebar navigation',
    super.key,
  });

  /// Destinations, top to bottom.
  final List<BeuiBounceSidebarItem> items;

  /// Selected item id (controlled). When null the sidebar holds its own state.
  final String? value;

  /// Initial selection when uncontrolled.
  final String? defaultValue;

  /// Called with the newly selected item id.
  final ValueChanged<String>? onChanged;

  /// Accessible name for the navigation region (source `ariaLabel`).
  final String semanticLabel;

  @override
  State<BeuiBounceSidebar> createState() => _BeuiBounceSidebarState();
}

class _BeuiBounceSidebarState extends State<BeuiBounceSidebar>
    with SingleTickerProviderStateMixin {
  final GlobalKey _listKey = GlobalKey();
  late Map<String, GlobalKey> _itemKeys;
  late Map<String, FocusNode> _focusNodes;

  String? _internal;
  int _previousIndex = -1;
  bool _hasPosition = false;

  /// Path endpoints for the in-flight (or last) jump.
  double _startY = 0;
  double _destY = 0;
  double _controlX = 0;
  double _controlY = 0;

  /// Settled visual position when not mid-jump (source `x`/`y` motion values).
  double _x = 0;
  double _y = 0;
  bool _animating = false;

  late final SingleMotionController _progress;

  bool get _controlled => widget.value != null;

  String get _selectedValue {
    final requested = _controlled ? widget.value! : (_internal ?? '');
    if (widget.items.any((i) => i.id == requested)) return requested;
    return widget.items.isEmpty ? '' : widget.items.first.id;
  }

  int get _selectedIndex =>
      widget.items.indexWhere((i) => i.id == _selectedValue);

  @override
  void initState() {
    super.initState();
    _internal =
        widget.defaultValue ??
        (widget.items.isEmpty ? null : widget.items.first.id);
    _rebuildMaps();
    _progress = SingleMotionController(
      motion: _bounceSpringBase,
      vsync: this,
      initialValue: 0,
    )..addListener(_onProgressTick);
    _progress.addStatusListener(_onProgressStatus);
  }

  @override
  void didUpdateWidget(BeuiBounceSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.items.map((i) => i.id).toSet();
    if (ids.length != _itemKeys.length || !ids.containsAll(_itemKeys.keys)) {
      for (final node in _focusNodes.values) {
        node.dispose();
      }
      _rebuildMaps();
    }
  }

  void _rebuildMaps() {
    _itemKeys = {for (final i in widget.items) i.id: GlobalKey()};
    _focusNodes = {for (final i in widget.items) i.id: FocusNode()};
  }

  @override
  void dispose() {
    _progress
      ..removeListener(_onProgressTick)
      ..removeStatusListener(_onProgressStatus)
      ..dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onProgressTick() {
    if (!_animating || !mounted) return;
    setState(() {});
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_animating) return;
    // Source `onComplete`: pin to the rail and destination.
    setState(() {
      _x = 0;
      _y = _destY;
      _animating = false;
      _progress.value = 1;
    });
  }

  Offset get _dotOffset {
    if (_animating) {
      final p = _progress.value;
      return Offset(
        _quadraticBezier(0, _controlX, 0, p),
        _quadraticBezier(_startY, _controlY, _destY, p),
      );
    }
    return Offset(_x, _y);
  }

  double? _measureDestinationY(String id) {
    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _itemKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || itemBox == null || !itemBox.hasSize) return null;
    final topLeft = listBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
    return topLeft.dy + (itemBox.size.height - _dotSize) / 2;
  }

  /// Source `snapIndicator` — stop the jump and pin to the active row (resize).
  void _snapIndicator() {
    final dest = _measureDestinationY(_selectedValue);
    if (dest == null) return;
    _progress.stop(canceled: true);
    setState(() {
      _x = 0;
      _y = dest;
      _destY = dest;
      _hasPosition = true;
      _animating = false;
      _previousIndex = _selectedIndex;
    });
  }

  /// Source `positionIndicator` — snap or curve-jump toward the active row.
  void _positionIndicator({required bool shouldAnimate}) {
    final dest = _measureDestinationY(_selectedValue);
    if (dest == null) return;

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!_hasPosition || reduce || !shouldAnimate) {
      _progress.stop(canceled: true);
      setState(() {
        _x = 0;
        _y = dest;
        _destY = dest;
        _hasPosition = true;
        _animating = false;
        _previousIndex = _selectedIndex;
      });
      return;
    }

    // Mid-jump: sample the live path so a re-target continues from where the
    // dot currently is (source stops the prior animate and reads `y.get()`).
    final startY = _animating
        ? _quadraticBezier(_startY, _controlY, _destY, _progress.value)
        : _y;
    final distance = dest - startY;
    final travel = distance.abs();
    final longJumpProgress = ((travel - 48) / 120).clamp(0.0, 1.0);
    final controlX = -((travel * 0.25).clamp(8.0, 40.0));
    final midpointY = (startY + dest) / 2;
    final controlY = dest + (midpointY - dest) * longJumpProgress;

    final spring = SpringMotion(
      SpringDescription(
        mass: 0.3 + 0.15 * longJumpProgress,
        stiffness: 280 - 60 * longJumpProgress,
        damping: 18 + longJumpProgress,
      ),
    );

    setState(() {
      _startY = startY;
      _destY = dest;
      _controlX = controlX;
      _controlY = controlY;
      _animating = true;
      _hasPosition = true;
      _previousIndex = _selectedIndex;
    });

    _progress.motion = motionFor(context, spring, isMovement: true);
    _progress.animateTo(1, from: 0, withVelocity: 0);
  }

  void _select(String id) {
    BeuiBounceSidebarItem? item;
    for (final i in widget.items) {
      if (i.id == id) {
        item = i;
        break;
      }
    }
    if (item == null || item.disabled) return;
    if (!_controlled) setState(() => _internal = id);
    widget.onChanged?.call(id);
  }

  void _moveFrom(String fromId, int delta) {
    final enabled = widget.items.where((i) => !i.disabled).toList();
    if (enabled.isEmpty) return;
    final i = enabled.indexWhere((e) => e.id == fromId);
    final start = i < 0 ? 0 : i;
    final next = enabled[(start + delta + enabled.length) % enabled.length];
    _select(next.id);
    _focusNodes[next.id]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    final selectedIndex = _selectedIndex;
    final selectedValue = _selectedValue;

    // After every build, re-position if the selection (or layout) changed —
    // mirrors source `useLayoutEffect` + ResizeObserver.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldAnimate = _hasPosition && _previousIndex != selectedIndex;
      // When the index did not change, only snap if we never measured (or a
      // resize already routed through SizeChangedLayoutNotifier). Selection
      // changes animate; first paint snaps.
      if (!_hasPosition || _previousIndex != selectedIndex) {
        _positionIndicator(shouldAnimate: shouldAnimate);
      }
    });

    final rows = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (i > 0) rows.add(const SizedBox(height: _itemGap));
      rows.add(
        _SidebarRow(
          measureKey: _itemKeys[item.id]!,
          focusNode: _focusNodes[item.id]!,
          item: item,
          active: item.id == selectedValue,
          colors: colors,
          onSelect: () => _select(item.id),
          onMove: (delta) => _moveFrom(item.id, delta),
        ),
      );
    }

    final list = Stack(
      key: _listKey,
      clipBehavior: Clip.none,
      children: [
        if (selectedIndex >= 0 && _hasPosition)
          Positioned(
            left: _dotLeft,
            top: 0,
            child: IgnorePointer(
              child: Transform.translate(
                offset: _dotOffset,
                child: Container(
                  key: beuiBounceSidebarIndicatorKey,
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: _listPadLeft),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      explicitChildNodes: true,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _snapIndicator();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(child: list),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyboard move intent (vertical list)
// ---------------------------------------------------------------------------

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.measureKey,
    required this.focusNode,
    required this.item,
    required this.active,
    required this.colors,
    required this.onSelect,
    required this.onMove,
  });

  final GlobalKey measureKey;
  final FocusNode focusNode;
  final BeuiBounceSidebarItem item;
  final bool active;
  final BeuiColors colors;
  final VoidCallback onSelect;
  final ValueChanged<int> onMove;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final enabled = !item.disabled;
    final active = widget.active;
    final colors = widget.colors;

    // Source: active → foreground; idle → mutedForeground; hover → foreground.
    final Color fg;
    if (!enabled) {
      fg = colors.mutedForeground;
    } else if (active || _hovered || _focused) {
      fg = colors.foreground;
    } else {
      fg = colors.mutedForeground;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (item.icon != null) ...[
          IconTheme.merge(
            data: IconThemeData(color: fg, size: 16),
            child: item.icon!,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: fg,
              height: 1.25,
            ),
            child: item.label,
          ),
        ),
      ],
    );

    return KeyedSubtree(
      key: widget.measureKey,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect();
              return null;
            },
          ),
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) {
              widget.onMove(intent.delta);
              return null;
            },
          ),
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onSelect : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: _itemMinHeight),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: _focused
                    ? Border.all(color: colors.ring, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              alignment: Alignment.centerLeft,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
