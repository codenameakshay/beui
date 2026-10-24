import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';

/// One option displayed by [BeuiMultiSelect].
@immutable
class BeuiMultiSelectOption {
  /// Creates an option with its submitted [value] and visible [label].
  const BeuiMultiSelectOption({
    required this.value,
    required this.label,
    this.keywords = const [],
    this.disabled = false,
    this.leading,
  });

  /// Stable value included in the selected values list.
  final String value;

  /// Human-readable label displayed in the list and token.
  final String label;

  /// Extra searchable text.
  final List<String> keywords;

  /// Whether this option can be selected.
  final bool disabled;

  /// Optional leading content, such as a colored dot or avatar.
  final Widget? leading;
}

/// Searchable multi-select with removable tokens and an anchored option panel.
///
/// Supply [value] and [onChanged] for controlled use, or leave [value] null and
/// seed [defaultValue] for internal state. [open] and [query] follow the same
/// controlled/uncontrolled convention. Selecting an item toggles it without
/// closing the list.
class BeuiMultiSelect extends StatefulWidget {
  /// Creates a multi-select over [items].
  const BeuiMultiSelect({
    required this.items,
    this.value,
    this.defaultValue = const [],
    this.onChanged,
    this.open,
    this.defaultOpen = false,
    this.onOpenChanged,
    this.query,
    this.defaultQuery = '',
    this.onQueryChanged,
    this.disabled = false,
    this.placeholder = 'Select options',
    this.searchHint = 'Search…',
    this.emptyLabel = 'No options found.',
    this.filter,
    super.key,
  });

  /// Options in display order.
  final List<BeuiMultiSelectOption> items;

  /// Controlled selected values. When null, [defaultValue] seeds internal state.
  final List<String>? value;

  /// Initial selections in uncontrolled mode.
  final List<String> defaultValue;

  /// Called whenever the selection changes.
  final ValueChanged<List<String>>? onChanged;

  /// Controlled panel visibility.
  final bool? open;

  /// Initial panel visibility in uncontrolled mode.
  final bool defaultOpen;

  /// Called whenever panel visibility changes.
  final ValueChanged<bool>? onOpenChanged;

  /// Controlled search query.
  final String? query;

  /// Initial query in uncontrolled mode.
  final String defaultQuery;

  /// Called whenever the query changes.
  final ValueChanged<String>? onQueryChanged;

  /// Disable the trigger and all selection/removal actions.
  final bool disabled;

  /// Placeholder shown when there are no selected values.
  final String placeholder;

  /// Search field hint.
  final String searchHint;

  /// Status text shown when filtering has no matches.
  final String emptyLabel;

  /// Optional custom filter. Receives option, query; defaults to case-folded
  /// substring matching over value, label, and keywords.
  final bool Function(BeuiMultiSelectOption option, String query)? filter;

  @override
  State<BeuiMultiSelect> createState() => _BeuiMultiSelectState();
}

class _BeuiMultiSelectState extends State<BeuiMultiSelect> {
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'beui_multi_select');
  late final TextEditingController _controller;
  late List<String> _internalValues;
  late bool _internalOpen;
  late String _internalQuery;
  int _activeIndex = -1;
  int _focusIntent = 0;

  bool get _isOpen => widget.open ?? _internalOpen;
  String get _query => widget.query ?? _internalQuery;
  List<String> get _values => widget.value ?? _internalValues;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  List<BeuiMultiSelectOption> get _visibleItems => widget.items
      .where((item) {
        final q = _query.trim().toLowerCase();
        if (q.isEmpty) return true;
        return widget.filter?.call(item, _query) ??
            <String>[
              item.value,
              item.label,
              ...item.keywords,
            ].join(' ').toLowerCase().contains(q);
      })
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _internalValues = List<String>.of(widget.defaultValue);
    _internalOpen = widget.defaultOpen;
    _internalQuery = widget.defaultQuery;
    _controller = TextEditingController(text: widget.query ?? _internalQuery);
  }

  @override
  void didUpdateWidget(covariant BeuiMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disabled ||
        (oldWidget.open != widget.open && widget.open == false)) {
      _focusIntent++;
    }
    final next = widget.query ?? _internalQuery;
    if (_controller.text != next) {
      _controller.value = TextEditingValue(text: next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool open, {bool restoreFocus = false}) {
    if (widget.disabled && open) return;
    if (widget.open == null) setState(() => _internalOpen = open);
    widget.onOpenChanged?.call(open);
    if (!open) {
      _focusIntent++;
      _setQuery('');
    }
    if (restoreFocus) _inputFocus.requestFocus();
  }

  void _setQuery(String query) {
    if (widget.query == null) setState(() => _internalQuery = query);
    widget.onQueryChanged?.call(query);
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    _activeIndex = _firstEnabledIndex();
  }

  int _firstEnabledIndex() =>
      _visibleItems.indexWhere((item) => !item.disabled);

  void _moveActive(int direction) {
    final items = _visibleItems;
    if (items.isEmpty) return;
    var next = _activeIndex;
    for (var count = 0; count < items.length; count++) {
      next = (next + direction) % items.length;
      if (next < 0) next += items.length;
      if (!items[next].disabled) {
        setState(() => _activeIndex = next);
        return;
      }
    }
  }

  void _toggleValue(String value) {
    final option = widget.items
        .where((item) => item.value == value)
        .firstOrNull;
    if (widget.disabled || option == null || option.disabled) return;
    final next = _values.contains(value)
        ? _values.where((entry) => entry != value).toList()
        : [..._values, value];
    if (widget.value == null) setState(() => _internalValues = next);
    widget.onChanged?.call(List<String>.unmodifiable(next));
    _setQuery('');
    _inputFocus.requestFocus();
  }

  void _removeChip(String value) {
    final intent = ++_focusIntent;
    final previousFocus = FocusManager.instance.primaryFocus;
    _removeValue(value);
    if (!_isOpen) _setOpen(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.disabled || intent != _focusIntent) return;
      final focus = FocusManager.instance.primaryFocus;
      final focusWithinSelect =
          focus?.context?.findAncestorStateOfType<_BeuiMultiSelectState>() ==
          this;
      final removedFocus = focus == null;
      if (!removedFocus &&
          focus != previousFocus &&
          focus != _inputFocus &&
          !focusWithinSelect) {
        return;
      }
      _inputFocus.requestFocus();
    });
  }

  void _removeValue(String value) {
    if (widget.disabled || !_values.contains(value)) return;
    final next = _values.where((entry) => entry != value).toList();
    if (widget.value == null) setState(() => _internalValues = next);
    widget.onChanged?.call(List<String>.unmodifiable(next));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace &&
        _query.isEmpty &&
        _values.isNotEmpty) {
      _removeValue(_values.last);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (!_isOpen) {
        _setOpen(true);
        _activeIndex = _firstEnabledIndex();
      } else {
        _moveActive(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home && _isOpen) {
      setState(() => _activeIndex = _firstEnabledIndex());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end && _isOpen) {
      final items = _visibleItems;
      setState(
        () => _activeIndex = items.lastIndexWhere((item) => !item.disabled),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (!_isOpen) {
        _setOpen(true);
        _activeIndex = _firstEnabledIndex();
      } else if (_activeIndex >= 0 && _activeIndex < _visibleItems.length) {
        _toggleValue(_visibleItems[_activeIndex].value);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _isOpen) {
      _setOpen(false, restoreFocus: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scope = _MultiSelectScope(
      state: this,
      child: BeuiOverlay(
        open: _isOpen,
        onDismiss: () => _setOpen(false),
        barrier: false,
        trapFocus: false,
        barrierBlur: 0,
        enterDuration: const Duration(milliseconds: 240),
        exitDuration: const Duration(milliseconds: 160),
        overlayBuilder: (context, animation, link) =>
            _MultiSelectContent(animation: animation, link: link),
        child: TapRegion(
          groupId: this,
          onTapOutside: (_) {
            _focusIntent++;
            if (_isOpen) _setOpen(false);
          },
          child: BeuiMultiSelectTrigger(
            key: _triggerKey,
            link: _link,
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      BeuiMultiSelectValue(placeholder: widget.placeholder),
                      BeuiMultiSelectInput(
                        controller: _controller,
                        focusNode: _inputFocus,
                        onKeyEvent: _onKey,
                        hintText: widget.searchHint,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevron_down,
                  size: 16,
                  color: BeuiColors.resolve(context).mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return scope;
  }
}

/// Trigger surface for a [BeuiMultiSelect].
class BeuiMultiSelectTrigger extends StatefulWidget {
  /// Creates a trigger around [child].
  const BeuiMultiSelectTrigger({required this.child, this.link, super.key});

  /// Trigger contents.
  final Widget child;

  /// Optional layer link used by the root's anchored overlay.
  final LayerLink? link;

  @override
  State<BeuiMultiSelectTrigger> createState() => _BeuiMultiSelectTriggerState();
}

class _BeuiMultiSelectTriggerState extends State<BeuiMultiSelectTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scope = _MultiSelectScope.of(context);
    final colors = BeuiColors.resolve(context);
    return CompositedTransformTarget(
      link: widget.link ?? scope.state._link,
      child: MouseRegion(
        onEnter: scope.state.widget.disabled
            ? null
            : (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: scope.state.widget.disabled
              ? null
              : () {
                  scope.state._setOpen(true);
                  scope.state._inputFocus.requestFocus();
                },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 208),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: _hovered && !scope.state.widget.disabled
                    ? colors.borderStrong
                    : colors.border,
              ),
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
              boxShadow: scope.state._inputFocus.hasFocus
                  ? [
                      BoxShadow(
                        color: colors.ring.withValues(alpha: .2),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Opacity(
              opacity: scope.state.widget.disabled ? .5 : 1,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selected values rendered as removable chips inside [BeuiMultiSelectTrigger].
class BeuiMultiSelectValue extends StatelessWidget {
  /// Creates the token collection and its empty [placeholder].
  const BeuiMultiSelectValue({this.placeholder = 'Select options', super.key});

  /// Text shown when no values are selected.
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final state = _MultiSelectScope.of(context).state;
    final colors = BeuiColors.resolve(context);
    if (state._values.isEmpty && !state._isOpen) {
      return Text(
        placeholder,
        style: TextStyle(color: colors.mutedForeground, fontSize: 13),
      );
    }
    if (state._values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final value in state._values)
          _MultiSelectToken(
            key: ValueKey('beui_multi_select_token_$value'),
            value: value,
            label:
                state.widget.items
                    .where((item) => item.value == value)
                    .firstOrNull
                    ?.label ??
                value,
          ),
      ],
    );
  }
}

class _MultiSelectToken extends StatelessWidget {
  const _MultiSelectToken({
    required this.value,
    required this.label,
    super.key,
  });
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final state = _MultiSelectScope.of(context).state;
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        height: 28,
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.only(left: 8, right: 2),
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            MergeSemantics(
              child: Semantics(
                label: 'Remove $label',
                child: IconButton(
                  onPressed: state.widget.disabled
                      ? null
                      : () {
                          state._removeChip(value);
                        },
                  icon: const Icon(LucideIcons.x, size: 12),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 22,
                    height: 22,
                  ),
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search input with combobox semantics and keyboard interaction.
class BeuiMultiSelectInput extends StatelessWidget {
  /// Creates the search field.
  const BeuiMultiSelectInput({
    this.controller,
    this.focusNode,
    this.onKeyEvent,
    this.hintText = 'Search…',
    this.showIcon = false,
    super.key,
  });

  /// Optional text controller; the root supplies its controlled controller.
  final TextEditingController? controller;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Keyboard handler.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Hint shown while no text is entered.
  final String hintText;

  /// Whether to show a search glyph.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final state = _MultiSelectScope.of(context).state;
    final colors = BeuiColors.resolve(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, maxWidth: 190),
      child: Focus(
        onKeyEvent: onKeyEvent,
        child: TextField(
          groupId: state,
          controller: controller ?? state._controller,
          focusNode: focusNode ?? state._inputFocus,
          enabled: !state.widget.disabled,
          onTap: () => state._setOpen(true),
          onChanged: (query) {
            state._setQuery(query);
            if (!state._isOpen) state._setOpen(true);
          },
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(color: colors.foreground, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: state._values.isEmpty ? hintText : '',
            hintStyle: TextStyle(color: colors.mutedForeground),
            prefixIcon: showIcon
                ? const Icon(LucideIcons.search, size: 14)
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Anchored options panel. This widget is provided by the root overlay.
class BeuiMultiSelectContent extends StatelessWidget {
  /// Creates a content wrapper around [child].
  const BeuiMultiSelectContent({
    required this.child,
    this.sideOffset = 6,
    super.key,
  });

  /// Panel content.
  final Widget child;

  /// Gap between the trigger and panel.
  final double sideOffset;

  @override
  Widget build(BuildContext context) => child;
}

class _MultiSelectContent extends StatelessWidget {
  const _MultiSelectContent({required this.animation, required this.link});
  final Animation<double> animation;
  final LayerLink link;

  @override
  Widget build(BuildContext context) {
    final state = _MultiSelectScope.of(context).state;
    final colors = BeuiColors.resolve(context);
    final reduce = state._reduceMotion;
    final box =
        state._triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 240.0;
    final height = box?.size.height ?? 44.0;
    return CompositedTransformFollower(
      link: state._link,
      showWhenUnlinked: false,
      offset: Offset(0, height + 6),
      child: TapRegion(
        groupId: state,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: width,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = animation.value;
                final y = reduce ? 0.0 : 6 * (1 - t);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, y),
                    child: child,
                  ),
                );
              },
              child: Material(
                elevation: 8,
                color: colors.background,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: BeuiMultiSelectContent(
                  child: BeuiMultiSelectList(
                    items: state._visibleItems,
                    activeIndex: state._activeIndex,
                    emptyLabel: state.widget.emptyLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable, multi-select option list.
class BeuiMultiSelectList extends StatelessWidget {
  /// Creates a list for [items].
  const BeuiMultiSelectList({
    required this.items,
    this.activeIndex = -1,
    this.emptyLabel = 'No options found.',
    super.key,
  });

  /// Options to show.
  final List<BeuiMultiSelectOption> items;

  /// Keyboard-highlighted row.
  final int activeIndex;

  /// Empty search result message.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final state = _MultiSelectScope.of(context).state;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Options',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 256),
        child: items.isEmpty
            ? Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text(emptyLabel)),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(6),
                itemCount: items.length,
                itemBuilder: (context, index) => BeuiMultiSelectItem(
                  option: items[index],
                  active: index == activeIndex,
                  selected: state._values.contains(items[index].value),
                  onSelect: state._toggleValue,
                ),
              ),
      ),
    );
  }
}

/// Selectable row used by [BeuiMultiSelectList].
class BeuiMultiSelectItem extends StatefulWidget {
  /// Creates an item row.
  const BeuiMultiSelectItem({
    required this.option,
    this.active = false,
    this.selected = false,
    this.onSelect,
    super.key,
  });

  /// Option represented by this row.
  final BeuiMultiSelectOption option;

  /// Whether keyboard navigation highlights this item.
  final bool active;

  /// Whether this item is selected.
  final bool selected;

  /// Optional selection callback. Defaults to the enclosing multi-select.
  final ValueChanged<String>? onSelect;

  @override
  State<BeuiMultiSelectItem> createState() => _BeuiMultiSelectItemState();
}

class _BeuiMultiSelectItemState extends State<BeuiMultiSelectItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = _MultiSelectScope.of(context).state;
    final colors = BeuiColors.resolve(context);
    final option = widget.option;
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !option.disabled,
      label: option.label,
      child: InkWell(
        onTap: option.disabled
            ? null
            : () => (widget.onSelect ?? state._toggleValue)(option.value),
        borderRadius: BorderRadius.circular(8),
        child: MouseRegion(
          onEnter: option.disabled
              ? null
              : (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: option.disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: state._reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: widget.active || selected || _hovered
                  ? colors.muted
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (option.leading != null) ...[
                  option.leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: option.disabled
                          ? colors.mutedForeground.withValues(alpha: .45)
                          : colors.foreground,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: selected
                      ? Icon(
                          LucideIcons.check,
                          size: 16,
                          color: colors.foreground,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectScope extends InheritedWidget {
  const _MultiSelectScope({required this.state, required super.child});
  final _BeuiMultiSelectState state;

  static _MultiSelectScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_MultiSelectScope>();
    assert(
      scope != null,
      'Multi-select parts must be used inside BeuiMultiSelect',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_MultiSelectScope oldWidget) =>
      oldWidget.state != state;
}
