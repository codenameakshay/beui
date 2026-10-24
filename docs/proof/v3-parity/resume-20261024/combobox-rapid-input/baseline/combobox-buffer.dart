import 'dart:js_interop';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder;

@JS('__readComboTrace')
external set _traceReader(JSFunction value);

/// Search matcher used by [BeuiCombobox].
typedef BeuiComboboxFilter =
    bool Function(String value, String query, List<String> keywords);

/// Default source-compatible filter: a trimmed query must be a subsequence of
/// the option value, label, or keywords (case-insensitive).
bool beuiComboboxSubsequenceFilter(
  String value,
  String query,
  List<String> keywords,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final haystack = <String>[value, ...keywords].join(' ').toLowerCase();
  var index = 0;
  final needleRunes = needle.runes.toList();
  for (final character in haystack.runes) {
    if (character == needleRunes[index]) index++;
    if (index == needle.length) return true;
  }
  return false;
}

/// Searchable, grouped picker with a morphing anchored panel.
///
/// Compose [trigger] from [BeuiComboboxTrigger] and [BeuiComboboxInput], and
/// compose [content] from [BeuiComboboxContent], [BeuiComboboxList], and
/// [BeuiComboboxItem] (optionally grouped with [BeuiComboboxGroup]). Value,
/// open state, and query are independently controlled when their respective
/// arguments are supplied; otherwise each is initialized from its default and
/// managed internally.
class BeuiCombobox extends StatefulWidget {
  /// Creates a searchable combobox.
  const BeuiCombobox({
    required this.trigger,
    required this.content,
    this.value,
    this.defaultValue,
    this.onValueChange,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.query,
    this.defaultQuery = '',
    this.onQueryChange,
    this.filter = beuiComboboxSubsequenceFilter,
    this.disabled = false,
    this.width,
    super.key,
  });

  /// Trigger subtree, conventionally [BeuiComboboxTrigger].
  final Widget trigger;

  /// Portalled content subtree, conventionally [BeuiComboboxContent].
  final Widget content;

  /// Controlled selected value; null enables internal state.
  final String? value;

  /// Initial selected value for uncontrolled use.
  final String? defaultValue;

  /// Called after an item is selected.
  final ValueChanged<String>? onValueChange;

  /// Controlled visibility; null enables internal state.
  final bool? open;

  /// Initial visibility for uncontrolled use.
  final bool defaultOpen;

  /// Called when requested visibility changes.
  final ValueChanged<bool>? onOpenChange;

  /// Controlled search text; null enables internal state.
  final String? query;

  /// Initial search text for uncontrolled use.
  final String defaultQuery;

  /// Called when search text changes.
  final ValueChanged<String>? onQueryChange;

  /// Predicate called with value and [label, ...keywords].
  final BeuiComboboxFilter filter;

  /// Disables interaction.
  final bool disabled;

  /// Optional panel width. Defaults to the trigger width.
  final double? width;

  @override
  State<BeuiCombobox> createState() => _BeuiComboboxState();
}

class _BeuiComboboxState extends State<BeuiCombobox> {
  final FocusNode _inputFocus = FocusNode(debugLabel: 'beui_combobox_input');
  final TextEditingController _inputController = TextEditingController();
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _panelKey = GlobalKey();
  final Map<String, _ComboboxOption> _items = <String, _ComboboxOption>{};
  final Map<String, Set<Object>> _registrants = <String, Set<Object>>{};
  String? _internalValue;
  String _internalQuery = '';
  late String _openQuery;
  bool _internalOpen = false;
  String? _activeValue;
  double _triggerWidth = 0;
  double _panelHeight = 0;
  bool _registrationRefreshScheduled = false;

  String? get _value => widget.value ?? _internalValue;
  String get _query => widget.query ?? _internalQuery;
  String get _listQuery => _open ? _query : _openQuery;
  bool get _open => widget.open ?? _internalOpen;

  List<_ComboboxOption> get _visibleItems => _items.values
      .where(
        (item) => widget.filter(item.value, _listQuery, <String>[
          item.label,
          ...item.keywords,
        ]),
      )
      .toList();

  List<_ComboboxOption> get _enabledItems =>
      _visibleItems.where((item) => !item.disabled).toList();

  @override
  void initState() {
    super.initState();
    _internalValue = widget.defaultValue;
    _internalQuery = widget.defaultQuery;
    _internalOpen = widget.defaultOpen;
    _openQuery = _query;
    _traceReader = (() => jsonEncode(_traces)).toJS;
    WidgetsBinding.instance.addPersistentFrameCallback((_) => _traceFrame++);
    _inputController.addListener(() => _trace("controller"));
  }

  @override
  void dispose() {
    _inputFocus.dispose();
    _inputController.dispose();
    super.dispose();
  }

  final _traces = <Map<String, Object?>>[];
  int _traceCount = 0;
  int _traceFrame = 0;
  void _trace(String event, [Object? detail]) {
    if (_traceCount++ > 1200) return;
    _traces.add({'event':event,'detail':detail,'frame':_traceFrame,'phase':WidgetsBinding.instance.schedulerPhase.name,'open':_open,'query':_query,'value':_value,'text':_inputController.text,'selection':_inputController.selection.toString(),'items':_items.keys.toList(),'focus':_inputFocus.hasFocus,'primary':FocusManager.instance.primaryFocus?.debugLabel,'time':DateTime.now().microsecondsSinceEpoch});
  }
  void _setQuery(String next) {
    _trace('setQuery', next);
    if (widget.query == null) setState(() => _internalQuery = next);
    widget.onQueryChange?.call(next);
    final text = _open ? _query : (_items[_value]?.label ?? '');
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (_open) _syncActive();
  }

  void _setOpen(bool next, {bool restoreFocus = false}) {
    _trace('setOpen', {'next':next,'restore':restoreFocus});
    if (widget.disabled && next) return;
    if (widget.open == null) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
    if (next) {
      _measureTrigger();
      _syncActive();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _inputFocus.requestFocus();
      });
    } else {
      _setQuery('');
      _activeValue = null;
      if (restoreFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inputFocus.requestFocus();
        });
      }
    }
  }

  void _measureTrigger() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.width != _triggerWidth) {
      setState(() => _triggerWidth = box.size.width);
    }
  }

  void _measurePanel() {
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null &&
        box.hasSize &&
        (box.size.height - _panelHeight).abs() > 0.5) {
      _panelHeight = box.size.height;
      if (mounted) setState(() {});
    }
  }

  void _register(_ComboboxOption item, Object owner) {
    _trace('register',item.value);
    _registrants.putIfAbsent(item.value, () => <Object>{}).add(owner);
    final old = _items[item.value];
    if (old != null &&
        old.label == item.label &&
        old.disabled == item.disabled &&
        old.keywords.join('\u0000') == item.keywords.join('\u0000')) {
      return;
    }
    _items[item.value] = item;
    if (_activeValue == null ||
        !_enabledItems.any((i) => i.value == _activeValue)) {
      _syncActive();
    }
    if (!_registrationRefreshScheduled) {
      _registrationRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _registrationRefreshScheduled = false;
        if (!mounted) return;
        if (!_open) {
          final label = _items[_value]?.label ?? '';
          _inputController.value = TextEditingValue(
            text: label,
            selection: TextSelection.collapsed(offset: label.length),
          );
        }
        setState(() {});
      });
    }
  }

  void _unregister(String value, Object owner) {
    _trace('unregister',value);
    final owners = _registrants[value];
    owners?.remove(owner);
    if (owners != null && owners.isNotEmpty) return;
    _registrants.remove(value);
    _items.remove(value);
    if (_activeValue == value) _syncActive();
  }

  void _syncActive() {
    final enabled = _enabledItems;
    if (enabled.isEmpty) {
      _activeValue = null;
    } else if (!enabled.any((item) => item.value == _activeValue)) {
      _activeValue = enabled
          .firstWhere(
            (item) => item.value == _value,
            orElse: () => enabled.first,
          )
          .value;
    }
  }

  void _moveActive(int delta, {bool toEnd = false}) {
    final enabled = _enabledItems;
    if (enabled.isEmpty) return;
    final index = enabled.indexWhere((item) => item.value == _activeValue);
    final next = delta == 0
        ? 0
        : toEnd
        ? enabled.length - 1
        : (index + delta + enabled.length) % enabled.length;
    setState(() => _activeValue = enabled[next].value);
  }

  void _select(String value) {
    final option = _items[value];
    if (option == null || option.disabled) return;
    if (widget.value == null) setState(() => _internalValue = value);
    widget.onValueChange?.call(value);
    _setOpen(false, restoreFocus: true);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _trace('localKey',event.logicalKey.keyLabel);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (!_open) {
        _setOpen(true);
      } else {
        _moveActive(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      }
      return KeyEventResult.handled;
    } else if (_open && key == LogicalKeyboardKey.home) {
      _moveActive(0, toEnd: false);
      return KeyEventResult.handled;
    } else if (_open && key == LogicalKeyboardKey.end) {
      _moveActive(1, toEnd: true);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter) {
      if (_open && _activeValue != null) {
        _select(_activeValue!);
      } else {
        _setOpen(true);
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape && _open) {
      _setOpen(false, restoreFocus: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _trace('build');
    final colors = BeuiColors.resolve(context);
    if (_open) _openQuery = _query;
    final visible = _visibleItems;
    if (_open &&
        _activeValue != null &&
        !visible.any((item) => item.value == _activeValue)) {
      _syncActive();
    }
    final scope = _ComboboxScope(
      state: this,
      query: _query,
      listQuery: _listQuery,
      value: _value,
      open: _open,
      activeValue: _activeValue,
      reduce: MediaQuery.disableAnimationsOf(context),
      colors: colors,
    );

    return _ComboboxScopeProvider(
      scope: scope,
      child: BeuiOverlay(
        open: _open,
        barrier: true,
        barrierColor: const Color(0x00000000),
        barrierDismissible: true,
        trapFocus: false,
        onDismiss: () { _trace('overlayDismiss'); _setOpen(false); },
        enterDuration: Duration(milliseconds: scope.reduce ? 100 : 500),
        exitDuration: Duration(milliseconds: scope.reduce ? 80 : 300),
        overlayBuilder: (context, animation, link) =>
            _buildPanel(context, animation, link, scope),
        child: KeyedSubtree(
          key: _triggerKey,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Focus(
                onKeyEvent: _onKey,
                onFocusChange: (focused) {
                  if (focused && !_open) _setOpen(true);
                },
                child: widget.trigger,
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Offstage(
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width:
                          widget.width ??
                          (_triggerWidth > 0 ? _triggerWidth : 240),
                      child: widget.content,
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

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
    _ComboboxScope scope,
  ) {
    final colors = scope.colors;
    final width = widget.width ?? (_triggerWidth > 0 ? _triggerWidth : 240);
    final settings = widget.content is BeuiComboboxContent
        ? widget.content as BeuiComboboxContent
        : null;
    final viewport = MediaQuery.sizeOf(context);
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerTop = triggerBox?.localToGlobal(Offset.zero).dy ?? 0;
    final below = viewport.height - triggerTop - (triggerBox?.size.height ?? 0);
    final above = triggerTop;
    var side = settings?.side ?? BeuiComboboxSide.bottom;
    if (settings?.avoidCollisions ?? true) {
      if (side == BeuiComboboxSide.bottom &&
          below <
              (_panelHeight > 0 ? _panelHeight : 256) +
                  (settings?.sideOffset ?? 6) &&
          above > below) {
        side = BeuiComboboxSide.top;
      } else if (side == BeuiComboboxSide.top &&
          above <
              (_panelHeight > 0 ? _panelHeight : 256) +
                  (settings?.sideOffset ?? 6) &&
          below > above) {
        side = BeuiComboboxSide.bottom;
      }
    }
    final align = settings?.align ?? BeuiComboboxAlign.start;
    final targetAnchor = switch ((side, align)) {
      (BeuiComboboxSide.bottom, BeuiComboboxAlign.start) =>
        Alignment.bottomLeft,
      (BeuiComboboxSide.bottom, BeuiComboboxAlign.center) =>
        Alignment.bottomCenter,
      (BeuiComboboxSide.bottom, BeuiComboboxAlign.end) => Alignment.bottomRight,
      (BeuiComboboxSide.top, BeuiComboboxAlign.start) => Alignment.topLeft,
      (BeuiComboboxSide.top, BeuiComboboxAlign.center) => Alignment.topCenter,
      (BeuiComboboxSide.top, BeuiComboboxAlign.end) => Alignment.topRight,
    };
    final followerAnchor = switch ((side, align)) {
      (BeuiComboboxSide.bottom, BeuiComboboxAlign.start) => Alignment.topLeft,
      (BeuiComboboxSide.bottom, BeuiComboboxAlign.center) =>
        Alignment.topCenter,
      (BeuiComboboxSide.bottom, BeuiComboboxAlign.end) => Alignment.topRight,
      (BeuiComboboxSide.top, BeuiComboboxAlign.start) => Alignment.bottomLeft,
      (BeuiComboboxSide.top, BeuiComboboxAlign.center) =>
        Alignment.bottomCenter,
      (BeuiComboboxSide.top, BeuiComboboxAlign.end) => Alignment.bottomRight,
    };
    final sideGap = settings?.sideOffset ?? 6;
    final sideOffset = Offset(
      0,
      side == BeuiComboboxSide.bottom ? sideGap : -sideGap,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePanel());
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: targetAnchor,
      followerAnchor: followerAnchor,
      offset: sideOffset,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: SingleMotionBuilder(
            value: _open ? 1.0 : 0.0,
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            builder: (context, progress, child) => ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: progress.clamp(0.0, 1.0),
                child: FadeTransition(opacity: animation, child: child),
              ),
            ),
            child: KeyedSubtree(
              key: _panelKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colors.foreground.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: widget.content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _ComboboxOption {
  const _ComboboxOption({
    required this.value,
    required this.label,
    required this.keywords,
    required this.disabled,
  });

  final String value;
  final String label;
  final List<String> keywords;
  final bool disabled;
}

class _ComboboxScope {
  const _ComboboxScope({
    required this.state,
    required this.query,
    required this.listQuery,
    required this.value,
    required this.open,
    required this.activeValue,
    required this.reduce,
    required this.colors,
  });

  final _BeuiComboboxState state;
  final String query;
  final String listQuery;
  final String? value;
  final bool open;
  final String? activeValue;
  final bool reduce;
  final BeuiColors colors;
}

class _ComboboxScopeProvider extends InheritedWidget {
  const _ComboboxScopeProvider({required this.scope, required super.child});
  final _ComboboxScope scope;

  static _ComboboxScope of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_ComboboxScopeProvider>();
    assert(provider != null, 'Combobox parts must be inside BeuiCombobox');
    return provider!.scope;
  }

  @override
  bool updateShouldNotify(_ComboboxScopeProvider oldWidget) =>
      scope.query != oldWidget.scope.query ||
      scope.listQuery != oldWidget.scope.listQuery ||
      scope.value != oldWidget.scope.value ||
      scope.open != oldWidget.scope.open ||
      scope.activeValue != oldWidget.scope.activeValue ||
      scope.reduce != oldWidget.scope.reduce ||
      scope.colors != oldWidget.scope.colors;
}

/// Trigger layout for a combobox. Tapping it opens and focuses the input.
class BeuiComboboxTrigger extends StatefulWidget {
  /// Creates a trigger around [child].
  const BeuiComboboxTrigger({
    required this.child,
    this.placeholder,
    this.height = 40,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    super.key,
  });

  /// Content, usually a [BeuiComboboxInput].
  final Widget child;

  /// Optional trailing widget; defaults to a dropdown chevron.
  final Widget? placeholder;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<BeuiComboboxTrigger> createState() => _BeuiComboboxTriggerState();
}

class _BeuiComboboxTriggerState extends State<BeuiComboboxTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scope = _ComboboxScopeProvider.of(context);
    return MouseRegion(
      onEnter: scope.state.widget.disabled
          ? null
          : (_) => setState(() => _hovered = true),
      onExit: scope.state.widget.disabled
          ? null
          : (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: scope.state.widget.disabled
            ? null
            : () => scope.state._setOpen(true),
        child: Container(
          constraints: BoxConstraints(minHeight: widget.height, minWidth: 208),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: _hovered ? scope.colors.borderStrong : scope.colors.border,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: widget.child),
              widget.placeholder ??
                  Icon(
                    Icons.unfold_more,
                    size: 16,
                    color: scope.colors.mutedForeground,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search input; focus stays here while Arrow keys move the active option.
class BeuiComboboxInput extends StatelessWidget {
  /// Creates a searchable field.
  const BeuiComboboxInput({
    this.label = 'Search options',
    this.hintText = 'Search…',
    this.keywords,
    super.key,
  });

  /// Accessible label.
  final String label;

  /// Empty-field hint.
  final String hintText;

  /// Optional semantic text for screen readers.
  final String? keywords;

  @override
  Widget build(BuildContext context) {
    final scope = _ComboboxScopeProvider.of(context);
    final state = scope.state;
    final selectedLabel = state._items[scope.value]?.label;
    final text = scope.open ? scope.query : (selectedLabel ?? '');
    state._trace('inputBuild',{'capturedOpen':scope.open,'desired':text});
    if (state._inputController.text != text) {
      state._inputController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return Semantics(
      label: keywords == null ? label : '$label, $keywords',
      textField: true,
      expanded: scope.open,
      child: TextField(
        controller: state._inputController,
        focusNode: state._inputFocus,
        enabled: !state.widget.disabled,
        onTap: () => state._setOpen(true),
        onChanged: (query) {
          state._trace('onChanged', {'capturedOpen':scope.open,'incoming':query});
          state._setOpen(true);
          state._setQuery(query);
        },
        style: TextStyle(fontSize: 14, color: scope.colors.foreground),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: scope.colors.mutedForeground),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: scope.colors.mutedForeground,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 24),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

/// Portal content wrapper. [side], [align], [sideOffset], and collision
/// avoidance are source-compatible placement controls.
class BeuiComboboxContent extends StatelessWidget {
  /// Creates the panel content.
  const BeuiComboboxContent({
    required this.child,
    this.side = BeuiComboboxSide.bottom,
    this.align = BeuiComboboxAlign.start,
    this.sideOffset = 6,
    this.avoidCollisions = true,
    super.key,
  });

  /// Panel list and related content.
  final Widget child;

  /// Preferred panel side.
  final BeuiComboboxSide side;

  /// Alignment relative to the trigger.
  final BeuiComboboxAlign align;

  /// Gap from the trigger.
  final double sideOffset;

  /// Whether to flip near a viewport edge.
  final bool avoidCollisions;

  @override
  Widget build(BuildContext context) => child;
}

/// Preferred side of the combobox panel.
enum BeuiComboboxSide { bottom, top }

/// Horizontal alignment of the panel.
enum BeuiComboboxAlign { start, center, end }

/// Scrollable listbox for [BeuiComboboxItem]s.
class BeuiComboboxList extends StatelessWidget {
  /// Creates an options list.
  const BeuiComboboxList({
    required this.children,
    this.ariaLabel = 'Options',
    this.maxHeight = 256,
    super.key,
  });

  /// Option and group widgets.
  final List<Widget> children;

  /// Accessible list label.
  final String ariaLabel;

  /// Maximum scrolling height.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: ariaLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// One selectable option.
class BeuiComboboxItem extends StatefulWidget {
  /// Creates an option with [value] and visible [child].
  const BeuiComboboxItem({
    required this.value,
    required this.child,
    this.textValue,
    this.keywords = const <String>[],
    this.disabled = false,
    this.onSelect,
    super.key,
  });

  /// Unique selected value.
  final String value;

  /// Option row content.
  final Widget child;

  /// Search/display label (defaults to [value]).
  final String? textValue;

  /// Additional search strings.
  final List<String> keywords;

  /// Excludes this item from keyboard selection.
  final bool disabled;

  /// Optional selection callback.
  final ValueChanged<String>? onSelect;

  @override
  State<BeuiComboboxItem> createState() => _BeuiComboboxItemState();
}

class _BeuiComboboxItemState extends State<BeuiComboboxItem> {
  late _BeuiComboboxState _owner;
  bool _hovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _ComboboxScopeProvider.of(context);
    _owner = scope.state;
    scope.state._register(
      _ComboboxOption(
        value: widget.value,
        label: widget.textValue ?? widget.value,
        keywords: widget.keywords,
        disabled: widget.disabled,
      ),
      this,
    );
  }

  @override
  void didUpdateWidget(BeuiComboboxItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _ComboboxScopeProvider.of(
        context,
      ).state._unregister(oldWidget.value, this);
    }
    if (oldWidget.value != widget.value ||
        oldWidget.textValue != widget.textValue ||
        oldWidget.disabled != widget.disabled ||
        oldWidget.keywords != widget.keywords) {
      final scope = _ComboboxScopeProvider.of(context);
      scope.state._register(
        _ComboboxOption(
          value: widget.value,
          label: widget.textValue ?? widget.value,
          keywords: widget.keywords,
          disabled: widget.disabled,
        ),
        this,
      );
    }
  }

  @override
  void dispose() {
    // A disposed item may be part of a subtree being replaced; unregister is
    // deferred so it never mutates an ancestor during its build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _owner._unregister(widget.value, this),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _ComboboxScopeProvider.of(context);
    final visible = scope.state.widget.filter(
      widget.value,
      scope.listQuery,
      <String>[widget.textValue ?? widget.value, ...widget.keywords],
    );
    if (!visible) return const SizedBox.shrink();
    final active = scope.activeValue == widget.value;
    final selected = scope.value == widget.value;
    final highlighted = active || _hovered;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      enabled: !widget.disabled,
      label: widget.textValue ?? widget.value,
      child: MouseRegion(
        onEnter: widget.disabled
            ? null
            : (_) => setState(() => _hovered = true),
        onExit: widget.disabled
            ? null
            : (_) => setState(() => _hovered = false),
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.disabled
              ? null
              : () {
                  widget.onSelect?.call(widget.value);
                  scope.state._select(widget.value);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: highlighted ? scope.colors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: scope.colors.foreground,
                      fontSize: 14,
                    ),
                    child: widget.child,
                  ),
                ),
                if (selected)
                  Icon(Icons.check, size: 16, color: scope.colors.foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Group wrapper for related options.
class BeuiComboboxGroup extends StatelessWidget {
  /// Creates a labeled/unlabeled option group.
  const BeuiComboboxGroup({required this.children, this.label, super.key});

  /// Group rows.
  final List<Widget> children;

  /// Optional group heading.
  final String? label;
  @override
  Widget build(BuildContext context) {
    final scope = _ComboboxScopeProvider.of(context);
    final options = children.whereType<BeuiComboboxItem>().toList();
    if (options.isNotEmpty &&
        !options.any(
          (item) => scope.state.widget.filter(
            item.value,
            scope.listQuery,
            <String>[item.textValue ?? item.value, ...item.keywords],
          ),
        )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (label != null) BeuiComboboxLabel(label!),
          ...children,
        ],
      ),
    );
  }
}

/// Group heading.
class BeuiComboboxLabel extends StatelessWidget {
  /// Creates a label.
  const BeuiComboboxLabel(this.text, {super.key});

  /// Heading text.
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: colors.mutedForeground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Empty-results announcement.
class BeuiComboboxEmpty extends StatelessWidget {
  /// Creates the empty status message.
  const BeuiComboboxEmpty({
    this.child = const Text('No options found.'),
    super.key,
  });

  /// Message content.
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = _ComboboxScopeProvider.of(context);
    final visible = scope.state._visibleItems.isNotEmpty;
    if (visible) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: child),
      ),
    );
  }
}

/// Visual separator between groups.
class BeuiComboboxSeparator extends StatelessWidget {
  /// Creates a separator.
  const BeuiComboboxSeparator({super.key});
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    color: BeuiColors.resolve(context).border,
  );
}

/// Displays the selected label or [placeholder].
class BeuiComboboxValue extends StatelessWidget {
  /// Creates a selected-value label.
  const BeuiComboboxValue({this.placeholder = 'Select an option', super.key});

  /// Text shown when no selection exists.
  final String placeholder;
  @override
  Widget build(BuildContext context) {
    final scope = _ComboboxScopeProvider.of(context);
    final label = scope.state._items[scope.value]?.label ?? placeholder;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: scope.value == null
            ? scope.colors.mutedForeground
            : scope.colors.foreground,
      ),
    );
  }
}
