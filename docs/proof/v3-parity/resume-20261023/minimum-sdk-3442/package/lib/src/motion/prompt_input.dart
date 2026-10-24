import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
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

/// Delivery state of one composer attachment.
enum BeuiPromptAttachmentStatus {
  /// Uploaded and ready to send.
  ready,

  /// In flight. The chip shows a determinate bar when
  /// [BeuiPromptAttachment.progress] is set, an indeterminate sweep otherwise.
  uploading,

  /// Upload failed. The chip offers retry when
  /// [BeuiPromptInput.onAttachmentRetry] is wired.
  failed,
}

/// One attachment riding along with the prompt, shown as a chip above the
/// field.
///
/// The package ships no file picker (spec §7): the consumer picks files with
/// whatever plugin fits their platform, uploads them, and reflects progress by
/// passing new instances through [BeuiPromptInput.attachments].
@immutable
class BeuiPromptAttachment {
  /// Creates an attachment chip.
  const BeuiPromptAttachment({
    required this.id,
    required this.name,
    this.thumbnail,
    this.icon,
    this.status = BeuiPromptAttachmentStatus.ready,
    this.progress,
    this.error,
  }) : assert(
         progress == null || (progress >= 0 && progress <= 1),
         'progress is a 0-1 fraction.',
       );

  /// Stable identity. Drives the chip's enter/exit animation, so it must not
  /// change as the attachment moves between statuses.
  final String id;

  /// File name shown on the chip.
  final String name;

  /// Optional image preview, rendered as the chip's 20px leading square.
  /// Takes precedence over [icon].
  final ImageProvider? thumbnail;

  /// Optional leading glyph for non-image attachments. Falls back to a generic
  /// file mark.
  final Widget? icon;

  /// Delivery state.
  final BeuiPromptAttachmentStatus status;

  /// Upload progress as a 0-1 fraction, when known.
  final double? progress;

  /// Failure note, surfaced on the chip and read by screen readers.
  final String? error;
}

/// Everything a submit carries: the trimmed prompt, the selected model, and
/// any attachments.
///
/// Delivered through [BeuiPromptInput.onSubmitFull]. The older
/// [BeuiPromptInput.onSubmit] still fires with just text + model, so existing
/// call sites keep working.
@immutable
class BeuiPromptSubmission {
  /// Creates a submission record.
  const BeuiPromptSubmission({
    required this.text,
    this.model,
    this.attachments = const [],
  });

  /// The trimmed prompt. May be empty when [attachments] is not.
  final String text;

  /// The model selected at submit time, if the picker is in use.
  final String? model;

  /// The attachments as they stood at submit time.
  final List<BeuiPromptAttachment> attachments;
}

/// Why a submit attempt did not go through.
///
/// Reported via [BeuiPromptInput.onSubmitBlocked] so a host can add its own
/// handling (queue the message, flash a hint) instead of the press vanishing.
enum BeuiPromptBlockedReason {
  /// Enter pressed while the agent is still generating.
  loading,

  /// Enter pressed with no text and no attachments.
  empty,
}

// ---------------------------------------------------------------------------
// Constants — layout mirrors the source's Tailwind tokens
// ---------------------------------------------------------------------------

/// Source `leading-6` line height used by the auto-grow min/max clamp.
const double _lineHeight = 24;

/// Source `text-sm` for the composer.
const double _fontSize = 14;

/// Source footer `min-h-8` / icon buttons `size-8`.
const double _footerMinH = 32;

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
/// **Attachments**: pass [attachments] to render a chip rail above the field,
/// with per-chip remove, upload progress and a retry on failure. Submissions
/// carry them through [onSubmitFull].
///
/// **Send / stop**: the trailing primary icon button shows ↑ when idle and a
/// filled square while [loading] — or a spinner while loading with no [onStop],
/// since a stop control that cannot stop anything is a lie. The swap springs on
/// [beuiSpringSwap] (opacity + y + scale) and now plays a real exit as well as
/// an entrance. Idle submit requires text or an attachment.
///
/// **Keyboard**: Enter submits, Shift+Enter inserts a newline, and Enter that
/// cannot submit (mid-stream, or on an empty composer) inserts a newline and
/// reports through [onSubmitBlocked] rather than vanishing. The `+` menu is
/// fully navigable — Enter/Space/Down to open, Up/Down to move, Home/End for
/// the ends, Esc to close with focus returning to the trigger.
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
    this.onSubmitFull,
    this.onSubmitBlocked,
    this.attachments = const [],
    this.onAttachmentRemoved,
    this.onAttachmentRetry,
    this.loading = false,
    this.onStop,
    this.minRows = 2,
    this.maxRows = 8,
    this.leadingAction,
    this.enabled = true,
    this.placeholder,
    this.semanticLabel,
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
  ///
  /// Kept for source parity and backward compatibility; it carries no
  /// attachments. Use [onSubmitFull] when the composer accepts attachments —
  /// both fire, in that order.
  final void Function(String value, String? model)? onSubmit;

  /// Called on submit with the full record: text, model and [attachments].
  final ValueChanged<BeuiPromptSubmission>? onSubmitFull;

  /// Called when a submit attempt was refused, with the reason.
  ///
  /// A blocked Enter (during generation, or on an empty composer) inserts a
  /// newline so the user can keep drafting, flashes the stop button while
  /// streaming, and reports here.
  final ValueChanged<BeuiPromptBlockedReason>? onSubmitBlocked;

  /// Attachments riding along with the prompt, shown as a chip rail above the
  /// field. Empty (the default) renders no rail at all.
  ///
  /// The list is owned by the consumer: handle [onAttachmentRemoved] and
  /// [onAttachmentRetry] and pass a new list back down.
  final List<BeuiPromptAttachment> attachments;

  /// Called with the attachment whose × was activated.
  final ValueChanged<BeuiPromptAttachment>? onAttachmentRemoved;

  /// Called with a failed attachment whose retry was activated. When null,
  /// failed chips show no retry affordance.
  final ValueChanged<BeuiPromptAttachment>? onAttachmentRetry;

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

  /// Placeholder when empty. Defaults to
  /// [BeuiAgentStrings.promptPlaceholder].
  final String? placeholder;

  /// Accessibility label for the text field (source `aria-label`). Defaults to
  /// [BeuiAgentStrings.promptSemanticLabel].
  final String? semanticLabel;

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
  bool _focused = false;

  /// Bumped each time Enter is swallowed mid-stream, to flash the stop button.
  int _stopPulse = 0;

  // Auto-grow measurement cache — see [_composerHeight].
  String? _measuredText;
  double? _measuredWidth;
  double? _measuredFontSize;
  double? _measuredLineHeight;
  int? _measuredMaxRows;
  int _measuredRows = 0;

  // First-line leading cache — see [_firstLineLeading].
  double? _leadingForFontSize;
  double _cachedLeading = 0;

  String get _text => widget.value ?? _controller.text;

  String? get _modelValue {
    if (widget.model != null) return widget.model;
    if (_internalModel != null) return _internalModel;
    if (widget.models.isEmpty) return null;
    return widget.defaultModel ?? widget.models.first.value;
  }

  /// An attachment-only message is a real message — an image with no caption
  /// is the commonest one — so the send button lights up for either.
  bool get _hasPayload =>
      _text.trim().isNotEmpty || widget.attachments.isNotEmpty;

  bool get _canSubmit => _hasPayload && widget.enabled && !widget.loading;

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
    if (!_canSubmit) return;
    widget.onSubmit?.call(prompt, _modelValue);
    widget.onSubmitFull?.call(
      BeuiPromptSubmission(
        text: prompt,
        model: _modelValue,
        attachments: List.unmodifiable(widget.attachments),
      ),
    );
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
    if (!widget.enabled) return KeyEventResult.ignored;

    // Blocked sends return `ignored` rather than swallowing the keystroke, so
    // Enter on an empty or mid-stream composer becomes the newline the user
    // can keep drafting with instead of doing nothing at all.
    if (widget.loading) {
      // Plus a visible answer to "why didn't that send?": draw the eye to the
      // control that can actually act right now.
      setState(() => _stopPulse++);
      widget.onSubmitBlocked?.call(BeuiPromptBlockedReason.loading);
      return KeyEventResult.ignored;
    }
    if (!_hasPayload) {
      widget.onSubmitBlocked?.call(BeuiPromptBlockedReason.empty);
      return KeyEventResult.ignored;
    }
    _submit();
    return KeyEventResult.handled;
  }

  /// The composer's font size and line-height multiplier, resolved once from
  /// [BeuiAgentTheme.typography.assistantBody] with the source's `text-sm
  /// leading-6` fallback — every composer style and metric derives from this.
  ({double fontSize, double height}) _composerMetrics(BeuiAgentTheme agent) {
    final body = agent.typography.assistantBody;
    return (
      fontSize: body.fontSize ?? _fontSize,
      height: body.height ?? _lineHeight / _fontSize,
    );
  }

  /// Composer text style — source `text-sm leading-6` with default tracking.
  ///
  /// [TextLeadingDistribution.even] is CSS's line-box model: the extra leading
  /// splits evenly above and below the glyphs.
  TextStyle _composerStyle(BeuiColors colors, BeuiAgentTheme agent) {
    final m = _composerMetrics(agent);
    return TextStyle(
      fontSize: m.fontSize,
      height: m.height,
      leadingDistribution: TextLeadingDistribution.even,
      // An unset letterSpacing inherits the host theme's body style (0.25–0.5
      // under Material) and widens the line by ~0.5px per character.
      letterSpacing: 0,
      color: colors.foreground,
    );
  }

  TextStyle _hiddenComposerStyle(BeuiAgentTheme agent) {
    final m = _composerMetrics(agent);
    return TextStyle(
      fontSize: m.fontSize,
      height: m.height,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: 0,
    );
  }

  StrutStyle _composerStrut(BeuiAgentTheme agent) {
    final m = _composerMetrics(agent);
    return StrutStyle(
      fontSize: m.fontSize,
      height: m.height,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  double _resolvedLineHeight(BeuiAgentTheme agent) {
    final m = _composerMetrics(agent);
    return m.height * m.fontSize;
  }

  double _resolvedFontSize(BeuiAgentTheme agent) =>
      _composerMetrics(agent).fontSize;

  /// The source's `resizeTextarea`: measure the wrapped text in a mirror of the
  /// field's content box, then clamp the row count to [minRows]…[maxRows].
  ///
  /// This runs in `build`, so laying out the *entire* prompt on every keystroke
  /// would jank on every character after pasting a long document. Two guards
  /// keep it cheap:
  ///
  ///  * The result is memoised on everything it depends on (text, available
  ///    width, resolved font size and line height), so a rebuild that changes
  ///    none of them — a focus change, a hover, an animation tick — reuses it.
  ///  * The painter is capped at [maxRows] lines. Past that the row count is
  ///    clamped anyway, so laying out the remaining thousands of lines only to
  ///    throw the number away is pure waste; `maxLines` makes it stop.
  double _composerHeight(BuildContext context, double maxWidth) {
    final agent = BeuiAgentTheme.of(context);
    final lineHeight = _resolvedLineHeight(agent);
    final fontSize = _resolvedFontSize(agent);
    // The field's content box is inset by the source's `px-2`.
    final textWidth = maxWidth.isFinite ? maxWidth - 16 : double.infinity;
    final text = _controller.text;

    final cacheHit =
        _measuredText == text &&
        _measuredWidth == textWidth &&
        _measuredFontSize == fontSize &&
        _measuredLineHeight == lineHeight &&
        _measuredMaxRows == widget.maxRows;

    if (!cacheHit) {
      var rows = widget.minRows;
      if (textWidth.isFinite && textWidth > 0) {
        final painter = TextPainter(
          // The source appends a zero-width space so a trailing newline counts.
          text: TextSpan(text: '$text​', style: _hiddenComposerStyle(agent)),
          strutStyle: _composerStrut(agent),
          textDirection: Directionality.of(context),
          maxLines: widget.maxRows,
        )..layout(maxWidth: textWidth);
        rows = painter.computeLineMetrics().length;
        painter.dispose();
      }
      _measuredText = text;
      _measuredWidth = textWidth;
      _measuredFontSize = fontSize;
      _measuredLineHeight = lineHeight;
      _measuredMaxRows = widget.maxRows;
      _measuredRows = rows;
    }

    return _measuredRows.clamp(widget.minRows, widget.maxRows) * lineHeight;
  }

  /// Half of `leading-6`'s extra leading, in logical pixels.
  ///
  /// CSS centres a line's leading around the glyphs, so the first baseline sits
  /// half a leading below the content box. Flutter's `EditableText` leaves the
  /// first line's ascent at the font's natural value, so the composer renders
  /// ~4px high against the site. Derived from the resolved font's own metrics
  /// (never a hardcoded offset) and folded into the field's top padding.
  /// Cached on the font size: this depends only on the resolved font metrics,
  /// so laying a painter out for it on every build was a second per-keystroke
  /// measurement doing no work.
  double _firstLineLeading(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final fontSize = _resolvedFontSize(agent);
    if (_leadingForFontSize == fontSize) return _cachedLeading;

    final painter = TextPainter(
      // Height unset → the painter reports the font's natural line height.
      text: TextSpan(
        text: 'x',
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: Directionality.of(context),
    )..layout();
    final natural = painter.preferredLineHeight;
    painter.dispose();
    final leading = (_resolvedLineHeight(agent) - natural) / 2;
    _leadingForFontSize = fontSize;
    _cachedLeading = leading > 0 ? leading : 0;
    return _cachedLeading;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
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
          border: widget.bordered
              ? Border.all(
                  color: borderColor,
                  width: agent.structure.borderWidth,
                )
              : null,
          borderRadius: agent.shapes.card,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.attachments.isNotEmpty)
              _AttachmentRail(
                colors: colors,
                attachments: widget.attachments,
                enabled: widget.enabled,
                reduce: reduce,
                onRemove: widget.onAttachmentRemoved,
                onRetry: widget.onAttachmentRetry,
              ),
            // Names the composer without nesting a second edit box inside the
            // first — MergeSemantics folds the field's own textField node
            // into this one instead of declaring a sibling that duplicates
            // it, so a screen reader announces the composer once.
            MergeSemantics(
              child: Semantics(
                label:
                    widget.semanticLabel ?? agent.strings.promptSemanticLabel,
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
                        style: _composerStyle(colors, agent),
                        strutStyle: _composerStrut(agent),
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
                          hintText:
                              widget.placeholder ??
                              agent.strings.promptPlaceholder,
                          hintStyle: _composerStyle(colors, agent).copyWith(
                            // Full-strength `mutedForeground` (5.9:1) keeps the
                            // composer's only label above the AA floor.
                            color: colors.mutedForeground,
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
            ),
            const SizedBox(height: 4),
            _Footer(
              colors: colors,
              reduce: reduce,
              swapMotion: swapMotion,
              enabled: widget.enabled,
              loading: widget.loading,
              canSubmit: _canSubmit,
              stopPulse: _stopPulse,
              actions: widget.actions,
              actionsOpen: _actionsOpen,
              onActionsOpenChange: (v) => setState(() => _actionsOpen = v),
              onAction: (v) {
                widget.onAction?.call(v);
                setState(() => _actionsOpen = false);
              },
              leadingAction: widget.leadingAction,
              models: widget.models,
              modelValue: _modelValue,
              onModelChange: _setModel,
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
    required this.stopPulse,
    required this.actions,
    required this.actionsOpen,
    required this.onActionsOpenChange,
    required this.onAction,
    required this.leadingAction,
    required this.models,
    required this.modelValue,
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
  final int stopPulse;
  final List<BeuiPromptAction> actions;
  final bool actionsOpen;
  final ValueChanged<bool> onActionsOpenChange;
  final ValueChanged<String> onAction;
  final Widget? leadingAction;
  final List<BeuiPromptModel> models;
  final String? modelValue;
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
              // Attaching a file while the agent is still answering is table
              // stakes, and so is lining up the next model. Neither has
              // anything to do with the stream, so neither goes dead for it.
              enabled: enabled,
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
                  enabled: enabled,
                  models: models,
                  value: modelValue,
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
            pulse: stopPulse,
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

class _ActionsButton extends StatefulWidget {
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
  State<_ActionsButton> createState() => _ActionsButtonState();
}

class _ActionsButtonState extends State<_ActionsButton> {
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'BeuiPromptActions');
  bool _focusVisible = false;

  @override
  void dispose() {
    _triggerFocus.dispose();
    super.dispose();
  }

  void _toggle() => widget.onOpenChange(!widget.open);

  /// Closes and puts focus back where it came from.
  ///
  /// Without this a keyboard user who opens the menu and dismisses it is left
  /// with focus on nothing at all — the standard menu contract, and the thing
  /// that makes the keyboard path usable rather than merely present.
  void _closeAndReturnFocus() {
    widget.onOpenChange(false);
    _triggerFocus.requestFocus();
  }

  /// The trigger's rect in global coordinates, for the menu's flip/clamp.
  Rect? get _triggerRect {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final enabled = widget.enabled;
    final plus = SingleMotionBuilder(
      value: widget.open ? 45.0 : 0.0,
      // [swapMotion] is already resolved through `motionFor` by the caller
      // (isMovement: true), so it is NoMotion under reduced motion already.
      motion: widget.swapMotion,
      builder: (context, deg, child) {
        // Reduced motion snaps (bypass NoMotion freeze-at-source).
        final angle = (widget.swapMotion is NoMotion || widget.reduce)
            ? (widget.open ? 45.0 : 0.0)
            : deg;
        return Transform.rotate(angle: angle * math.pi / 180, child: child);
      },
      child: Icon(
        BeuiAgentTheme.of(context).icons.add,
        size: 16,
        color: colors.mutedForeground,
      ),
    );

    return BeuiOverlay(
      open: widget.open,
      barrier: true,
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      // The menu takes focus itself (see [_ActionsMenu]); the overlay's own
      // trap would fight the roving focus inside it. Esc still works — the
      // overlay listens for it without needing the trap.
      trapFocus: false,
      onDismiss: _closeAndReturnFocus,
      enterDuration: Duration(milliseconds: widget.reduce ? 120 : 280),
      exitDuration: Duration(milliseconds: widget.reduce ? 100 : 160),
      overlayBuilder: (context, animation, link) => _AnchoredMenu(
        anchor: _triggerRect,
        animation: animation,
        reduce: widget.reduce,
        colors: colors,
        width: 224,
        child: _ActionsMenu(
          colors: colors,
          actions: widget.actions,
          onAction: widget.onAction,
          onDismiss: _closeAndReturnFocus,
        ),
      ),
      // The slop is the outermost wrapper on purpose: RenderProxyBox.hitTest
      // rejects positions outside its own size before descending, so a
      // Semantics above it would swallow the very pointers it exists to catch.
      child: BeuiMinHitTarget(
        child: Semantics(
          button: true,
          enabled: enabled,
          expanded: widget.open,
          label: 'Add to prompt',
          onTap: enabled ? _toggle : null,
          child: FocusableActionDetector(
            focusNode: _triggerFocus,
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              // Down opens the menu straight onto its first row, the way a
              // native menu button behaves.
              SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _toggle();
                  return null;
                },
              ),
            },
            onShowFocusHighlight: (value) =>
                setState(() => _focusVisible = value),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? _toggle : null,
              child: BeuiFocusRing(
                focused: _focusVisible,
                borderRadius: BorderRadius.circular(10),
                child: KeyedSubtree(
                  key: _triggerKey,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: plus),
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

/// Floating menu anchored to the trigger — above it by preference (source
/// `side=top, align=start, offset 8`), flipped below and clamped horizontally
/// when there is no room.
///
/// The previous implementation pinned a fixed-width panel to the trigger at a
/// fixed offset with no awareness of the viewport at all, so a composer near
/// the top of the window rendered its menu off-screen and one near an edge
/// rendered it past that edge. [_MenuLayoutDelegate] measures instead.
class _AnchoredMenu extends StatelessWidget {
  const _AnchoredMenu({
    required this.anchor,
    required this.animation,
    required this.reduce,
    required this.colors,
    required this.width,
    required this.child,
  });

  /// The trigger's global rect, or null if it could not be measured (in which
  /// case the menu falls back to the top-left safe area).
  final Rect? anchor;
  final Animation<double> animation;
  final bool reduce;
  final BeuiColors colors;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rect =
        anchor ??
        Rect.fromLTWH(media.padding.left + 8, media.padding.top, 0, 0);

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _MenuLayoutDelegate(
          anchor: rect,
          // Keep clear of notches, rounded corners and the soft keyboard.
          safeArea: media.padding + media.viewInsets,
        ),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value.clamp(0.0, 1.0);
            final scale = reduce ? 1.0 : 0.96 + 0.04 * t;
            return Opacity(
              opacity: t,
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
      ),
    );
  }
}

/// Places a menu panel against an anchor, flipping and clamping to stay on
/// screen.
///
/// Preference order matches the source: above the trigger, start-aligned, 8px
/// clear. If the panel is taller than the space above it flips below; if it
/// fits neither it takes the roomier side and is capped to it, so a very long
/// menu is bounded rather than overflowing. Horizontal position is clamped into
/// the safe area regardless.
class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _MenuLayoutDelegate({required this.anchor, required this.safeArea});

  final Rect anchor;
  final EdgeInsets safeArea;

  /// Source `sideOffset` — the gap between trigger and panel.
  static const double _gap = 8;

  /// Breathing room kept against the viewport edge.
  static const double _margin = 8;

  double _spaceAbove() => anchor.top - safeArea.top - _gap - _margin;
  double _spaceBelow(Size size) =>
      size.height - safeArea.bottom - anchor.bottom - _gap - _margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    // Never demand more height than the roomier side can give.
    final maxHeight = math.max(math.max(_spaceAbove(), _spaceBelow(size)), 0.0);
    return BoxConstraints(
      maxWidth: math.max(size.width - safeArea.horizontal - _margin * 2, 0.0),
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = _spaceAbove();
    final below = _spaceBelow(size);
    // Above unless it does not fit and below is roomier — the source's
    // preferred side wins every tie.
    final placeAbove = childSize.height <= above || above >= below;

    final dy = placeAbove
        ? anchor.top - _gap - childSize.height
        : anchor.bottom + _gap;

    final minX = safeArea.left + _margin;
    final maxX = math.max(
      size.width - safeArea.right - _margin - childSize.width,
      minX,
    );
    final minY = safeArea.top + _margin;
    final maxY = math.max(
      size.height - safeArea.bottom - _margin - childSize.height,
      minY,
    );
    return Offset(anchor.left.clamp(minX, maxX), dy.clamp(minY, maxY));
  }

  @override
  bool shouldRelayout(_MenuLayoutDelegate old) =>
      old.anchor != anchor || old.safeArea != safeArea;
}

/// The `+` popover's rows, with the roving-focus model a menu is expected to
/// have: the first choosable row takes focus on open, Up/Down move between rows
/// (wrapping, skipping disabled ones), Home/End jump to the ends, Enter/Space
/// choose, and Esc closes with focus returning to the trigger.
class _ActionsMenu extends StatefulWidget {
  const _ActionsMenu({
    required this.colors,
    required this.actions,
    required this.onAction,
    required this.onDismiss,
  });

  final BeuiColors colors;
  final List<BeuiPromptAction> actions;
  final ValueChanged<String> onAction;
  final VoidCallback onDismiss;

  @override
  State<_ActionsMenu> createState() => _ActionsMenuState();
}

class _ActionsMenuState extends State<_ActionsMenu> {
  late List<FocusNode> _nodes;
  int _active = -1;

  @override
  void initState() {
    super.initState();
    _buildNodes();
    // Focus the first choosable row once the overlay is on screen, so the menu
    // is immediately drivable from the keyboard that opened it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = widget.actions.indexWhere((a) => a.enabled);
      if (first >= 0) _focus(first);
    });
  }

  void _buildNodes() {
    _nodes = [
      for (var i = 0; i < widget.actions.length; i++)
        FocusNode(debugLabel: 'BeuiPromptAction $i'),
    ];
  }

  @override
  void didUpdateWidget(_ActionsMenu old) {
    super.didUpdateWidget(old);
    if (widget.actions.length != old.actions.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _buildNodes();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _focus(int i) {
    if (i < 0 || i >= _nodes.length) return;
    setState(() => _active = i);
    _nodes[i].requestFocus();
  }

  /// Steps [delta] rows, skipping disabled entries and wrapping at the ends.
  void _move(int delta) {
    final n = widget.actions.length;
    if (n == 0) return;
    var i = _active < 0 ? (delta > 0 ? -1 : 0) : _active;
    for (var step = 0; step < n; step++) {
      i = (i + delta) % n;
      if (i < 0) i += n;
      if (widget.actions[i].enabled) {
        _focus(i);
        return;
      }
    }
  }

  void _edge({required bool last}) {
    final i = last
        ? widget.actions.lastIndexWhere((a) => a.enabled)
        : widget.actions.indexWhere((a) => a.enabled);
    if (i >= 0) _focus(i);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
          TraversalDirection.down,
        ),
        SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
          TraversalDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.home): _MenuEdgeIntent(last: false),
        SingleActivator(LogicalKeyboardKey.end): _MenuEdgeIntent(last: true),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // Handled here rather than by default traversal so the ring wraps and
          // disabled rows are skipped — a menu, not a tab order.
          DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
            onInvoke: (intent) {
              switch (intent.direction) {
                case TraversalDirection.down:
                  _move(1);
                case TraversalDirection.up:
                  _move(-1);
                case TraversalDirection.left:
                case TraversalDirection.right:
                  break;
              }
              return null;
            },
          ),
          _MenuEdgeIntent: CallbackAction<_MenuEdgeIntent>(
            onInvoke: (intent) {
              _edge(last: intent.last);
              return null;
            },
          ),
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onDismiss();
              return null;
            },
          ),
        },
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Prompt actions',
          child: Padding(
            padding: const EdgeInsets.all(6), // p-1.5
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.actions.length; i++)
                  _ActionRow(
                    colors: widget.colors,
                    action: widget.actions[i],
                    focusNode: _nodes[i],
                    onFocused: () => setState(() => _active = i),
                    onTap: widget.actions[i].enabled
                        ? () => widget.onAction(widget.actions[i].value)
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

/// Home/End inside a menu.
class _MenuEdgeIntent extends Intent {
  const _MenuEdgeIntent({required this.last});

  /// True for End (last row), false for Home (first row).
  final bool last;
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.colors,
    required this.action,
    required this.focusNode,
    required this.onFocused,
    required this.onTap,
  });

  final BeuiColors colors;
  final BeuiPromptAction action;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final VoidCallback? onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    // Keyboard focus and pointer hover land on the same highlight, so the row
    // under the caret reads identically however you got there.
    final highlight = enabled && (_hovered || _focusVisible);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.action.label,
      hint: widget.action.description,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        onFocusChange: (value) {
          if (value) widget.onFocused();
        },
        onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.ease,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: highlight ? widget.colors.muted : null,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model picker
//
// One implementation, always: the gooey, keyboard-navigable [BeuiSelect],
// whether or not a model carries an icon — [BeuiSelectOption]'s `icon` slot
// covers that case, so a glyph is never a reason to swap to a different,
// pointer-only picker.
// ---------------------------------------------------------------------------

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.enabled,
    required this.models,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final List<BeuiPromptModel> models;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 208),
      child: BeuiSelect(
        options: [
          for (final m in models)
            BeuiSelectOption(
              value: m.value,
              label: m.label,
              icon: m.icon,
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
    required this.pulse,
    required this.onSubmit,
    required this.onStop,
  });

  final BeuiColors colors;
  final bool reduce;
  final Motion swapMotion;
  final bool loading;
  final bool canSubmit;

  /// Increments each time Enter was pressed mid-stream. See [_StopPulse].
  final int pulse;
  final VoidCallback onSubmit;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    // A stop square you cannot press is a lie: it looks like the one control
    // that could interrupt the stream, and does nothing. Without an `onStop`
    // it becomes a plain busy indicator, which is what it actually is.
    final stoppable = onStop != null;
    final enabled = loading ? stoppable : canSubmit;

    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: loading
            ? (stoppable
                  ? BeuiAgentTheme.of(context).strings.stopGenerating
                  : 'Generating')
            : 'Send prompt',
        child: _StopPulse(
          pulse: pulse,
          active: loading,
          reduce: reduce,
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
              stoppable: stoppable,
              reduce: reduce,
              swapMotion: swapMotion,
              color: colors.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-shot flash when [pulse] changes — the visible answer to "I pressed
/// Enter and nothing happened".
///
/// Enter cannot send mid-stream, so it draws the eye to the control that *can*
/// act instead. Under reduced motion the scale is dropped and only the dip in
/// opacity remains: movement out, opacity kept, per the project's per-channel
/// rule.
class _StopPulse extends StatefulWidget {
  const _StopPulse({
    required this.pulse,
    required this.active,
    required this.reduce,
    required this.child,
  });

  final int pulse;
  final bool active;
  final bool reduce;
  final Widget child;

  @override
  State<_StopPulse> createState() => _StopPulseState();
}

class _StopPulseState extends State<_StopPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;

  @override
  void initState() {
    super.initState();
    // Constructed here, never lazily: a `late final` initialiser that only the
    // guarded paths touch ends up running inside dispose(), building a Ticker
    // on an element that is already unmounting.
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didUpdateWidget(_StopPulse old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse && widget.active) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, child) {
        if (_flash.value == 0) return child!;
        // One symmetric out-and-back across the flash.
        final t = math.sin(_flash.value * math.pi);
        Widget body = Opacity(opacity: 1 - 0.35 * t, child: child);
        if (!widget.reduce) {
          body = Transform.scale(scale: 1 + 0.12 * t, child: body);
        }
        return body;
      },
      child: widget.child,
    );
  }
}

/// AnimatePresence-style send <-> stop icon swap on [beuiSpringSwap].
///
/// Source: opacity 0->1, y 3->0, scale 0.8->1 enter; exit y -3 / scale 0.8.
/// Reduced motion: opacity only (snap position/scale).
class _SwapIcon extends StatelessWidget {
  const _SwapIcon({
    required this.loading,
    required this.stoppable,
    required this.reduce,
    required this.swapMotion,
    required this.color,
  });

  final bool loading;
  final bool stoppable;
  final bool reduce;
  final Motion swapMotion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String key;
    final Widget icon;
    if (loading && stoppable) {
      key = 'stop';
      icon = SizedBox.square(
        dimension: 12,
        child: CustomPaint(painter: _StopSquarePainter(color: color)),
      );
    } else if (loading) {
      // Nothing to stop — say "busy", not "press me".
      key = 'busy';
      icon = _BusySpinner(color: color, reduce: reduce);
    } else {
      key = 'send';
      icon = Icon(
        BeuiAgentTheme.of(context).icons.send,
        size: 16,
        color: color,
      );
    }

    if (reduce || swapMotion is NoMotion) {
      return KeyedSubtree(key: ValueKey(key), child: icon);
    }

    // The source's swap has a documented *exit* (y -3, scale 0.8, fade) that
    // never ran: the outgoing icon was replaced outright and only the incoming
    // one animated, so the swap read as a hard cut into a spring.
    // AnimatedSwitcher keeps the outgoing child alive long enough to play it,
    // and the exit is the faster half of the pair — the house rule.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 140),
      switchInCurve: beuiEaseOut,
      switchOutCurve: beuiEaseOut,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      transitionBuilder: (child, animation) =>
          _SwapTransition(animation: animation, child: child),
      child: KeyedSubtree(key: ValueKey(key), child: icon),
    );
  }
}

/// Source enter `opacity 0->1, y 3->0, scale 0.8->1`; the exit mirrors it
/// upward (`y -> -3`), so the outgoing glyph leaves the way the incoming one
/// arrives.
class _SwapTransition extends StatelessWidget {
  const _SwapTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final exiting = animation.status == AnimationStatus.reverse;
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (exiting ? -3 : 3) * (1 - t)),
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: inner),
          ),
        );
      },
      child: child,
    );
  }
}

/// The busy mark shown while loading with no `onStop` — a rotating spinner,
/// static under reduced motion.
class _BusySpinner extends StatefulWidget {
  const _BusySpinner({required this.color, required this.reduce});

  final Color color;
  final bool reduce;

  @override
  State<_BusySpinner> createState() => _BusySpinnerState();
}

class _BusySpinnerState extends State<_BusySpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!widget.reduce) _spin.repeat();
  }

  @override
  void didUpdateWidget(_BusySpinner old) {
    super.didUpdateWidget(old);
    if (widget.reduce && _spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    } else if (!widget.reduce && !_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      BeuiAgentTheme.of(context).icons.spinner,
      size: 16,
      color: widget.color,
    );
    if (widget.reduce) return glyph;
    return RepaintBoundary(
      child: RotationTransition(turns: _spin, child: glyph),
    );
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

// ---------------------------------------------------------------------------
// Attachment rail
// ---------------------------------------------------------------------------

/// Chip height — sized so a 20px thumbnail clears its 4px inset on both sides.
const double _chipHeight = 28;

/// The horizontal chip rail above the field.
///
/// The composer had no attachment surface at all: no model, no chips, no
/// per-attachment remove, and `onSubmit` could not carry a file even if the
/// host had one. Attaching was an `onAction('image')` intent that went nowhere.
///
/// The rail scrolls horizontally rather than wrapping, so a composer with eight
/// attachments stays the height the user sized it to.
class _AttachmentRail extends StatelessWidget {
  const _AttachmentRail({
    required this.colors,
    required this.attachments,
    required this.enabled,
    required this.reduce,
    required this.onRemove,
    required this.onRetry,
  });

  final BeuiColors colors;
  final List<BeuiPromptAttachment> attachments;
  final bool enabled;
  final bool reduce;
  final ValueChanged<BeuiPromptAttachment>? onRemove;
  final ValueChanged<BeuiPromptAttachment>? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: _chipHeight,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Attachments',
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: attachments.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final a = attachments[i];
              return _AttachmentChip(
                key: ValueKey(a.id),
                colors: colors,
                attachment: a,
                enabled: enabled,
                reduce: reduce,
                onRemove: onRemove == null ? null : () => onRemove!(a),
                onRetry:
                    onRetry == null ||
                        a.status != BeuiPromptAttachmentStatus.failed
                    ? null
                    : () => onRetry!(a),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One attachment chip: leading thumbnail or glyph, truncated name, and a
/// remove ×, with an upload wash while in flight and a retry when failed.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.colors,
    required this.attachment,
    required this.enabled,
    required this.reduce,
    required this.onRemove,
    required this.onRetry,
    super.key,
  });

  final BeuiColors colors;
  final BeuiPromptAttachment attachment;
  final bool enabled;
  final bool reduce;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final icons = BeuiAgentTheme.of(context).icons;
    final failed = a.status == BeuiPromptAttachmentStatus.failed;
    final uploading = a.status == BeuiPromptAttachmentStatus.uploading;

    final Widget leading;
    if (a.thumbnail != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image(
          image: a.thumbnail!,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
        ),
      );
    } else {
      leading = SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: IconTheme.merge(
            data: IconThemeData(
              size: 14,
              color: failed ? colors.destructive : colors.mutedForeground,
            ),
            child: a.icon ?? Icon(failed ? icons.warning : icons.file),
          ),
        ),
      );
    }

    Widget body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        leading,
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0,
              color: failed ? colors.destructive : colors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 2),
        if (failed && onRetry != null)
          _ChipAction(
            colors: colors,
            icon: icons.retry,
            label: 'Retry ${a.name}',
            tint: colors.destructive,
            onPressed: enabled ? onRetry : null,
          ),
        if (onRemove != null)
          _ChipAction(
            colors: colors,
            icon: icons.close,
            label: 'Remove ${a.name}',
            onPressed: enabled ? onRemove : null,
          ),
        const SizedBox(width: 2),
      ],
    );

    // The upload wash rides *behind* the content so the name stays readable
    // throughout, rather than the chip swapping out for a progress bar.
    if (uploading) {
      body = Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _UploadWash(
                  progress: a.progress,
                  reduce: reduce,
                  color: colors.foreground.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          body,
        ],
      );
    }

    return Semantics(
      container: true,
      // Without this the chip node merges its descendants and swallows the
      // remove/retry buttons, leaving the rail navigable but not operable.
      explicitChildNodes: true,
      label: a.name,
      // Status and any failure reason travel with the chip, so the rail is
      // navigable without sight of the wash or the tint.
      value: switch (a.status) {
        BeuiPromptAttachmentStatus.ready => 'Attached',
        BeuiPromptAttachmentStatus.uploading =>
          a.progress == null
              ? 'Uploading'
              : 'Uploading, ${(a.progress! * 100).round()}%',
        BeuiPromptAttachmentStatus.failed => a.error ?? 'Upload failed',
      },
      liveRegion: failed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: failed
              ? colors.destructive.withValues(alpha: 0.1)
              : colors.muted,
          border: Border.all(
            color: failed
                ? colors.destructive.withValues(alpha: 0.4)
                : colors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(height: _chipHeight, child: body),
      ),
    );
  }
}

/// The in-flight wash: a determinate fill when [progress] is known, an
/// indeterminate sweep when it is not.
///
/// Under reduced motion the sweep is dropped (a determinate fill still updates,
/// because that is information rather than decoration).
class _UploadWash extends StatefulWidget {
  const _UploadWash({
    required this.progress,
    required this.reduce,
    required this.color,
  });

  final double? progress;
  final bool reduce;
  final Color color;

  @override
  State<_UploadWash> createState() => _UploadWashState();
}

class _UploadWashState extends State<_UploadWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.progress == null && !widget.reduce) _sweep.repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    if (progress != null) {
      return SingleMotionBuilder(
        value: progress.clamp(0.0, 1.0),
        motion: const CurvedMotion(Duration(milliseconds: 280), beuiEaseOut),
        active: !widget.reduce,
        builder: (context, t, _) => FractionallySizedBox(
          widthFactor: t.clamp(0.0, 1.0),
          heightFactor: 1,
          child: ColoredBox(color: widget.color),
        ),
      );
    }
    if (widget.reduce) {
      return FractionallySizedBox(
        widthFactor: 1,
        heightFactor: 1,
        child: ColoredBox(color: widget.color),
      );
    }
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        // 0 → 1 → 0, so the fill breathes rather than snapping back.
        final t = 1 - (1 - 2 * _sweep.value).abs();
        return FractionallySizedBox(
          widthFactor: 0.15 + 0.85 * t,
          heightFactor: 1,
          child: ColoredBox(color: widget.color),
        );
      },
    );
  }
}

/// A chip's trailing control (remove, retry) with the full contract: button
/// semantics, keyboard activation, a focus ring and 44px of hit slop over a
/// 20px glyph.
class _ChipAction extends StatefulWidget {
  const _ChipAction({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tint,
  });

  final BeuiColors colors;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? tint;

  @override
  State<_ChipAction> createState() => _ChipActionState();
}

class _ChipActionState extends State<_ChipAction> {
  bool _hovered = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = widget.tint ?? widget.colors.mutedForeground;
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        onTap: widget.onPressed,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          onShowHoverHighlight: (v) => setState(() => _hovered = v),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: BeuiFocusRing(
              focused: _focusVisible,
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 12,
                    color: _hovered && enabled
                        ? (widget.tint ?? widget.colors.foreground)
                        : base,
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
