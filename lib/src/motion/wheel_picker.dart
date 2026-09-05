import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';

// Source `wheel-picker.tsx` builds an iOS-style drum by hand out of DOM
// transforms and a bespoke physics loop — it deliberately does NOT reuse the
// five shared spring tokens (see its comment: "the wheel coasts in whole-row
// units and springs to an integer detent, which a layout spring can't express
// cleanly"). The physics it hand-rolls — flick momentum with a per-ms
// deceleration, whole-row snap, and a spring-tipped settle — is exactly what
// Flutter's [FixedExtentScrollPhysics] already provides natively: a friction
// fling that resolves onto an integer item with a spring-damped landing. So the
// faithful port drives a [ListWheelScrollView] with a [FixedExtentScrollController]
// rather than re-deriving the source's DECELERATION / MAX_VELOCITY / easeOutBack
// constants — the physical result (coast, snap, gentle overshoot) matches, and
// the momentum reads as native iOS on both touch and trackpad.
//
// The source's DOM-only touches that DO carry over as visible fidelity are the
// *geometry*: the cylinder curvature (`itemAngle = 90/cutoff`, `radius =
// itemHeight/tan(itemAngle)`) and the two-tier contrast (a dimmed drum of
// muted rows with one crisp foreground row framed in the centre window, behind
// a top/bottom mask fade). Those are reproduced below — the drum curvature is
// mapped onto [ListWheelScrollView.diameterRatio] from the identical
// `visibleCount` math, and the crisp-centre / dimmed-edge split is done with a
// centre highlight band plus [ListWheelScrollView.overAndUnderCenterOpacity].

/// One selectable row of a [BeuiWheelPicker].
///
/// Mirrors the source `WheelPickerOption = string | { label; value }`: a row is
/// identified by its [value] (what [BeuiWheelPicker.onChanged] emits and what
/// [BeuiWheelPicker.value] matches against) and displays [label], falling back
/// to [value] when no distinct label is given.
@immutable
class BeuiWheelPickerOption {
  /// Creates an option with an explicit [value] and optional display [label].
  const BeuiWheelPickerOption({required this.value, this.label});

  /// Creates an option whose display text and value are the same string.
  const BeuiWheelPickerOption.text(this.value) : label = null;

  /// The stable identity emitted by [BeuiWheelPicker.onChanged].
  final String value;

  /// Optional display text; falls back to [value].
  final String? label;

  /// The text shown for this row.
  String get displayLabel => label ?? value;
}

/// Optional style overrides for [BeuiWheelPicker]. Null fields resolve from the
/// ambient [BeuiColors] theme extension (or sensible defaults).
@immutable
class BeuiWheelPickerStyle {
  /// Creates a set of [BeuiWheelPicker] overrides.
  const BeuiWheelPickerStyle({
    this.backgroundColor,
    this.borderColor,
    this.highlightColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.textStyle,
    this.borderRadius,
    this.width,
  });

  /// Drum container fill. Defaults to `BeuiColors.card`.
  final Color? backgroundColor;

  /// Drum container border. Defaults to `BeuiColors.border`.
  final Color? borderColor;

  /// Centre selection band fill. Defaults to `BeuiColors.foreground` at 4% alpha
  /// (source `bg-foreground/[0.04]`).
  final Color? highlightColor;

  /// Colour of the crisp, centred row. Defaults to `BeuiColors.foreground`.
  final Color? selectedTextColor;

  /// Colour of the dimmed drum rows. Defaults to `BeuiColors.mutedForeground`.
  final Color? unselectedTextColor;

  /// Base text style for rows (colour is overridden per-row). Defaults to a
  /// 16px medium label.
  final TextStyle? textStyle;

  /// Container corner radius. Defaults to 16 (source `rounded-2xl`).
  final double? borderRadius;

  /// Fixed picker width. Defaults to 160.
  final double? width;

  /// Returns a copy with the given fields replaced.
  BeuiWheelPickerStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    Color? highlightColor,
    Color? selectedTextColor,
    Color? unselectedTextColor,
    TextStyle? textStyle,
    double? borderRadius,
    double? width,
  }) {
    return BeuiWheelPickerStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      highlightColor: highlightColor ?? this.highlightColor,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      unselectedTextColor: unselectedTextColor ?? this.unselectedTextColor,
      textStyle: textStyle ?? this.textStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      width: width ?? this.width,
    );
  }
}

/// Test handle on the underlying scrollable drum.
@visibleForTesting
const beuiWheelPickerListKey = ValueKey<String>('beui_wheel_picker_list');

/// An iOS-style wheel picker — the Flutter port of beUI's `wheel-picker`.
///
/// Rows sit on a curved drum: the centred row is drawn crisp in the foreground
/// colour inside a highlight window, while rows away from centre rotate back
/// and dim to the muted colour behind a top/bottom mask fade. A flick coasts
/// with momentum and snaps to the nearest row with a gentle spring landing;
/// trackpad/scroll-wheel drives the drum the same way; Up/Down (and Home/End)
/// move the selection by keyboard.
///
/// **Controlled + uncontrolled** (mirroring the source): pass [value] +
/// [onChanged] to drive it externally, or omit [value] and seed the initial
/// row with [defaultValue] to let the widget own its state.
///
/// The momentum, snap and spring-landing come from Flutter's
/// [FixedExtentScrollPhysics] rather than the source's hand-rolled per-ms
/// deceleration loop — the physical result (free coast → whole-row detent →
/// soft overshoot) matches, and reads as native on touch and trackpad. See the
/// file header for the physics/geometry mapping.
///
/// Reduced motion flattens the drum (no 3D rotation — the movement the rules
/// drop) while keeping the picker fully scrollable and keeping the crisp/dimmed
/// contrast; keyboard steps jump instead of animating.
class BeuiWheelPicker extends StatefulWidget {
  /// Creates a wheel picker over [options].
  const BeuiWheelPicker({
    required this.options,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.visibleCount = 5,
    this.itemHeight = 36,
    this.enabled = true,
    this.style,
    this.semanticLabel,
    super.key,
  }) : assert(visibleCount > 0, 'visibleCount must be positive');

  /// The rows to choose from, top to bottom.
  final List<BeuiWheelPickerOption> options;

  /// The selected row's [BeuiWheelPickerOption.value] (controlled). When null,
  /// the widget owns its selection internally (uncontrolled), seeded from
  /// [defaultValue].
  final String? value;

  /// The initially selected value in uncontrolled mode. Ignored when [value] is
  /// non-null.
  final String? defaultValue;

  /// Called with the newly selected [BeuiWheelPickerOption.value] as the drum
  /// passes each row (matching the source, which emits continuously while the
  /// wheel spins, not only on settle).
  final ValueChanged<String>? onChanged;

  /// Rows visible through the window; odd reads best. More rows = flatter curve
  /// (source `visibleCount`, default 5).
  final int visibleCount;

  /// Row height in logical pixels (source `itemHeight`, default 36).
  final double itemHeight;

  /// Whether the picker responds to input. Disabled is dimmed and unfocusable.
  final bool enabled;

  /// Optional visual overrides.
  final BeuiWheelPickerStyle? style;

  /// Accessibility label for the picker (source `aria-label`).
  final String? semanticLabel;

  @override
  State<BeuiWheelPicker> createState() => _BeuiWheelPickerState();
}

class _BeuiWheelPickerState extends State<BeuiWheelPicker> {
  late FixedExtentScrollController _controller;
  late int _selected;
  late final FocusNode _focusNode = FocusNode();
  bool _focusVisible = false;

  int get _last => widget.options.length - 1;

  int _indexOf(String? value) {
    if (value == null) return 0;
    final i = widget.options.indexWhere((o) => o.value == value);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _selected = _indexOf(widget.value ?? widget.defaultValue);
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void didUpdateWidget(BeuiWheelPicker old) {
    super.didUpdateWidget(old);
    // Follow a controlled value change from outside. Mirrors the source effect
    // that glides the drum back onto `value` when the prop moves out from under
    // it; a no-op when the drum already sits on the requested row (e.g. the
    // parent just echoed our own onChanged).
    if (widget.value != null && widget.value != old.value) {
      final target = _indexOf(widget.value);
      if (target != _selected) {
        _selected = target;
        _reduce
            ? _controller.jumpToItem(target)
            : _controller.animateToItem(
                target,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  void _emit(int index) {
    final clamped = index.clamp(0, _last);
    if (clamped == _selected) return;
    _selected = clamped;
    HapticFeedback.selectionClick();
    if (widget.value == null) setState(() {}); // uncontrolled repaint
    widget.onChanged?.call(widget.options[clamped].value);
  }

  void _step(int by) {
    if (!widget.enabled) return;
    final target = (_selected + by).clamp(0, _last);
    if (target == _selected) return;
    if (_reduce) {
      _controller.jumpToItem(target);
      _emit(target);
    } else {
      _controller.animateToItem(
        target,
        // Source keyboard step: 300ms with a spring-tipped (easeOutBack) settle.
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final style = widget.style;
    final reduce = _reduce;
    final enabled = widget.enabled;

    final itemHeight = widget.itemHeight;
    final width = style?.width ?? 160.0;
    final radiusCorner = style?.borderRadius ?? 16.0;
    final bg = style?.backgroundColor ?? colors.card;
    final borderColor = style?.borderColor ?? colors.border;
    final highlight =
        style?.highlightColor ?? colors.foreground.withValues(alpha: 0.04);
    final selectedColor = style?.selectedTextColor ?? colors.foreground;
    final unselectedColor =
        style?.unselectedTextColor ?? colors.mutedForeground;
    final baseTextStyle =
        style?.textStyle ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500);

    // Cylinder geometry, reproduced from the source's `visibleCount` math:
    //   rowsEachSide = floor(visibleCount/2); cutoff = rowsEachSide + 1;
    //   itemAngle = 90/cutoff;  radius = itemHeight / tan(itemAngle);
    //   height = round(2·radius·sin(rowsEachSide·itemAngle) + itemHeight).
    //
    // Both engines project a row seated on the drum to the same closed form,
    //   Y(i) = R·sin(i·θ) / (1 + p·R·(1 − cos(i·θ))),
    // the source via CSS `perspective: 1000px` + rotateX/translateZ, Flutter via
    // `MatrixUtils.createCylindricalProjectionTransform`. So matching the render
    // is exactly matching the triple (R, θ, p), and ListWheelScrollView exposes
    // one knob for each:
    //
    //   R = viewportHeight·diameterRatio/2   → diameterRatio = 2·radius/height
    //   θ = (itemHeight/height)·2·maxVisibleRadian/squeeze
    //   p = perspective                      → 0.001, i.e. CSS's 1000px
    //
    // `maxVisibleRadian` is π/2 whenever diameterRatio < 1 (list_wheel_viewport
    // .dart), and 2·radius < height holds for every visibleCount — the drum is
    // always narrower than the box it sits in — so it is π/2 here by
    // construction, and squeeze follows.
    //
    // Solving R through diameterRatio *alone* (no squeeze) is what a per-row
    // angle match on its own gives you, and it is wrong: it forces
    // R = height·diameterRatio/2 ≥ height/2 = 114.5 against the source's 101.4,
    // spreading the rows ~26% too far apart and pushing the outermost pair past
    // the box edge to be clipped mid-glyph.
    final rowsEachSide = math.max(1, widget.visibleCount ~/ 2);
    final cutoff = rowsEachSide + 1;
    final itemAngle = (math.pi / 2) / cutoff;
    final drumRadius = itemHeight / math.tan(itemAngle);
    final viewportHeight =
        (2 * drumRadius * math.sin(rowsEachSide * itemAngle) + itemHeight)
            .roundToDouble();

    final double diameterRatio;
    final double squeeze;
    if (reduce) {
      // Flatten the drum: reduced motion drops the 3D rotation (the movement),
      // keeping a plain scrollable list. A large ratio makes every row's angle
      // ~0, so nothing rotates.
      diameterRatio = 100;
      squeeze = 1;
    } else {
      diameterRatio = 2 * drumRadius / viewportHeight;
      squeeze = (itemHeight / viewportHeight) * math.pi / itemAngle;
    }

    Widget row(int i) {
      final isSelected = i == _selected;
      return SizedBox(
        height: itemHeight,
        child: Center(
          child: Text(
            widget.options[i].displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseTextStyle.copyWith(
              color: isSelected ? selectedColor : unselectedColor,
            ),
          ),
        ),
      );
    }

    final wheel = ListWheelScrollView.useDelegate(
      key: beuiWheelPickerListKey,
      controller: _controller,
      itemExtent: itemHeight,
      diameterRatio: diameterRatio,
      squeeze: squeeze,
      // CSS `perspective: 1000px` → 1/1000. Flutter's own default is 0.003,
      // which would over-foreshorten the outer rows against the source.
      perspective: 0.001,
      // The source dims off-centre rows *only* by colour — every drum row is
      // `text-muted-foreground` and the crisp centre copy is `text-foreground`,
      // which `row()` already reproduces. There is no per-row opacity ramp; the
      // sole alpha falloff is the shared `maskFade` gradient below. Dimming here
      // as well would multiply the two, and did: it put the off-centre rows at
      // less than half the source's luminance.
      overAndUnderCenterOpacity: 1,
      physics: enabled
          ? const FixedExtentScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onSelectedItemChanged: enabled ? _emit : null,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.options.length,
        builder: (context, i) => row(i),
      ),
    );

    // Top/bottom mask fade (source `mask-image: linear-gradient(to bottom,
    // transparent, #000 22%, #000 78%, transparent)`).
    final masked = ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0.0, 0.22, 0.78, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: wheel,
    );

    final stack = Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: masked),
        // Centre selection band.
        IgnorePointer(
          child: Container(
            height: itemHeight,
            // Source: `absolute inset-x-0 … rounded-md` — the band runs the full
            // width of the wheel, with no horizontal inset.
            decoration: BoxDecoration(
              color: highlight,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );

    final container = Container(
      width: width,
      height: viewportHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(radiusCorner),
        boxShadow: _focusVisible
            ? [BoxShadow(color: colors.ring, spreadRadius: 2)]
            : null,
      ),
      child: stack,
    );

    return Semantics(
      label: widget.semanticLabel,
      enabled: enabled,
      value: widget.options.isEmpty
          ? null
          : widget.options[_selected.clamp(0, _last)].displayLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: _focusNode,
        mouseCursor: enabled ? SystemMouseCursors.grab : MouseCursor.defer,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _WheelStepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _WheelStepIntent(1),
          SingleActivator(LogicalKeyboardKey.home): _WheelHomeIntent(),
          SingleActivator(LogicalKeyboardKey.end): _WheelEndIntent(),
        },
        actions: <Type, Action<Intent>>{
          _WheelStepIntent: CallbackAction<_WheelStepIntent>(
            onInvoke: (intent) {
              _step(intent.by);
              return null;
            },
          ),
          _WheelHomeIntent: CallbackAction<_WheelHomeIntent>(
            onInvoke: (_) {
              _step(-_selected);
              return null;
            },
          ),
          _WheelEndIntent: CallbackAction<_WheelEndIntent>(
            onInvoke: (_) {
              _step(_last - _selected);
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        child: Opacity(opacity: enabled ? 1.0 : 0.5, child: container),
      ),
    );
  }
}

/// Move the selection by [by] rows (±1 for Arrow keys).
class _WheelStepIntent extends Intent {
  const _WheelStepIntent(this.by);
  final int by;
}

/// Jump to the first row (Home).
class _WheelHomeIntent extends Intent {
  const _WheelHomeIntent();
}

/// Jump to the last row (End).
class _WheelEndIntent extends Intent {
  const _WheelEndIntent();
}
