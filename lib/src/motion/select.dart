import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart'
    show
        CurvedMotion,
        SingleMotionBuilder,
        SingleMotionController,
        SpringMotion;

/// One selectable option in a [BeuiSelect] / [BeuiMorphSelect].
///
/// The Flutter analog of the source's `<SelectItem value="…">Label</SelectItem>`
/// — [value] is committed through `onChanged`; [label] supplies stable text for
/// semantics and typeahead, and is the fallback display when [labelWidget] is
/// absent.
@immutable
class BeuiSelectOption {
  /// Creates an option carrying [value] and shown as [label].
  const BeuiSelectOption({
    required this.value,
    required this.label,
    this.labelWidget,
    this.icon,
    this.enabled = true,
  });

  /// The value committed when this option is chosen.
  final String value;

  /// The stable text used by semantics, typeahead and fallback display.
  final String label;

  /// Optional display-only option content. [label] remains the stable textual
  /// label used by accessibility and keyboard typeahead.
  final Widget? labelWidget;

  /// Optional leading glyph, rendered at 16px before [label] in the list and
  /// standard trigger, and at 14px in the compact trigger's 16px slot.
  /// Framework-native, so any widget works — an [Icon], an avatar, a vendor
  /// mark.
  ///
  /// Options without an icon reserve no space, so a list where only some
  /// options carry one stays left-aligned on the label rather than indenting
  /// everything.
  final Widget? icon;

  /// Whether the option can be chosen. Disabled options are dimmed and skipped
  /// by keyboard navigation.
  final bool enabled;
}

// ---------------------------------------------------------------------------
// Default Select motion — source UNFOLD_SPRING and UNFOLD_EXIT.
// ---------------------------------------------------------------------------

/// Framer Motion 12.43.0 `motion-dom/dist/es/animation/generators/spring.mjs`
/// resolves `visualDuration` as `root = 2π/(visualDuration*1.2)`,
/// `stiffness = root² * mass`, `damping = 2*clamp(0.05,1,1-bounce)*sqrt(mass*stiffness)`.
/// For source `{visualDuration: .2, bounce: .12}`, mass=1 yields 685.389 / 46.076.
/// `visualDuration` is perceptual, not an exact duration: don't use the old
/// `2π/duration` approximation.
const _unfoldSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 685.389, damping: 46.076),
);

/// Source `UNFOLD_EXIT = {duration: .2, ease: EASE_OUT}`.
const _unfoldExit = CurvedMotion(Duration(milliseconds: 200), beuiEaseOut);

const _rowsEnter = CurvedMotion(Duration(milliseconds: 120), beuiEaseOut);
const _rowsExit = CurvedMotion(Duration(milliseconds: 80), beuiEaseOut);

/// Morph Select retains its independent chevron transition.
const _morphChevronSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 247, damping: 22),
);

/// Shared-layout morph — source `MORPH = { duration: 0.5, bounce: 0.22 }`.
/// ω = 2π/0.5 ≈ 12.57, ζ = 0.78 → stiffness ≈ 158, damping ≈ 20. Drives the
/// trigger↔panel size morph in [BeuiMorphSelect].
const _morphSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 158, damping: 20),
);

const double _gap = 8; // source GAP / panel pull-away
const double _lip = 8; // source LIP / initial near-edge reveal
const double _radius = 12; // rounded-xl

enum _Placement { bottom, top }

class _OpenSelectIntent extends Intent {
  const _OpenSelectIntent();
}

const int _staggerMs = 35; // source staggerChildren 0.035
const int _itemDurMs = 300;

// ===========================================================================
// BeuiSelect — the default (gooey accordion) dropdown.
// ===========================================================================

/// The trigger style of a [BeuiSelect].
enum BeuiSelectVariant {
  /// The bordered field trigger: 14px label, 12×8 padding, full width.
  standard,

  /// A borderless trigger sized to its label up to 208px: 32px tall (growing
  /// only for large text scales), 12px muted label, 8px horizontal padding, a
  /// muted fill on hover, and a 208px panel. The source's prompt-input model
  /// picker (`h-8 px-2 py-0 text-xs border-0`).
  compact,
}

/// A dropdown select whose panel unfolds out of the trigger — the Flutter port
/// of beUI's `select` (the gooey/accordion variant), built on [BeuiOverlay] and
/// anchored to the trigger with a [LayerLink] + [CompositedTransformFollower],
/// the same overlay pattern as [BeuiTooltip].
///
/// **Open choreography**: one source-derived unfold progress controls the
/// full-size panel's near-edge clip, its 8px pull-away gap and corners, and the
/// chevron. Rows reveal together from y=-4 in 120ms; they fade out in 80ms on
/// close, without blur or stagger. The trigger remains laid out at full size;
/// only paint/transform properties animate. The panel flips above the trigger
/// when there isn't room below.
///
/// **Controlled or uncontrolled**: pass [value] + [onChanged] to control it, or
/// omit [value] and seed [defaultValue] for internal state. **Keyboard**: Enter
/// / Space / ArrowDown open it; Up/Down move the highlight; Enter commits; Esc
/// closes. Reduced motion keeps static panel geometry with a short opacity
/// fade and no row transform.
class BeuiSelect extends StatefulWidget {
  /// Creates a select over [options].
  const BeuiSelect({
    required this.options,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.placeholder = 'Select',
    this.enabled = true,
    this.variant = BeuiSelectVariant.standard,
    super.key,
  });

  /// The options to choose from.
  final List<BeuiSelectOption> options;

  /// Controlled selected value. When null the select owns its state.
  final String? value;

  /// Uncontrolled initial value (used only when [value] is null).
  final String? defaultValue;

  /// Called with the chosen option's value.
  final ValueChanged<String>? onChanged;

  /// Controlled panel visibility. When null, [BeuiSelect] owns open state.
  final bool? open;

  /// Initial visibility for an uncontrolled select.
  final bool defaultOpen;

  /// Called whenever an interaction requests a visibility change.
  final ValueChanged<bool>? onOpenChange;

  /// Shown in the trigger until a value is selected.
  final String placeholder;

  /// Whether the trigger is interactive.
  final bool enabled;

  /// The trigger style. Defaults to [BeuiSelectVariant.standard].
  final BeuiSelectVariant variant;

  @override
  State<BeuiSelect> createState() => _BeuiSelectState();
}

/// The state shared by [BeuiSelect] and [BeuiMorphSelect]: the controlled /
/// uncontrolled value, the trigger + off-stage measurement plumbing, the
/// active-option index, and the keyboard contract (Enter/Space/ArrowDown to
/// open, Up/Down to move, Enter to commit). Both variants open and close
/// their panel with different motion, so [_setOpen] stays abstract.
mixin _SelectStateMixin<W extends StatefulWidget> on State<W> {
  List<BeuiSelectOption> get _options;
  String? get _controlledValue;
  String? get _defaultValue;
  ValueChanged<String>? get _onChanged;
  void _setOpen(bool next);

  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _measureKey = GlobalKey();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'beui_select_panel');

  String? _internalValue;
  Size _triggerSize = Size.zero;
  double _panelHeight = 0;
  int _active = -1;

  String? get _value => _controlledValue ?? _internalValue;

  /// Bounded width for the panel (and its off-stage measurement); falls back to
  /// a sensible default until the trigger has been measured.
  double get _panelWidth => _triggerSize.width > 0 ? _triggerSize.width : 240;

  @override
  void initState() {
    super.initState();
    _internalValue = _defaultValue;
  }

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  int _selectedIndex() => _options.indexWhere((o) => o.value == _value);
  int _firstEnabled() => _options.indexWhere((o) => o.enabled);

  /// The selected option's leading glyph, or null when nothing is selected.
  Widget? get _selectedIcon {
    final i = _selectedIndex();
    return i >= 0 ? _options[i].icon : null;
  }

  void _measure() {
    final t = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (t != null && t.hasSize && t.size != _triggerSize) {
      setState(() => _triggerSize = t.size);
    }
    final p = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (p != null && p.hasSize && p.size.height != _panelHeight) {
      setState(() => _panelHeight = p.size.height);
    }
  }

  void _select(int index) {
    if (index < 0 || index >= _options.length) return;
    final opt = _options[index];
    if (!opt.enabled) return;
    if (_controlledValue == null) setState(() => _internalValue = opt.value);
    _onChanged?.call(opt.value);
    _setOpen(false);
  }

  void _moveActive(int delta) {
    final n = _options.length;
    if (n == 0) return;
    var i = _active;
    for (var step = 0; step < n; step++) {
      i = (i + delta) % n;
      if (i < 0) i += n;
      if (_options[i].enabled) {
        setState(() => _active = i);
        return;
      }
    }
  }

  KeyEventResult _onTriggerKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowDown) {
      _setOpen(true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onPanelKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _moveActive(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _moveActive(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _select(_active);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _BeuiSelectState extends State<BeuiSelect>
    with TickerProviderStateMixin, _SelectStateMixin<BeuiSelect> {
  bool _open = false;
  _Placement _placement = _Placement.bottom;
  bool _triggerHovered = false; // source hover:border-(--color-border-strong)
  bool _triggerFocused =
      false; // source focus-visible:ring-2 ring-foreground/20
  late final SingleMotionController _unfold;
  late final SingleMotionController _rows;
  late final Listenable _motion;
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'beui_select_trigger');
  final Map<String, FocusNode> _rowFocusNodes = {};
  String? _activeValue;
  String? _spacePressedValue;
  String _typedPrefix = '';
  DateTime? _typedAt;
  Timer? _typeaheadReset;
  bool? _lastReduce;

  bool get _isOpen => widget.open ?? _open;

  @override
  List<BeuiSelectOption> get _options => widget.options;
  @override
  String? get _controlledValue => widget.value;
  @override
  String? get _defaultValue => widget.defaultValue;
  @override
  ValueChanged<String>? get _onChanged => widget.onChanged;

  @override
  double get _panelWidth => widget.variant == BeuiSelectVariant.compact
      ? 208 // source SelectContent `w-52`
      : super._panelWidth;

  @override
  void initState() {
    super.initState();
    _open = widget.defaultOpen;
    _syncActive(reset: true);
    _unfold = SingleMotionController(
      vsync: this,
      motion: _unfoldSpring,
      initialValue: _isOpen ? 1 : 0,
    );
    _rows = SingleMotionController(
      vsync: this,
      motion: _rowsEnter,
      initialValue: _isOpen ? 1 : 0,
    );
    _motion = Listenable.merge([_unfold, _rows]);
  }

  @override
  void dispose() {
    _typeaheadReset?.cancel();
    _triggerFocus.dispose();
    for (final node in _rowFocusNodes.values) {
      node.dispose();
    }
    _unfold.dispose();
    _rows.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BeuiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasOpen = oldWidget.open ?? _open;
    if (wasOpen != _isOpen) {
      _animateOpen(
        _isOpen,
        setStateNeeded: false,
        restoreFocus: !_isOpen && _panelFocus.hasFocus,
      );
    }
    if (oldWidget.options != widget.options) {
      _syncActive();
      final values = widget.options.map((option) => option.value).toSet();
      for (final value in _rowFocusNodes.keys.toList()) {
        if (!values.contains(value)) _rowFocusNodes.remove(value)?.dispose();
      }
      if (_isOpen) _focusActiveAfterFrame();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && _lastReduce != true) {
      _unfold.value = _isOpen ? 1 : 0;
      _rows.value = _isOpen ? 1 : 0;
    }
    _lastReduce = reduce;
  }

  @override
  void _measure() {
    super._measure();
    if (!_isOpen || _triggerSize == Size.zero || _panelHeight <= 0) return;
    final previous = _placement;
    _decidePlacement();
    if (_placement != previous) setState(() {});
  }

  void _decidePlacement() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _placement = _Placement.bottom;
      return;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final screenH = MediaQuery.sizeOf(context).height;
    final below = screenH - (top + box.size.height);
    final needed = _panelHeight + 16;
    _placement = (below < needed && top > below)
        ? _Placement.top
        : _Placement.bottom;
  }

  double _compactPanelOffsetX(BuildContext context) {
    if (widget.variant != BeuiSelectVariant.compact) return 0;
    final trigger = _triggerKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(
      context,
      rootOverlay: true,
    ).context.findRenderObject();
    if (trigger is! RenderBox ||
        overlay is! RenderBox ||
        !trigger.hasSize ||
        !overlay.hasSize) {
      return 0;
    }

    final triggerOrigin = trigger.localToGlobal(Offset.zero, ancestor: overlay);
    final transformedPanelRight = trigger
        .localToGlobal(Offset(_panelWidth, 0), ancestor: overlay)
        .dx;
    final transformedPanelWidth = (transformedPanelRight - triggerOrigin.dx)
        .abs();
    final left = triggerOrigin.dx
        .clamp(0.0, math.max(0.0, overlay.size.width - transformedPanelWidth))
        .toDouble();
    final shiftedOrigin = trigger.globalToLocal(
      triggerOrigin + Offset(left - triggerOrigin.dx, 0),
      ancestor: overlay,
    );
    return shiftedOrigin.dx;
  }

  @override
  void _setOpen(bool next, {bool restoreFocus = true}) {
    if (next == _isOpen) return;
    widget.onOpenChange?.call(next);
    if (widget.open != null) return;
    _open = next;
    _animateOpen(next, restoreFocus: restoreFocus);
  }

  void _animateOpen(
    bool next, {
    bool setStateNeeded = true,
    bool restoreFocus = true,
  }) {
    if (!next) _spacePressedValue = null;
    if (next) {
      _decidePlacement();
      _syncActive(reset: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen) _focusActiveAfterFrame();
      });
    } else if (restoreFocus) {
      _triggerFocus.requestFocus();
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _unfold.value = next ? 1 : 0;
      _rows.value = next ? 1 : 0;
    } else {
      _unfold.motion = next ? _unfoldSpring : _unfoldExit;
      _unfold.animateTo(next ? 1 : 0);
      _rows.motion = next ? _rowsEnter : _rowsExit;
      _rows.animateTo(next ? 1 : 0);
    }
    if (setStateNeeded) setState(() {});
  }

  void _syncActive({bool reset = false}) {
    final current = _options.indexWhere(
      (option) => option.value == _activeValue && option.enabled,
    );
    if (!reset && current >= 0) {
      _active = current;
      return;
    }
    final selected = reset
        ? _options.indexWhere(
            (option) => option.value == _value && option.enabled,
          )
        : -1;
    _active = selected >= 0 ? selected : _firstEnabled();
    _activeValue = _active >= 0 ? _options[_active].value : null;
  }

  void _moveActiveDefault(int delta) {
    _syncActive();
    var i = _active;
    while (i + delta >= 0 && i + delta < _options.length) {
      i += delta;
      if (_options[i].enabled) {
        setState(() {
          _active = i;
          _activeValue = _options[i].value;
        });
        _focusActiveAfterFrame();
        return;
      }
    }
  }

  void _moveToEnabled({required bool last}) {
    final indices = [
      for (var i = 0; i < _options.length; i++)
        if (_options[i].enabled) i,
    ];
    if (indices.isEmpty) return;
    final i = last ? indices.last : indices.first;
    setState(() {
      _active = i;
      _activeValue = _options[i].value;
    });
    _focusActiveAfterFrame();
  }

  void _typeahead(String character) {
    if (character.isEmpty || character.length != 1) return;
    final now = DateTime.now();
    _typedPrefix =
        _typedAt != null && now.difference(_typedAt!).inMilliseconds < 500
        ? '$_typedPrefix${character.toLowerCase()}'
        : character.toLowerCase();
    _typedAt = now;
    _typeaheadReset?.cancel();
    _typeaheadReset = Timer(const Duration(milliseconds: 500), () {
      _typedPrefix = '';
      _typedAt = null;
    });
    _syncActive();
    final query = _typedPrefix;
    final start = _typedPrefix.length == 1 ? _active + 1 : _active;
    for (var step = 0; step < _options.length; step++) {
      final i = (start + step) % _options.length;
      final option = _options[i];
      if (option.enabled && option.label.toLowerCase().startsWith(query)) {
        setState(() {
          _active = i;
          _activeValue = option.value;
        });
        _focusActiveAfterFrame();
        return;
      }
    }
  }

  KeyEventResult _onPanelKeyDefault(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      final activeFocused =
          _activeValue != null &&
          (_rowFocusNodes[_activeValue]?.hasPrimaryFocus ?? false);
      if (event is KeyDownEvent) {
        _spacePressedValue = activeFocused ? _activeValue : null;
      } else if (event is KeyUpEvent) {
        final pressed = _spacePressedValue;
        _spacePressedValue = null;
        if (pressed != null && pressed == _activeValue && activeFocused) {
          _selectDefault(_active);
        }
      }
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      _setOpen(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      final backwards = HardwareKeyboard.instance.isShiftPressed;
      _setOpen(false, restoreFocus: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerFocus.requestFocus();
          FocusManager.instance.applyFocusChangesIfNeeded();
          if (backwards) {
            _triggerFocus.previousFocus();
          } else {
            _triggerFocus.nextFocus();
          }
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveActiveDefault(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveActiveDefault(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _moveToEnabled(last: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _moveToEnabled(last: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _selectDefault(_active);
      return KeyEventResult.handled;
    }
    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        event.character != null &&
        event.character != ' ') {
      _typeahead(event.character!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectDefault(int index) {
    if (index < 0 || index >= _options.length || !_options[index].enabled) {
      return;
    }
    final option = _options[index];
    if (_controlledValue == null) setState(() => _internalValue = option.value);
    widget.onChanged?.call(option.value);
    _setOpen(false);
  }

  FocusNode _focusNodeForOption(int index) => _rowFocusNodes.putIfAbsent(
    _options[index].value,
    () => FocusNode(debugLabel: 'beui_select_option_${_options[index].value}'),
  );

  void _focusActiveAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOpen) _focusActive();
    });
  }

  void _focusActive() {
    if (_active >= 0 && _options[_active].enabled) {
      _focusNodeForOption(_active).requestFocus();
    } else {
      _panelFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final colors = BeuiColors.resolve(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final progress = _unfold.value.clamp(0.0, 1.0);
        return BeuiOverlay(
          open: _isOpen,
          barrier: true,
          barrierColor: const Color(0x00000000),
          barrierDismissible: true,
          trapFocus: false,
          onDismiss: () => _setOpen(false, restoreFocus: false),
          enterDuration: Duration(milliseconds: reduced ? 120 : 200),
          exitDuration: Duration(milliseconds: reduced ? 120 : 200),
          overlayBuilder: (context, animation, link) =>
              _buildPanel(context, animation, link, progress),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Keep content laid out for measurement; it is not animated.
              Positioned(
                left: 0,
                top: 0,
                child: Offstage(
                  child: SizedBox(
                    width: _panelWidth,
                    child: KeyedSubtree(
                      key: _measureKey,
                      child: _OptionColumn(
                        options: widget.options,
                        value: _value,
                        active: -1,
                        colors: colors,
                        clock: null,
                        reduce: true,
                        togetherReveal: true,
                        onHover: (_) {},
                        onTap: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
              KeyedSubtree(
                key: _triggerKey,
                child: _buildTrigger(colors, progress),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrigger(BeuiColors colors, double progress) {
    final selected = _selectedIndex() >= 0;
    final selectedOption = selected ? widget.options[_selectedIndex()] : null;
    final label = selectedOption?.label ?? widget.placeholder;
    final icon = _selectedIcon;
    final compact = widget.variant == BeuiSelectVariant.compact;

    return Semantics(
      label: label,
      button: true,
      enabled: widget.enabled,
      expanded: _isOpen,
      onTap: widget.enabled
          ? () {
              _triggerFocus.requestFocus();
              _setOpen(!_isOpen);
            }
          : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          focusNode: _triggerFocus,
          enabled: widget.enabled,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowUp): _OpenSelectIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): _OpenSelectIntent(),
            SingleActivator(LogicalKeyboardKey.enter): _OpenSelectIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter):
                _OpenSelectIntent(),
            SingleActivator(LogicalKeyboardKey.space): _OpenSelectIntent(),
          },
          actions: {
            _OpenSelectIntent: CallbackAction<_OpenSelectIntent>(
              onInvoke: (_) {
                _setOpen(true);
                return null;
              },
            ),
          },
          onShowFocusHighlight: (f) => setState(() => _triggerFocused = f),
          child: MouseRegion(
            onEnter: widget.enabled
                ? (_) => setState(() => _triggerHovered = true)
                : null,
            onExit: compact || widget.enabled
                ? (_) => setState(() => _triggerHovered = false)
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled
                  ? () {
                      _triggerFocus.requestFocus();
                      _setOpen(!_isOpen);
                    }
                  : null,
              child: Builder(
                builder: (context) {
                  final labelText = Text(
                    label,
                    maxLines: compact ? 1 : null,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            color: colors.mutedForeground,
                          )
                        : TextStyle(
                            fontSize: 14,
                            color: selected
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                  );
                  return Opacity(
                    opacity: widget.enabled ? 1 : 0.5,
                    child: Container(
                      constraints: compact
                          ? const BoxConstraints(minHeight: 32, maxWidth: 208)
                          : null,
                      decoration: BoxDecoration(
                        color: compact
                            ? (widget.enabled && _triggerHovered
                                  ? colors.muted
                                  : const Color(0x00000000))
                            : colors.background,
                        border: compact
                            ? null
                            : Border.all(
                                color: _triggerHovered
                                    ? colors.borderStrong
                                    : colors.border,
                              ),
                        borderRadius: _triggerCorners(_triggerNear(progress)),
                        boxShadow: _triggerFocused
                            ? [
                                BoxShadow(
                                  color: colors.foreground.withValues(
                                    alpha: 0.2,
                                  ),
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      padding: compact
                          ? const EdgeInsets.symmetric(horizontal: 8)
                          : const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                      child: Row(
                        mainAxisSize: compact
                            ? MainAxisSize.min
                            : MainAxisSize.max,
                        children: [
                          if (icon != null) ...[
                            _OptionIcon(
                              icon: icon,
                              color: colors.mutedForeground,
                              glyphSize: compact ? 14 : 16,
                            ),
                            SizedBox(width: compact ? 6 : 8),
                          ],
                          if (selectedOption?.labelWidget
                              case final labelWidget?)
                            Flexible(child: labelWidget)
                          else if (compact)
                            Flexible(child: labelText)
                          else
                            Expanded(child: labelText),
                          const SizedBox(width: 8),
                          _Chevron(
                            progress: progress,
                            color: colors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The trigger's corner radii — the edge facing the panel uses [near], the
  /// other three stay rounded.
  BorderRadius _triggerCorners(double near) {
    final r = Radius.circular(_radius);
    final n = Radius.circular(near);
    return _placement == _Placement.top
        ? BorderRadius.only(
            topLeft: n,
            topRight: n,
            bottomLeft: r,
            bottomRight: r,
          )
        : BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: n,
            bottomRight: n,
          );
  }

  double _triggerNear(double progress) {
    final p = progress.clamp(0.0, 1.0);
    if (p < 0.2) return _radius * (1 - p / 0.2);
    if (p < 0.4) return 0;
    return _radius * ((p - 0.4) / 0.6);
  }

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
    double progress,
  ) {
    final colors = BeuiColors.resolve(context);
    final isTop = _placement == _Placement.top;
    final width = _panelWidth;
    final offsetX = _compactPanelOffsetX(context);

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      offset: Offset(offsetX, 0),
      targetAnchor: isTop ? Alignment.topLeft : Alignment.bottomLeft,
      followerAnchor: isTop ? Alignment.bottomLeft : Alignment.topLeft,
      child: Focus(
        focusNode: _panelFocus,
        skipTraversal: true,
        descendantsAreFocusable: _isOpen,
        descendantsAreTraversable: _isOpen,
        onKeyEvent: _onPanelKeyDefault,
        child: SizedBox(
          width: width,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = animation.value.clamp(0.0, 1.0);
              final exiting =
                  animation.status == AnimationStatus.reverse ||
                  animation.status == AnimationStatus.dismissed;
              final reduced = MediaQuery.disableAnimationsOf(context);
              final geometryProgress = reduced && exiting ? 1.0 : progress;
              final detach = ((geometryProgress - 0.4) / 0.6).clamp(0.0, 1.0);
              final opacity = reduced
                  ? exiting
                        ? 1 - beuiEaseOut.transform(1 - t)
                        : beuiEaseOut.transform(t)
                  : (progress / 0.12).clamp(0.0, 1.0);
              return _panelBody(
                colors: colors,
                reduce: reduced,
                isTop: isTop,
                width: width,
                progress: geometryProgress,
                detach: detach,
                opacity: opacity,
                rowPhase: reduced ? null : _rows.value,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _panelBody({
    required BeuiColors colors,
    required bool reduce,
    required bool isTop,
    required double width,
    required double progress,
    required double detach,
    required double opacity,
    required double? rowPhase,
  }) {
    final gap = _gap * detach;

    final content = _OptionColumn(
      options: widget.options,
      value: _value,
      active: _active,
      colors: colors,
      clock: rowPhase,
      reduce: reduce,
      togetherReveal: true,
      rovingFocus: true,
      focusNodeForOption: _focusNodeForOption,
      onHover: (i) {
        if (widget.options[i].enabled && _active != i) {
          setState(() {
            _active = i;
            _activeValue = widget.options[i].value;
          });
          _focusActiveAfterFrame();
        }
      },
      onTap: _selectDefault,
    );

    final panel = ClipRect(
      clipper: _UnfoldClipper(progress: progress, isTop: isTop),
      clipBehavior: progress.clamp(0.0, 1.0) == 1 ? Clip.none : Clip.hardEdge,
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: _panelCorners(_radius * detach, isTop),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: width, child: content),
      ),
    );

    return Transform.translate(
      offset: Offset(0, isTop ? -gap : gap),
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: panel),
    );
  }

  BorderRadius _panelCorners(double near, bool isTop) {
    final r = Radius.circular(_radius);
    final n = Radius.circular(near);
    // Near edge (facing the trigger) rounds from 0→12; the far edge stays 12.
    return isTop
        ? BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: n,
            bottomRight: n,
          )
        : BorderRadius.only(
            topLeft: n,
            topRight: n,
            bottomLeft: r,
            bottomRight: r,
          );
  }
}

// ===========================================================================
// BeuiMorphSelect — the shared-layout morph variant.
// ===========================================================================

/// A select whose trigger **morphs into the panel** — instead of a detached
/// dropdown, the trigger box itself grows down into the menu and shrinks back,
/// one continuous surface. The Flutter port of beUI's `select-morph`.
///
/// The source shares a `layoutId` between the closed trigger and the open panel;
/// both are `inset-x-0` (same width), so the morph is a pure **height** grow on
/// [_morphSpring] (`duration 0.5, bounce 0.22`). Ported onto [BeuiOverlay]
/// (anchored to the trigger's top-left at the trigger's width) so the panel is
/// hit-testable where it overflows the surrounding layout; the closed trigger
/// stays in the base tree as the anchor and is covered by the opaque panel while
/// open. The panel header mirrors the trigger row (seamless morph) and collapses
/// the panel when tapped; its chevron rotates 180°. Below a hairline the options
/// **stagger in** (source `staggerChildren 0.035, delayChildren 0.08`), each
/// rising 6px through a blur(3px)→0 fade. Enter springs from 0; exit eases the
/// height back down.
///
/// **Controlled or uncontrolled** ([value] + [onChanged], or [defaultValue]).
/// **Keyboard**: Enter / Space / ArrowDown open; Up/Down move the highlight;
/// Enter commits; Esc closes. Reduced motion keeps the height morph brief and
/// fades options without movement.
class BeuiMorphSelect extends StatefulWidget {
  /// Creates a morph select over [options].
  const BeuiMorphSelect({
    required this.options,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.placeholder = 'Select',
    this.enabled = true,
    super.key,
  });

  /// The options to choose from.
  final List<BeuiSelectOption> options;

  /// Controlled selected value. When null the select owns its state.
  final String? value;

  /// Uncontrolled initial value (used only when [value] is null).
  final String? defaultValue;

  /// Called with the chosen option's value.
  final ValueChanged<String>? onChanged;

  /// Shown in the trigger/header until a value is selected.
  final String placeholder;

  /// Whether the trigger is interactive.
  final bool enabled;

  @override
  State<BeuiMorphSelect> createState() => _BeuiMorphSelectState();
}

class _BeuiMorphSelectState extends State<BeuiMorphSelect>
    with _SelectStateMixin<BeuiMorphSelect> {
  bool _open = false;

  @override
  List<BeuiSelectOption> get _options => widget.options;
  @override
  String? get _controlledValue => widget.value;
  @override
  String? get _defaultValue => widget.defaultValue;
  @override
  ValueChanged<String>? get _onChanged => widget.onChanged;

  double get _triggerHeight =>
      _triggerSize.height > 0 ? _triggerSize.height : 41;

  @override
  void _setOpen(bool next) {
    if (next == _open) return;
    if (next) {
      final sel = _selectedIndex();
      _active = sel >= 0 ? sel : _firstEnabled();
    }
    setState(() => _open = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _panelFocus.requestFocus(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final selected = _selectedIndex() >= 0;
    final label = selected
        ? widget.options[_selectedIndex()].label
        : widget.placeholder;

    return BeuiOverlay(
      open: _open,
      barrier: true,
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      trapFocus: false,
      onDismiss: () => _setOpen(false),
      enterDuration: Duration(milliseconds: reduce ? 160 : 560),
      exitDuration: Duration(milliseconds: reduce ? 120 : 320),
      overlayBuilder: (context, animation, link) =>
          _buildPanel(context, animation, link, colors, reduce),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Off-stage measurement of the full open panel (header + list).
          Positioned(
            left: 0,
            top: 0,
            child: Offstage(
              child: SizedBox(
                width: _panelWidth,
                child: KeyedSubtree(
                  key: _measureKey,
                  child: _morphContent(
                    colors: colors,
                    reduce: true,
                    label: label,
                    selected: selected,
                    measuring: true,
                    clock: 1,
                  ),
                ),
              ),
            ),
          ),
          // The closed trigger stays in the base tree as the anchor; the open
          // panel (opaque) covers it.
          KeyedSubtree(
            key: _triggerKey,
            child: _MorphRow(
              label: label,
              icon: _selectedIcon,
              selected: selected,
              colors: colors,
              open: false,
              bordered: true,
              onTap: widget.enabled ? () => _setOpen(true) : null,
              onKeyEvent: widget.enabled ? _onTriggerKey : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
    BeuiColors colors,
    bool reduce,
  ) {
    final selected = _selectedIndex() >= 0;
    final label = selected
        ? widget.options[_selectedIndex()].label
        : widget.placeholder;
    final width = _panelWidth;
    final triggerH = _triggerHeight;
    final panelH = _panelHeight > 0 ? _panelHeight : triggerH;

    Widget surface(double p, double clock) {
      final h = triggerH + (panelH - triggerH) * p;
      return Container(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: p > 0.02
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: h,
          child: OverflowBox(
            minHeight: 0,
            maxHeight: panelH,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: panelH,
              child: _morphContent(
                colors: colors,
                reduce: reduce,
                label: label,
                selected: selected,
                measuring: false,
                clock: reduce ? 1 : clock,
                morphProgress: p,
              ),
            ),
          ),
        ),
      );
    }

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topLeft,
      followerAnchor: Alignment.topLeft,
      child: Focus(
        focusNode: _panelFocus,
        onKeyEvent: _onPanelKey,
        child: SizedBox(
          width: width,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = animation.value.clamp(0.0, 1.0);
              final exiting =
                  animation.status == AnimationStatus.reverse ||
                  animation.status == AnimationStatus.dismissed;
              if (reduce) return surface(t, t);
              if (exiting) return surface(beuiEaseOut.transform(t), t);
              return SingleMotionBuilder(
                value: 1.0,
                from: 0.0,
                motion: _morphSpring,
                builder: (context, p, _) => surface(p.clamp(0.0, 1.0), t),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The morph surface's content: header (mirrors the trigger, toggles closed),
  /// a hairline, and the staggering option list.
  Widget _morphContent({
    required BeuiColors colors,
    required bool reduce,
    required String label,
    required bool selected,
    required bool measuring,
    required double clock,
    double morphProgress = 1,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MorphRow(
          label: label,
          icon: _selectedIcon,
          selected: selected,
          colors: colors,
          open: measuring ? true : _open,
          openProgress: morphProgress,
          bordered: false,
          onTap: measuring ? null : () => _setOpen(false),
        ),
        Container(height: 1, color: colors.border),
        _OptionColumn(
          options: widget.options,
          value: _value,
          active: _active,
          colors: colors,
          clock: (reduce || measuring) ? null : clock,
          reduce: reduce || measuring,
          delayChildrenMs: 80,
          onHover: (i) {
            if (widget.options[i].enabled && _active != i) {
              setState(() => _active = i);
            }
          },
          onTap: _select,
        ),
      ],
    );
  }
}

/// The trigger / header row shared by [BeuiMorphSelect]'s closed trigger and
/// open panel header, so the morph reads as one continuous surface.
///
/// Stateful only so the **bordered** closed-trigger variant can mirror the
/// source's trigger states — `hover:border-(--color-border-strong)` and
/// `focus-visible:ring-2 ring-foreground/20`. The non-bordered header carries no
/// border, hover or ring.
class _MorphRow extends StatefulWidget {
  const _MorphRow({
    required this.label,
    required this.selected,
    required this.colors,
    required this.open,
    required this.bordered,
    this.icon,
    this.onTap,
    this.onKeyEvent,
    this.openProgress = 1,
  });

  final String label;
  final Widget? icon;
  final bool selected;
  final BeuiColors colors;
  final bool open;
  final double openProgress;
  final bool bordered;
  final VoidCallback? onTap;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;

  @override
  State<_MorphRow> createState() => _MorphRowState();
}

class _MorphRowState extends State<_MorphRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    // When rendered as the open header, drive the chevron by the morph progress
    // so it rotates in lock-step with the grow; otherwise spring on toggle.
    final chevron = widget.open
        ? Transform.rotate(
            angle: (reduce ? 1 : widget.openProgress) * math.pi,
            child: Icon(
              LucideIcons.chevron_down,
              size: 16,
              color: colors.mutedForeground,
            ),
          )
        : _MorphChevron(open: false, color: colors.mutedForeground);

    Widget row = Container(
      decoration: widget.bordered
          ? BoxDecoration(
              color: colors.background,
              // hover:border-(--color-border-strong)
              border: Border.all(
                color: _hovered ? colors.borderStrong : colors.border,
              ),
              borderRadius: BorderRadius.circular(_radius),
              // focus-visible:ring-2 ring-foreground/20
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: colors.foreground.withValues(alpha: 0.2),
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            )
          : null,
      // Source ROW: px-3.5 py-2.5.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            _OptionIcon(icon: widget.icon!, color: colors.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: widget.selected
                    ? colors.foreground
                    : colors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          chevron,
        ],
      ),
    );

    // Hover tracking only matters for the bordered trigger.
    if (widget.bordered) {
      row = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: row,
      );
    }
    if (widget.onTap != null) {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: row,
      );
    }
    if (widget.onKeyEvent != null) {
      row = Focus(
        onKeyEvent: widget.onKeyEvent,
        onFocusChange: (f) => setState(() => _focused = f),
        child: row,
      );
    }
    return row;
  }
}

/// A [BeuiSelectOption.icon] sized and tinted to match the row it sits in.
///
/// `IconTheme` rather than a hard cast, so the slot accepts any widget while
/// an [Icon] still picks up the row's colour and configurable glyph size
/// (16px by default).
class _OptionIcon extends StatelessWidget {
  const _OptionIcon({
    required this.icon,
    required this.color,
    this.glyphSize = 16,
  });

  final Widget icon;
  final Color color;
  final double glyphSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    height: 16,
    child: Center(
      child: IconTheme.merge(
        data: IconThemeData(size: glyphSize, color: color),
        child: icon,
      ),
    ),
  );
}

/// The chevron glyph that rotates from the shared default-Select progress.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: progress * math.pi,
      child: Icon(LucideIcons.chevron_down, size: 16, color: color),
    );
  }
}

class _MorphChevron extends StatelessWidget {
  const _MorphChevron({required this.open, required this.color});

  final bool open;
  final Color color;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: open ? 1 : 0,
    motion: motionFor(
      context,
      _morphChevronSpring,
      isMovement: true,
      reducedFallback: beuiSpringSnap,
    ),
    builder: (context, progress, child) =>
        Transform.rotate(angle: progress * math.pi, child: child),
    child: Icon(LucideIcons.chevron_down, size: 16, color: color),
  );
}

class _UnfoldClipper extends CustomClipper<Rect> {
  const _UnfoldClipper({required this.progress, required this.isTop});

  final double progress;
  final bool isTop;

  @override
  Rect getClip(Size size) {
    final p = progress.clamp(0.0, 1.0);
    final revealHeight =
        _lip + (size.height - _lip).clamp(0.0, size.height) * p;
    return isTop
        ? Rect.fromLTWH(0, size.height - revealHeight, size.width, revealHeight)
        : Rect.fromLTWH(0, 0, size.width, revealHeight);
  }

  @override
  bool shouldReclip(covariant _UnfoldClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.isTop != isTop;
}

/// Option rows with default Select's together reveal or unchanged Morph motion.
class _OptionColumn extends StatelessWidget {
  const _OptionColumn({
    required this.options,
    required this.value,
    required this.active,
    required this.colors,
    required this.clock,
    required this.reduce,
    this.togetherReveal = false,
    this.rovingFocus = false,
    this.focusNodeForOption,
    required this.onHover,
    required this.onTap,
    this.delayChildrenMs = 50,
  });

  final List<BeuiSelectOption> options;
  final String? value;
  final int active;
  final BeuiColors colors;

  /// Normalized 0..1 enter clock. Null → no stagger (static).
  final double? clock;

  final bool reduce;
  final bool togetherReveal;
  final bool rovingFocus;
  final FocusNode? Function(int index)? focusNodeForOption;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onTap;
  final int delayChildrenMs;

  static const int _windowMs = 600;

  @override
  Widget build(BuildContext context) {
    final c = reduce ? null : clock;
    return Padding(
      padding: const EdgeInsets.all(4), // p-1
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) _wrapReveal(i, c, _row(i)),
        ],
      ),
    );
  }

  Widget _wrapReveal(int i, double? c, Widget row) {
    if (c == null) return row;
    if (togetherReveal) {
      final p = c.clamp(0.0, 1.0);
      return Opacity(
        opacity: p,
        child: Transform.translate(
          key: ValueKey('beui-select-row-reveal-${options[i].value}'),
          offset: Offset(0, reduce ? 0 : -4 * (1 - p)),
          child: row,
        ),
      );
    }
    final start = (delayChildrenMs + i * _staggerMs) / _windowMs;
    const width = _itemDurMs / _windowMs;
    final p = beuiEaseOut.transform(((c - start) / width).clamp(0.0, 1.0));
    Widget child = row;
    final blur = beuiBlurSigma(3) * (1 - p); // blur(3px) → σ1.5
    if (blur > 0.05) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: child,
      );
    }
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, -6 * (1 - p)), child: child),
    );
  }

  Widget _row(int i) {
    final opt = options[i];
    final isSelected = opt.value == value;
    final isActive = i == active;
    final highlight = isSelected || isActive;
    final row = MouseRegion(
      onEnter: opt.enabled ? (_) => onHover(i) : null,
      cursor: opt.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: opt.enabled ? () => onTap(i) : null,
        child: Opacity(
          opacity: opt.enabled ? 1 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: highlight ? colors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(8), // rounded-lg
            ),
            // px-2.5 py-1.5
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                if (opt.icon != null) ...[
                  _OptionIcon(
                    icon: opt.icon!,
                    color: highlight
                        ? colors.foreground
                        : colors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child:
                      (togetherReveal ? opt.labelWidget : null) ??
                      Text(
                        opt.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: highlight
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                      ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(LucideIcons.check, size: 14, color: colors.foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    Widget result = row;
    if (togetherReveal) {
      result = Semantics(
        label: opt.label,
        button: true,
        enabled: opt.enabled,
        selected: isSelected,
        onTap: opt.enabled ? () => onTap(i) : null,
        child: ExcludeSemantics(child: row),
      );
    }
    if (rovingFocus) {
      result = Focus(
        focusNode: focusNodeForOption?.call(i),
        canRequestFocus: opt.enabled && isActive,
        skipTraversal: !opt.enabled || !isActive,
        child: result,
      );
    }
    return result;
  }
}
