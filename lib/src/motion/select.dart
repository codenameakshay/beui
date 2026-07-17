import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder, SpringMotion;

/// One selectable option in a [BeuiSelect] / [BeuiMorphSelect].
///
/// The Flutter analog of the source's `<SelectItem value="…">Label</SelectItem>`
/// — [value] is committed through `onChanged`; [label] is what the option row
/// and the trigger display.
@immutable
class BeuiSelectOption {
  /// Creates an option carrying [value] and shown as [label].
  const BeuiSelectOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  /// The value committed when this option is chosen.
  final String value;

  /// The visible label (also shown in the trigger once selected).
  final String label;

  /// Whether the option can be chosen. Disabled options are dimmed and skipped
  /// by keyboard navigation.
  final bool enabled;
}

// ---------------------------------------------------------------------------
// Springs — Framer `{ type: "spring", duration, bounce }` tokens converted to
// SpringDescription (mass 1): ω = 2π/duration, ζ = 1 − bounce, stiffness = ω²,
// damping = 2ζω (the house conversion, see popover.dart / PORTING_SPEC §1).
// ---------------------------------------------------------------------------

/// Chevron rotate — source `CHEVRON_TRANSITION = { duration: 0.4, bounce: 0.3 }`.
/// ω = 2π/0.4 ≈ 15.71, ζ = 0.7 → stiffness ≈ 247, damping ≈ 22.
const _chevronSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 247, damping: 22),
);

/// Panel height accordion — source content `height` spring
/// `{ duration: 0.42, bounce: 0.14 }`. ω = 2π/0.42 ≈ 14.96, ζ = 0.86 →
/// stiffness ≈ 224, damping ≈ 26.
const _heightSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 224, damping: 26),
);

/// Gap open — the panel pinches away from the trigger — source content
/// `marginTop/Bottom` spring `{ duration: 0.6, bounce: 0.5 }`. ω = 2π/0.6 ≈
/// 10.47, ζ = 0.5 → stiffness ≈ 110, damping ≈ 10.5. The high bounce is what
/// springs the gap open past its rest and settles it back.
const _gapSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 110, damping: 10.5),
);

/// Shared-layout morph — source `MORPH = { duration: 0.5, bounce: 0.22 }`.
/// ω = 2π/0.5 ≈ 12.57, ζ = 0.78 → stiffness ≈ 158, damping ≈ 20. Drives the
/// trigger↔panel size morph in [BeuiMorphSelect].
const _morphSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 158, damping: 20),
);

const double _gap = 8; // source nearGap (marginTop 8)
const double _radius = 12; // rounded-xl

enum _Placement { bottom, top }

// Stagger constants (ms), normalized against the enter clock in-builder.
const int _staggerMs = 35; // source staggerChildren 0.035
const int _itemDurMs = 300;

// Gap opens 0.12s after height on the 0.6s enter clock — source `gapT` carries
// `delay: 0.12` relative to the height spring. Below this fraction the gap holds
// flush at 0; above it the bouncy gap spring runs.
const double _gapDelayFraction = 0.12 / 0.6; // 0.2

// Panel near-corner (the edge facing the trigger) uses the source's DEDICATED
// corner transition `radiusT`, NOT the height spring: open eases 0→12 over 0.3s
// (EASE_OUT) after a 0.14s delay; close eases 12→0 over 0.16s (EASE_OUT). Both
// are normalized against the overlay enter/exit clocks (600ms / 300ms).
double _panelNearOpen(double t) {
  const delay = 0.14 / 0.6; // 0.2333…
  const dur = 0.3 / 0.6; // 0.5
  return _radius * beuiEaseOut.transform(((t - delay) / dur).clamp(0.0, 1.0));
}

double _panelNearClose(double t) {
  const dur = 0.16 / 0.3; // 0.5333… (the exit clock `t` runs 1→0)
  return _radius * (1 - beuiEaseOut.transform(((1 - t) / dur).clamp(0.0, 1.0)));
}

// ===========================================================================
// BeuiSelect — the default (gooey accordion) dropdown.
// ===========================================================================

/// A dropdown select whose panel unfolds out of the trigger — the Flutter port
/// of beUI's `select` (the gooey/accordion variant), built on [BeuiOverlay] and
/// anchored to the trigger with a [LayerLink] + [CompositedTransformFollower],
/// the same overlay pattern as [BeuiTooltip].
///
/// **Open choreography** (mirrors the source's per-channel transitions): the
/// panel starts flush against the trigger (gap 0, near corners square) then
/// **separates** — its height springs open on [_heightSpring]
/// (`duration 0.42, bounce 0.14`), a gap springs apart on the bouncy
/// [_gapSpring] (`0.6/0.5`), and the corners facing the trigger round from 0→12
/// while the far corners stay rounded. Options **stagger in** (source
/// `staggerChildren 0.035, delayChildren 0.05`), each rising 6px through a
/// blur(3px)→0 opacity fade. The chevron rotates 180° on [_chevronSpring], and
/// the trigger edge facing the panel **pinches flat then rounds back** (source's
/// `[12,0,12]` corner keyframes). The panel flips above the trigger when there
/// isn't room below. Each channel springs on enter (via `from: 0`, like the
/// tooltip) and eases *forward* to its collapse on exit — the exit is not a
/// time-reversed entrance.
///
/// **Controlled or uncontrolled**: pass [value] + [onChanged] to control it, or
/// omit [value] and seed [defaultValue] for internal state. **Keyboard**: Enter
/// / Space / ArrowDown open it; Up/Down move the highlight; Enter commits; Esc
/// closes. Reduced motion keeps a quick height + opacity reveal but drops the
/// gap, the corner pinch and the per-option movement (options fade only).
class BeuiSelect extends StatefulWidget {
  /// Creates a select over [options].
  const BeuiSelect({
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

  /// Shown in the trigger until a value is selected.
  final String placeholder;

  /// Whether the trigger is interactive.
  final bool enabled;

  @override
  State<BeuiSelect> createState() => _BeuiSelectState();
}

class _BeuiSelectState extends State<BeuiSelect>
    with SingleTickerProviderStateMixin {
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _measureKey = GlobalKey();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'BeuiSelect panel');

  late final AnimationController _cornerCtrl;
  Animatable<double> _cornerTween = ConstantTween<double>(_radius);

  bool _open = false;
  String? _internalValue;
  Size _triggerSize = Size.zero;
  double _panelHeight = 0;
  _Placement _placement = _Placement.bottom;
  int _active = -1;
  bool _triggerHovered = false; // source hover:border-(--color-border-strong)
  bool _triggerFocused =
      false; // source focus-visible:ring-2 ring-foreground/20

  String? get _value => widget.value ?? _internalValue;

  /// Bounded width for the panel (and its off-stage measurement); falls back to
  /// a sensible default until the trigger has been measured.
  double get _panelWidth => _triggerSize.width > 0 ? _triggerSize.width : 240;

  @override
  void initState() {
    super.initState();
    _internalValue = widget.defaultValue;
    _cornerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1,
    );
  }

  @override
  void dispose() {
    _cornerCtrl.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  int _selectedIndex() => widget.options.indexWhere((o) => o.value == _value);
  int _firstEnabled() => widget.options.indexWhere((o) => o.enabled);

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

  void _setOpen(bool next) {
    if (next == _open) return;
    if (next) {
      _decidePlacement();
      final sel = _selectedIndex();
      _active = sel >= 0 ? sel : _firstEnabled();
      // Trigger edge pinches flat (0) then rounds back to 12 — source open
      // keyframes [12,0,12] over 0.6s.
      _cornerTween = _openCornerSeq;
      _cornerCtrl.duration = const Duration(milliseconds: 600);
    } else {
      // Close keyframes [12,0,12] over 0.42s.
      _cornerTween = _closeCornerSeq;
      _cornerCtrl.duration = const Duration(milliseconds: 420);
    }
    _cornerCtrl.forward(from: 0);
    setState(() => _open = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _panelFocus.requestFocus(),
      );
    }
  }

  void _select(int index) {
    if (index < 0 || index >= widget.options.length) return;
    final opt = widget.options[index];
    if (!opt.enabled) return;
    if (widget.value == null) setState(() => _internalValue = opt.value);
    widget.onChanged?.call(opt.value);
    _setOpen(false);
  }

  void _moveActive(int delta) {
    final n = widget.options.length;
    if (n == 0) return;
    var i = _active;
    for (var step = 0; step < n; step++) {
      i = (i + delta) % n;
      if (i < 0) i += n;
      if (widget.options[i].enabled) {
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

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return BeuiOverlay(
      open: _open,
      barrier: true,
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      trapFocus: false,
      onDismiss: () => _setOpen(false),
      enterDuration: Duration(milliseconds: reduce ? 160 : 600),
      exitDuration: Duration(milliseconds: reduce ? 120 : 300),
      overlayBuilder: _buildPanel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Off-stage panel content, measured for the accordion height. Laid
          // out but never painted.
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
                    onHover: (_) {},
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
          KeyedSubtree(key: _triggerKey, child: _buildTrigger(colors)),
        ],
      ),
    );
  }

  Widget _buildTrigger(BeuiColors colors) {
    final selected = _selectedIndex() >= 0;
    final label = selected
        ? widget.options[_selectedIndex()].label
        : widget.placeholder;

    return Focus(
      canRequestFocus: widget.enabled,
      onKeyEvent: widget.enabled ? _onTriggerKey : null,
      onFocusChange: (f) => setState(() => _triggerFocused = f),
      child: MouseRegion(
        onEnter: widget.enabled
            ? (_) => setState(() => _triggerHovered = true)
            : null,
        onExit: widget.enabled
            ? (_) => setState(() => _triggerHovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _setOpen(!_open) : null,
          child: AnimatedBuilder(
            animation: _cornerCtrl,
            builder: (context, _) {
              final reduce = MediaQuery.disableAnimationsOf(context);
              final near = reduce
                  ? _radius
                  : _cornerTween.evaluate(_cornerCtrl);
              return Opacity(
                opacity: widget.enabled ? 1 : 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    // hover:border-(--color-border-strong)
                    border: Border.all(
                      color: _triggerHovered
                          ? colors.borderStrong
                          : colors.border,
                    ),
                    borderRadius: _triggerCorners(near),
                    // focus-visible:ring-2 ring-foreground/20
                    boxShadow: _triggerFocused
                        ? [
                            BoxShadow(
                              color: colors.foreground.withValues(alpha: 0.2),
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: selected
                                ? colors.foreground
                                : colors.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Chevron(open: _open, color: colors.mutedForeground),
                    ],
                  ),
                ),
              );
            },
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

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isTop = _placement == _Placement.top;
    final width = _panelWidth;

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: isTop ? Alignment.topLeft : Alignment.bottomLeft,
      followerAnchor: isTop ? Alignment.bottomLeft : Alignment.topLeft,
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
              if (reduce) {
                return _panelBody(
                  colors: colors,
                  reduce: true,
                  isTop: isTop,
                  width: width,
                  clock: t,
                  hp: t,
                  gp: 0,
                  near: _radius,
                );
              }
              if (exiting) {
                // Forward-eased collapse (its own targets, not a reversed
                // spring): height and gap ease back to flush; the near corner
                // squares off on its dedicated close transition (0.16s).
                final hp = beuiEaseOut.transform(t);
                return _panelBody(
                  colors: colors,
                  reduce: false,
                  isTop: isTop,
                  width: width,
                  clock: t,
                  hp: hp,
                  gp: t,
                  near: _panelNearClose(t),
                );
              }
              // Enter: height springs from 0 on its own ticker (the `from: 0`
              // makes it animate on mount, like the tooltip); the gap is held
              // flush until 0.12s (source `gapT` delay) then springs open on the
              // bouncy gap spring; the near corner rounds on its dedicated
              // transition (delay 0.14s, 0.3s), independent of the height.
              return SingleMotionBuilder(
                value: 1.0,
                from: 0.0,
                motion: _heightSpring,
                builder: (context, hp, _) {
                  final gapTarget = t >= _gapDelayFraction ? 1.0 : 0.0;
                  return SingleMotionBuilder(
                    value: gapTarget,
                    from: 0.0,
                    motion: _gapSpring,
                    builder: (context, gp, _) {
                      return _panelBody(
                        colors: colors,
                        reduce: false,
                        isTop: isTop,
                        width: width,
                        clock: t,
                        hp: hp,
                        gp: gp,
                        near: _panelNearOpen(t),
                      );
                    },
                  );
                },
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
    required double clock,
    required double hp,
    required double gp,
    required double near,
  }) {
    final gap = _gap * gp.clamp(0.0, 1.5);
    final opacity = beuiEaseOut.transform(
      (clock * (600 / 180)).clamp(0.0, 1.0),
    );

    final content = _OptionColumn(
      options: widget.options,
      value: _value,
      active: _active,
      colors: colors,
      clock: reduce ? null : clock,
      reduce: reduce,
      onHover: (i) {
        if (widget.options[i].enabled && _active != i) {
          setState(() => _active = i);
        }
      },
      onTap: _select,
    );

    final panel = Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: _panelCorners(near, isTop),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRect(
        child: Align(
          alignment: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          heightFactor: hp.clamp(0.0, 1.0),
          child: SizedBox(width: width, child: content),
        ),
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

class _BeuiMorphSelectState extends State<BeuiMorphSelect> {
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _measureKey = GlobalKey();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'BeuiMorphSelect panel');

  bool _open = false;
  String? _internalValue;
  Size _triggerSize = Size.zero;
  double _panelHeight = 0;
  int _active = -1;

  String? get _value => widget.value ?? _internalValue;

  double get _panelWidth => _triggerSize.width > 0 ? _triggerSize.width : 240;
  double get _triggerHeight =>
      _triggerSize.height > 0 ? _triggerSize.height : 41;

  @override
  void initState() {
    super.initState();
    _internalValue = widget.defaultValue;
  }

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  int _selectedIndex() => widget.options.indexWhere((o) => o.value == _value);
  int _firstEnabled() => widget.options.indexWhere((o) => o.enabled);

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

  void _select(int index) {
    if (index < 0 || index >= widget.options.length) return;
    final opt = widget.options[index];
    if (!opt.enabled) return;
    if (widget.value == null) setState(() => _internalValue = opt.value);
    widget.onChanged?.call(opt.value);
    _setOpen(false);
  }

  void _moveActive(int delta) {
    final n = widget.options.length;
    if (n == 0) return;
    var i = _active;
    for (var step = 0; step < n; step++) {
      i = (i + delta) % n;
      if (i < 0) i += n;
      if (widget.options[i].enabled) {
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

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
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
    this.onTap,
    this.onKeyEvent,
    this.openProgress = 1,
  });

  final String label;
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
        : _Chevron(open: false, color: colors.mutedForeground);

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

/// The chevron glyph that rotates 180° between closed and open on
/// [_chevronSpring].
class _Chevron extends StatelessWidget {
  const _Chevron({required this.open, required this.color});
  final bool open;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SingleMotionBuilder(
      value: open ? 1.0 : 0.0,
      motion: reduce
          ? const SpringMotion(
              SpringDescription(mass: 1, stiffness: 700, damping: 60),
            )
          : _chevronSpring,
      builder: (context, p, child) =>
          Transform.rotate(angle: p * math.pi, child: child),
      child: Icon(LucideIcons.chevron_down, size: 16, color: color),
    );
  }
}

/// The list of option rows, optionally staggering each in (opacity + 6px rise +
/// blur(3px)→0) as the panel opens. Shared by both variants.
class _OptionColumn extends StatelessWidget {
  const _OptionColumn({
    required this.options,
    required this.value,
    required this.active,
    required this.colors,
    required this.clock,
    required this.reduce,
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
          for (var i = 0; i < options.length; i++) _wrapStagger(i, c, _row(i)),
        ],
      ),
    );
  }

  Widget _wrapStagger(int i, double? c, Widget row) {
    if (c == null) return row;
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
    return MouseRegion(
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
                Expanded(
                  child: Text(
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
  }
}

// Trigger corner keyframe sequences for the default variant.
// Open: source keyframes `[12,0,12]` with `times:[0,0.4,1]`, ease EASE_OUT over
// 0.6s — the near edge eases 12→0 across the first 40% as the panel attaches,
// then 0→12 across the last 60% as it separates (no flat hold). Close: 12→0→12
// with `times:[0,0.5,1]` (50/50) over 0.42s.
final Animatable<double> _openCornerSeq = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(
      begin: _radius,
      end: 0.0,
    ).chain(CurveTween(curve: beuiEaseOut)),
    weight: 40,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 0.0,
      end: _radius,
    ).chain(CurveTween(curve: beuiEaseOut)),
    weight: 60,
  ),
]);

final Animatable<double> _closeCornerSeq = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(
      begin: _radius,
      end: 0.0,
    ).chain(CurveTween(curve: beuiEaseOut)),
    weight: 50,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 0.0,
      end: _radius,
    ).chain(CurveTween(curve: beuiEaseOut)),
    weight: 50,
  ),
]);
