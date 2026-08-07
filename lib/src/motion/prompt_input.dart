import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'button/base.dart';
import 'select.dart';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// One model option in a [BeuiPromptInput] picker.
///
/// Mirrors the source's `PromptModel` (`value` / `label` / optional `icon`).
@immutable
class BeuiPromptModel {
  /// Creates a model option.
  const BeuiPromptModel({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  /// Stable value committed via [BeuiPromptInput.onModelChange].
  final String value;

  /// Visible label in the trigger and list.
  final String label;

  /// Optional leading glyph (framework-native widget).
  final Widget? icon;

  /// Whether the option can be chosen.
  final bool enabled;
}

/// One entry in the [BeuiPromptInput] actions popover (attach image, skill…).
///
/// Mirrors the source's `PromptAction`.
@immutable
class BeuiPromptAction {
  /// Creates an action entry.
  const BeuiPromptAction({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.enabled = true,
  });

  /// Stable value committed via [BeuiPromptInput.onAction].
  final String value;

  /// Primary label.
  final String label;

  /// Optional secondary description under [label].
  final String? description;

  /// Optional leading glyph.
  final Widget? icon;

  /// Whether the action can be chosen.
  final bool enabled;
}

// ---------------------------------------------------------------------------
// Constants — layout mirrors the source's Tailwind tokens
// ---------------------------------------------------------------------------

/// Source `leading-6` line height used by the auto-grow min/max clamp.
const double _lineHeight = 24;

/// Source `text-sm` for the composer.
const double _fontSize = 14;

/// Source form `rounded-2xl` = 16.
const double _shellRadius = 16;

/// Source footer `min-h-8` / icon buttons `size-8`.
const double _footerMinH = 32;

/// Select trigger chevron rotate — source `CHEVRON_TRANSITION =
/// { duration: 0.4, bounce: 0.3 }`. ω = 2π/0.4 ≈ 15.71, ζ = 0.7 →
/// stiffness ≈ 247, damping ≈ 22 (matches `select.dart`'s private token).
const _promptChevronSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 247, damping: 22),
);

// ---------------------------------------------------------------------------
// BeuiPromptInput
// ---------------------------------------------------------------------------

/// An auto-growing agent composer with prompt actions, model selection,
/// keyboard submission, and animated send/stop states — the Flutter port of
/// beUI's `prompt-input`.
///
/// **Composer**: a multi-line field that grows between [minRows] and [maxRows]
/// (source defaults 2…8). Enter submits; Shift+Enter inserts a newline.
///
/// **Actions**: a ghost + button opens an overlay menu of [actions]; the plus
/// rotates 45° on open via [beuiSpringSwap]. Choosing an action calls
/// [onAction] and closes the menu.
///
/// **Model**: when [models] is non-empty a compact [BeuiSelect]-style trigger
/// shows the current model (optional icon + label). Selection is controlled
/// (`model` + [onModelChange]) or uncontrolled ([defaultModel]).
///
/// **Send / stop**: the trailing primary icon button shows ↑ when idle and a
/// filled square while [loading]. The swap springs on [beuiSpringSwap]
/// (opacity + y + scale). Idle submit requires a non-empty trim and is disabled
/// while [enabled] is false or [loading]; stop is enabled only when [onStop]
/// is provided.
///
/// **Controlled + uncontrolled** for both text (`value` / [defaultValue] /
/// [onValueChange]) and model. Uncontrolled submit clears the field after
/// [onSubmit], matching the source.
///
/// Reduced motion drops the plus rotation, the send/stop movement, and
/// snap-swaps icons (opacity-only).
class BeuiPromptInput extends StatefulWidget {
  /// Creates a prompt input.
  const BeuiPromptInput({
    this.value,
    this.defaultValue = '',
    this.onValueChange,
    this.models = const [],
    this.model,
    this.defaultModel,
    this.onModelChange,
    this.actions = const [],
    this.onAction,
    this.onSubmit,
    this.loading = false,
    this.onStop,
    this.minRows = 2,
    this.maxRows = 8,
    this.leadingAction,
    this.enabled = true,
    this.placeholder = 'Ask the agent to do something…',
    this.semanticLabel = 'Prompt',
    this.focusNode,
    this.controller,
    this.autofocus = false,
    this.surfaceColor,
    this.bordered = true,
    super.key,
  }) : assert(minRows >= 1),
       assert(maxRows >= minRows),
       assert(
         value == null || controller == null,
         'Provide either value (controlled) or controller, not both.',
       );

  /// Controlled text. When null the field owns its state (seeded from
  /// [defaultValue] or [controller]).
  final String? value;

  /// Uncontrolled initial text.
  final String defaultValue;

  /// Called on every text edit.
  final ValueChanged<String>? onValueChange;

  /// Models offered by the picker. Empty hides the picker.
  final List<BeuiPromptModel> models;

  /// Controlled selected model value.
  final String? model;

  /// Uncontrolled initial model (falls back to `models.first.value`).
  final String? defaultModel;

  /// Called when the selected model changes.
  final ValueChanged<String>? onModelChange;

  /// Actions offered by the + popover. Empty hides the + button.
  final List<BeuiPromptAction> actions;

  /// Called with an action's [BeuiPromptAction.value] when chosen.
  final ValueChanged<String>? onAction;

  /// Called with the trimmed prompt and optional current model on submit.
  final void Function(String value, String? model)? onSubmit;

  /// When true the send button becomes a stop control.
  final bool loading;

  /// Invoked when the stop button is pressed while [loading].
  final VoidCallback? onStop;

  /// Minimum textarea rows (source default 2).
  final int minRows;

  /// Maximum textarea rows before scrolling (source default 8).
  final int maxRows;

  /// Optional widget inserted after the actions button (source `leadingAction`).
  final Widget? leadingAction;

  /// Whether the composer accepts input.
  final bool enabled;

  /// Placeholder when empty.
  final String placeholder;

  /// Accessibility label for the text field (source `aria-label`).
  final String semanticLabel;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Optional external controller (uncontrolled text path).
  final TextEditingController? controller;

  /// Autofocus the field on mount.
  final bool autofocus;

  /// Overrides the composer fill. Defaults to `BeuiColors.background` (source
  /// `bg-background`). Embedded composers use the source's `bg-muted`.
  final Color? surfaceColor;

  /// Draws the resting + focus-within border (source `border border-border/80
  /// focus-within:border-foreground/25`). Pass false for the source's
  /// `border-0 focus-within:border-transparent` embedded variant.
  final bool bordered;

  @override
  State<BeuiPromptInput> createState() => _BeuiPromptInputState();
}

class _BeuiPromptInputState extends State<BeuiPromptInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocus = false;

  String? _internalModel;
  bool _actionsOpen = false;
  bool _modelOpen = false;
  bool _focused = false;

  String get _text => widget.value ?? _controller.text;

  String? get _modelValue {
    if (widget.model != null) return widget.model;
    if (_internalModel != null) return _internalModel;
    if (widget.models.isEmpty) return null;
    return widget.defaultModel ?? widget.models.first.value;
  }

  BeuiPromptModel? get _currentModel {
    final v = _modelValue;
    if (v == null) return null;
    for (final m in widget.models) {
      if (m.value == v) return m;
    }
    return null;
  }

  bool get _canSubmit =>
      _text.trim().isNotEmpty && widget.enabled && !widget.loading;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _ownsController = true;
      _controller = TextEditingController(
        text: widget.value ?? widget.defaultValue,
      );
    }
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _ownsFocus = true;
      _focusNode = FocusNode(debugLabel: 'BeuiPromptInput');
    }
    _focusNode
      ..addListener(_onFocusChange)
      ..onKeyEvent = _onFieldKey;
    _controller.addListener(_onTextTick);
    _internalModel =
        widget.defaultModel ??
        (widget.models.isNotEmpty ? widget.models.first.value : null);
  }

  @override
  void didUpdateWidget(BeuiPromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextTick);
      if (_ownsController) _controller.dispose();
      if (widget.controller != null) {
        _ownsController = false;
        _controller = widget.controller!;
      } else {
        _ownsController = true;
        _controller = TextEditingController(
          text: widget.value ?? widget.defaultValue,
        );
      }
      _controller.addListener(_onTextTick);
    } else if (widget.value != null &&
        widget.value != oldWidget.value &&
        widget.value != _controller.text) {
      // Controlled external update.
      _controller.value = TextEditingValue(
        text: widget.value!,
        selection: TextSelection.collapsed(offset: widget.value!.length),
      );
    }

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode
        ..removeListener(_onFocusChange)
        ..onKeyEvent = null;
      if (_ownsFocus) _focusNode.dispose();
      if (widget.focusNode != null) {
        _ownsFocus = false;
        _focusNode = widget.focusNode!;
      } else {
        _ownsFocus = true;
        _focusNode = FocusNode(debugLabel: 'BeuiPromptInput');
      }
      _focusNode
        ..addListener(_onFocusChange)
        ..onKeyEvent = _onFieldKey;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextTick);
    _focusNode
      ..removeListener(_onFocusChange)
      ..onKeyEvent = null;
    if (_ownsController) _controller.dispose();
    if (_ownsFocus) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final next = _focusNode.hasFocus;
    if (next != _focused) setState(() => _focused = next);
  }

  void _onTextTick() {
    // Rebuild so canSubmit / border state stay in sync when uncontrolled.
    if (widget.value == null) setState(() {});
  }

  void _setModel(String next) {
    if (widget.model == null) setState(() => _internalModel = next);
    widget.onModelChange?.call(next);
  }

  void _submit() {
    final prompt = _text.trim();
    if (prompt.isEmpty || !widget.enabled || widget.loading) return;
    widget.onSubmit?.call(prompt, _modelValue);
    // Uncontrolled: clear after submit (source behaviour).
    if (widget.value == null) {
      _controller.clear();
      widget.onValueChange?.call('');
    }
    _focusNode.requestFocus();
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    // Shift+Enter → newline (let the field handle it).
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    // Skip while an IME composition is active when possible.
    final composing = _controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    _submit();
    return KeyEventResult.handled;
  }

  /// Composer text style — source `text-sm leading-6` with default tracking.
  ///
  /// [TextLeadingDistribution.even] is CSS's line-box model: the extra leading
  /// splits evenly above and below the glyphs.
  TextStyle _composerStyle(BeuiColors colors) => TextStyle(
    fontSize: _fontSize,
    height: _lineHeight / _fontSize,
    leadingDistribution: TextLeadingDistribution.even,
    // An unset letterSpacing inherits the host theme's body style (0.25–0.5
    // under Material) and widens the line by ~0.5px per character.
    letterSpacing: 0,
    color: colors.foreground,
  );

  static const TextStyle _hiddenComposerStyle = TextStyle(
    fontSize: _fontSize,
    height: _lineHeight / _fontSize,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
  );

  static const StrutStyle _composerStrut = StrutStyle(
    fontSize: _fontSize,
    height: _lineHeight / _fontSize,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The source's `resizeTextarea`: measure the wrapped text in a mirror of the
  /// field's content box, then clamp the row count to [minRows]…[maxRows].
  double _composerHeight(BuildContext context, double maxWidth) {
    // The field's content box is inset by the source's `px-2`.
    final textWidth = maxWidth.isFinite ? maxWidth - 16 : double.infinity;
    var rows = widget.minRows;
    if (textWidth.isFinite && textWidth > 0) {
      final painter = TextPainter(
        // The source appends a zero-width space so a trailing newline counts.
        text: TextSpan(
          text: '${_controller.text}​',
          style: _hiddenComposerStyle,
        ),
        strutStyle: _composerStrut,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: textWidth);
      rows = painter.computeLineMetrics().length;
      painter.dispose();
    }
    return rows.clamp(widget.minRows, widget.maxRows) * _lineHeight;
  }

  /// Half of `leading-6`'s extra leading, in logical pixels.
  ///
  /// CSS centres a line's leading around the glyphs, so the first baseline sits
  /// half a leading below the content box. Flutter's `EditableText` leaves the
  /// first line's ascent at the font's natural value, so the composer renders
  /// ~4px high against the site. Derived from the resolved font's own metrics
  /// (never a hardcoded offset) and folded into the field's top padding.
  double _firstLineLeading(BuildContext context) {
    final painter = TextPainter(
      // Height unset → the painter reports the font's natural line height.
      text: const TextSpan(
        text: 'x',
        style: TextStyle(fontSize: _fontSize),
      ),
      textDirection: Directionality.of(context),
    )..layout();
    final natural = painter.preferredLineHeight;
    painter.dispose();
    final leading = (_lineHeight - natural) / 2;
    return leading > 0 ? leading : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final swapMotion = motionFor(context, beuiSpringSwap, isMovement: true);

    final borderColor = _focused
        ? colors.foreground.withValues(alpha: 0.25)
        : colors.border.withValues(alpha: colors.border.a * 0.8);

    return Opacity(
      opacity: widget.enabled ? 1 : 0.6,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        decoration: BoxDecoration(
          color: widget.surfaceColor ?? colors.background,
          // `border-0` in the source removes the box entirely — a transparent
          // 1px border would still inset the child and make the shell 2px
          // taller than the site's.
          border: widget.bordered ? Border.all(color: borderColor) : null,
          borderRadius: BorderRadius.circular(_shellRadius),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: widget.semanticLabel,
              textField: true,
              child: DefaultTextHeightBehavior(
                // CSS puts half of `leading-6`'s extra leading above the first
                // line; Flutter's paragraph default leaves the first ascent at
                // the font's natural value, parking the text ~4px high.
                textHeightBehavior: const TextHeightBehavior(
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    // The source sizes the textarea's *border box* to
                    // `clamp(scrollHeight, minRows*24, maxRows*24)` off an
                    // invisible mirror div, so the `pt-1.5` lives inside that
                    // height. Flutter's minLines/maxLines would add the padding
                    // on top and make the shell 6px taller than the site's.
                    height: _composerHeight(context, constraints.maxWidth),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: _composerStyle(colors),
                      strutStyle: _composerStrut,
                      cursorColor: colors.foreground,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        // source `px-2 pt-1.5`, plus the half-leading CSS puts
                        // above the first line and Flutter's field does not.
                        contentPadding: EdgeInsets.fromLTRB(
                          8,
                          6 + _firstLineLeading(context),
                          8,
                          0,
                        ),
                        hintText: widget.placeholder,
                        hintStyle: _composerStyle(colors).copyWith(
                          color: colors.mutedForeground.withValues(alpha: 0.55),
                        ),
                      ),
                      onChanged: (v) {
                        widget.onValueChange?.call(v);
                        if (widget.value == null) setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _Footer(
              colors: colors,
              reduce: reduce,
              swapMotion: swapMotion,
              enabled: widget.enabled,
              loading: widget.loading,
              canSubmit: _canSubmit,
              actions: widget.actions,
              actionsOpen: _actionsOpen,
              onActionsOpenChange: (v) => setState(() => _actionsOpen = v),
              onAction: (v) {
                widget.onAction?.call(v);
                setState(() => _actionsOpen = false);
              },
              leadingAction: widget.leadingAction,
              models: widget.models,
              currentModel: _currentModel,
              modelValue: _modelValue,
              modelOpen: _modelOpen,
              onModelOpenChange: (v) => setState(() => _modelOpen = v),
              onModelChange: (v) {
                _setModel(v);
                setState(() => _modelOpen = false);
              },
              onSubmit: _submit,
              onStop: widget.onStop,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer — actions + model + send/stop
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer({
    required this.colors,
    required this.reduce,
    required this.swapMotion,
    required this.enabled,
    required this.loading,
    required this.canSubmit,
    required this.actions,
    required this.actionsOpen,
    required this.onActionsOpenChange,
    required this.onAction,
    required this.leadingAction,
    required this.models,
    required this.currentModel,
    required this.modelValue,
    required this.modelOpen,
    required this.onModelOpenChange,
    required this.onModelChange,
    required this.onSubmit,
    required this.onStop,
  });

  final BeuiColors colors;
  final bool reduce;
  final Motion swapMotion;
  final bool enabled;
  final bool loading;
  final bool canSubmit;
  final List<BeuiPromptAction> actions;
  final bool actionsOpen;
  final ValueChanged<bool> onActionsOpenChange;
  final ValueChanged<String> onAction;
  final Widget? leadingAction;
  final List<BeuiPromptModel> models;
  final BeuiPromptModel? currentModel;
  final String? modelValue;
  final bool modelOpen;
  final ValueChanged<bool> onModelOpenChange;
  final ValueChanged<String> onModelChange;
  final VoidCallback onSubmit;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _footerMinH,
      child: Row(
        // source: `mt-1 flex min-h-8 items-center gap-1`
        spacing: 4,
        children: [
          if (actions.isNotEmpty)
            _ActionsButton(
              colors: colors,
              reduce: reduce,
              swapMotion: swapMotion,
              enabled: enabled && !loading,
              open: actionsOpen,
              onOpenChange: onActionsOpenChange,
              actions: actions,
              onAction: onAction,
            ),
          ?leadingAction,
          if (models.isNotEmpty) ...[
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ModelPicker(
                  colors: colors,
                  enabled: enabled && !loading,
                  models: models,
                  current: currentModel,
                  value: modelValue,
                  open: modelOpen,
                  onOpenChange: onModelOpenChange,
                  onChanged: onModelChange,
                ),
              ),
            ),
          ] else
            const Spacer(),
          _SendStopButton(
            colors: colors,
            reduce: reduce,
            swapMotion: swapMotion,
            loading: loading,
            canSubmit: canSubmit,
            onSubmit: onSubmit,
            onStop: onStop,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions (+ overlay menu)
//
// Source uses MorphPopover; the Flutter MorphPopover lays out in-tree and
// cannot escape a 32px footer Row's max-height, so the panel is measured /
// clipped wrong. Actions open through [BeuiOverlay] (root overlay) with a
// spring panel entrance that matches SPRING_PANEL scale+opacity feel.
// ---------------------------------------------------------------------------

class _ActionsButton extends StatelessWidget {
  const _ActionsButton({
    required this.colors,
    required this.reduce,
    required this.swapMotion,
    required this.enabled,
    required this.open,
    required this.onOpenChange,
    required this.actions,
    required this.onAction,
  });

  final BeuiColors colors;
  final bool reduce;
  final Motion swapMotion;
  final bool enabled;
  final bool open;
  final ValueChanged<bool> onOpenChange;
  final List<BeuiPromptAction> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final plus = SingleMotionBuilder(
      value: open ? 45.0 : 0.0,
      motion: reduce ? const NoMotion() : swapMotion,
      builder: (context, deg, child) {
        // Reduced motion snaps (bypass NoMotion freeze-at-source).
        final angle = (swapMotion is NoMotion || reduce)
            ? (open ? 45.0 : 0.0)
            : deg;
        return Transform.rotate(
          angle: angle * 3.141592653589793 / 180,
          child: child,
        );
      },
      child: Icon(LucideIcons.plus, size: 16, color: colors.mutedForeground),
    );

    return BeuiOverlay(
      open: open,
      barrier: true,
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      trapFocus: false,
      onDismiss: () => onOpenChange(false),
      enterDuration: Duration(milliseconds: reduce ? 120 : 280),
      exitDuration: Duration(milliseconds: reduce ? 100 : 160),
      overlayBuilder: (context, animation, link) => _AnchoredMenu(
        link: link,
        animation: animation,
        reduce: reduce,
        colors: colors,
        width: 224,
        child: _ActionsMenu(
          colors: colors,
          actions: actions,
          onAction: onAction,
        ),
      ),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Add to prompt',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onOpenChange(!open) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: SizedBox(width: 32, height: 32, child: Center(child: plus)),
          ),
        ),
      ),
    );
  }
}

/// Floating menu anchored above the trigger (side=top, align=start, offset 8).
class _AnchoredMenu extends StatelessWidget {
  const _AnchoredMenu({
    required this.link,
    required this.animation,
    required this.reduce,
    required this.colors,
    required this.width,
    required this.child,
  });

  final LayerLink link;
  final Animation<double> animation;
  final bool reduce;
  final BeuiColors colors;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topLeft,
      followerAnchor: Alignment.bottomLeft,
      offset: const Offset(0, -8),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value.clamp(0.0, 1.0);
          final opacity = t;
          final scale = reduce ? 1.0 : 0.96 + 0.04 * t;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SizedBox(width: width, child: child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.colors,
    required this.actions,
    required this.onAction,
  });

  final BeuiColors colors;
  final List<BeuiPromptAction> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6), // p-1.5
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in actions)
            _ActionRow(
              colors: colors,
              action: action,
              onTap: action.enabled ? () => onAction(action.value) : null,
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.colors,
    required this.action,
    required this.onTap,
  });

  final BeuiColors colors;
  final BeuiPromptAction action;
  final VoidCallback? onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.ease,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: _hovered && enabled ? widget.colors.muted : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.action.icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(
                            size: 16,
                            color: widget.colors.mutedForeground,
                          ),
                          child: widget.action.icon!,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.action.label,
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 0, // tracking-normal
                          color: widget.colors.foreground,
                        ),
                      ),
                      if (widget.action.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.action.description!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            letterSpacing: 0, // tracking-normal
                            color: widget.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model picker — compact trigger + overlay list (icons + labels)
// ---------------------------------------------------------------------------

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.colors,
    required this.enabled,
    required this.models,
    required this.current,
    required this.value,
    required this.open,
    required this.onOpenChange,
    required this.onChanged,
  });

  final BeuiColors colors;
  final bool enabled;
  final List<BeuiPromptModel> models;
  final BeuiPromptModel? current;
  final String? value;
  final bool open;
  final ValueChanged<bool> onOpenChange;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Icon-less models reuse the gooey [BeuiSelect]. Icon models need a custom
    // overlay so glyphs render (BeuiSelectOption is label-only).
    final hasIcons = models.any((m) => m.icon != null);
    if (!hasIcons) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 208),
        child: BeuiSelect(
          options: [
            for (final m in models)
              BeuiSelectOption(
                value: m.value,
                label: m.label,
                enabled: m.enabled,
              ),
          ],
          value: value,
          onChanged: onChanged,
          enabled: enabled,
          placeholder: 'Choose model',
        ),
      );
    }

    final reduce = MediaQuery.disableAnimationsOf(context);
    final label = current?.label ?? 'Choose model';
    final trigger = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: open ? colors.muted : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current?.icon != null) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: IconTheme(
                  data: IconThemeData(size: 14, color: colors.mutedForeground),
                  child: current!.icon!,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0, // tracking-normal
                  color: colors.mutedForeground,
                ),
              ),
            ),
            // Source `SelectTrigger` always appends a `h-4 w-4` ChevronDown in
            // `text-muted-foreground`, `gap-2` after the value, rotating 180°
            // on open.
            const SizedBox(width: 8),
            SingleMotionBuilder(
              value: open ? 1.0 : 0.0,
              motion: motionFor(
                context,
                _promptChevronSpring,
                isMovement: true,
              ),
              builder: (context, p, child) =>
                  Transform.rotate(angle: p * math.pi, child: child),
              child: Icon(
                LucideIcons.chevron_down,
                size: 16,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );

    return BeuiOverlay(
      open: open,
      barrier: true,
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      trapFocus: false,
      onDismiss: () => onOpenChange(false),
      enterDuration: Duration(milliseconds: reduce ? 120 : 280),
      exitDuration: Duration(milliseconds: reduce ? 100 : 160),
      overlayBuilder: (context, animation, link) => _AnchoredMenu(
        link: link,
        animation: animation,
        reduce: reduce,
        colors: colors,
        width: 208,
        child: _ModelMenu(
          colors: colors,
          models: models,
          value: value,
          onChanged: onChanged,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onOpenChange(!open) : null,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: trigger),
      ),
    );
  }
}

class _ModelMenu extends StatelessWidget {
  const _ModelMenu({
    required this.colors,
    required this.models,
    required this.value,
    required this.onChanged,
  });

  final BeuiColors colors;
  final List<BeuiPromptModel> models;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in models)
            _ModelRow(
              colors: colors,
              model: m,
              selected: m.value == value,
              onTap: m.enabled ? () => onChanged(m.value) : null,
            ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatefulWidget {
  const _ModelRow({
    required this.colors,
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final BeuiColors colors;
  final BeuiPromptModel model;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ModelRow> createState() => _ModelRowState();
}

class _ModelRowState extends State<_ModelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlight = widget.selected || (_hovered && enabled);
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: highlight ? widget.colors.muted : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Row(
              children: [
                if (widget.model.icon != null) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(
                          size: 16,
                          color: widget.colors.mutedForeground,
                        ),
                        child: widget.model.icon!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.model.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 0, // tracking-normal
                      color: widget.selected
                          ? widget.colors.foreground
                          : widget.colors.mutedForeground,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(
                    LucideIcons.check,
                    size: 14,
                    color: widget.colors.foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send / stop
// ---------------------------------------------------------------------------

class _SendStopButton extends StatelessWidget {
  const _SendStopButton({
    required this.colors,
    required this.reduce,
    required this.swapMotion,
    required this.loading,
    required this.canSubmit,
    required this.onSubmit,
    required this.onStop,
  });

  final BeuiColors colors;
  final bool reduce;
  final Motion swapMotion;
  final bool loading;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final enabled = loading ? onStop != null : canSubmit;
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? 'Stop generating' : 'Send prompt',
      child: BeuiButton(
        variant: BeuiButtonVariant.primary,
        size: BeuiButtonSize.icon,
        onPressed: !enabled
            ? null
            : loading
            ? onStop
            : onSubmit,
        child: _SwapIcon(
          loading: loading,
          reduce: reduce,
          swapMotion: swapMotion,
          color: colors.primaryForeground,
        ),
      ),
    );
  }
}

/// AnimatePresence-style send ↔ stop icon swap on [beuiSpringSwap].
///
/// Source: opacity 0→1, y 3→0, scale 0.8→1 enter; exit y −3 / scale 0.8.
/// Reduced motion: opacity only (snap position/scale).
class _SwapIcon extends StatelessWidget {
  const _SwapIcon({
    required this.loading,
    required this.reduce,
    required this.swapMotion,
    required this.color,
  });

  final bool loading;
  final bool reduce;
  final Motion swapMotion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Keyed AnimatedSwitcher-like: drive progress 0→1 on each flip via a
    // SingleMotionBuilder that restarts when [loading] changes. With
    // NoMotion under reduce we snap to the settled state.
    final key = loading ? 'stop' : 'send';
    final icon = loading
        ? SizedBox.square(
            dimension: 12,
            child: CustomPaint(painter: _StopSquarePainter(color: color)),
          )
        : Icon(LucideIcons.arrow_up, size: 16, color: color);

    if (reduce || swapMotion is NoMotion) {
      return KeyedSubtree(key: ValueKey(key), child: icon);
    }

    return _SpringSwapIcon(key: ValueKey(key), motion: swapMotion, child: icon);
  }
}

/// The stop mark — source `<Square className="size-3 fill-current" />`.
///
/// An [Icon] can only draw the icon font's stroked outline, which reads as a
/// hollow box against the white disc. Lucide authors `square` as an 18×18 rect
/// with `rx=2` in a 24-unit box, stroked 2 units wide; `fill-current` fills and
/// strokes the same path (spec §3: paint it, never bundle an asset).
class _StopSquarePainter extends CustomPainter {
  const _StopSquarePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 3 * s, 18 * s, 18 * s),
      Radius.circular(2 * s),
    );
    final paint = Paint()..color = color;
    canvas
      ..drawRRect(rect, paint)
      ..drawRRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_StopSquarePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SpringSwapIcon extends StatefulWidget {
  const _SpringSwapIcon({required this.motion, required this.child, super.key});

  final Motion motion;
  final Widget child;

  @override
  State<_SpringSwapIcon> createState() => _SpringSwapIconState();
}

class _SpringSwapIconState extends State<_SpringSwapIcon> {
  // 0 = enter start, 1 = settled. Mounted each key change so enter always runs.
  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: 1.0,
      from: 0.0,
      motion: widget.motion,
      builder: (context, t, child) {
        final opacity = t.clamp(0.0, 1.0);
        final y = (1 - t) * 3;
        final scale = 0.8 + 0.2 * t;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
