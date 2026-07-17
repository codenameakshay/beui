import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import 'base.dart';

/// Lifecycle state of a [BeuiStatefulButton].
enum BeuiButtonState {
  /// Resting; shows the label (and optional idle icon).
  idle,

  /// Busy; shows a spinner + loading text; input is locked.
  loading,

  /// Completed; shows a check + success text.
  success,

  /// Failed; shows an ✗ + error text.
  error,
}

/// A [BeuiButton] that morphs between idle / loading / success / error — the
/// Flutter port of beUI's `StatefulButton`.
///
/// Each state swaps a leading icon (spinner / check / ✗) and the label, and the
/// button width morphs to fit. While [BeuiButtonState.loading] the button is
/// disabled and announces busy state. Reduced motion crossfades icon and text
/// (no roll/blur).
class BeuiStatefulButton extends StatelessWidget {
  /// Creates a stateful button.
  const BeuiStatefulButton({
    required this.label,
    this.state = BeuiButtonState.idle,
    this.onPressed,
    this.loadingText = 'Loading',
    this.successText = 'Done',
    this.errorText = 'Try again',
    this.icon,
    this.variant = BeuiButtonVariant.primary,
    this.size = BeuiButtonSize.md,
    super.key,
  });

  /// The idle label.
  final String label;

  /// Current state.
  final BeuiButtonState state;

  /// Tap callback (ignored while loading).
  final VoidCallback? onPressed;

  /// Text shown while loading.
  final String loadingText;

  /// Text shown on success.
  final String successText;

  /// Text shown on error.
  final String errorText;

  /// Optional leading icon shown in the idle state.
  final IconData? icon;

  /// Visual style.
  final BeuiButtonVariant variant;

  /// Size.
  final BeuiButtonSize size;

  String get _text => switch (state) {
    BeuiButtonState.loading => loadingText,
    BeuiButtonState.success => successText,
    BeuiButtonState.error => errorText,
    BeuiButtonState.idle => label,
  };

  /// The leading status icon (spinner / check / ✗) — none while idle.
  IconData? get _leadingIcon => switch (state) {
    BeuiButtonState.loading => LucideIcons.loader_circle,
    BeuiButtonState.success => LucideIcons.check,
    BeuiButtonState.error => LucideIcons.x,
    BeuiButtonState.idle => null,
  };

  /// The trailing idle icon — only shown while idle (matching the source).
  IconData? get _trailingIcon => state == BeuiButtonState.idle ? icon : null;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isBusy = state == BeuiButtonState.loading;

    final textSlot = _CascadeText(_text);

    return Semantics(
      liveRegion: true,
      child: BeuiButton(
        onPressed: isBusy ? null : onPressed,
        variant: variant,
        size: size,
        // Source passes `whileHover={undefined}` to the base Button — the state
        // swap owns the motion, so the 1.02 hover lift is killed here.
        enableHoverScale: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: beuiEaseOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconSlot(
                icon: _leadingIcon,
                spinner: isBusy,
                side: _IconSide.leading,
                reduce: reduce,
              ),
              textSlot,
              _IconSlot(
                icon: _trailingIcon,
                spinner: false,
                side: _IconSide.trailing,
                reduce: reduce,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon slot (source ICON_VARIANTS)
// ---------------------------------------------------------------------------

/// Which end of the row an [_IconSlot] sits on (controls the gap padding and
/// the width-morph reveal direction).
enum _IconSide { leading, trailing }

// Source ICON_VARIANTS tokens (stateful.tsx).
const double _iconBlurSigma = 3; // ROLL_BLUR blur(6px) → sigma 3
const int _iconExitMs = 160; // exit `duration: 0.16`

/// A single leading/trailing icon cell — the Flutter port of the source's
/// `IconSlot` (`ICON_VARIANTS`). On appearance the cell springs open on
/// [beuiSpringSwap] (width 0→24px, scale 0.7→1, opacity 0→1, blur(6px)→0); on
/// removal it collapses over ~160ms [beuiEaseOut]. Reduced motion crossfades
/// (opacity only, no width morph), mirroring the source's `reduce` branch.
class _IconSlot extends StatefulWidget {
  const _IconSlot({
    required this.icon,
    required this.spinner,
    required this.side,
    required this.reduce,
  });

  /// The glyph in this slot; null means the slot is empty.
  final IconData? icon;

  /// Render a spinning loader instead of a static glyph.
  final bool spinner;

  /// Which end of the row this slot occupies.
  final _IconSide side;

  /// Whether reduced motion is active.
  final bool reduce;

  @override
  State<_IconSlot> createState() => _IconSlotState();
}

class _IconSlotState extends State<_IconSlot>
    with SingleTickerProviderStateMixin {
  IconData? _icon;
  bool _spinner = false;

  IconData? _prevIcon;
  bool _prevSpinner = false;
  bool _hasPrev = false;

  // Suppresses the enter animation on the very first mount (source
  // `AnimatePresence initial={false}`); only genuine swaps animate in.
  bool _animateIn = false;

  late final AnimationController _exit =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: _iconExitMs),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _hasPrev) {
          setState(() {
            _hasPrev = false;
            _prevIcon = null;
          });
        }
      });

  bool _sameId(IconData? a, bool aSpin, IconData? b, bool bSpin) =>
      a == b && (a == null || aSpin == bSpin);

  @override
  void initState() {
    super.initState();
    _icon = widget.icon;
    _spinner = widget.spinner;
  }

  @override
  void didUpdateWidget(_IconSlot old) {
    super.didUpdateWidget(old);
    if (!_sameId(widget.icon, widget.spinner, _icon, _spinner)) {
      _prevIcon = _icon;
      _prevSpinner = _spinner;
      _hasPrev = _icon != null; // only a non-empty previous rolls out
      _icon = widget.icon;
      _spinner = widget.spinner;
      _animateIn = true;
      _exit
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  Alignment get _clipAlign => widget.side == _IconSide.leading
      ? Alignment.centerLeft
      : Alignment.centerRight;

  EdgeInsets get _pad => widget.side == _IconSide.leading
      ? const EdgeInsets.only(right: 8)
      : const EdgeInsets.only(left: 8);

  Widget _content(IconData icon, bool spinner) => Padding(
    padding: _pad,
    child: spinner ? const _Spinner(size: 16) : Icon(icon, size: 16),
  );

  Widget _buildEnter(IconData icon, bool spinner) {
    final content = _content(icon, spinner);
    if (!_animateIn) return content;
    final key = ValueKey('enter-${widget.side}-${icon.codePoint}-$spinner');
    if (widget.reduce) {
      // Source reduce branch: opacity crossfade only, no width morph.
      return TweenAnimationBuilder<double>(
        key: key,
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        builder: (context, o, child) => Opacity(opacity: o, child: child),
        child: content,
      );
    }
    return SingleMotionBuilder(
      key: key,
      value: 1,
      from: 0,
      motion: beuiSpringSwap,
      builder: (context, p, child) => _morph(child!, p.clamp(0.0, 1.0)),
      child: content,
    );
  }

  Widget _buildExit(IconData icon, bool spinner) {
    final content = _content(icon, spinner);
    if (widget.reduce) {
      return Opacity(
        opacity: (1 - _exit.value).clamp(0.0, 1.0),
        child: content,
      );
    }
    // Exit rolls the reveal back: width, scale, opacity collapse and blur grows,
    // eased over ~160ms with beuiEaseOut.
    final e = beuiEaseOut.transform(_exit.value);
    return _morph(content, 1 - e);
  }

  /// Applies the ICON_VARIANTS geometry at progress [p] (0 = collapsed/blurred,
  /// 1 = settled): clip width p·24px, scale 0.7→1, opacity 0→1, blur 6px→0.
  Widget _morph(Widget child, double p) {
    Widget g = child;
    final sigma = (1 - p) * _iconBlurSigma;
    if (sigma > 0.05) {
      g = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: g,
      );
    }
    g = Transform.scale(scale: 0.7 + 0.3 * p, child: g);
    g = Opacity(opacity: p.clamp(0.0, 1.0), child: g);
    return ClipRect(
      child: Align(
        alignment: _clipAlign,
        widthFactor: p < 0 ? 0.0 : p,
        child: g,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exit,
      builder: (context, _) {
        final kids = <Widget>[
          if (_hasPrev && _prevIcon != null)
            _buildExit(_prevIcon!, _prevSpinner),
          if (_icon != null) _buildEnter(_icon!, _spinner),
        ];
        if (kids.isEmpty) return const SizedBox.shrink();
        return Row(mainAxisSize: MainAxisSize.min, children: kids);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cascade text (per-letter slot roll — source CASCADE_LETTER_VARIANTS)
// ---------------------------------------------------------------------------

/// Per-letter slot cascade with blur — the Flutter port of the source's
/// StatefulButton text roll (`CASCADE_LETTER_VARIANTS`). On a text change the
/// old letters roll up and out (blurring) while the new letters roll up from
/// below into place, staggered left-to-right and clipped to one line.
///
/// The enter rides the [beuiSpringSwap] token (source `SPRING_SWAP`), released
/// staggered left-to-right; the exit is a ~160ms [beuiEaseOut] tween at half the
/// stagger (source `delay * 0.5`). Same mechanic as `action_swap.dart`.
class _CascadeText extends StatefulWidget {
  const _CascadeText(this.text);

  final String text;

  @override
  State<_CascadeText> createState() => _CascadeTextState();
}

class _CascadeTextState extends State<_CascadeText>
    with SingleTickerProviderStateMixin {
  static const int _staggerMs = 25; // source CASCADE_STAGGER 0.025s
  static const int _enterMs = 360; // covers the SPRING_SWAP settle
  static const int _exitMs = 160; // source exit 0.16s
  static const double _blur = 3; // source ROLL_BLUR blur(6px) → sigma 3

  late final AnimationController _controller;
  late String _current = widget.text;
  String? _previous;

  int _durationMs(String t) =>
      _enterMs + _staggerMs * (t.length - 1).clamp(0, 80);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: _durationMs(_current)),
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _previous != null) {
            setState(() => _previous = null);
          }
        });
  }

  @override
  void didUpdateWidget(_CascadeText old) {
    super.didUpdateWidget(old);
    if (widget.text != _current) {
      _previous = _current;
      _current = widget.text;
      _controller
        ..duration = Duration(milliseconds: _durationMs(_current))
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // At rest (or reduced motion): plain crisp text, no per-letter overhead.
    if (reduce || _previous == null) {
      return Text(_current, style: style, maxLines: 1, softWrap: false);
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final totalMs = _controller.duration!.inMilliseconds;
          final roll = (style.fontSize ?? 14) * 1.15; // ~105% of a line
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Exiting text — positioned, so it doesn't drive the slot width.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _letters(
                  _previous!,
                  t,
                  totalMs,
                  roll,
                  style,
                  exiting: true,
                ),
              ),
              // Entering text — sizes the slot to the new label immediately.
              _letters(_current, t, totalMs, roll, style, exiting: false),
            ],
          );
        },
      ),
    );
  }

  Widget _letters(
    String text,
    double t,
    int totalMs,
    double roll,
    TextStyle style, {
    required bool exiting,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          _letter(text[i], i, t, totalMs, roll, style, exiting: exiting),
      ],
    );
  }

  Widget _letter(
    String char,
    int i,
    double t,
    int totalMs,
    double roll,
    TextStyle style, {
    required bool exiting,
  }) {
    if (exiting) {
      // Exit: 160ms EASE_OUT tween at half the enter stagger (source
      // `delay * 0.5`) — rolls up and out, fading and blurring.
      final start = (i * _staggerMs * 0.5) / totalMs;
      final p = ((t - start) / (_exitMs / totalMs)).clamp(0.0, 1.0);
      final e = beuiEaseOut.transform(p);
      return _glyph(
        char,
        style,
        dy: -e * roll, // roll up and out
        opacity: 1 - e,
        blur: e * _blur,
      );
    }

    // Enter: the SPRING_SWAP token (source CASCADE_LETTER_VARIANTS), released
    // once the shared clock crosses the letter's `index × 25ms` stagger —
    // opacity and blur ride the spring's own progress.
    final released = t * totalMs >= i * _staggerMs;
    return SingleMotionBuilder(
      value: released ? 0.0 : roll,
      from: roll,
      motion: beuiSpringSwap,
      builder: (context, dy, child) {
        final p = (1 - dy / roll).clamp(0.0, 1.0);
        Widget glyph = child!;
        final sigma = (1 - p) * _blur;
        if (sigma > 0.05) {
          glyph = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: glyph,
          );
        }
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, dy), child: glyph),
        );
      },
      child: Text(char, style: style, maxLines: 1, softWrap: false),
    );
  }

  Widget _glyph(
    String char,
    TextStyle style, {
    required double dy,
    required double opacity,
    required double blur,
  }) {
    Widget glyph = Text(char, style: style, maxLines: 1, softWrap: false);
    if (blur > 0.05) {
      glyph = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: glyph,
      );
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, dy), child: glyph),
    );
  }
}

/// A continuously spinning loader icon.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.size});
  final double size;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(LucideIcons.loader_circle, size: widget.size),
    );
  }
}
