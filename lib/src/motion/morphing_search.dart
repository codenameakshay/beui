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
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_open && event.logicalKey == LogicalKeyboardKey.escape) {
      _setOpen(false);
      return true;
    }
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
    if (focused != null && focused.widget is EditableText) return false;
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    final results = _results;
    if (_active >= results.length) _active = math.max(0, results.length - 1);
    final trigger = Semantics(
      button: true,
      label: widget.placeholder,
      expanded: _open,
      child: SizedBox(
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
    _wasOpen = _open;
    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      barrierColor: colors.background.withValues(alpha: .05),
      barrierBlur: 6,
      enterDuration: const Duration(milliseconds: 580),
      exitDuration: const Duration(milliseconds: 320),
      overlayBuilder: (context, animation, link) {
        final media = MediaQuery.sizeOf(context);
        final width = math.min(448.0, media.width - 32);
        final maxHeight = math.max(96.0, math.min(288.0, media.height - 80));
        Widget panel = Material(
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
                        },
                        onSubmitted: (_) {
                          if (results.isNotEmpty) _select(results[_active]);
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
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.emptyMessage,
                          style: TextStyle(color: colors.mutedForeground),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return Semantics(
                            selected: index == _active,
                            child: Material(
                              color: index == _active
                                  ? colors.foreground.withValues(alpha: .06)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onHover: (hover) {
                                  if (hover) setState(() => _active = index);
                                },
                                onTap: () => _select(item),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      if (item.icon != null) ...[
                                        Icon(
                                          item.icon,
                                          size: 16,
                                          color: colors.mutedForeground,
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: colors.foreground,
                                              ),
                                            ),
                                            if (item.description
                                                case final description?)
                                              Text(
                                                description,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colors.mutedForeground,
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
            ],
          ),
        );
        panel = Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Search',
          child: panel,
        );
        if (!reduce) {
          panel = SingleMotionBuilder(
            value: _open ? 1.0 : 0.0,
            from: 0,
            motion: motionFor(context, _searchMorph, isMovement: true),
            builder: (context, progress, child) => Transform.scale(
              scale: .96 + progress.clamp(0, 1) * .04,
              child: child,
            ),
            child: panel,
          );
        }
        return CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topLeft,
          showWhenUnlinked: false,
          child: SizedBox(width: width, child: panel),
        );
      },
      child: trigger,
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
