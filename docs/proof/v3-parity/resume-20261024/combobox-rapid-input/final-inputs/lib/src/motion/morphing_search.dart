import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '../tokens/icons.dart';
import '_engine.dart';

/// A searchable entry shown by [BeuiMorphingSearch].
@immutable
class BeuiMorphingSearchItem {
  /// Creates a search result.
  const BeuiMorphingSearchItem({
    required this.id,
    required this.title,
    this.description,
    this.keywords = const [],
    this.icon,
    this.onSelect,
  });

  /// Stable result identifier.
  final String id;

  /// Primary result label.
  final String title;

  /// Optional supporting text.
  final String? description;

  /// Additional searchable terms.
  final List<String> keywords;

  /// Optional leading icon.
  final IconData? icon;

  /// Called when this result is selected.
  final VoidCallback? onSelect;
}

/// A search field or compact icon that opens a keyboard-navigable result panel.
class BeuiMorphingSearch extends StatefulWidget {
  /// Creates a morphing search surface.
  const BeuiMorphingSearch({
    required this.items,
    this.placeholder = 'Search',
    this.shortcut = 'f',
    this.iconOnly = false,
    this.emptyMessage = 'No results found.',
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.onQueryChange,
    this.onSelect,
    super.key,
  });

  /// Searchable results.
  final List<BeuiMorphingSearchItem> items;

  /// Field and trigger label.
  final String placeholder;

  /// Single-key global shortcut; an empty string disables it.
  final String shortcut;

  /// Renders the closed trigger as a compact icon.
  final bool iconOnly;

  /// Empty-results label.
  final String emptyMessage;

  /// Controlled open state.
  final bool? open;

  /// Initial state when uncontrolled.
  final bool defaultOpen;

  /// Called when the requested open state changes.
  final ValueChanged<bool>? onOpenChange;

  /// Called as the query changes.
  final ValueChanged<String>? onQueryChange;

  /// Called after an item-level selection callback.
  final ValueChanged<BeuiMorphingSearchItem>? onSelect;

  @override
  State<BeuiMorphingSearch> createState() => _BeuiMorphingSearchState();
}

// Framer duration/bounce conversion: ω=2π/0.58, ζ=1−0.22, k=ω², c=2ζω.
const _searchMorph = SpringMotion(
  SpringDescription(mass: 1, stiffness: 117.4, damping: 16.9),
);

class _BeuiMorphingSearchState extends State<BeuiMorphingSearch> {
  late bool _internalOpen = widget.defaultOpen;
  final _query = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _handleInputKey);
  final _triggerFocus = FocusNode();
  final _triggerKey = GlobalKey();
  final _resultKeys = <int, GlobalKey>{};
  final _resultsScroll = ScrollController();
  int _active = 0;
  bool _wasOpen = false;

  bool get _open => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void didUpdateWidget(covariant BeuiMorphingSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_open && !_wasOpen) _focusInput();
    if (!_open && _wasOpen) _query.clear();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _query.dispose();
    _focus.dispose();
    _triggerFocus.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final shortcut = widget.shortcut.toLowerCase();
    if (_open ||
        shortcut.isEmpty ||
        event.logicalKey.keyLabel.toLowerCase() != shortcut ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isShiftPressed) {
      return false;
    }
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    _setOpen(true);
    return true;
  }

  KeyEventResult _handleInputKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final results = _results;
      if (results.isNotEmpty) {
        setState(
          () => _active =
              (_active +
                      (event.logicalKey == LogicalKeyboardKey.arrowDown
                          ? 1
                          : -1))
                  .clamp(0, results.length - 1),
        );
        _revealActiveResult();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final results = _results;
      if (results.isNotEmpty) {
        _select(results[_active.clamp(0, results.length - 1)]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _revealActiveResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open || !_resultsScroll.hasClients) return;
      final activeContext = _resultKeys[_active]?.currentContext;
      if (activeContext != null) {
        final row = activeContext.findRenderObject()!;
        _resultsScroll.position
          ..ensureVisible(
            row,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          )
          ..ensureVisible(
            row,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        return;
      }
      final mountedIndices = _resultKeys.entries
          .where((entry) => entry.value.currentContext != null)
          .map((entry) => entry.key);
      if (mountedIndices.isEmpty) return;
      final position = _resultsScroll.position;
      final direction = _active > mountedIndices.reduce(math.max) ? 1 : -1;
      final offset = (position.pixels + direction * position.viewportDimension)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (offset == position.pixels) return;
      _resultsScroll.jumpTo(offset);
      _revealActiveResult();
    });
  }

  void _setOpen(bool value) {
    if (widget.open == null) setState(() => _internalOpen = value);
    widget.onOpenChange?.call(value);
    if (value) {
      _query.clear();
      widget.onQueryChange?.call('');
      _active = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput());
    } else {
      _query.clear();
      widget.onQueryChange?.call('');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerFocus.requestFocus();
      });
    }
  }

  void _focusInput() {
    if (mounted) _focus.requestFocus();
  }

  List<BeuiMorphingSearchItem> get _results {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where(
          (item) => <String>[
            item.title,
            item.description ?? '',
            ...item.keywords,
          ].join(' ').toLowerCase().contains(q),
        )
        .toList();
  }

  void _select(BeuiMorphingSearchItem item) {
    item.onSelect?.call();
    widget.onSelect?.call(item);
    _setOpen(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final morphMotion = motionFor(context, _searchMorph, isMovement: true);
    final reduce = morphMotion is NoMotion;
    final results = _results;
    if (_active >= results.length) _active = math.max(0, results.length - 1);
    final trigger = Semantics(
      key: _triggerKey,
      button: true,
      label: widget.placeholder,
      expanded: _open,
      child: SizedBox(
        key: const ValueKey('beui-morphing-search-trigger'),
        width: widget.iconOnly ? 48 : 288,
        height: 48,
        child: OutlinedButton(
          onPressed: () => _setOpen(true),
          focusNode: _triggerFocus,
          style: OutlinedButton.styleFrom(
            alignment: widget.iconOnly
                ? Alignment.center
                : Alignment.centerLeft,
            backgroundColor: colors.background.withValues(alpha: .6),
            foregroundColor: colors.mutedForeground,
            side: BorderSide(color: colors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 0 : 14),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 16, color: colors.mutedForeground),
              if (!widget.iconOnly) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.placeholder,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.shortcut.isNotEmpty)
                  _KeyHint(
                    label: widget.shortcut.toUpperCase(),
                    colors: colors,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    final triggerSize = Size(widget.iconOnly ? 48 : 288, 48);
    _wasOpen = _open;
    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      barrierColor: colors.background.withValues(alpha: .05),
      barrierBlur: 6,
      enterDuration: const Duration(milliseconds: 580),
      exitDuration: const Duration(milliseconds: 320),
      overlayBuilder: (context, animation, link) {
        final media = MediaQuery.of(context);
        final viewport =
            Overlay.of(context, rootOverlay: true).context.findRenderObject()
                as RenderBox;
        final origin =
            (_triggerKey.currentContext!.findRenderObject() as RenderBox)
                .localToGlobal(Offset.zero, ancestor: viewport);
        final width = math.min(448.0, math.max(0.0, viewport.size.width - 32));
        final bottom = viewport.size.height - media.viewInsets.bottom - 16;
        final maxHeight = math.max(0.0, math.min(288.0, bottom - 65));
        final resultsHeight = math.min(
          maxHeight,
          results.isEmpty
              ? 64.0
              : 16.0 +
                    results.fold<double>(
                      0,
                      (height, item) =>
                          height + (item.description == null ? 40 : 54),
                    ),
        );
        final panelSize = Size(width, 49 + resultsHeight);
        final panelOrigin = Offset(
          origin.dx.clamp(
            16.0,
            math.max(16.0, viewport.size.width - width - 16),
          ),
          origin.dy.clamp(16.0, math.max(16.0, bottom - panelSize.height)),
        );
        return CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topLeft,
          showWhenUnlinked: false,
          offset: panelOrigin - origin,
          child: MotionBuilder<Size>(
            value: _open ? panelSize : triggerSize,
            from: reduce ? panelSize : triggerSize,
            active: !reduce,
            converter: const SizeMotionConverter(),
            motion: morphMotion,
            builder: (context, size, child) => SizedBox(
              key: const ValueKey('beui-morphing-search-panel'),
              width: size.width,
              height: size.height,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: panelSize.width,
                  maxWidth: panelSize.width,
                  minHeight: panelSize.height,
                  maxHeight: panelSize.height,
                  child: child,
                ),
              ),
            ),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Search',
              child: Material(
                color: colors.background.withValues(alpha: .9),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            LucideIcons.search,
                            size: 16,
                            color: colors.mutedForeground,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _query,
                              focusNode: _focus,
                              autofocus: true,
                              onChanged: (value) {
                                _active = 0;
                                widget.onQueryChange?.call(value);
                                setState(() {});
                                _revealActiveResult();
                              },
                              onSubmitted: (_) {
                                if (results.isNotEmpty) {
                                  _select(results[_active]);
                                }
                              },
                              onEditingComplete: () {},
                              decoration: InputDecoration.collapsed(
                                hintText: widget.placeholder,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Text('Esc'),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.border),
                    ClipRect(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _open ? 1 : 0),
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        curve: beuiEaseOut,
                        builder: (context, progress, child) => Align(
                          alignment: Alignment.topCenter,
                          heightFactor: progress,
                          child: child,
                        ),
                        child: SizedBox(
                          width: width,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: resultsHeight,
                            ),
                            child: results.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      widget.emptyMessage,
                                      style: TextStyle(
                                        color: colors.mutedForeground,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _resultsScroll,
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(8),
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      final item = results[index];
                                      return Semantics(
                                        key: _resultKeys.putIfAbsent(
                                          index,
                                          GlobalKey.new,
                                        ),
                                        selected: index == _active,
                                        child: Material(
                                          color: index == _active
                                              ? colors.foreground.withValues(
                                                  alpha: .06,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: InkWell(
                                            onHover: (hover) {
                                              if (hover) {
                                                setState(() => _active = index);
                                              }
                                            },
                                            onTap: () => _select(item),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              child: Row(
                                                children: [
                                                  if (item.icon != null) ...[
                                                    Icon(
                                                      item.icon,
                                                      size: 16,
                                                      color: colors
                                                          .mutedForeground,
                                                    ),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item.title,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: colors
                                                                .foreground,
                                                          ),
                                                        ),
                                                        if (item.description
                                                            case final description?)
                                                          Text(
                                                            description,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: colors
                                                                  .mutedForeground,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: ExcludeSemantics(
        excluding: _open,
        child: IgnorePointer(
          ignoring: _open,
          child: Opacity(opacity: _open ? 0 : 1, child: trigger),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label, required this.colors});
  final String label;
  final BeuiColors colors;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: colors.mutedForeground),
    ),
  );
}
