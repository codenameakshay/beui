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
    );
    if (widget.trigger == null) {
      return _ColorPickerInherited(scope: scope, child: widget.child);
    }
    return _ColorPickerInherited(
      scope: scope,
      child: BeuiOverlay(
        open: _open,
        onDismiss: () => _setOpen(false),
        barrier: true,
        barrierColor: const Color(0x00000000),
        barrierDismissible: true,
        trapFocus: false,
        enterDuration: Duration(milliseconds: scope.reduce ? 140 : 250),
        exitDuration: Duration(milliseconds: scope.reduce ? 120 : 180),
        overlayBuilder: (context, animation, link) =>
            CompositedTransformFollower(
              link: link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: FadeTransition(
                opacity: animation,
                child: Material(
                  color: colors.background,
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: widget.label,
                    child: SizedBox(width: 288, child: widget.child),
                  ),
                ),
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
  });
  final Color color;
  final bool alpha, enabled, reduce;
  final void Function(Color, {bool commit}) onColor;
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
      scope.color != old.scope.color || scope.enabled != old.scope.enabled;
}

/// Saturation/value 2D control with arrow-key operation.
class BeuiColorPickerArea extends StatelessWidget {
  /// Creates the picker area.
  const BeuiColorPickerArea({
    this.label = 'Saturation and brightness',
    super.key,
  });

  /// Accessible name.
  final String label;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    final hsv = HSVColor.fromColor(scope.color);
    final colors = BeuiColors.resolve(context);
    void update(Offset p, Size size, {bool commit = false}) => scope.onColor(
      HSVColor.fromAHSV(
        scope.color.a,
        hsv.hue,
        (p.dx / size.width).clamp(0.0, 1.0),
        (1 - p.dy / size.height).clamp(0.0, 1.0),
      ).toColor(),
      commit: commit,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, 144);
        return Semantics(
          label: label,
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
            child: GestureDetector(
              onPanDown: scope.enabled
                  ? (e) => update(e.localPosition, size)
                  : null,
              onPanUpdate: scope.enabled
                  ? (e) => update(e.localPosition, size)
                  : null,
              onPanEnd: scope.enabled
                  ? (_) => scope.onColor(scope.color, commit: true)
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                          Colors.black,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Color(0x00ffffff)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
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
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scope.color,
                              border: Border.all(
                                color: colors.background,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.foreground.withValues(
                                    alpha: .22,
                                  ),
                                  blurRadius: 4,
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

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({required this.label, required this.alpha});
  final String label;
  final bool alpha;
  @override
  Widget build(BuildContext context) {
    final scope = _ColorPickerInherited.of(context);
    if (alpha && !scope.alpha) return const SizedBox.shrink();
    final hsv = HSVColor.fromColor(scope.color);
    final value = alpha ? scope.color.a : hsv.hue / 360;
    final colors = BeuiColors.resolve(context);
    void set(double dx, double width, {bool commit = false}) {
      final t = (dx / width).clamp(0.0, 1.0);
      final next = alpha
          ? scope.color.withValues(alpha: t)
          : HSVColor.fromAHSV(
              scope.color.a,
              t * 360,
              hsv.saturation,
              hsv.value,
            ).toColor();
      scope.onColor(next, commit: commit);
    }

    return LayoutBuilder(
      builder: (context, box) => Semantics(
        label: label,
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
                ? (_) => scope.onColor(scope.color, commit: true)
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: scope.color,
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
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(12), child: child);
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
