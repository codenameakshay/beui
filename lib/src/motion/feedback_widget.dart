import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder, SpringMotion;
import 'button/base.dart';
import 'button/stateful.dart';

/// The payload handed to [BeuiFeedbackWidget.onSubmit] — the port of the source
/// `FeedbackData` interface.
@immutable
class BeuiFeedbackData {
  /// Creates a feedback payload.
  const BeuiFeedbackData({required this.message});

  /// The message the user typed.
  final String message;
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
/// Dismisses on Escape or an outside tap while open (never mid-send). Anchor it
/// inside a bounded [Stack]/box (see the example) — it aligns itself to the
/// chosen [position] corner with a 16px inset and grows from that corner.
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
    super.key,
  });

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

  @override
  State<BeuiFeedbackWidget> createState() => _BeuiFeedbackWidgetState();
}

class _BeuiFeedbackWidgetState extends State<BeuiFeedbackWidget> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  _Status _status = _Status.idle;
  Timer? _closeTimer;
  Timer? _focusTimer;

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

    // Match the source: arm the field once the open morph has settled so the
    // caret doesn't appear inside a still-scaling panel.
    _focusTimer?.cancel();
    _focusTimer = Timer(reduce ? Duration.zero : _morphOpenDuration, () {
      if (mounted) _fieldFocus.requestFocus();
    });
  }

  void _close() {
    if (_busy) return;
    _clearCloseTimer();
    _focusTimer?.cancel();
    _fieldFocus.unfocus();
    setState(() {
      _status = _Status.idle;
      _text.clear();
    });
  }

  void _scheduleSuccessClose() {
    _clearCloseTimer();
    _closeTimer = Timer(_successDuration, _close);
  }

  Future<void> _submit() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() => _status = _Status.sending);
    try {
      await widget.onSubmit?.call(BeuiFeedbackData(message: _text.text));
      if (!mounted) return;
      setState(() => _status = _Status.sent);
      _scheduleSuccessClose();
    } catch (_) {
      // Preserve the message so a rejected submission can be retried.
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final style = widget.style;

    final triggerSize = style?.triggerSize ?? 48.0;
    final openRadius = style?.openRadius ?? 20.0;
    final triggerRadius = style?.triggerRadius ?? 40.0;
    final edgeInset = style?.edgeInset ?? 16.0;
    final maxWidth = style?.maxWidth ?? 320.0;
    final surface = style?.surfaceColor ?? colors.background;
    final card = style?.cardColor ?? colors.border.withValues(alpha: 0.6);
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
            children: [
              ...previousChildren,
              ?currentChild,
            ],
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
    return Semantics(
      button: true,
      label: widget.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openPanel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Center(
            child: Icon(
              widget.icon ?? LucideIcons.message_square,
              size: 20,
              color: colors.foreground,
            ),
          ),
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
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                focusNode: _fieldFocus,
                enabled: !_busy,
                minLines: 3,
                maxLines: 3,
                cursorColor: colors.foreground,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 14, color: colors.foreground),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colors.mutedForeground.withValues(alpha: 0.6),
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
                  state: _busy
                      ? BeuiButtonState.loading
                      : BeuiButtonState.idle,
                  onPressed: (_busy || _text.text.trim().isEmpty)
                      ? null
                      : _submit,
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
        final t = animation.value; // linear 0..1 (reversed for the exiting view)
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
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.colors, required this.onTap});

  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.foreground.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.x,
              size: 12,
              color: colors.mutedForeground,
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
    return Container(
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
    final accent = Theme.of(context).extension<BeuiColors>()?.accent ??
        widget.success;

    final disc = SingleMotionBuilder(
      value: _popped ? 1.0 : 0.0,
      motion: _pop,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(color: widget.success, shape: BoxShape.circle),
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
