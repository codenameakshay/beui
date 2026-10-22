import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
  }

  @override
  void didUpdateWidget(covariant BeuiMorphingSearchChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && widget.query != null) {
      _controller.value = TextEditingValue(text: widget.query!);
    }
    if (oldWidget.storageKey != widget.storageKey && widget.recents == null) {
      _recents = [..._initialRecents()];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setChips(List<String> value) {
    if (widget.chips == null) setState(() => _chips = value);
    widget.onChipsChange?.call(value);
  }

  void _setQuery(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    if (widget.query == null) setState(() => _query = value);
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
    if (widget.open == null) setState(() => _internalOpen = value);
    widget.onOpenChange?.call(value);
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
      _setOpen(true);
      final rows = _rows;
      if (rows.isNotEmpty) {
        setState(
          () => _active =
              (_active + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(
                0,
                rows.length - 1,
              ),
        );
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
        260.0,
        150.0 +
            chips.fold<double>(0, (width, chip) => width + chip.length * 7.0),
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
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(LucideIcons.search, size: 20, color: colors.mutedForeground),
          const SizedBox(width: 8),
          if (chips.isNotEmpty)
            ...chips.indexed.map((entry) {
              final (index, chip) = entry;
              Widget pill = Chip(
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
              if (!reduce) {
                pill = SingleMotionBuilder(
                  value: 1,
                  from: 0,
                  motion: motionFor(context, beuiSpringSwap, isMovement: true),
                  builder: (context, progress, child) => Opacity(
                    opacity: progress.clamp(0, 1),
                    child: Transform.scale(
                      scale: .6 + .4 * progress.clamp(0, 1),
                      child: child,
                    ),
                  ),
                  child: pill,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: pill,
              );
            }),
          Expanded(
            child: Semantics(
              textField: true,
              label: widget.label,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: !widget.disabled,
                onChanged: (value) {
                  if (widget.query == null) _query = value;
                  widget.onQueryChange?.call(value);
                  if (!_isOpen) _setOpen(true);
                  setState(() => _active = 0);
                },
                onTap: () => _setOpen(true),
                decoration: InputDecoration.collapsed(
                  hintText: widget.placeholder,
                ),
                style: TextStyle(color: colors.foreground),
              ),
            ),
          ),
          if (widget.actions != null) widget.actions!,
        ],
      ),
    );
    final expandedBar = reduce
        ? SizedBox(width: _isOpen ? maxBarWidth : restBarWidth, child: bar)
        : SingleMotionBuilder(
            value: _isOpen ? 1.0 : 0.0,
            from: 0,
            motion: motionFor(context, _chipsEnter, isMovement: true),
            builder: (context, progress, child) => SizedBox(
              width:
                  restBarWidth +
                  (maxBarWidth - restBarWidth) * progress.clamp(0, 1),
              child: child,
            ),
            child: bar,
          );
    return BeuiOverlay(
      open:
          _isOpen &&
          (rows.isNotEmpty || widget.loading || widget.emptyState != null),
      onDismiss: () => _setOpen(false),
      barrierColor: colors.background.withValues(alpha: .04),
      barrierBlur: beuiBlurSigma(20),
      barrierSaturation: 1.6,
      enterDuration: const Duration(milliseconds: 380),
      exitDuration: const Duration(milliseconds: 260),
      overlayBuilder: (context, animation, link) {
        var above = 0.0;
        final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          above = box.localToGlobal(Offset.zero).dy;
        }
        final below = MediaQuery.sizeOf(context).height - above - 56;
        final side = widget.side == BeuiMorphingSearchChipsSide.auto
            ? (above < 320 && below > above
                  ? BeuiMorphingSearchChipsSide.bottom
                  : BeuiMorphingSearchChipsSide.top)
            : widget.side;
        final surface = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: beuiBlurSigma(20),
              sigmaY: beuiBlurSigma(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: glass,
                border: Border.all(
                  color: colors.foreground.withValues(alpha: .08),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      _currentQuery.isEmpty ? 'Recent' : 'Suggestions',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                  if (rows.isEmpty && widget.emptyState != null)
                    widget.emptyState!,
                  for (final (index, row) in rows.indexed)
                    Semantics(
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
                          title: Text(row),
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
        );
        Widget animated = surface;
        if (!reduce) {
          animated = SingleMotionBuilder(
            value: _isOpen ? 1.0 : 0.0,
            from: 0,
            motion: motionFor(
              context,
              _isOpen ? _chipsEnter : _chipsExit,
              isMovement: true,
            ),
            builder: (context, progress, child) => Opacity(
              opacity: progress.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(
                  0,
                  (side == BeuiMorphingSearchChipsSide.top ? -1 : 1) *
                      (1 - progress) *
                      8,
                ),
                child: child,
              ),
            ),
            child: animated,
          );
        }
        return CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.topCenter,
          followerAnchor: side == BeuiMorphingSearchChipsSide.top
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          offset: Offset(0, side == BeuiMorphingSearchChipsSide.top ? -8 : 8),
          showWhenUnlinked: false,
          child: SizedBox(
            width: math.min(560, MediaQuery.sizeOf(context).width - 32),
            child: animated,
          ),
        );
      },
      child: Row(
        key: _barKey,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: expandedBar),
          if (widget.name != null)
            ...chips.map(
              (chip) => Semantics(
                label: '${widget.name}: $chip',
                child: const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}
