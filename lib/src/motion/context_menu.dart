import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// ---------------------------------------------------------------------------
// Tokens — mirror source constants
// ---------------------------------------------------------------------------

const double _viewportPadding = 8;
const Duration _longPressDelay = Duration(milliseconds: 520);
const double _longPressTolerance = 10;
const Duration _morphDuration = Duration(milliseconds: 300);
const Duration _reduceMorphDuration = Duration(milliseconds: 100);
const Duration _typeaheadReset = Duration(milliseconds: 500);
const double _minWidth = 224; // source min-w-56
const double _panelRadius = 12;
const double _rowRadius = 8; // rounded-lg

/// Visual tone for a selectable context-menu row.
enum BeuiContextMenuTone {
  /// Default foreground.
  standard,

  /// Destructive / danger action (source `tone="destructive"`).
  destructive,
}

/// Kind of a [BeuiContextMenuItem] row.
enum BeuiContextMenuItemKind {
  /// Ordinary action row (`menuitem`).
  action,

  /// Toggleable checkbox row (`menuitemcheckbox`).
  checkbox,

  /// Exclusive radio choice (`menuitemradio`).
  radio,

  /// Non-interactive section label.
  label,

  /// Horizontal rule between groups.
  separator,
}

/// One row in a [BeuiContextMenu] — action, checkbox, radio, label, or separator.
///
/// The Flutter analog of the source's `<ContextMenuItem>` /
/// `<ContextMenuCheckboxItem>` / `<ContextMenuRadioItem>` /
/// `<ContextMenuLabel>` / `<ContextMenuSeparator>` compound primitives,
/// collapsed into a data model so the consumer builds a simple `items` list
/// rather than nested widgets.
@immutable
class BeuiContextMenuItem {
  const BeuiContextMenuItem._({
    required this.kind,
    this.id,
    this.label = '',
    this.icon,
    this.shortcut,
    this.onSelect,
    this.enabled = true,
    this.closeOnSelect = true,
    this.tone = BeuiContextMenuTone.standard,
    this.checked = false,
    this.onCheckedChange,
    this.inset = false,
  });

  /// A selectable action row.
  const BeuiContextMenuItem({
    required String label,
    VoidCallback? onSelect,
    IconData? icon,
    String? shortcut,
    bool enabled = true,
    bool closeOnSelect = true,
    BeuiContextMenuTone tone = BeuiContextMenuTone.standard,
    String? id,
  }) : this._(
         kind: BeuiContextMenuItemKind.action,
         id: id,
         label: label,
         icon: icon,
         shortcut: shortcut,
         onSelect: onSelect,
         enabled: enabled,
         closeOnSelect: closeOnSelect,
         tone: tone,
       );

  /// A checkbox choice. [checked] is controlled by the consumer;
  /// [onCheckedChange] receives the toggled value. Defaults to not closing
  /// the menu (source checkbox items typically keep the menu open).
  const BeuiContextMenuItem.checkbox({
    required String label,
    required bool checked,
    ValueChanged<bool>? onCheckedChange,
    IconData? icon,
    String? shortcut,
    bool enabled = true,
    bool closeOnSelect = false,
    BeuiContextMenuTone tone = BeuiContextMenuTone.standard,
    String? id,
  }) : this._(
         kind: BeuiContextMenuItemKind.checkbox,
         id: id,
         label: label,
         icon: icon,
         shortcut: shortcut,
         enabled: enabled,
         closeOnSelect: closeOnSelect,
         tone: tone,
         checked: checked,
         onCheckedChange: onCheckedChange,
       );

  /// A radio choice. [checked] is controlled by the consumer; call
  /// [onSelect] (or own state) to mark this option selected.
  const BeuiContextMenuItem.radio({
    required String label,
    required bool checked,
    VoidCallback? onSelect,
    IconData? icon,
    String? shortcut,
    bool enabled = true,
    bool closeOnSelect = true,
    BeuiContextMenuTone tone = BeuiContextMenuTone.standard,
    String? id,
  }) : this._(
         kind: BeuiContextMenuItemKind.radio,
         id: id,
         label: label,
         icon: icon,
         shortcut: shortcut,
         onSelect: onSelect,
         enabled: enabled,
         closeOnSelect: closeOnSelect,
         tone: tone,
         checked: checked,
       );

  /// A non-interactive uppercase section label.
  const BeuiContextMenuItem.label(
    String label, {
    bool inset = false,
    String? id,
  }) : this._(
         kind: BeuiContextMenuItemKind.label,
         id: id,
         label: label,
         inset: inset,
         closeOnSelect: false,
       );

  /// A horizontal separator.
  const BeuiContextMenuItem.separator({String? id})
    : this._(
        kind: BeuiContextMenuItemKind.separator,
        id: id,
        closeOnSelect: false,
      );

  /// Row kind.
  final BeuiContextMenuItemKind kind;

  /// Optional stable identity (for tests / keys).
  final String? id;

  /// Visible label / typeahead haystack. Empty for separators.
  final String label;

  /// Optional leading glyph (framework-native [IconData]).
  final IconData? icon;

  /// Trailing keyboard hint (e.g. `⌘D`).
  final String? shortcut;

  /// Invoked for action / radio rows when chosen.
  final VoidCallback? onSelect;

  /// Whether the row can be chosen.
  final bool enabled;

  /// Close the menu after selecting (source `closeOnSelect`, default true;
  /// checkbox factory defaults to false).
  final bool closeOnSelect;

  /// Visual tone (destructive paints in the destructive color).
  final BeuiContextMenuTone tone;

  /// Checkbox / radio checked state (controlled).
  final bool checked;

  /// Checkbox toggle callback.
  final ValueChanged<bool>? onCheckedChange;

  /// Indent label text (source `inset`).
  final bool inset;

  /// Whether this row participates in keyboard focus / selection.
  bool get isSelectable =>
      (kind == BeuiContextMenuItemKind.action ||
          kind == BeuiContextMenuItemKind.checkbox ||
          kind == BeuiContextMenuItemKind.radio) &&
      enabled;
}

/// How the menu was opened — gates the clip-morph entrance (keyboard opens
/// instantly, matching the source).
enum BeuiContextMenuModality {
  /// Right-click / secondary pointer.
  pointer,

  /// Shift+F10 / ContextMenu key.
  keyboard,

  /// Touch long-press.
  touch,
}

/// A pointer-origin context menu — the Flutter port of beUI's `context-menu`.
///
/// Wrap any [child] trigger area. **Secondary-click**, **long-press** (520ms,
/// 10px move cancel), or **Shift+F10** / ContextMenu key opens a floating panel
/// at the pointer (or trigger centre for keyboard) with a **pointer-origin
/// scale morph** + opacity fade (`EASE_OUT` 300ms — see note below). A
/// shared-layout style **gliding highlight** tracks the active row on
/// [beuiSpringLayout].
///
/// Items are a flat [items] list of [BeuiContextMenuItem] (action / checkbox /
/// radio / label / separator). Keyboard: ↑/↓, Home/End, Enter, Esc; multi-char
/// typeahead jumps to the first matching enabled label (500ms buffer).
///
/// Built on [BeuiOverlay] (transparent barrier, Esc / tap-outside dismiss, root
/// overlay, focus trap). Controlled (`open` + `onOpenChange`) or uncontrolled.
/// Reduced motion drops the scale morph and highlight glide, keeping a brief
/// opacity fade.
///
/// **Scope notes:**
/// - Entrance approximates the source's `clip-path: inset(...)` morph with a
///   scale-from-origin transform — Flutter's [ClipPath] also clips hit-tests,
///   which would leave rows untappable during the open animation.
/// - Nested submenus are not ported (the source has none either).
class BeuiContextMenu extends StatefulWidget {
  /// Creates a context menu around [child] with [items].
  const BeuiContextMenu({
    required this.child,
    required this.items,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.enabled = true,
    this.semanticLabel = 'Context menu',
    this.minWidth = _minWidth,
    super.key,
  });

  /// The trigger / hit target. Right-click, long-press, or keyboard open it.
  final Widget child;

  /// Menu rows.
  final List<BeuiContextMenuItem> items;

  /// Controlled open state; null for uncontrolled with [defaultOpen].
  final bool? open;

  /// Uncontrolled initial open state.
  final bool defaultOpen;

  /// Fires when the menu wants to open/close.
  final ValueChanged<bool>? onOpenChange;

  /// When false, pointer / keyboard open is ignored.
  final bool enabled;

  /// Accessibility label for the menu panel (source `ariaLabel`).
  final String semanticLabel;

  /// Minimum panel width (source `min-w-56` = 224).
  final double minWidth;

  @override
  State<BeuiContextMenu> createState() => _BeuiContextMenuState();
}

class _BeuiContextMenuState extends State<BeuiContextMenu> {
  late bool _internalOpen = widget.defaultOpen;
  Offset _point = Offset.zero;
  BeuiContextMenuModality _modality = BeuiContextMenuModality.pointer;
  int _activeIndex = -1;
  Rect? _pillRect;
  Size _panelSize = Size.zero;
  Offset _position = Offset.zero;
  Offset _origin = const Offset(12, 12);
  bool _morphReady = false;

  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _panelKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();
  final Map<int, GlobalKey> _rowKeys = {};
  final FocusNode _menuFocus = FocusNode(debugLabel: 'BeuiContextMenu');

  Timer? _longPressTimer;
  Offset? _longPressOrigin;
  String _typeahead = '';
  Timer? _typeaheadTimer;

  bool get _open => widget.open ?? _internalOpen;

  List<int> get _selectableIndices {
    final out = <int>[];
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.items[i].isSelectable) out.add(i);
    }
    return out;
  }

  @override
  void dispose() {
    _cancelLongPress();
    _typeaheadTimer?.cancel();
    _menuFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (next == _open) return;
    if (widget.open == null) {
      setState(() => _internalOpen = next);
    } else {
      setState(() {}); // re-render pending controlled echo
    }
    widget.onOpenChange?.call(next);
    if (!next) {
      _activeIndex = -1;
      _pillRect = null;
      _morphReady = false;
      _typeahead = '';
    }
  }

  void _openAt(Offset globalPoint, BeuiContextMenuModality modality) {
    if (!widget.enabled) return;
    setState(() {
      _point = globalPoint;
      _modality = modality;
      _activeIndex = -1;
      _pillRect = null;
      _panelSize = Size.zero;
      _morphReady = false;
      _position = globalPoint;
      _origin = const Offset(12, 12);
    });
    _setOpen(true);
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressOrigin = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    if (event.kind != PointerDeviceKind.touch &&
        event.kind != PointerDeviceKind.stylus) {
      return;
    }
    _cancelLongPress();
    _longPressOrigin = event.position;
    _longPressTimer = Timer(_longPressDelay, () {
      final origin = _longPressOrigin;
      if (origin == null || !mounted) return;
      _longPressTimer = null;
      _longPressOrigin = null;
      _openAt(origin, BeuiContextMenuModality.touch);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _longPressOrigin;
    if (origin == null) return;
    if ((event.position - origin).distance > _longPressTolerance) {
      _cancelLongPress();
    }
  }

  void _openFromKeyboard() {
    if (!widget.enabled) return;
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    final point = Offset(
      topLeft.dx + math.min(24, size.width / 2),
      topLeft.dy + size.height / 2,
    );
    _openAt(point, BeuiContextMenuModality.keyboard);
  }

  void _recomputePlacement(Size size) {
    final media = MediaQuery.sizeOf(context);
    // Prefer not to go above 0 when the menu is taller than remaining space.
    final clampedLeft = _point.dx
        .clamp(
          _viewportPadding,
          math.max(
            _viewportPadding,
            media.width - size.width - _viewportPadding,
          ),
        )
        .toDouble();
    final clampedTop = _point.dy
        .clamp(
          _viewportPadding,
          math.max(
            _viewportPadding,
            media.height - size.height - _viewportPadding,
          ),
        )
        .toDouble();

    final origin = Offset(
      (_point.dx - clampedLeft)
          .clamp(12.0, math.max(12.0, size.width - 12))
          .toDouble(),
      (_point.dy - clampedTop)
          .clamp(12.0, math.max(12.0, size.height - 12))
          .toDouble(),
    );

    final sizeChanged = size != _panelSize;
    final posChanged =
        clampedLeft != _position.dx || clampedTop != _position.dy;
    final originChanged = origin != _origin;
    if (!sizeChanged && !posChanged && !originChanged) return;

    setState(() {
      _panelSize = size;
      _position = Offset(clampedLeft, clampedTop);
      _origin = origin;
    });
  }

  void _scheduleMorphReady() {
    if (_morphReady) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || _modality == BeuiContextMenuModality.keyboard) {
      setState(() => _morphReady = true);
      return;
    }
    // Two frames so the collapsed clip paints before expanding (source RAF×2).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_open) return;
        setState(() => _morphReady = true);
      });
    });
  }

  static const _maxMeasureAttempts = 10;

  void _scheduleMeasureAndFocus([int attempt = 0]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _recomputePlacement(box.size);
        _scheduleMorphReady();
      } else if (!_morphReady && attempt < _maxMeasureAttempts) {
        // Portal may not have mounted yet (OverlayPortal show is also
        // post-frame) — try again next frame until we have a size.
        _scheduleMeasureAndFocus(attempt + 1);
      }
      // Focus first enabled item after open.
      final selectable = _selectableIndices;
      if (selectable.isNotEmpty && _activeIndex < 0) {
        setState(() => _activeIndex = selectable.first);
        _schedulePillMeasure();
      }
      if (!_menuFocus.hasFocus) {
        _menuFocus.requestFocus();
      }
    });
  }

  void _schedulePillMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      if (_activeIndex < 0 || _activeIndex >= widget.items.length) {
        if (_pillRect != null) setState(() => _pillRect = null);
        return;
      }
      final rowBox =
          _rowKeys[_activeIndex]?.currentContext?.findRenderObject()
              as RenderBox?;
      final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (rowBox == null || listBox == null || !rowBox.attached) return;
      final rect =
          rowBox.localToGlobal(Offset.zero, ancestor: listBox) & rowBox.size;
      if (rect != _pillRect) setState(() => _pillRect = rect);
    });
  }

  void _setActive(int index) {
    if (index == _activeIndex) return;
    if (index >= 0 && !widget.items[index].isSelectable) return;
    setState(() => _activeIndex = index);
    _schedulePillMeasure();
  }

  void _moveActive(int direction) {
    final selectable = _selectableIndices;
    if (selectable.isEmpty) return;
    final current = selectable.indexOf(_activeIndex);
    final next = current < 0
        ? 0
        : (current + direction + selectable.length) % selectable.length;
    _setActive(selectable[next]);
  }

  void _activateHomeEnd({required bool home}) {
    final selectable = _selectableIndices;
    if (selectable.isEmpty) return;
    _setActive(home ? selectable.first : selectable.last);
  }

  void _selectIndex(int index) {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (!item.isSelectable) return;
    if (item.kind == BeuiContextMenuItemKind.checkbox) {
      item.onCheckedChange?.call(!item.checked);
    } else {
      item.onSelect?.call();
    }
    if (item.closeOnSelect) _setOpen(false);
  }

  void _typeaheadKey(String ch) {
    _typeahead += ch.toLowerCase();
    _typeaheadTimer?.cancel();
    _typeaheadTimer = Timer(_typeaheadReset, () {
      _typeahead = '';
    });
    final selectable = _selectableIndices;
    for (final i in selectable) {
      final label = widget.items[i].label.trim().toLowerCase();
      if (label.startsWith(_typeahead)) {
        _setActive(i);
        return;
      }
    }
  }

  KeyEventResult _onMenuKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveActive(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveActive(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _activateHomeEnd(home: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _activateHomeEnd(home: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_activeIndex >= 0) _selectIndex(_activeIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _setOpen(false);
      return KeyEventResult.handled;
    }
    // Typeahead — single printable characters without modifiers.
    final label = event.character;
    if (label != null &&
        label.length == 1 &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        label.codeUnitAt(0) >= 32) {
      _typeaheadKey(label);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_open) _scheduleMeasureAndFocus();

    final trigger = Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _cancelLongPress(),
      onPointerCancel: (_) => _cancelLongPress(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) {
          _cancelLongPress();
          _openAt(details.globalPosition, BeuiContextMenuModality.pointer);
        },
        child: KeyedSubtree(key: _triggerKey, child: widget.child),
      ),
    );

    final focusedTrigger = FocusableActionDetector(
      enabled: widget.enabled,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f10, shift: true):
            _OpenContextMenuIntent(),
        SingleActivator(LogicalKeyboardKey.contextMenu):
            _OpenContextMenuIntent(),
      },
      actions: {
        _OpenContextMenuIntent: CallbackAction<_OpenContextMenuIntent>(
          onInvoke: (_) {
            _openFromKeyboard();
            return null;
          },
        ),
      },
      child: trigger,
    );

    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      barrier: true,
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      trapFocus: true,
      enterDuration: _morphDuration,
      exitDuration: const Duration(milliseconds: 160),
      overlayBuilder: _buildPanel,
      child: focusedTrigger,
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    // Overlay portal mounts asynchronously — keep measuring from the panel
    // build path so placement/morph aren't stuck waiting on the host rebuild.
    if (_open && (_panelSize == Size.zero || !_morphReady)) {
      _scheduleMeasureAndFocus();
    }

    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final visualOpen = _open && _morphReady;
    final instant = reduce || _modality == BeuiContextMenuModality.keyboard;

    final motion = instant
        ? CurvedMotion(
            reduce ? _reduceMorphDuration : Duration.zero,
            beuiEaseOut,
          )
        : const CurvedMotion(_morphDuration, beuiEaseOut);

    // Full-size layer (like command-palette / select) so the overlay Stack's
    // non-positioned child participates in hit-testing reliably; the panel
    // itself is Positioned at the pointer inside.
    //
    // Source opens with a clip-path inset morph from the pointer. Flutter's
    // ClipPath also clips hit-tests (rows untappable mid-entrance), so the
    // port uses a scale-from-origin + opacity fade for the same pointer-origin
    // read while keeping the full panel hittable.
    return FadeTransition(
      opacity: animation,
      child: Stack(
        children: [
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: SingleMotionBuilder(
              value: visualOpen ? 1.0 : 0.0,
              from: 0,
              motion: motion,
              builder: (context, t, child) {
                final progress = t.clamp(0.0, 1.0);
                if (instant || _panelSize == Size.zero) {
                  return child!;
                }
                final size = _panelSize;
                final ax = size.width == 0
                    ? 0.0
                    : (_origin.dx / size.width) * 2 - 1;
                final ay = size.height == 0
                    ? 0.0
                    : (_origin.dy / size.height) * 2 - 1;
                // Collapsed ≈ 16px origin sliver → scale from ~0.08 toward 1.
                final scale = lerpDouble(
                  0.08,
                  1.0,
                  beuiEaseOut.transform(progress),
                )!;
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment(ax, ay),
                  child: child,
                );
              },
              child: _MenuPanel(
                key: _panelKey,
                listKey: _listKey,
                rowKeys: _rowKeys,
                items: widget.items,
                activeIndex: _activeIndex,
                pillRect: _pillRect,
                colors: colors,
                reduce: reduce,
                minWidth: widget.minWidth,
                semanticLabel: widget.semanticLabel,
                focusNode: _menuFocus,
                onKey: _onMenuKey,
                onHover: _setActive,
                onSelect: _selectIndex,
                onPillMeasure: _schedulePillMeasure,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenContextMenuIntent extends Intent {
  const _OpenContextMenuIntent();
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.listKey,
    required this.rowKeys,
    required this.items,
    required this.activeIndex,
    required this.pillRect,
    required this.colors,
    required this.reduce,
    required this.minWidth,
    required this.semanticLabel,
    required this.focusNode,
    required this.onKey,
    required this.onHover,
    required this.onSelect,
    required this.onPillMeasure,
    super.key,
  });

  final GlobalKey listKey;
  final Map<int, GlobalKey> rowKeys;
  final List<BeuiContextMenuItem> items;
  final int activeIndex;
  final Rect? pillRect;
  final BeuiColors colors;
  final bool reduce;
  final double minWidth;
  final String semanticLabel;
  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onSelect;
  final VoidCallback onPillMeasure;

  @override
  Widget build(BuildContext context) {
    onPillMeasure();

    // Fixed min width (source min-w-56) — Positioned overlay has no max
    // constraint, so stretch columns need a definite width.
    final panel = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: minWidth,
        child: Container(
          padding: const EdgeInsets.all(6), // p-1.5
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(_panelRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            key: listKey,
            children: [
              if (pillRect != null)
                MotionBuilder<Rect>(
                  value: pillRect!,
                  motion: motionFor(
                    context,
                    beuiSpringLayout,
                    isMovement: true,
                  ),
                  converter: const RectMotionConverter(),
                  builder: (context, rect, _) {
                    final activeItem =
                        activeIndex >= 0 && activeIndex < items.length
                        ? items[activeIndex]
                        : null;
                    final destructive =
                        activeItem?.tone == BeuiContextMenuTone.destructive;
                    // NoMotion holds the rect it was seeded with, so under
                    // reduced motion the highlight parked on the first row and
                    // arrow-key navigation had no visible indicator at all.
                    // Read the target rect directly instead — the same
                    // compensation `expandable_action_bar` uses.
                    final r = reduce ? pillRect! : rect;
                    return Positioned(
                      left: r.left,
                      top: r.top,
                      width: r.width,
                      height: r.height,
                      child: DecoratedBox(
                        key: const ValueKey('beui-context-menu-highlight'),
                        decoration: BoxDecoration(
                          color: destructive
                              ? colors.destructive.withValues(alpha: 0.10)
                              : colors.foreground.withValues(alpha: 0.065),
                          borderRadius: BorderRadius.circular(_rowRadius),
                        ),
                      ),
                    );
                  },
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _MenuRow(
                      key: rowKeys.putIfAbsent(i, GlobalKey.new),
                      item: items[i],
                      active: i == activeIndex,
                      colors: colors,
                      onHover: () => onHover(i),
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Focus(
      focusNode: focusNode,
      onKeyEvent: onKey,
      child: Semantics(
        container: true,
        label: semanticLabel,
        explicitChildNodes: true,
        child: panel,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.active,
    required this.colors,
    required this.onHover,
    required this.onTap,
    super.key,
  });

  final BeuiContextMenuItem item;
  final bool active;
  final BeuiColors colors;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case BeuiContextMenuItemKind.separator:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, thickness: 1, color: colors.border),
        );
      case BeuiContextMenuItemKind.label:
        return Padding(
          padding: EdgeInsets.fromLTRB(item.inset ? 32 : 10, 6, 10, 4),
          child: Text(
            item.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: colors.mutedForeground,
            ),
          ),
        );
      case BeuiContextMenuItemKind.action:
      case BeuiContextMenuItemKind.checkbox:
      case BeuiContextMenuItemKind.radio:
        return _SelectableRow(
          item: item,
          active: active,
          colors: colors,
          onHover: onHover,
          onTap: onTap,
        );
    }
  }
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.item,
    required this.active,
    required this.colors,
    required this.onHover,
    required this.onTap,
  });

  final BeuiContextMenuItem item;
  final bool active;
  final BeuiColors colors;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destructive = item.tone == BeuiContextMenuTone.destructive;
    final fg = destructive ? colors.destructive : colors.foreground;
    final enabled = item.enabled;

    Widget? leading;
    if (item.kind == BeuiContextMenuItemKind.checkbox) {
      // Source: a Lucide `Check` (h-3.5) that pops in on SPRING_PANEL under
      // AnimatePresence — `{opacity: 0, scale: 0.75} → {opacity: 1, scale: 1}`.
      leading = SizedBox(
        width: 16,
        height: 16,
        child: _CheckMark(checked: item.checked, color: fg),
      );
    } else if (item.kind == BeuiContextMenuItemKind.radio) {
      leading = SizedBox(
        width: 16,
        height: 16,
        child: Center(
          child: AnimatedOpacity(
            opacity: item.checked ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          ),
        ),
      );
    } else if (item.icon != null) {
      leading = Icon(item.icon, size: 16, color: fg);
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 10)],
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (item.shortcut != null) ...[
            const SizedBox(width: 16),
            Text(
              item.shortcut!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      checked:
          item.kind == BeuiContextMenuItemKind.checkbox ||
              item.kind == BeuiContextMenuItemKind.radio
          ? item.checked
          : null,
      label: item.label,
      child: MouseRegion(
        onEnter: enabled ? (_) => onHover() : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(opacity: enabled ? 1 : 0.4, child: row),
        ),
      ),
    );
  }
}

/// The checkbox row's tick — a Lucide check that pops in on [beuiSpringPanel]
/// (source `initial {opacity: 0, scale: 0.75} → animate {opacity: 1, scale: 1}`
/// under `AnimatePresence`) and shrinks back out when unchecked.
///
/// Under reduced motion it crossfades in place over 80ms (source's
/// `{ duration: 0.08 }` branch), with no scale.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked, required this.color});

  final bool checked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final mark = Icon(LucideIcons.check, size: 14, color: color);
    if (reduce) {
      return AnimatedOpacity(
        opacity: checked ? 1 : 0,
        duration: const Duration(milliseconds: 80),
        child: mark,
      );
    }
    return SingleMotionBuilder(
      value: checked ? 1.0 : 0.0,
      motion: beuiSpringPanel,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        // 0.75 → 1 across the same channel.
        child: Transform.scale(scale: 0.75 + 0.25 * t, child: child),
      ),
      child: mark,
    );
  }
}
