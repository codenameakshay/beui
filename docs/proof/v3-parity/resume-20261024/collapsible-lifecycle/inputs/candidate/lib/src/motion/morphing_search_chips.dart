import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Direction in which the suggestions surface opens.
enum BeuiMorphingSearchChipsSide { auto, bottom, top }

/// A docked search field with removable filters and recent/suggested terms.
class BeuiMorphingSearchChips extends StatefulWidget {
  /// Creates a chip search field.
  const BeuiMorphingSearchChips({
    this.chips,
    this.defaultChips = const [],
    this.onChipsChange,
    this.query,
    this.defaultQuery = '',
    this.onQueryChange,
    this.recents,
    this.defaultRecents = const [],
    this.onRecentsChange,
    this.storageKey,
    this.maxRecents = 5,
    this.suggestions = const [],
    this.filter,
    this.maxSuggestions = 6,
    this.loading = false,
    this.maxChips,
    this.normalize,
    this.emptyState,
    this.side = BeuiMorphingSearchChipsSide.top,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.disabled = false,
    this.name,
    this.placeholder = 'Search',
    this.label = 'Search',
    this.actions,
    super.key,
  });

  /// Active filters. When set, state is controlled by the caller.
  final List<String>? chips;

  /// Initial filters in uncontrolled mode.
  final List<String> defaultChips;

  /// Called when filters change.
  final ValueChanged<List<String>>? onChipsChange;

  /// Controlled query text.
  final String? query;

  /// Initial query text.
  final String defaultQuery;

  /// Called when query changes.
  final ValueChanged<String>? onQueryChange;

  /// Controlled recent terms.
  final List<String>? recents;

  /// Initial recents.
  final List<String> defaultRecents;

  /// Called when recents change.
  final ValueChanged<List<String>>? onRecentsChange;

  /// In-process persistence key for uncontrolled recents.
  final String? storageKey;

  /// Maximum persisted recent terms.
  final int maxRecents;

  /// Available suggestions.
  final List<String> suggestions;

  /// Custom match function, or false to show suggestions without filtering.
  final Object? filter;

  /// Maximum suggestion matches (the typed query row is additional).
  final int maxSuggestions;

  /// Whether suggestions are loading.
  final bool loading;

  /// Maximum number of selected chips.
  final int? maxChips;

  /// Normalizes a term or returns null to reject it.
  final String? Function(String term)? normalize;

  /// Optional content shown with no query and no recents.
  final Widget? emptyState;

  /// Panel direction. Auto flips down when less than 320px is available above.
  final BeuiMorphingSearchChipsSide side;

  /// Controlled open state.
  final bool? open;

  /// Initial open state.
  final bool defaultOpen;

  /// Called when open state changes.
  final ValueChanged<bool>? onOpenChange;

  /// Disables interaction.
  final bool disabled;

  /// Form field name for hidden chip values.
  final String? name;

  /// Search hint.
  final String placeholder;

  /// Accessible input label.
  final String label;

  /// Optional trailing controls.
  final Widget? actions;

  @override
  State<BeuiMorphingSearchChips> createState() =>
      _BeuiMorphingSearchChipsState();
}

// Deliberately process-local: no plugin dependency; widgets sharing a key share recents.
final Map<String, List<String>> _recentsByStorageKey = {};

const _chipsEnter = SpringMotion(
  SpringDescription(mass: .8, stiffness: 380, damping: 28),
);
const _chipsExit = SpringMotion(
  SpringDescription(mass: .6, stiffness: 520, damping: 40),
);

class _BeuiMorphingSearchChipsState extends State<BeuiMorphingSearchChips> {
  late List<String> _chips = [...widget.chips ?? widget.defaultChips];
  late String _query = widget.query ?? widget.defaultQuery;
  late List<String> _recents = [...widget.recents ?? _initialRecents()];
  late bool _internalOpen = widget.defaultOpen;
  final _controller = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);
  final _barKey = GlobalKey();
  final _rowsScroll = ScrollController();
  final _activeRowKey = GlobalKey();
  bool _revealActiveRow = false;
  Rect _barRect = const Rect.fromLTWH(0, 0, 0, 56);
  bool _measurementScheduled = false;
  int _active = 0;
  int? _markedChip;

  List<String> _initialRecents() => widget.storageKey == null
      ? widget.defaultRecents
      : (_recentsByStorageKey[widget.storageKey] ?? widget.defaultRecents);
  bool get _isOpen => (widget.open ?? _internalOpen) && !widget.disabled;
  List<String> get _currentChips => widget.chips ?? _chips;
  String get _currentQuery => widget.query ?? _query;
  List<String> get _currentRecents => widget.recents ?? _recents;

  @override
  void initState() {
    super.initState();
    _controller.text = _currentQuery;
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant BeuiMorphingSearchChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        widget.query != null &&
        widget.query != _controller.text) {
      final text = widget.query!;
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: text,
        selection: selection.isValid
            ? selection.copyWith(
                baseOffset: math.min(selection.baseOffset, text.length),
                extentOffset: math.min(selection.extentOffset, text.length),
              )
            : TextSelection.collapsed(offset: text.length),
      );
    }
    if (!listEquals(oldWidget.chips, widget.chips)) _markedChip = null;
    if (oldWidget.query != widget.query ||
        (oldWidget.open != true && widget.open == true)) {
      _resetActiveRow();
    }
    if (oldWidget.storageKey != widget.storageKey && widget.recents == null) {
      _recents = [..._initialRecents()];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _rowsScroll.dispose();
    super.dispose();
  }

  void _setChips(List<String> value) {
    setState(() {
      _markedChip = null;
      if (widget.chips == null) _chips = value;
    });
    widget.onChipsChange?.call(value);
  }

  void _setQuery(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      if (widget.query == null) _query = value;
      _resetActiveRow();
    });
    widget.onQueryChange?.call(value);
  }

  void _setRecents(List<String> value) {
    value = value.take(widget.maxRecents).toList();
    if (widget.recents == null) setState(() => _recents = value);
    if (widget.storageKey case final key?) {
      if (widget.recents == null) _recentsByStorageKey[key] = [...value];
    }
    widget.onRecentsChange?.call(value);
  }

  void _setOpen(bool value) {
    if (value == _isOpen) return;
    setState(() {
      if (widget.open == null) _internalOpen = value;
      if (value) _resetActiveRow();
    });
    widget.onOpenChange?.call(value);
  }

  void _onFocusChange() {
    if (_focus.hasFocus && !widget.disabled) _setOpen(true);
    setState(() {});
  }

  void _resetActiveRow() {
    _active = 0;
    _revealActiveRow = true;
  }

  void _scheduleActiveRowReveal() {
    if (!_revealActiveRow) return;
    _revealActiveRow = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen || !_rowsScroll.hasClients) return;
      final row = _activeRowKey.currentContext?.findRenderObject();
      if (row == null || !row.attached) return;
      _rowsScroll.position
        ..ensureVisible(
          row,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        )
        ..ensureVisible(
          row,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
    });
  }

  void _scheduleBarMeasurement() {
    if (_measurementScheduled || !_isOpen) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || !_isOpen) return;
      final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect != _barRect) setState(() => _barRect = rect);
      }
      // Observe layout/scroll frames without keeping an idle panel animating.
      _scheduleBarMeasurement();
    });
  }

  List<String> get _rows {
    final query = _currentQuery.trim();
    if (query.isEmpty) return _currentRecents;
    final needle = query.toLowerCase();
    final seen = <String>{needle, ..._currentChips.map((e) => e.toLowerCase())};
    final matches = <String>[];
    for (final term in [..._currentRecents, ...widget.suggestions]) {
      if (seen.contains(term.toLowerCase())) continue;
      final matchesQuery =
          widget.suggestions.contains(term) && widget.filter is bool
          ? widget.filter == false || term.toLowerCase().contains(needle)
          : widget.suggestions.contains(term) &&
                widget.filter is bool Function(String, String)
          ? (widget.filter as bool Function(String, String))(term, query)
          : term.toLowerCase().contains(needle);
      if (matchesQuery) {
        seen.add(term.toLowerCase());
        matches.add(term);
      }
    }
    return [query, ...matches.take(widget.maxSuggestions)];
  }

  Widget _chipPill(String chip, int index, BeuiColors colors) => Chip(
    label: Text(chip),
    deleteIcon: const Icon(LucideIcons.x, size: 14),
    onDeleted: widget.disabled ? null : () => _remove(chip),
    backgroundColor: colors.foreground.withValues(
      alpha: _markedChip == index ? .12 : .07,
    ),
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    labelStyle: TextStyle(color: colors.foreground, fontSize: 13),
  );

  Widget _searchField(BeuiColors colors) => TextField(
    controller: _controller,
    focusNode: _focus,
    enabled: !widget.disabled,
    onChanged: (value) {
      if (widget.query == null) _query = value;
      widget.onQueryChange?.call(value);
      if (!_isOpen) _setOpen(true);
      setState(_resetActiveRow);
    },
    onTap: () => _setOpen(true),
    decoration: InputDecoration.collapsed(hintText: widget.placeholder),
    style: TextStyle(color: colors.foreground),
  );

  TextSpan _suggestionTitle(String row, BeuiColors colors) {
    final query = _currentQuery.trim();
    final matchStart = query.isEmpty
        ? -1
        : row.toLowerCase().indexOf(query.toLowerCase());
    if (matchStart < 0) return TextSpan(text: row);
    final matchEnd = matchStart + query.length;
    return TextSpan(
      children: [
        TextSpan(text: row.substring(0, matchStart)),
        TextSpan(
          text: row.substring(matchStart, matchEnd),
          style: TextStyle(
            color: colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: row.substring(matchEnd)),
      ],
    );
  }

  void _add(String raw) {
    final term =
        (widget.normalize?.call(raw) ??
                (widget.normalize == null ? raw.trim() : null))
            ?.trim();
    if (term == null || term.isEmpty) return;
    final exists = _currentChips.any(
      (e) => e.trim().toLowerCase() == term.toLowerCase(),
    );
    if (!exists &&
        (widget.maxChips == null || _currentChips.length < widget.maxChips!)) {
      _setChips([..._currentChips, term]);
    }
    _setRecents([
      term,
      ..._currentRecents.where((e) => e.toLowerCase() != term.toLowerCase()),
    ]);
    _setQuery('');
  }

  void _remove(String term) =>
      _setChips(_currentChips.where((e) => e != term).toList());

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_currentQuery.isNotEmpty) {
        _setQuery('');
      } else {
        _setOpen(false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (!_isOpen) {
        _setOpen(true);
        return KeyEventResult.handled;
      }
      final rows = _rows;
      if (rows.isNotEmpty) {
        setState(() {
          _active = (_active + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
              .clamp(0, rows.length - 1);
          _revealActiveRow = true;
        });
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && _isOpen && _rows.isNotEmpty) {
      _add(_rows[_active.clamp(0, _rows.length - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace &&
        _currentQuery.isEmpty &&
        _currentChips.isNotEmpty) {
      if (_markedChip == null) {
        setState(() => _markedChip = _currentChips.length - 1);
      } else {
        final index = _markedChip!;
        _remove(_currentChips[index]);
        setState(() => _markedChip = null);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft &&
        _currentQuery.isEmpty &&
        _currentChips.isNotEmpty) {
      setState(
        () => _markedChip = ((_markedChip ?? _currentChips.length) - 1).clamp(
          0,
          _currentChips.length - 1,
        ),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        _currentQuery.isEmpty &&
        _markedChip != null) {
      setState(() {
        _markedChip = _markedChip! + 1 >= _currentChips.length
            ? null
            : _markedChip! + 1;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete &&
        _isOpen &&
        _currentQuery.isEmpty &&
        _currentRecents.isNotEmpty) {
      final index = _active.clamp(0, _currentRecents.length - 1);
      _setRecents([
        ..._currentRecents.take(index),
        ..._currentRecents.skip(index + 1),
      ]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _scheduleBarMeasurement();
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final chips = _currentChips;
    final rows = _rows;
    final maxBarWidth = math.max(
      0.0,
      math.min(560.0, MediaQuery.sizeOf(context).width - 32),
    );
    final restBarWidth = math.min(
      maxBarWidth,
      math.max(
        400.0,
        72.0 +
            widget.placeholder.length * 9.0 +
            chips.fold<double>(
              0,
              (width, chip) => width + chip.length * 9.0 + 52,
            ),
      ),
    );
    final glass = colors.background.withValues(alpha: .55);
    final bar = Container(
      constraints: const BoxConstraints(minHeight: 56, maxWidth: 576),
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: glass,
        border: Border.all(color: colors.foreground.withValues(alpha: .08)),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 20, color: colors.mutedForeground),
          const SizedBox(width: 8),
          if (chips.isNotEmpty)
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, chip) in chips.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: reduce
                            ? _chipPill(chip, index, colors)
                            : SingleMotionBuilder(
                                value: 1,
                                from: 0,
                                motion: motionFor(
                                  context,
                                  beuiSpringSwap,
                                  isMovement: true,
                                ),
                                builder: (context, progress, child) => Opacity(
                                  opacity: progress.clamp(0, 1),
                                  child: Transform.scale(
                                    scale: .6 + .4 * progress.clamp(0, 1),
                                    child: child,
                                  ),
                                ),
                                child: _chipPill(chip, index, colors),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Semantics(
              textField: true,
              label: widget.label,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 0),
                child: _searchField(colors),
              ),
            ),
          ),
          if (widget.actions != null) widget.actions!,
        ],
      ),
    );
    final expandedBar = reduce
        ? SizedBox(width: _isOpen ? maxBarWidth : restBarWidth, child: bar)
        : MotionBuilder<Size>(
            value: Size(_isOpen ? maxBarWidth : restBarWidth, 56),
            from: Size(restBarWidth, 56),
            converter: const SizeMotionConverter(),
            motion: motionFor(context, _chipsEnter, isMovement: true),
            builder: (context, size, child) => SizedBox(
              width: size.width,
              height: size.height,
              child: ClipRect(child: child),
            ),
            child: bar,
          );
    return BeuiOverlay(
      open:
          _isOpen &&
          (rows.isNotEmpty || widget.loading || widget.emptyState != null),
      onDismiss: _focus.hasFocus ? null : () => _setOpen(false),
      barrier: false,
      trapFocus: false,
      enterDuration: const Duration(milliseconds: 380),
      exitDuration: const Duration(milliseconds: 260),
      overlayBuilder: (context, animation, link) {
        _scheduleActiveRowReveal();
        final barOrigin = _barRect.topLeft;
        final barSize = _barRect.size;
        final above = barOrigin.dy;
        final below =
            MediaQuery.sizeOf(context).height - above - barSize.height;
        final side = widget.side == BeuiMorphingSearchChipsSide.auto
            ? (above < 320 && below > above
                  ? BeuiMorphingSearchChipsSide.bottom
                  : BeuiMorphingSearchChipsSide.top)
            : widget.side;
        final media = MediaQuery.sizeOf(context);
        final availableHeight = math.max(
          0.0,
          side == BeuiMorphingSearchChipsSide.top
              ? above - 8
              : media.height - above - barSize.height - 16,
        );
        final naturalPanelHeight =
            88.0 +
            rows.length * 56 +
            (widget.loading ? 50 : 0) +
            (rows.isEmpty && widget.emptyState != null ? 80 : 0);
        final panelHeight = math.min(naturalPanelHeight, availableHeight);
        final surface = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: beuiBlurSigma(20),
              sigmaY: beuiBlurSigma(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: panelHeight,
              ),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: glass,
                border: Border.all(
                  color: colors.foreground.withValues(alpha: .08),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                controller: _rowsScroll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentQuery.isEmpty ? 'Recent' : 'Suggestions',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ),
                          if (_currentQuery.isEmpty &&
                              _currentRecents.isNotEmpty)
                            TextButton(
                              onPressed: () => _setRecents(const []),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                    if (rows.isEmpty && widget.emptyState != null)
                      widget.emptyState!,
                    for (final (index, row) in rows.indexed)
                      Semantics(
                        key: index == _active ? _activeRowKey : null,
                        selected: index == _active,
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            dense: true,
                            selected: index == _active,
                            leading: Icon(
                              _currentQuery.isEmpty
                                  ? LucideIcons.clock
                                  : LucideIcons.search,
                              size: 16,
                            ),
                            title: Text.rich(_suggestionTitle(row, colors)),
                            onTap: () => _add(row),
                          ),
                        ),
                      ),
                    if (widget.loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Searching…'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final panelWidth = math.min(
          560.0,
          MediaQuery.sizeOf(context).width - 32,
        );
        final seed = const Size(112, 40);
        final target = Size(panelWidth, panelHeight);
        final animated = reduce
            ? SizedBox(
                width: target.width,
                height: target.height,
                child: surface,
              )
            : MotionBuilder<Size>(
                value: _isOpen ? target : seed,
                from: seed,
                converter: const SizeMotionConverter(),
                motion: motionFor(
                  context,
                  _isOpen ? _chipsEnter : _chipsExit,
                  isMovement: true,
                ),
                builder: (context, size, child) => SizedBox(
                  width: size.width,
                  height: size.height,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: side == BeuiMorphingSearchChipsSide.top
                          ? Alignment.bottomLeft
                          : Alignment.topLeft,
                      minWidth: target.width,
                      maxWidth: target.width,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: child,
                    ),
                  ),
                ),
                child: surface,
              );
        return SizedBox(
          width: media.width,
          height: media.height,
          child: Stack(
            children: [
              Positioned(
                left: barOrigin.dx,
                top: side == BeuiMorphingSearchChipsSide.top
                    ? null
                    : above + barSize.height + 8,
                bottom: side == BeuiMorphingSearchChipsSide.top
                    ? media.height - above + 8
                    : null,
                child: TapRegion(groupId: this, child: animated),
              ),
            ],
          ),
        );
      },
      child: TapRegion(
        groupId: this,
        onTapOutside: !widget.disabled && _isOpen
            ? (_) => _setOpen(false)
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: KeyedSubtree(key: _barKey, child: expandedBar),
            ),
            if (widget.name != null)
              ...chips.map(
                (chip) => Semantics(
                  label: '${widget.name}: $chip',
                  child: const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
