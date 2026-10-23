import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// HSVA color value: hue in 0–360, saturation/value in 0–100, alpha in 0–1.
@immutable
class BeuiHsva {
  /// Creates an HSVA value.
  const BeuiHsva(this.h, this.s, this.v, [this.a = 1]);
  final double h, s, v, a;
}

/// Parses short or long CSS hex colors (with optional alpha).
Color? beuiColorFromHex(String input) {
  var hex = input.trim().replaceFirst('#', '');
  if (!RegExp(
    r'^(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  ).hasMatch(hex)) {
    return null;
  }
  if (hex.length <= 4) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 8) {
    hex = '${hex.substring(6, 8)}${hex.substring(0, 6)}';
  } else {
    hex = 'ff$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

/// Formats [color] as lowercase #rrggbb or #rrggbbaa.
String beuiColorToHex(Color color, {bool includeAlpha = true}) {
  String pair(int n) => n.toRadixString(16).padLeft(2, '0');
  final alpha = color.a * 255;
  return '#${pair((color.r * 255).round())}${pair((color.g * 255).round())}'
      '${pair((color.b * 255).round())}'
      '${includeAlpha && alpha.round() != 255 ? pair(alpha.round()) : ''}';
}

/// One named color swatch for [BeuiColorPickerPresets].
@immutable
class BeuiColorPickerPresetItem {
  /// Creates a preset from a hex color and optional accessible name.
  const BeuiColorPickerPresetItem(this.value, {this.label});
  final String value;
  final String? label;
}

/// Composable color picker with optional anchored trigger and floating panel.
///
/// Pass [value] and [onChanged] for controlled use, or [defaultValue] for
/// internal state. [child] is the inline picker body; when [trigger] is set it
/// is shown in a [BeuiOverlay] dialog instead. Eye-dropper sampling is not
/// available on Flutter platforms, so [BeuiColorPickerEyeDropper] is a safe
/// no-op placeholder.
class BeuiColorPicker extends StatefulWidget {
  /// Creates a color picker.
  const BeuiColorPicker({
    required this.child,
    this.trigger,
    this.value,
    this.defaultValue = '#3478f6',
    this.onChanged,
    this.onCommit,
    this.alpha = true,
    this.open,
    this.defaultOpen = false,
    this.onOpenChanged,
    this.enabled = true,
    this.label = 'Color picker',
    super.key,
  });

  /// Picker body, usually composed of the other `BeuiColorPicker*` parts.
  final Widget child;

  /// Optional trigger; when supplied, [child] appears in a floating dialog.
  final Widget? trigger;

  /// Controlled color, in CSS hex form.
  final String? value;

  /// Initial color in uncontrolled mode.
  final String defaultValue;

  /// Called whenever the color changes.
  final ValueChanged<String>? onChanged;

  /// Called when an interaction settles.
  final ValueChanged<String>? onCommit;

  /// Whether alpha is editable.
  final bool alpha;

  /// Controlled dialog visibility.
  final bool? open;

  /// Initial dialog visibility in uncontrolled mode.
  final bool defaultOpen;

  /// Called when dialog visibility changes.
  final ValueChanged<bool>? onOpenChanged;

  /// Disables all picker controls.
  final bool enabled;

  /// Accessible dialog name.
  final String label;

  @override
  State<BeuiColorPicker> createState() => _BeuiColorPickerState();
}

class _BeuiColorPickerState extends State<BeuiColorPicker> {
  final _chipKey = GlobalKey();
  late Color _internalColor =
      beuiColorFromHex(widget.defaultValue) ?? const Color(0xff3478f6);
  late bool _internalOpen = widget.defaultOpen;

  Color get _color => widget.value == null
      ? _internalColor
      : (beuiColorFromHex(widget.value!) ?? _internalColor);
  bool get _open => widget.open ?? _internalOpen;

  void _setColor(Color value, {bool commit = false}) {
    final next = widget.alpha ? value : value.withAlpha(255);
    if (widget.value == null) setState(() => _internalColor = next);
    final hex = beuiColorToHex(next);
    widget.onChanged?.call(hex);
    if (commit) widget.onCommit?.call(hex);
  }

  void _setOpen(bool value) {
    if (value == _open) return;
    if (widget.open == null) setState(() => _internalOpen = value);
    widget.onOpenChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final scope = _ColorPickerScope(
      color: _color,
      alpha: widget.alpha,
      enabled: widget.enabled,
      reduce: MediaQuery.disableAnimationsOf(context),
      onColor: _setColor,
      chipKey: widget.trigger == null ? null : _chipKey,
      open: _open,
    );
    if (widget.trigger == null) {
      return _ColorPickerInherited(scope: scope, child: widget.child);
    }
    final panel = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _PickerReveal(
            open: _open,
            delay: const Duration(milliseconds: 100),
            movement: false,
            child: DecoratedBox(
              key: const ValueKey('color-picker-panel-surface'),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 32,
                    spreadRadius: -8,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: widget.label,
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(width: 288, child: widget.child),
          ),
        ),
      ],
    );
    return _ColorPickerInherited(
      scope: scope,
      child: BeuiOverlay(
        open: _open,
        onDismiss: () => _setOpen(false),
        barrier: true,
        barrierColor: const Color(0x00000000),
        barrierDismissible: true,
        trapFocus: false,
        enterDuration: const Duration(milliseconds: 600),
        exitDuration: Duration(milliseconds: scope.reduce ? 120 : 600),
        overlayBuilder: (context, animation, link) =>
            CompositedTransformFollower(
              link: link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: IgnorePointer(
                ignoring: !_open,
                child: ExcludeSemantics(excluding: !_open, child: panel),
              ),
            ),
        child: InkWell(
          onTap: widget.enabled ? () => _setOpen(!_open) : null,
          child: widget.trigger!,
        ),
      ),
    );
  }
}

@immutable
class _ColorPickerScope {
  const _ColorPickerScope({
    required this.color,
    required this.alpha,
    required this.enabled,
    required this.reduce,
    required this.onColor,
    this.chipKey,
    this.open = false,
  });
  final Color color;
  final bool alpha, enabled, reduce;
  final void Function(Color, {bool commit}) onColor;
  final GlobalKey? chipKey;
  final bool open;
}

class _ColorPickerInherited extends InheritedWidget {
  const _ColorPickerInherited({required this.scope, required super.child});
  final _ColorPickerScope scope;
  static _ColorPickerScope of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_ColorPickerInherited>();
    assert(
      inherited != null,
      'Color picker parts must be inside BeuiColorPicker',
    );
    return inherited!.scope;
  }

  @override
  bool updateShouldNotify(_ColorPickerInherited old) =>
      scope.color != old.scope.color ||
      scope.enabled != old.scope.enabled ||
      scope.open != old.scope.open ||
      scope.reduce != old.scope.reduce;
}

/// Saturation/value 2D control with arrow-key operation.
class BeuiColorPickerArea extends StatefulWidget {
  /// Creates the picker area.
  const BeuiColorPickerArea({
    this.label = 'Saturation and brightness',
    super.key,
  });

  /// Accessible name.
  final String label;

  @override
  State<BeuiColorPickerArea> createState() => _BeuiColorPickerAreaState();
}

class _BeuiColorPickerAreaState extends State<BeuiColorPickerArea> {
  Offset? _loupePosition;
  Color? _loupeColor;
  late Color _gestureColor;

  void _showLoupe(Offset position, Size size, HSVColor hsv, double alpha) {
    final color = HSVColor.fromAHSV(
      alpha,
      hsv.hue,
      (position.dx / size.width).clamp(0.0, 1.0),
      (1 - position.dy / size.height).clamp(0.0, 1.0),
    ).toColor();
    setState(() {
      _loupePosition = position;
      _loupeColor = color;
    });
  }

  void _hideLoupe() {
    if (_loupePosition == null) return;
    setState(() {
      _loupePosition = null;
      _loupeColor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final hsv = HSVColor.fromColor(scope.color);
    final colors = BeuiColors.resolve(context);
    final thumbMotion = motionFor(context, beuiSpringLayout, isMovement: true);
    final thumbSurface = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scope.color,
        border: Border.all(color: colors.background, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.foreground.withValues(alpha: .22),
            blurRadius: 4,
          ),
        ],
      ),
    );
    final thumb = scope.chipKey == null
        ? thumbSurface
        : _PickerReveal(
            open: scope.open,
            delay: const Duration(milliseconds: 220),
            duration: const Duration(milliseconds: 200),
            movement: false,
            child: thumbSurface,
          );
    void update(Offset p, Size size) {
      _gestureColor = HSVColor.fromAHSV(
        scope.color.a,
        hsv.hue,
        (p.dx / size.width).clamp(0.0, 1.0),
        (1 - p.dy / size.height).clamp(0.0, 1.0),
      ).toColor();
      scope.onColor(_gestureColor);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, 160);
        return Semantics(
          label: widget.label,
          value:
              'Saturation ${(hsv.saturation * 100).round()}%, brightness ${(hsv.value * 100).round()}%',
          slider: true,
          child: Focus(
            onKeyEvent: (node, event) {
              if (!scope.enabled || event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              final step = HardwareKeyboard.instance.isShiftPressed ? .1 : .01;
              var saturation = hsv.saturation;
              var brightness = hsv.value;
              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowLeft:
                  saturation -= step;
                case LogicalKeyboardKey.arrowRight:
                  saturation += step;
                case LogicalKeyboardKey.arrowDown:
                  brightness -= step;
                case LogicalKeyboardKey.arrowUp:
                  brightness += step;
                case LogicalKeyboardKey.home:
                  saturation = 0;
                case LogicalKeyboardKey.end:
                  saturation = 1;
                case LogicalKeyboardKey.pageDown:
                  brightness = 0;
                case LogicalKeyboardKey.pageUp:
                  brightness = 1;
                default:
                  return KeyEventResult.ignored;
              }
              scope.onColor(
                HSVColor.fromAHSV(
                  scope.color.a,
                  hsv.hue,
                  saturation.clamp(0.0, 1.0),
                  brightness.clamp(0.0, 1.0),
                ).toColor(),
                commit: true,
              );
              return KeyEventResult.handled;
            },
            child: MouseRegion(
              onHover: (event) =>
                  _showLoupe(event.localPosition, size, hsv, scope.color.a),
              onExit: (_) => _hideLoupe(),
              child: Listener(
                onPointerDown: (event) =>
                    _showLoupe(event.localPosition, size, hsv, scope.color.a),
                onPointerMove: (event) =>
                    _showLoupe(event.localPosition, size, hsv, scope.color.a),
                onPointerUp: (_) => _hideLoupe(),
                onPointerCancel: (_) => _hideLoupe(),
                child: GestureDetector(
                  onPanDown: scope.enabled
                      ? (e) => update(e.localPosition, size)
                      : null,
                  onPanUpdate: scope.enabled
                      ? (e) => update(e.localPosition, size)
                      : null,
                  onPanEnd: scope.enabled
                      ? (_) => scope.onColor(_gestureColor, commit: true)
                      : null,
                  child: _PickerAreaMorph(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: DecoratedBox(
                            key: const ValueKey('color-picker-spectrum'),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: HSVColor.fromAHSV(
                                  1,
                                  hsv.hue,
                                  1,
                                  1,
                                ).toColor(),
                              ),
                              child: Stack(
                                children: [
                                  const Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Color(0x00ffffff),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0x00000000),
                                            Colors.black,
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (thumbMotion is NoMotion)
                                    Positioned(
                                      left:
                                          (hsv.saturation * size.width).clamp(
                                            0,
                                            size.width,
                                          ) -
                                          8,
                                      top:
                                          ((1 - hsv.value) * size.height).clamp(
                                            0,
                                            size.height,
                                          ) -
                                          8,
                                      child: thumb,
                                    )
                                  else
                                    SingleMotionBuilder(
                                      value: hsv.saturation,
                                      motion: thumbMotion,
                                      builder: (context, saturation, child) =>
                                          SingleMotionBuilder(
                                            value: hsv.value,
                                            motion: thumbMotion,
                                            builder: (context, value, child) =>
                                                Positioned(
                                                  left:
                                                      (saturation * size.width)
                                                          .clamp(
                                                            0,
                                                            size.width,
                                                          ) -
                                                      8,
                                                  top:
                                                      ((1 - value) *
                                                              size.height)
                                                          .clamp(
                                                            0,
                                                            size.height,
                                                          ) -
                                                      8,
                                                  child: child!,
                                                ),
                                            child: child!,
                                          ),
                                      child: thumb,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_loupePosition != null)
                          Positioned(
                            key: const ValueKey('color-picker-loupe'),
                            left: _loupePosition!.dx + 10,
                            top: _loupePosition!.dy - 50,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _loupeColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x55000000),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hue slider.
class BeuiColorPickerHue extends StatelessWidget {
  /// Creates a hue slider.
  const BeuiColorPickerHue({this.label = 'Hue', super.key});

  /// Accessible name.
  final String label;
  @override
  Widget build(BuildContext context) =>
      _ColorSlider(label: label, alpha: false);
}

/// Alpha slider, hidden when alpha is disabled on the root.
class BeuiColorPickerAlpha extends StatelessWidget {
  /// Creates an alpha slider.
  const BeuiColorPickerAlpha({this.label = 'Opacity', super.key});

  /// Accessible name.
  final String label;
  @override
  Widget build(BuildContext context) => _ColorSlider(label: label, alpha: true);
}

class _ColorSlider extends StatefulWidget {
  const _ColorSlider({required this.label, required this.alpha});
  final String label;
  final bool alpha;

  @override
  State<_ColorSlider> createState() => _ColorSliderState();
}

class _ColorSliderState extends State<_ColorSlider> {
  late Color _gestureColor;

  @override
  Widget build(BuildContext context) {
    final alpha = widget.alpha;
    final scope = _ColorPickerInherited.of(context);
    if (alpha && !scope.alpha) return const SizedBox.shrink();
    final hsv = HSVColor.fromColor(scope.color);
    final value = alpha ? scope.color.a : hsv.hue / 360;
    final colors = BeuiColors.resolve(context);
    void set(double dx, double width, {bool commit = false}) {
      final t = (dx / width).clamp(0.0, 1.0);
      _gestureColor = alpha
          ? scope.color.withValues(alpha: t)
          : HSVColor.fromAHSV(
              scope.color.a,
              t * 360,
              hsv.saturation,
              hsv.value,
            ).toColor();
      scope.onColor(_gestureColor, commit: commit);
    }

    return LayoutBuilder(
      builder: (context, box) => Semantics(
        label: widget.label,
        slider: true,
        value: '${(value * 100).round()}%',
        child: Focus(
          onKeyEvent: (node, event) {
            if (!scope.enabled || event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            final step = HardwareKeyboard.instance.isShiftPressed ? .1 : .01;
            var next = value;
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowLeft:
              case LogicalKeyboardKey.arrowDown:
                next -= step;
              case LogicalKeyboardKey.arrowRight:
              case LogicalKeyboardKey.arrowUp:
                next += step;
              case LogicalKeyboardKey.home:
                next = 0;
              case LogicalKeyboardKey.end:
                next = 1;
              case LogicalKeyboardKey.pageDown:
                next -= .1;
              case LogicalKeyboardKey.pageUp:
                next += .1;
              default:
                return KeyEventResult.ignored;
            }
            final t = next.clamp(0.0, 1.0);
            scope.onColor(
              alpha
                  ? scope.color.withValues(alpha: t)
                  : HSVColor.fromAHSV(
                      scope.color.a,
                      t * 360,
                      hsv.saturation,
                      hsv.value,
                    ).toColor(),
              commit: true,
            );
            return KeyEventResult.handled;
          },
          child: GestureDetector(
            onPanDown: scope.enabled
                ? (e) => set(e.localPosition.dx, box.maxWidth)
                : null,
            onPanUpdate: scope.enabled
                ? (e) => set(e.localPosition.dx, box.maxWidth)
                : null,
            onPanEnd: scope.enabled
                ? (_) => scope.onColor(_gestureColor, commit: true)
                : null,
            child: SizedBox(
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: alpha
                          ? LinearGradient(
                              colors: [
                                scope.color.withValues(alpha: 0),
                                scope.color,
                              ],
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xffff0000),
                                Color(0xffffff00),
                                Color(0xff00ff00),
                                Color(0xff00ffff),
                                Color(0xff0000ff),
                                Color(0xffff00ff),
                                Color(0xffff0000),
                              ],
                            ),
                    ),
                  ),
                  if (scope.reduce)
                    Align(
                      alignment: Alignment((value * 2 - 1).clamp(-1.0, 1.0), 0),
                      child: _ColorSliderThumb(colors: colors),
                    )
                  else
                    SingleMotionBuilder(
                      value: value,
                      motion: motionFor(
                        context,
                        beuiSpringLayout,
                        isMovement: true,
                      ),
                      builder: (context, position, child) => Align(
                        alignment: Alignment(
                          (position * 2 - 1).clamp(-1.0, 1.0),
                          0,
                        ),
                        child: child,
                      ),
                      child: _ColorSliderThumb(colors: colors),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSliderThumb extends StatelessWidget {
  const _ColorSliderThumb({required this.colors});
  final BeuiColors colors;
  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: colors.background,
      border: Border.all(color: colors.border, width: 2),
      boxShadow: [
        BoxShadow(
          color: colors.foreground.withValues(alpha: .2),
          blurRadius: 3,
        ),
      ],
    ),
  );
}

/// Editable CSS hex text field; commits valid colors on Enter or focus loss.
class BeuiColorPickerHex extends StatefulWidget {
  /// Creates the hex input.
  const BeuiColorPickerHex({super.key});
  @override
  State<BeuiColorPickerHex> createState() => _BeuiColorPickerHexState();
}

class _BeuiColorPickerHexState extends State<BeuiColorPickerHex> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final hex = beuiColorToHex(scope.color).substring(1).toUpperCase();
    if (!_controller.selection.isValid || !_controller.selection.isCollapsed) {
      _controller.text = hex;
    } else if (_controller.text.isEmpty) {
      _controller.text = hex;
    }
    void commit() {
      final color = beuiColorFromHex(_controller.text);
      if (color != null) {
        scope.onColor(color, commit: true);
        _controller.text = beuiColorToHex(color).substring(1).toUpperCase();
      } else {
        _controller.text = hex;
      }
    }

    return TextField(
      controller: _controller,
      enabled: scope.enabled,
      maxLength: 8,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
      ],
      onSubmitted: (_) => commit(),
      onEditingComplete: commit,
      decoration: const InputDecoration(
        prefixText: '#',
        counterText: '',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    );
  }
}

/// RGB or HSL channel editors.
class BeuiColorPickerChannels extends StatelessWidget {
  /// Creates channel inputs.
  const BeuiColorPickerChannels({this.format = BeuiColorFormat.rgb, super.key});

  /// Channel representation.
  final BeuiColorFormat format;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final color = scope.color;
    final hsl = HSLColor.fromColor(color);
    final values = format == BeuiColorFormat.rgb
        ? [
            (color.r * 255.0).round().clamp(0, 255),
            (color.g * 255.0).round().clamp(0, 255),
            (color.b * 255.0).round().clamp(0, 255),
          ]
        : [
            (hsl.hue.round()),
            (hsl.saturation * 100).round(),
            (hsl.lightness * 100).round(),
          ];
    final labels = format == BeuiColorFormat.rgb
        ? ['Red', 'Green', 'Blue']
        : ['Hue', 'Saturation', 'Lightness'];
    if (scope.alpha) {
      values.add((color.a * 100).round());
      labels.add('Opacity');
    }
    return Row(
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < values.length - 1 ? 6 : 0),
              child: TextField(
                enabled: scope.enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: labels[i],
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                controller: TextEditingController(text: '${values[i]}'),
                onSubmitted: (text) {
                  final max = i == 3
                      ? 100
                      : format == BeuiColorFormat.rgb
                      ? 255
                      : (i == 0 ? 360 : 100);
                  final n = (int.tryParse(text) ?? values[i]).clamp(0, max);
                  final next = i == 3
                      ? color.withValues(alpha: n / 100)
                      : format == BeuiColorFormat.rgb
                      ? Color.fromARGB(
                          (color.a * 255.0).round().clamp(0, 255),
                          i == 0 ? n : (color.r * 255.0).round().clamp(0, 255),
                          i == 1 ? n : (color.g * 255.0).round().clamp(0, 255),
                          i == 2 ? n : (color.b * 255.0).round().clamp(0, 255),
                        )
                      : HSLColor.fromAHSL(
                          color.a,
                          i == 0 ? n.toDouble() : hsl.hue,
                          i == 1 ? n / 100 : hsl.saturation,
                          i == 2 ? n / 100 : hsl.lightness,
                        ).toColor();
                  scope.onColor(next, commit: true);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Selects between RGB and HSL channel display.
enum BeuiColorFormat { rgb, hsl }

/// Eye-dropper action. Flutter platforms do not expose a screen sampling API;
/// this control intentionally does nothing and remains available to compose.
class BeuiColorPickerEyeDropper extends StatelessWidget {
  /// Creates the no-op eye-dropper action.
  const BeuiColorPickerEyeDropper({
    this.label = 'Pick a color from the screen',
    super.key,
  });

  /// Accessible label.
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return IconButton(
      tooltip: '$label (unavailable on this platform)',
      onPressed: null,
      icon: Icon(LucideIcons.pipette, color: colors.mutedForeground),
    );
  }
}

/// Preset swatch row.
class BeuiColorPickerPresets extends StatelessWidget {
  /// Creates preset swatches.
  const BeuiColorPickerPresets({required this.items, super.key});

  /// Preset colors.
  final List<BeuiColorPickerPresetItem> items;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [for (final item in items) BeuiColorPickerPreset(item: item)],
  );
}

/// Applies one preset color.
class BeuiColorPickerPreset extends StatelessWidget {
  /// Creates a preset swatch.
  const BeuiColorPickerPreset({required this.item, super.key});

  /// Preset configuration.
  final BeuiColorPickerPresetItem item;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final color = beuiColorFromHex(item.value);
    final selected =
        color != null && color.toARGB32() == scope.color.toARGB32();
    return Semantics(
      button: true,
      label: item.label ?? item.value,
      selected: selected,
      child: GestureDetector(
        onTap: scope.enabled && color != null
            ? () => scope.onColor(color, commit: true)
            : null,
        child: AnimatedContainer(
          duration: Duration(milliseconds: scope.reduce ? 0 : 180),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? BeuiColors.resolve(context).mutedForeground,
            border: Border.all(
              color: selected
                  ? BeuiColors.resolve(context).foreground
                  : BeuiColors.resolve(context).border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: BeuiColors.resolve(
                        context,
                      ).ring.withValues(alpha: .25),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Default trigger swatch that toggles the anchored dialog.
class BeuiColorPickerTrigger extends StatelessWidget {
  /// Creates a trigger. Pass [child] to replace the hexadecimal label.
  const BeuiColorPickerTrigger({this.child, super.key});

  /// Optional replacement label.
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final colors = BeuiColors.resolve(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 14),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: scope.chipKey,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: scope.open && !scope.reduce
                  ? Colors.transparent
                  : scope.color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
          ),
          const SizedBox(width: 10),
          child ??
              Text(
                beuiColorToHex(scope.color).toUpperCase(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
        ],
      ),
    );
  }
}

/// Container marker for composing the picker body. In Flutter, provide its
/// child as [BeuiColorPicker.child].
class BeuiColorPickerContent extends StatelessWidget {
  /// Creates a content group.
  const BeuiColorPickerContent({required this.child, super.key});

  /// Content widgets.
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final body = child;
    var row = 0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: scope.chipKey == null || body is! Column
          ? body
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: body.crossAxisAlignment,
              children: [
                for (final item in body.children)
                  if (item is BeuiColorPickerArea || item is SizedBox)
                    item
                  else
                    _PickerReveal(
                      open: scope.open,
                      delay: Duration(milliseconds: 100 + 35 * ++row),
                      child: item,
                    ),
              ],
            ),
    );
  }
}

class _PickerReveal extends StatefulWidget {
  const _PickerReveal({
    required this.open,
    required this.delay,
    required this.child,
    this.movement = true,
    this.invert = false,
    this.duration = const Duration(milliseconds: 160),
  });
  final bool open;
  final Duration delay;
  final Widget child;
  final bool movement;
  final bool invert;
  final Duration duration;
  @override
  State<_PickerReveal> createState() => _PickerRevealState();
}

class _PickerRevealState extends State<_PickerReveal> {
  Timer? _timer;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _retarget();
  }

  @override
  void didUpdateWidget(_PickerReveal old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) _retarget();
  }

  void _retarget() {
    _timer?.cancel();
    if (!widget.open) {
      _visible = false;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: _visible ? 1 : 0,
    from: 0,
    motion: CurvedMotion(
      widget.open ? widget.duration : const Duration(milliseconds: 100),
      beuiEaseOut,
    ),
    child: widget.child,
    builder: (context, p, child) => Opacity(
      opacity: (widget.invert ? 1 - p : p).clamp(0, 1),
      child: widget.movement && !MediaQuery.disableAnimationsOf(context)
          ? Transform.translate(offset: Offset(0, -6 * (1 - p)), child: child)
          : child,
    ),
  );
}

class _PickerAreaMorph extends StatefulWidget {
  const _PickerAreaMorph({required this.child});
  final Widget child;
  @override
  State<_PickerAreaMorph> createState() => _PickerAreaMorphState();
}

class _PickerAreaMorphState extends State<_PickerAreaMorph> {
  final _areaKey = GlobalKey();
  Rect? _chip;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    if (scope.chipKey == null || scope.reduce) return widget.child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final area = _areaKey.currentContext?.findRenderObject() as RenderBox?;
      final chip =
          scope.chipKey?.currentContext?.findRenderObject() as RenderBox?;
      if (area != null && chip != null && area.hasSize && chip.hasSize) {
        final rect =
            area.globalToLocal(chip.localToGlobal(Offset.zero)) & chip.size;
        if (_chip != rect) setState(() => _chip = rect);
      }
    });
    return SizedBox(
      key: _areaKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final target = Offset.zero & Size(constraints.maxWidth, 160);
          if (_chip == null) return Opacity(opacity: 0, child: widget.child);
          return SingleMotionBuilder(
            value: scope.open ? 1 : 0,
            from: 0,
            motion: SpringMotion(
              SpringDescription.withDurationAndBounce(
                duration: const Duration(milliseconds: 500),
                bounce: .2,
              ),
            ),
            child: widget.child,
            builder: (context, p, child) {
              final rect = Rect.lerp(_chip ?? target, target, p)!;
              return Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.identity()
                  ..translateByDouble(rect.left, rect.top, 0, 1)
                  ..scaleByDouble(
                    rect.width / target.width,
                    rect.height / target.height,
                    1,
                    1,
                  ),
                child: Stack(
                  children: [
                    child!,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _PickerReveal(
                          open: scope.open,
                          invert: true,
                          delay: const Duration(milliseconds: 60),
                          duration: const Duration(milliseconds: 400),
                          movement: false,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scope.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Live color swatch displaying the current selection.
class BeuiColorPickerSwatch extends StatelessWidget {
  /// Creates a color swatch.
  const BeuiColorPickerSwatch({this.size = 28, super.key});

  /// Swatch edge length.
  final double size;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scope.color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: BeuiColors.resolve(context).border),
      ),
    );
  }
}
