import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder, SpringMotion;
import '_focus_ring.dart';
import '_hit_target.dart';
import 'button/base.dart';
import 'button/stateful.dart';

/// An optional one-tap rating alongside the written message.
///
/// See [BeuiFeedbackWidget.showSentiment], which is off by default.
enum BeuiFeedbackSentiment {
  /// The user rated the experience positively.
  positive,

  /// The user rated the experience negatively.
  negative,
}

/// The payload handed to [BeuiFeedbackWidget.onSubmit] — the port of the source
/// `FeedbackData` interface.
@immutable
class BeuiFeedbackData {
  /// Creates a feedback payload.
  const BeuiFeedbackData({required this.message, this.sentiment});

  /// The message the user typed.
  final String message;

  /// The chosen rating, when [BeuiFeedbackWidget.showSentiment] is on and the
  /// user picked one. Null otherwise.
  final BeuiFeedbackSentiment? sentiment;
}

/// Which bottom corner the widget anchors to (source `position`).
enum BeuiFeedbackPosition {
  /// Anchored to the bottom-right corner (default).
  bottomRight,

  /// Anchored to the bottom-left corner.
  bottomLeft,
}

/// Optional visual overrides for [BeuiFeedbackWidget]. Null fields resolve from
/// the ambient [BeuiColors] theme extension (or sensible defaults).
@immutable
class BeuiFeedbackWidgetStyle {
  /// Creates a set of [BeuiFeedbackWidget] overrides.
  const BeuiFeedbackWidgetStyle({
    this.maxWidth,
    this.triggerSize,
    this.openRadius,
    this.triggerRadius,
    this.edgeInset,
    this.surfaceColor,
    this.cardColor,
    this.successColor,
  });

  /// Max width of the open panel, in px. Defaults to 320 (source
  /// `min(86vw, 320px)`; the 86% clamp is applied against the available width).
  final double? maxWidth;

  /// Edge length of the collapsed circular trigger. Defaults to 48 (`h-12 w-12`).
  final double? triggerSize;

  /// Corner radius of the open panel. Defaults to 20 (source open `borderRadius`).
  final double? openRadius;

  /// Corner radius of the collapsed trigger. Defaults to 40 (source closed
  /// `borderRadius`, i.e. a full circle at 48px).
  final double? triggerRadius;

  /// Inset from the anchored corner, in px. Defaults to 16 (`bottom-4`).
  final double? edgeInset;

  /// The shell surface color. Defaults to [BeuiColors.background].
  final Color? surfaceColor;

  /// The inner card color. Defaults to [BeuiColors.border] at 60% alpha
  /// (source `bg-border/60`).
  final Color? cardColor;

  /// The success badge / check color. Defaults to [BeuiColors.success].
  final Color? successColor;

  /// Returns a copy with the given fields replaced.
  BeuiFeedbackWidgetStyle copyWith({
    double? maxWidth,
    double? triggerSize,
    double? openRadius,
    double? triggerRadius,
    double? edgeInset,
    Color? surfaceColor,
    Color? cardColor,
    Color? successColor,
  }) {
    return BeuiFeedbackWidgetStyle(
      maxWidth: maxWidth ?? this.maxWidth,
      triggerSize: triggerSize ?? this.triggerSize,
      openRadius: openRadius ?? this.openRadius,
      triggerRadius: triggerRadius ?? this.triggerRadius,
      edgeInset: edgeInset ?? this.edgeInset,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      cardColor: cardColor ?? this.cardColor,
      successColor: successColor ?? this.successColor,
    );
  }
}

// ---------------------------------------------------------------------------
// Source timing/curve constants (mirror `feedback-widget.tsx` verbatim).
// ---------------------------------------------------------------------------

/// Auto-dismiss delay after a successful submit (source `SUCCESS_DURATION_MS`).
const Duration _successDuration = Duration(milliseconds: 1600);

/// The trigger grows into the panel with a slight overshoot on open
/// (source `MORPH_OPEN_EASE = [0.34, 1.25, 0.64, 1]`).
const Cubic _morphOpenEase = Cubic(0.34, 1.25, 0.64, 1);

/// A calmer curve on close so dismissing feels faster and less prominent
/// (source `MORPH_CLOSE_EASE = [0.22, 1, 0.36, 1]`).
const Cubic _morphCloseEase = Cubic(0.22, 1, 0.36, 1);

/// Source `MORPH_OPEN_DURATION = 0.4`.
const Duration _morphOpenDuration = Duration(milliseconds: 400);

/// Source `MORPH_CLOSE_DURATION = 0.28`.
const Duration _morphCloseDuration = Duration(milliseconds: 280);

/// Source `MORPH_FADE_DURATION = 0.22` — the opacity/blur window inside the
/// slower positional morph.
const double _morphFadeFraction = 0.22 / 0.4; // 0.55 of the 0.4s move window.

/// Source `MORPH_SLIDE = 40` — how far content slides in/out along x.
const double _morphSlide = 40;

/// Source `MORPH_SCALE = 0.97`.
const double _morphScale = 0.97;

/// Source `MORPH_BLUR = "blur(2px)"` → sigma via [beuiBlurSigma].
const double _morphBlurPx = 2;

/// The lifecycle of the widget (source `Status`).
enum _Status { idle, open, sending, sent, error }

/// A corner-anchored feedback capsule that **morphs** from a circular trigger
/// into a form panel, then celebrates on success — the Flutter port of beUI's
/// `feedback-widget`.
///
/// One persistent shell grows out of the corner: the collapsed 48×48 circle
/// (`triggerRadius` 40) expands to a `min(86vw, 320px)` rounded panel
/// (`openRadius` 20). The shell leads the reveal on a slight-overshoot curve
/// (`MORPH_OPEN_EASE`, 0.4s) and collapses on a calmer curve (`MORPH_CLOSE_EASE`,
/// 0.28s); its contents cross-fade a beat behind with an x-slide (±40), a
/// 0.97→1 scale and a 2px blur (`MORPH_FADE_DURATION` 0.22s for opacity/blur,
/// the positional channels riding the full 0.4s). The trigger glyph additionally
/// rolls in from a 45° tilt.
///
/// Submitting swaps the inner view (form → sent / error) on a short blur-up
/// (`EASE_OUT`, 0.24s in / 0.16s out). Success bursts a ring of eight sprinkles
/// (alternating [BeuiColors.success] / [BeuiColors.accent]), pops a success
/// badge on a bespoke spring (stiffness 500 · damping 22) and strokes a check,
/// then auto-dismisses after 1.6s.
///
/// **Self-managed** (matching the source, which owns its own open + message
/// state): the only callback is [onSubmit]. It may be async — the Submit button
/// shows a sending state until it resolves; a thrown error routes to the retry
/// view (the typed message is preserved so a rejected submit can be retried).
///
/// Dismisses on Escape or an outside tap while open (never mid-send) — and the
/// typed draft survives every one of those, so a stray tap outside no longer
/// destroys a half-written report. The text is cleared only by a submit that
/// actually succeeded.
///
/// Every control is keyboard-reachable (trigger, close, sentiment chips) and
/// carries a 44px hit area over its painted size. Anchor it inside a bounded
/// [Stack]/box (see the example) — it aligns itself to the chosen [position]
/// corner with a 16px inset and grows from that corner.
///
/// Reduced motion drops every transform (slide/scale/rotate/blur and the
/// sprinkle burst) and keeps only the opacity/color cross-fades; the shell
/// resizes instantly (source `duration: 0`) and the field focuses immediately.
class BeuiFeedbackWidget extends StatefulWidget {
  /// Creates a feedback widget.
  const BeuiFeedbackWidget({
    this.onSubmit,
    this.position = BeuiFeedbackPosition.bottomRight,
    this.title = 'Help us improve',
    this.placeholder = 'Share an idea or report a bug',
    this.icon,
    this.style,
    this.showSentiment = false,
    this.sentimentLabel = 'How was your experience?',
    this.positiveLabel = 'Good',
    this.negativeLabel = 'Bad',
    this.minLines = 3,
    this.maxLines = 6,
    this.emptyMessage = 'Write a little about what happened first.',
    super.key,
  }) : assert(maxLines >= minLines);

  /// Called on submit. May be async; the button shows a sending state until it
  /// resolves. Throwing routes to the error/retry view.
  final FutureOr<void> Function(BeuiFeedbackData data)? onSubmit;

  /// Which bottom corner to anchor to. Defaults to [BeuiFeedbackPosition.bottomRight].
  final BeuiFeedbackPosition position;

  /// Panel heading. Defaults to `Help us improve`.
  final String title;

  /// Textarea placeholder. Defaults to `Share an idea or report a bug`.
  final String placeholder;

  /// Trigger glyph. Defaults to [LucideIcons.message_square].
  final IconData? icon;

  /// Optional visual overrides.
  final BeuiFeedbackWidgetStyle? style;

  /// Shows a two-button sentiment row above the textarea.
  ///
  /// Off by default, for fidelity with the source, which has no rating
  /// dimension. Turning it on is the single highest-leverage change available
  /// here: one tap is a complete response, so people who would never write a
  /// paragraph still tell you something, and the ones who do write get a frame
  /// to write inside. The chosen sentiment arrives on [BeuiFeedbackData].
  final bool showSentiment;

  /// Heading above the sentiment row.
  final String sentimentLabel;

  /// Label for the positive choice.
  final String positiveLabel;

  /// Label for the negative choice.
  final String negativeLabel;

  /// Rows the textarea starts at.
  final int minLines;

  /// Rows the textarea grows to before it scrolls.
  ///
  /// The field used to be pinned at three rows, so anything longer than a
  /// couple of sentences was written through a letterbox. It now grows.
  final int maxLines;

  /// Shown under the field when Submit is pressed with nothing written.
  ///
  /// Submit stays enabled and explains itself rather than sitting greyed out
  /// with no reason given.
  final String emptyMessage;

  @override
  State<BeuiFeedbackWidget> createState() => _BeuiFeedbackWidgetState();
}

class _BeuiFeedbackWidgetState extends State<BeuiFeedbackWidget> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  _Status _status = _Status.idle;
  Timer? _closeTimer;
  Timer? _focusTimer;
  BeuiFeedbackSentiment? _sentiment;
  bool _showEmptyError = false;

  bool get _open => _status != _Status.idle;
  bool get _busy => _status == _Status.sending;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _focusTimer?.cancel();
    _text.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _clearCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _openPanel() {
    if (_open) return;
    _clearCloseTimer();
    final reduce = MediaQuery.disableAnimationsOf(context);
    setState(() => _status = _Status.open);

    // The field used to be armed only after the full 400ms open morph, which
    // left a dead zone long enough to swallow the first characters of anyone
    // who started typing straight away — and a caret is not a transform, so
    // there is nothing to protect it from. Focus lands well before the morph
    // finishes and simply rides it.
    _focusTimer?.cancel();
    _focusTimer = Timer(
      reduce ? Duration.zero : const Duration(milliseconds: 180),
      () {
        if (mounted) _fieldFocus.requestFocus();
      },
    );
  }

  void _close() {
    if (_busy) return;
    _clearCloseTimer();
    _focusTimer?.cancel();
    _fieldFocus.unfocus();
    setState(() {
      _status = _Status.idle;
      _showEmptyError = false;
      // The draft is NOT cleared here. A stray outside tap used to destroy
      // whatever had been typed, with no confirmation and no undo — and the
      // error path already proved drafts can survive a state change. Text now
      // survives every close and is cleared only by a successful submit, so
      // reopening resumes where the user left off.
    });
  }

  /// Auto-dismisses the success view — unless a screen reader is running.
  ///
  /// 1.6s is comfortably shorter than it takes an assistive technology to
  /// announce the confirmation, so the panel used to self-destruct mid-sentence
  /// and the one moment the user most needs confirming was the one they never
  /// heard. With a reader active the view holds until it is dismissed.
  void _scheduleSuccessClose() {
    _clearCloseTimer();
    if (MediaQuery.accessibleNavigationOf(context)) return;
    _closeTimer = Timer(_successDuration, _close);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_text.text.trim().isEmpty) {
      // Explain, rather than presenting a dead button and leaving the user to
      // work out which of the two fields is the problem.
      setState(() => _showEmptyError = true);
      _fieldFocus.requestFocus();
      return;
    }
    setState(() {
      _showEmptyError = false;
      _status = _Status.sending;
    });
    try {
      await widget.onSubmit?.call(
        BeuiFeedbackData(message: _text.text, sentiment: _sentiment),
      );
      if (!mounted) return;
      setState(() => _status = _Status.sent);
      // The only place the draft is discarded: it actually went somewhere.
      _text.clear();
      _sentiment = null;
      _scheduleSuccessClose();
    } catch (_) {
      // Preserve the message so a rejected submission can be retried.
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final style = widget.style;

    final triggerSize = style?.triggerSize ?? 48.0;
    final openRadius = style?.openRadius ?? 20.0;
    final triggerRadius = style?.triggerRadius ?? 40.0;
    final edgeInset = style?.edgeInset ?? 16.0;
    final maxWidth = style?.maxWidth ?? 320.0;
    final surface = style?.surfaceColor ?? colors.background;
    final card =
        style?.cardColor ??
        colors.border.withValues(alpha: colors.border.a * 0.6);
    final success = style?.successColor ?? colors.success;

    final left = widget.position == BeuiFeedbackPosition.bottomLeft;
    final contentOffset = left ? -_morphSlide : _morphSlide;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxWidth + edgeInset * 2;
        final openW = math
            .min(maxWidth, available * 0.86)
            .clamp(triggerSize, double.infinity);
        final innerW = openW - 16; // p-2 shell padding on both sides.

        final morphDuration = reduce
            ? Duration.zero
            : (_open ? _morphOpenDuration : _morphCloseDuration);
        final morphCurve = _open ? _morphOpenEase : _morphCloseEase;

        // The trigger↔panel swap. popLayout-style: the two views cross-fade with
        // opposite x-slides so the surface reads as one continuous morph.
        final content = AnimatedSwitcher(
          duration: _morphOpenDuration,
          reverseDuration: _morphCloseDuration,
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
            children: [...previousChildren, ?currentChild],
          ),
          transitionBuilder: (child, animation) => _MorphSlot(
            animation: animation,
            isPanel: child.key == const ValueKey('panel'),
            contentOffset: contentOffset,
            reduce: reduce,
            child: child,
          ),
          child: _open
              ? SizedBox(
                  key: const ValueKey('panel'),
                  width: openW,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _panel(
                      colors: colors,
                      card: card,
                      success: success,
                      innerW: innerW - 16,
                      reduce: reduce,
                    ),
                  ),
                )
              : SizedBox(
                  key: const ValueKey('trigger'),
                  width: triggerSize,
                  height: triggerSize,
                  child: _trigger(colors),
                ),
        );

        // The persistent shell grows out of the corner. [AnimatedContainer] sizes
        // to the content and morphs only its decoration (radius 40→20, colour,
        // shadow); [AnimatedSize] morphs the *rendered* size between the trigger
        // (48×48) and the panel, laying the content out at its natural size and
        // clipping it — so text can never rewrap or overflow mid-morph. Overshoot
        // on open, calmer on close.
        Widget shell = AnimatedContainer(
          duration: morphDuration,
          curve: morphCurve,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(
              _open ? openRadius : triggerRadius,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 15,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: content,
        );
        // Reduced motion resizes instantly (source `duration: 0`); an
        // AnimatedSize would both be pointless and, at zero duration, re-dirty
        // itself during layout. Only wrap it when motion is enabled.
        if (!reduce) {
          shell = AnimatedSize(
            duration: morphDuration,
            curve: morphCurve,
            alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
            child: shell,
          );
        }

        // Escape + outside-tap dismissal, only while open and not mid-send.
        if (_open) {
          shell = TapRegion(
            onTapOutside: _busy ? null : (_) => _close(),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (!_busy) _close();
                },
              },
              child: Focus(child: shell),
            ),
          );
        }

        return Align(
          alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
          child: Padding(padding: EdgeInsets.all(edgeInset), child: shell),
        );
      },
    );
  }

  Widget _trigger(BeuiColors colors) {
    return _IconAction(
      colors: colors,
      label: widget.title,
      onPressed: _openPanel,
      // The trigger fills the 48px capsule it lives in, so it needs no extra
      // slop — only the tab stop and the activation keys it was missing.
      size: null,
      radius: 24,
      child: Center(
        child: Icon(
          widget.icon ?? LucideIcons.message_square,
          size: 20,
          color: colors.foreground,
        ),
      ),
    );
  }

  Widget _panel({
    required BeuiColors colors,
    required Color card,
    required Color success,
    required double innerW,
    required bool reduce,
  }) {
    // Inner view swap (form / sent / error): a short blur-up, exit faster than
    // entrance (source EASE_OUT, 0.24s in / 0.16s out).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
      switchInCurve: beuiEaseOut,
      switchOutCurve: beuiEaseOut,
      transitionBuilder: (child, animation) =>
          _ViewSlot(animation: animation, reduce: reduce, child: child),
      child: switch (_status) {
        _Status.sent => _SentView(
          key: const ValueKey('sent'),
          colors: colors,
          card: card,
          success: success,
          reduce: reduce,
        ),
        _Status.error => _ErrorView(
          key: const ValueKey('error'),
          colors: colors,
          card: card,
          onRetry: _submit,
        ),
        _ => _formView(colors: colors, card: card, innerW: innerW),
      },
    );
  }

  Widget _formView({
    required BeuiColors colors,
    required Color card,
    required double innerW,
  }) {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CloseButton(colors: colors, onTap: _close),
                ],
              ),
              if (widget.showSentiment) ...[
                const SizedBox(height: 10),
                _SentimentRow(
                  colors: colors,
                  label: widget.sentimentLabel,
                  positiveLabel: widget.positiveLabel,
                  negativeLabel: widget.negativeLabel,
                  value: _sentiment,
                  enabled: !_busy,
                  onChanged: (v) =>
                      setState(() => _sentiment = _sentiment == v ? null : v),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                focusNode: _fieldFocus,
                enabled: !_busy,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                cursorColor: colors.foreground,
                onChanged: (_) => setState(() {
                  if (_showEmptyError && _text.text.trim().isNotEmpty) {
                    _showEmptyError = false;
                  }
                }),
                style: TextStyle(fontSize: 14, color: colors.foreground),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    // Full-strength `mutedForeground` (5.9:1); the 0.6
                    // multiplier put it at 2.55:1.
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              if (_showEmptyError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Text(
                      widget.emptyMessage,
                      style: TextStyle(fontSize: 12, color: colors.destructive),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: BeuiButton(
                  variant: BeuiButtonVariant.secondary,
                  onPressed: _busy ? null : _close,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BeuiStatefulButton(
                  label: 'Submit',
                  loadingText: 'Sending',
                  state: _busy ? BeuiButtonState.loading : BeuiButtonState.idle,
                  // Enabled even when empty: a disabled button explains
                  // nothing, and pressing it now says what is missing.
                  onPressed: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The trigger↔panel morph slot. Slides in from ±[contentOffset], scales
/// 0.97→1 and blurs 2px→0 (the panel); the trigger additionally rolls in from a
/// 45° tilt. Opacity/blur finish on the compressed [_morphFadeFraction] window
/// while the positional channels ride the full duration — both on
/// `MORPH_CLOSE_EASE`. Reduced motion keeps opacity only.
class _MorphSlot extends StatelessWidget {
  const _MorphSlot({
    required this.animation,
    required this.isPanel,
    required this.contentOffset,
    required this.reduce,
    required this.child,
  });

  final Animation<double> animation;
  final bool isPanel;
  final double contentOffset;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t =
            animation.value; // linear 0..1 (reversed for the exiting view)
        final fadeRaw = (t / _morphFadeFraction).clamp(0.0, 1.0);
        final opacity = _morphCloseEase.transform(fadeRaw);
        if (reduce) return Opacity(opacity: opacity, child: child);

        final move = _morphCloseEase.transform(t);
        final dir = isPanel ? contentOffset : -contentOffset;
        final dx = (1 - move) * dir;
        final scale = _lerp(_morphScale, 1, move);
        final blur = (1 - opacity) * beuiBlurSigma(_morphBlurPx);
        final rotation = isPanel ? 0.0 : (1 - move) * (math.pi / 4);

        Widget result = child!;
        if (blur > 0.01) {
          result = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: result,
          );
        }
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(scale: scale, child: result),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// The inner form/sent/error view transition: rise 8px with a 4px blur-up,
/// cross-fading on `EASE_OUT`. Reduced motion keeps opacity only.
class _ViewSlot extends StatelessWidget {
  const _ViewSlot({
    required this.animation,
    required this.reduce,
    required this.child,
  });

  final Animation<double> animation;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        if (reduce) return Opacity(opacity: t, child: child);
        final dy = (1 - t) * 8;
        final blur = (1 - t) * beuiBlurSigma(4);
        Widget result = child!;
        if (blur > 0.01) {
          result = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: result,
          );
        }
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: result),
        );
      },
      child: child,
    );
  }
}

/// The small circular close (X) button in the form header.
///
/// Painted at 20px — under even WCAG 2.5.8's relaxed 24px floor, let alone the
/// 44px one — and previously pointer-only. The paint is unchanged (this is a
/// fidelity port) but the hit area is now 44px and it is reachable, focusable
/// and activatable from a keyboard.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.colors, required this.onTap});

  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _IconAction(
      colors: colors,
      label: 'Close',
      onPressed: onTap,
      size: 20,
      radius: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.foreground.withValues(alpha: 0.07),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(LucideIcons.x, size: 12, color: colors.mutedForeground),
        ),
      ),
    );
  }
}

/// An icon control with the full interactive contract: button semantics,
/// Enter/Space activation, a hover cursor, a non-shifting focus ring, and at
/// least 44px of hit area over whatever it paints.
class _IconAction extends StatefulWidget {
  const _IconAction({
    required this.colors,
    required this.label,
    required this.onPressed,
    required this.size,
    required this.radius,
    required this.child,
  });

  final BeuiColors colors;
  final String label;
  final VoidCallback onPressed;

  /// Painted size, or null to fill the parent.
  final double? size;
  final double radius;
  final Widget child;

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final Widget body = BeuiFocusRing(
      focused: _focusVisible,
      borderRadius: BorderRadius.circular(widget.radius),
      child: widget.size == null
          ? widget.child
          : SizedBox(
              width: widget.size,
              height: widget.size,
              child: widget.child,
            ),
    );

    // The slop must be the OUTERMOST wrapper. Every widget between it and the
    // pointer is a RenderProxyBox, and RenderProxyBox.hitTest rejects anything
    // outside its own size before descending — so a Semantics or a gesture
    // detector above it would swallow the very pointers the slop exists to
    // catch, and the extra area would be dead.
    Widget wrap(Widget child) =>
        widget.size == null ? child : BeuiMinHitTarget(child: child);

    return wrap(
      Semantics(
        button: true,
        label: widget.label,
        onTap: widget.onPressed,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: body,
          ),
        ),
      ),
    );
  }
}

/// The opt-in sentiment row: two selectable chips above the textarea.
class _SentimentRow extends StatelessWidget {
  const _SentimentRow({
    required this.colors,
    required this.label,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final BeuiColors colors;
  final String label;
  final String positiveLabel;
  final String negativeLabel;
  final BeuiFeedbackSentiment? value;
  final bool enabled;
  final ValueChanged<BeuiFeedbackSentiment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.mutedForeground),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SentimentChip(
                colors: colors,
                icon: LucideIcons.thumbs_up,
                label: positiveLabel,
                selected: value == BeuiFeedbackSentiment.positive,
                enabled: enabled,
                onPressed: () => onChanged(BeuiFeedbackSentiment.positive),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SentimentChip(
                colors: colors,
                icon: LucideIcons.thumbs_down,
                label: negativeLabel,
                selected: value == BeuiFeedbackSentiment.negative,
                enabled: enabled,
                onPressed: () => onChanged(BeuiFeedbackSentiment.negative),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SentimentChip extends StatefulWidget {
  const _SentimentChip({
    required this.colors,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final BeuiColors colors;
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_SentimentChip> createState() => _SentimentChipState();
}

class _SentimentChipState extends State<_SentimentChip> {
  bool _hovered = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final on = widget.selected;
    final fg = on ? colors.foreground : colors.mutedForeground;
    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        // Reported as a toggle, so its state is audible as well as visible.
        toggled: on,
        enabled: widget.enabled,
        label: widget.label,
        onTap: widget.enabled ? widget.onPressed : null,
        child: FocusableActionDetector(
          enabled: widget.enabled,
          mouseCursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          onShowHoverHighlight: (v) => setState(() => _hovered = v),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onPressed : null,
            child: BeuiFocusRing(
              focused: _focusVisible,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.ease,
                height: 32,
                decoration: BoxDecoration(
                  color: on
                      ? colors.foreground.withValues(alpha: 0.08)
                      : (_hovered ? colors.muted : Colors.transparent),
                  border: Border.all(
                    color: on ? colors.foreground : colors.border,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                          color: fg,
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
  }
}

/// The success celebration view: a sprinkle burst + a popping success badge with
/// a self-drawing check, and the "Thanks!" copy.
class _SentView extends StatelessWidget {
  const _SentView({
    required this.colors,
    required this.card,
    required this.success,
    required this.reduce,
    super.key,
  });

  final BeuiColors colors;
  final Color card;
  final Color success;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      // The confirmation was purely visual: a sighted user got a sprinkle
      // burst and a check, a screen-reader user got 1.6s of silence and then
      // the panel vanishing. Announce it.
      liveRegion: true,
      label: 'Thanks! Your feedback helps us build something better.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: _SuccessBadge(success: success, reduce: reduce),
            ),
            const SizedBox(height: 12),
            // Excluded because the live-region label above already carries this
            // copy; left in, a reader would say it twice.
            ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Thanks!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your feedback helps us build something better.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 48px success badge: eight sprinkles burst outward, the disc pops on a
/// bespoke spring (stiffness 500 · damping 22, +0.04s), and the check strokes on
/// (0.35s EASE_OUT, +0.15s). Under reduced motion the disc + check appear
/// instantly and no sprinkles fire.
class _SuccessBadge extends StatefulWidget {
  const _SuccessBadge({required this.success, required this.reduce});

  final Color success;
  final bool reduce;

  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge>
    with TickerProviderStateMixin {
  // Bespoke pop spring — source `{ type: "spring", stiffness: 500, damping: 22 }`
  // (Framer default mass 1). Drives the disc scale 0→1.
  static const SpringMotion _pop = SpringMotion(
    SpringDescription(mass: 1, stiffness: 500, damping: 22),
  );

  late final AnimationController _check = AnimationController(
    vsync: this,
    // 0.35s draw + 0.15s delay.
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _draw = CurvedAnimation(
    parent: _check,
    curve: const Interval(0.15 / 0.5, 1, curve: beuiEaseOut),
  );

  bool _popped = false;
  Timer? _popTimer;

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _popped = true;
      _check.value = 1;
    } else {
      _popTimer = Timer(const Duration(milliseconds: 40), () {
        if (mounted) setState(() => _popped = true);
      });
      _check.forward();
    }
  }

  @override
  void dispose() {
    _popTimer?.cancel();
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = BeuiColors.resolve(context).accent;

    final disc = SingleMotionBuilder(
      value: _popped ? 1.0 : 0.0,
      motion: _pop,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.success,
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: _draw,
              builder: (context, _) => CustomPaint(
                size: const Size(20, 20),
                painter: _CheckPainter(progress: _draw.value),
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (!widget.reduce)
          for (var i = 0; i < 8; i++)
            _Sprinkle(
              angle: (i / 8) * math.pi * 2,
              delayMs: 180 + i * 20,
              color: i.isEven ? widget.success : accent,
            ),
        disc,
      ],
    );
  }
}

/// One celebration sprinkle: bursts from center to radius 26 while its opacity
/// keyframes [0,1,0] and scale keyframes [0,1,0.4] over 0.6s (source `SPRINKLES`).
class _Sprinkle extends StatefulWidget {
  const _Sprinkle({
    required this.angle,
    required this.delayMs,
    required this.color,
  });

  final double angle;
  final int delayMs;
  final Color color;

  @override
  State<_Sprinkle> createState() => _SprinkleState();
}

class _SprinkleState extends State<_Sprinkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  double _kf3(double t, double a, double b, double c) =>
      t < 0.5 ? _lerp(a, b, t / 0.5) : _lerp(b, c, (t - 0.5) / 0.5);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        final dist = 26 * t;
        final x = math.cos(widget.angle) * dist;
        final y = math.sin(widget.angle) * dist;
        final opacity = _kf3(_c.value, 0, 1, 0);
        final scale = _kf3(_c.value, 0, 1, 0.4);
        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Strokes the success check `M5 12.5l4.5 4.5L19 7.5` in a 24×24 space, drawing
/// a leading fraction [progress] of the path.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0);
    final path = Path()
      ..moveTo(5, 12.5)
      ..lineTo(9.5, 17)
      ..lineTo(19, 7.5);
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// The submission-failed view: a destructive badge, copy, and a retry button.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.colors,
    required this.card,
    required this.onRetry,
    super.key,
  });

  final BeuiColors colors;
  final Color card;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.circle_alert,
                size: 20,
                color: colors.destructive,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "We couldn't send your feedback. Please try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            BeuiButton(
              size: BeuiButtonSize.sm,
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
