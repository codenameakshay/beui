import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One command in a [BeuiCommandPalette] (source `CommandItem`).
@immutable
class BeuiCommandItem {
  /// Creates a command item.
  const BeuiCommandItem({
    required this.id,
    required this.label,
    required this.onSelect,
    this.group,
    this.hint,
    this.keywords = const [],
    this.icon,
    this.badge,
  });

  /// Stable identity.
  final String id;

  /// Row label; also the primary fuzzy-match haystack.
  final String label;

  /// Invoked when the item is chosen; the palette closes after.
  final VoidCallback onSelect;

  /// Section header this item is grouped under (default `Results`).
  final String? group;

  /// Trailing keyboard hint chip (e.g. `⌘N`).
  final String? hint;

  /// Extra fuzzy-match haystacks.
  final List<String> keywords;

  /// Optional leading glyph.
  final IconData? icon;

  /// Optional trailing widget (e.g. a badge).
  final Widget? badge;
}

/// Subsequence fuzzy match (source `fuzzyMatch`).
bool _fuzzyMatch(String needle, String hay) {
  if (needle.isEmpty) return true;
  needle = needle.toLowerCase();
  hay = hay.toLowerCase();
  var i = 0;
  for (final ch in hay.split('')) {
    if (ch == needle[i]) i++;
    if (i == needle.length) return true;
  }
  return false;
}

/// Opened via a keyboard shortcut many times a day — the entrance must read
/// as instant. Tight spring, even faster exit (source `PANEL_SPRING`,
/// 560 · 40 · 0.5).
const _panelSpring = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 560, damping: 40),
);

/// Exit: 120ms `EASE_OUT` (source close transition).
const _exitMotion = CurvedMotion(Duration(milliseconds: 120), beuiEaseOut);

/// Active-row glide — tracks rapid arrow-key navigation, deliberately tighter
/// than `SPRING_LAYOUT` so it never lags (source 480 · 38).
const _rowSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 480, damping: 38),
);

/// A ⌘K command palette: fuzzy filter, grouped results, spring-gliding active
/// row — the Flutter port of beUI's `CommandPalette`, built on [BeuiOverlay].
///
/// Mount it anywhere (optionally around a [child] trigger); it listens for
/// Cmd/Ctrl+[shortcut] app-wide, exactly like the source's window listener.
/// `open` follows the library's controlled + uncontrolled convention.
class BeuiCommandPalette extends StatefulWidget {
  /// Creates a command palette host.
  const BeuiCommandPalette({
    required this.items,
    this.shortcut = 'k',
    this.placeholder = 'Type a command or search…',
    this.emptyMessage = 'No results found.',
    this.open,
    this.onOpenChange,
    this.child,
    super.key,
  });

  /// The commands.
  final List<BeuiCommandItem> items;

  /// Opens with Cmd/Ctrl + this key (source `shortcut = "k"`).
  final String shortcut;

  /// Search field placeholder.
  final String placeholder;

  /// Shown when the filter matches nothing.
  final String emptyMessage;

  /// Controlled open state; null for uncontrolled.
  final bool? open;

  /// Fires when the palette wants to open/close.
  final ValueChanged<bool>? onOpenChange;

  /// Optional in-tree child (e.g. a trigger button).
  final Widget? child;

  @override
  State<BeuiCommandPalette> createState() => _BeuiCommandPaletteState();
}

class _BeuiCommandPaletteState extends State<BeuiCommandPalette> {
  bool _internalOpen = false;
  final TextEditingController _query = TextEditingController();
  int _active = 0;
  final Map<String, GlobalKey> _rowKeys = {};
  final GlobalKey _listKey = GlobalKey();
  Rect? _pillRect;

  bool get _open => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _query.dispose();
    super.dispose();
  }

  void _setOpen(bool value) {
    if (value == _open) return;
    if (value) {
      _query.clear();
      _active = 0;
      _pillRect = null;
    }
    if (widget.open == null) {
      setState(() => _internalOpen = value);
    } else {
      setState(() {}); // re-render pending the controlled echo
    }
    widget.onOpenChange?.call(value);
  }

  /// The source's window keydown listener: Cmd/Ctrl+shortcut toggles.
  /// (Esc-to-close is [BeuiOverlay]'s job while open.)
  bool _onGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    if ((keyboard.isMetaPressed || keyboard.isControlPressed) &&
        event.logicalKey.keyLabel.toLowerCase() ==
            widget.shortcut.toLowerCase()) {
      _setOpen(!_open);
      return true;
    }
    return false;
  }

  List<BeuiCommandItem> get _filtered {
    final query = _query.text;
    final matched = query.isEmpty
        ? widget.items
        : widget.items.where((it) {
            return _fuzzyMatch(query, it.label) ||
                _fuzzyMatch(query, it.group ?? '') ||
                it.keywords.any((k) => _fuzzyMatch(query, k));
          }).toList();
    // Flatten in grouped display order — the source's `cursor` walks the
    // grouped list, so arrow keys follow what the eye sees.
    final grouped = _group(matched);
    return [for (final list in grouped.values) ...list];
  }

  Map<String, List<BeuiCommandItem>> _group(List<BeuiCommandItem> items) {
    final grouped = <String, List<BeuiCommandItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.group ?? 'Results', () => []).add(item);
    }
    return grouped;
  }

  void _setActive(int index, {bool measure = true}) {
    if (index == _active) return;
    setState(() => _active = index);
    if (measure) _schedulePillMeasure();
  }

  void _select(BeuiCommandItem item) {
    item.onSelect();
    _setOpen(false);
  }

  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final filtered = _filtered;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _setActive(
        filtered.isEmpty ? 0 : (_active + 1).clamp(0, filtered.length - 1),
      );
      _revealActive();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _setActive(
        (_active - 1).clamp(0, filtered.isEmpty ? 0 : filtered.length - 1),
      );
      _revealActive();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_active < filtered.length) _select(filtered[_active]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _revealActive() {
    final filtered = _filtered;
    if (_active >= filtered.length) return;
    final context = _rowKeys[filtered[_active].id]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      context,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  /// Measures the active row against the list content — the `layoutId` pill.
  void _schedulePillMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      final filtered = _filtered;
      if (_active >= filtered.length) {
        if (_pillRect != null) setState(() => _pillRect = null);
        return;
      }
      final rowBox =
          _rowKeys[filtered[_active].id]?.currentContext?.findRenderObject()
              as RenderBox?;
      final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (rowBox == null || listBox == null || !rowBox.attached) return;
      final rect =
          rowBox.localToGlobal(Offset.zero, ancestor: listBox) & rowBox.size;
      if (rect != _pillRect) setState(() => _pillRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      // bg-background/5 + backdrop blur(12px) — the source's glass veil.
      barrierColor: Theme.of(
        context,
      ).extension<BeuiColors>()!.background.withValues(alpha: 0.05),
      barrierBlur: 6, // blur(12px) ≈ σ6
      enterDuration: const Duration(milliseconds: 180),
      exitDuration: const Duration(milliseconds: 120),
      overlayBuilder: _buildPanel,
      child: widget.child ?? const SizedBox.shrink(),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final media = MediaQuery.of(context);
    final filtered = _filtered;
    final hasIcons = widget.items.any((it) => it.icon != null);

    final grouped = _group(filtered);
    _schedulePillMeasure();

    // `rounded-2xl border border-border bg-card shadow-2xl`.
    Widget panel = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: colors.border),
        boxShadow: const [
          // shadow-2xl: 0 25px 50px -12px rgb(0 0 0 / 0.25)
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 25),
            blurRadius: 50,
            spreadRadius: -12,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SearchRow(
              controller: _query,
              placeholder: widget.placeholder,
              colors: colors,
              onChanged: (_) {
                _active = 0;
                setState(() {});
                _schedulePillMeasure();
              },
              onKeyEvent: _onListKey,
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.6, // max-h-[60vh]
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32), // p-8
                        child: Text(
                          widget.emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.mutedForeground,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(8), // p-2
                        child: Stack(
                          key: _listKey,
                          children: [
                            if (_pillRect != null)
                              MotionBuilder<Rect>(
                                value: _pillRect!,
                                motion: reduce ? const NoMotion() : _rowSpring,
                                converter: const RectMotionConverter(),
                                builder: (context, rect, _) => Positioned(
                                  left: rect.left,
                                  top: rect.top,
                                  width: rect.width,
                                  height: rect.height,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (i, entry)
                                    in grouped.entries.indexed) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: ExcludeSemantics(
                                      child: Text(
                                        entry.key.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          // The source's inherited leading —
                                          // a 15px line box on a 10px face.
                                          height: 1.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                          color: colors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final item in entry.value)
                                    _CommandRow(
                                      key: _rowKeys.putIfAbsent(
                                        item.id,
                                        GlobalKey.new,
                                      ),
                                      item: item,
                                      active: filtered.indexOf(item) == _active,
                                      hasIcons: hasIcons,
                                      colors: colors,
                                      onHover: () =>
                                          _setActive(filtered.indexOf(item)),
                                      onTap: () => _select(item),
                                    ),
                                  // `mb-1 last:mb-0` on the group wrapper.
                                  if (i < grouped.length - 1)
                                    const SizedBox(height: 4),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
      child: panel,
    );

    // Entrance: opacity + y -8 + scale 0.97 on PANEL_SPRING; exit 120ms
    // EASE_OUT. Reduced motion keeps the fade only (~100ms).
    final fade = CurvedAnimation(parent: animation, curve: beuiEaseOut);
    Widget animated = FadeTransition(opacity: fade, child: panel);
    if (!reduce) {
      animated = SingleMotionBuilder(
        value: _open ? 1.0 : 0.0,
        from: 0.0,
        motion: _open ? _panelSpring : _exitMotion,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, -8 * (1 - t)),
          child: Transform.scale(
            scale: 0.97 + 0.03 * t.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: animated,
      );
    }

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(
          top: media.size.height * 0.18, // pt-[18vh]
          left: 16,
          right: 16,
          bottom: 16,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'Command palette',
            child: animated,
          ),
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.placeholder,
    required this.colors,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final String placeholder;
  final BeuiColors colors;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  @override
  Widget build(BuildContext context) {
    // `h-12` sits on the *input*, not the row — so the row is 48px of input
    // plus the 1px `border-b`, 49 total. Container adds the border to its
    // own padding, so the SizedBox keeps the input at exactly 48.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        spacing: 12, // gap-3
        children: [
          Icon(LucideIcons.search, size: 16, color: colors.mutedForeground),
          Expanded(
            child: SizedBox(
              height: 48, // h-12 on the input
              // `isCollapsed` fields align to the top of a tight box; the
              // source centres the text in the 48px input.
              child: Center(
                child: Focus(
                  onKeyEvent: onKeyEvent,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: onChanged,
                    style: TextStyle(fontSize: 14, color: colors.foreground),
                    cursorColor: colors.foreground,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: placeholder,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Kbd(label: 'ESC', colors: colors),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.item,
    required this.active,
    required this.hasIcons,
    required this.colors,
    required this.onHover,
    required this.onTap,
    super.key,
  });

  final BeuiCommandItem item;
  final bool active;
  final bool hasIcons;
  final BeuiColors colors;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? colors.foreground : colors.mutedForeground;
    return Semantics(
      button: true,
      selected: active,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8), // px-2 py-2
            child: Row(
              spacing: 12, // gap-3
              children: [
                if (item.icon != null)
                  Icon(item.icon, size: 16, color: color)
                else if (hasIcons)
                  const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // `text-sm` — 14px on a 20px line box, which is what makes
                    // the row 36px tall (py-2 + 20).
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: color,
                    ),
                  ),
                ),
                if (item.badge != null) item.badge!,
                if (item.hint != null) _Kbd(label: item.hint!, colors: colors),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd({required this.label, required this.colors});

  final String label;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        // 14px line box + py-0.5 + 1px borders = the source's 20px chip.
        style: TextStyle(
          fontSize: 10,
          height: 1.4,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}
