import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_shake.dart';

// The success accent (source Tailwind `emerald-500`). Distinct from
// [BeuiColors.success] (a different oklch hue) — the source hardcodes this
// exact swatch for the OTP check and border, not the theme's success token.
const _emerald500 = Color(0xFF10B981);

/// External validation state of a [BeuiOtpInput] (source `OTPStatus`).
enum BeuiOtpStatus {
  /// No feedback.
  idle,

  /// Shakes the row and shows [BeuiOtpInput.errorMessage].
  error,

  /// Draws the check and shows [BeuiOtpInput.successMessage].
  success,
}

/// One-time-passcode input with a gliding caret, roll-in digits, error shake
/// and success check draw — the Flutter port of beUI's `OTPInput`.
///
/// The slot grid is purely presentational; input is owned by a transparent
/// [EditableText] whose text is kept mirrored to the joined code. Soft-keyboard
/// edits are diffed old->new and applied at the active slot, so digit-by-digit
/// entry accumulates and advances and a delete steps back; paste / SMS autofill
/// (via [AutofillHints.oneTimeCode]) spreads a whole code across the slots. A
/// hardware-key handler covers physical keyboards (digits overwrite the active
/// slot and advance, backspace clears in place or steps back, delete clears,
/// arrows/home/end move the caret); the two paths guard each other so a desktop
/// keystroke is never applied twice. State is a fixed-length slot array, so
/// clearing a middle slot leaves an in-place hole (the source's deliberate
/// behavior).
///
/// Reduced motion drops the digit roll/blur, caret blink, shake and check
/// scale-pop; fades and the drawn check remain instant.
class BeuiOtpInput extends StatefulWidget {
  /// Creates an OTP input.
  const BeuiOtpInput({
    this.length = 6,
    this.value,
    this.defaultValue = '',
    this.onChanged,
    this.onComplete,
    this.label,
    this.hint,
    this.successMessage,
    this.errorMessage,
    this.status = BeuiOtpStatus.idle,
    this.mask = false,
    this.disabled = false,
    this.autofocus = false,
    this.semanticLabel = 'One-time passcode',
    super.key,
  });

  /// Number of slots (source `length = 6`).
  final int length;

  /// Controlled value; null for uncontrolled (with [defaultValue]).
  final String? value;

  /// Initial digits when uncontrolled.
  final String defaultValue;

  /// Fires with the joined digits on every edit.
  final ValueChanged<String>? onChanged;

  /// Fires once on the empty→full transition (source `onComplete`).
  final ValueChanged<String>? onComplete;

  /// Optional label rendered above the slots.
  final String? label;

  /// Helper text below the slots while idle.
  final String? hint;

  /// Message below the slots when [status] is success.
  final String? successMessage;

  /// Message below the slots when [status] is error.
  final String? errorMessage;

  /// External validation feedback.
  final BeuiOtpStatus status;

  /// Render dots instead of the typed digits.
  final bool mask;

  /// Disables input and dims the grid.
  final bool disabled;

  /// Focus the input on mount (opt-in, for OTP-first screens).
  final bool autofocus;

  /// Accessible label for the underlying input (source `aria-label`).
  final String semanticLabel;

  @override
  State<BeuiOtpInput> createState() => _BeuiOtpInputState();
}

String _sanitize(String raw, int length) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > length ? digits.substring(0, length) : digits;
}

List<String> _toSlots(String raw, int length) {
  final digits = _sanitize(raw, length);
  return List.generate(length, (i) => i < digits.length ? digits[i] : '');
}

// Slot metrics (source: h-14 w-12 gap-2 rounded-xl text-xl).
const _slotWidth = 48.0;
const _slotHeight = 56.0;
const _slotGap = 8.0;

class _BeuiOtpInputState extends State<BeuiOtpInput>
    with SingleTickerProviderStateMixin {
  late List<String> _slots = _toSlots(
    widget.value ?? widget.defaultValue,
    widget.length,
  );
  int _active = 0;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'BeuiOtpInput');
  bool _focused = false;

  /// The last value we pushed into [_controller]; the baseline the native
  /// [_onNativeChanged] diff compares against. Kept equal to [_joined].
  String _lastSynced = '';

  /// Set when [_onKey] applies a hardware keystroke; makes the paired native
  /// [_onNativeChanged] echo (desktop IME re-reporting the same key) a no-op.
  bool _hardwareGuard = false;

  /// Set when [_onNativeChanged] applies a soft/IME edit; makes a paired
  /// hardware [_onKey] echo (reverse dispatch order on desktop) a no-op.
  bool _softGuard = false;

  /// Error shake — imperative so it replays on every transition into error.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  String get _joined => _slots.join();

  @override
  void initState() {
    super.initState();
    _syncController();
    _focusNode.addListener(() {
      if (_focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void didUpdateWidget(BeuiOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final joinedBefore = _joined;
    // Pull in external value changes; skip the parent echoing our own
    // onChanged so internal holes survive the controlled round-trip.
    final value = widget.value;
    if (value != null && _sanitize(value, widget.length) != _joined) {
      _slots = _toSlots(value, widget.length);
    }
    if (widget.length != oldWidget.length) {
      _slots = _toSlots(_joined, widget.length);
      _active = _active.clamp(0, widget.length - 1);
    }
    // Re-mirror the hidden field only when the digits actually moved, so a bare
    // parent rebuild never disturbs an in-flight caret / IME composition.
    if (_joined != joinedBefore) _syncController();
    if (widget.status == BeuiOtpStatus.error &&
        oldWidget.status != BeuiOtpStatus.error &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _commit(List<String> next) {
    final wasComplete = _slots.every((c) => c.isNotEmpty);
    setState(() => _slots = next);
    final str = next.join();
    widget.onChanged?.call(str);
    // Fire only on the empty→full transition, not on every edit of a full code.
    if (!wasComplete && next.every((c) => c.isNotEmpty)) {
      widget.onComplete?.call(str);
    }
    // Truth is the slot array; the hidden field always mirrors it so the native
    // diff has a stable baseline and a soft-keyboard backspace has something to
    // delete (an empty field would emit no change event).
    _syncController();
  }

  /// Mirror the hidden [EditableText] to the joined code, caret at the end.
  /// Programmatic assignment never re-invokes [_onNativeChanged], so this is
  /// safe to call from inside that handler.
  void _syncController() {
    final text = _joined;
    _lastSynced = text;
    final selection = TextSelection.collapsed(offset: text.length);
    if (_controller.text != text || _controller.selection != selection) {
      _controller.value = TextEditingValue(text: text, selection: selection);
    }
  }

  /// Source's backspace: a filled active slot clears in place; an empty one
  /// steps back and clears there. Shared by the hardware and native paths.
  void _backspace() {
    if (_slots[_active].isNotEmpty) {
      _clearSlot(_active);
    } else if (_active > 0) {
      _clearSlot(_active - 1);
      setState(() => _active -= 1);
    }
  }

  void _armGuard({required bool hardware}) {
    if (hardware) {
      _hardwareGuard = true;
    } else {
      _softGuard = true;
    }
    _scheduleGuardClear();
  }

  // A hardware key and its IME echo (or vice versa) land within one frame, so a
  // post-frame reset bounds the guard to that pair without swallowing the next
  // genuine event.
  void _scheduleGuardClear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hardwareGuard = false;
      _softGuard = false;
    });
  }

  void _clearSlot(int index) {
    final next = [..._slots];
    next[index] = '';
    _commit(next);
  }

  /// Single insertion path: one digit overwrites the active slot and advances;
  /// a multi-digit chunk (paste / autofill) fills forward from [from].
  void _insert(String raw, {int? from}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final next = [..._slots];
    var i = from ?? _active;
    for (final ch in digits.split('')) {
      if (i >= widget.length) break;
      next[i] = ch;
      i++;
    }
    _commit(next);
    setState(() => _active = i.clamp(0, widget.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.disabled) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final digit = _digitOf(key);
    final mutatesText =
        digit != null ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete;
    // Reverse dispatch order on desktop: the IME's onChanged already applied
    // this keystroke, so swallow the raw-key echo instead of double-applying.
    if (mutatesText && _softGuard) {
      _softGuard = false;
      return KeyEventResult.handled;
    }
    if (digit != null) {
      _insert(digit);
      _armGuard(hardware: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      _armGuard(hardware: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _clearSlot(_active);
      _armGuard(hardware: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _active = (_active - 1).clamp(0, widget.length - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _active = (_active + 1).clamp(0, widget.length - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      setState(() => _active = 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      setState(() => _active = widget.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String? _digitOf(LogicalKeyboardKey key) {
    final id = key.keyId;
    if (id >= LogicalKeyboardKey.digit0.keyId &&
        id <= LogicalKeyboardKey.digit9.keyId) {
      return String.fromCharCode(0x30 + (id - LogicalKeyboardKey.digit0.keyId));
    }
    if (id >= LogicalKeyboardKey.numpad0.keyId &&
        id <= LogicalKeyboardKey.numpad9.keyId) {
      return String.fromCharCode(
        0x30 + (id - LogicalKeyboardKey.numpad0.keyId),
      );
    }
    return null;
  }

  /// Soft-keyboard / IME / paste / autofill path. The field text mirrors the
  /// joined code, so diffing the last-synced value against the incoming one
  /// isolates what the user did: a single digit typed (overwrite the active
  /// slot and advance), a deletion (step back), or a multi-digit chunk pasted /
  /// autofilled (spread across the slots). Re-syncs the mirror afterwards.
  void _onNativeChanged(String raw) {
    if (widget.disabled) return;
    // Echo of a hardware keystroke the raw-key path already applied.
    if (_hardwareGuard) {
      _hardwareGuard = false;
      _syncController();
      return;
    }
    final old = _lastSynced;
    if (raw == old) return;

    // Common prefix / suffix (non-overlapping) bracket the edited span.
    final maxShared = math.min(old.length, raw.length);
    var prefix = 0;
    while (prefix < maxShared && old[prefix] == raw[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < maxShared - prefix &&
        old[old.length - 1 - suffix] == raw[raw.length - 1 - suffix]) {
      suffix++;
    }
    final removed = old.substring(prefix, old.length - suffix);
    final insertedRaw = raw.substring(prefix, raw.length - suffix);
    final inserted = insertedRaw.replaceAll(RegExp(r'\D'), '');

    if (removed.isEmpty && inserted.isEmpty) {
      // Only stray non-digits changed (e.g. an IME space) — drop them.
      _syncController();
      return;
    }

    // A soft edit landed; a paired hardware echo (reverse order) must skip.
    _armGuard(hardware: false);

    if (removed.isNotEmpty && insertedRaw.isEmpty) {
      // Deletion — apply source backspace semantics per removed character.
      for (var i = 0; i < removed.length; i++) {
        _backspace();
      }
    } else if (removed.isEmpty && inserted.length == 1) {
      // One digit typed: overwrite the active slot and advance.
      _insert(inserted, from: _active);
    } else if (old.isEmpty) {
      // Whole code into an empty field — autofill: spread from the start.
      _commit(_toSlots(inserted, widget.length));
      setState(() => _active = inserted.length.clamp(0, widget.length - 1));
    } else if (removed.isEmpty && inserted.length > 1) {
      // A chunk pasted mid-field: spread forward from the active slot.
      _insert(inserted, from: _active);
    } else {
      // Mixed replace / autocorrect: rebuild from the sanitized value.
      final digits = _sanitize(raw, widget.length);
      _commit(_toSlots(digits, widget.length));
      setState(() => _active = digits.length.clamp(0, widget.length - 1));
    }
    // _commit / _insert / _backspace each re-mirror via _syncController.
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.disabled) return;
    final slot = (details.localPosition.dx / (_slotWidth + _slotGap))
        .floor()
        .clamp(0, widget.length - 1);
    // Clamp to the first empty slot so a click can't jump ahead of progress.
    final firstEmpty = _slots.indexWhere((c) => c.isEmpty);
    final cap = firstEmpty == -1 ? widget.length - 1 : firstEmpty;
    setState(() => _active = slot < cap ? slot : cap);
    _focusNode.requestFocus();
  }

  // Shake keyframes (source `x: [0, -5, 5, -3, 3, -1, 0]`, 450ms EASE_OUT,
  // eased per segment — Framer expands a single `ease` to one per keyframe).
  static const _shakeFrames = [0.0, -5.0, 5.0, -3.0, 3.0, -1.0, 0.0];

  double _shakeX(double t) => beuiShakeOffset(t, _shakeFrames, beuiEaseOut);

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final status = widget.status;
    final showSuccess = status == BeuiOtpStatus.success;
    final activeIndex = _focused && !widget.disabled ? _active : -1;
    final message = showSuccess
        ? widget.successMessage
        : status == BeuiOtpStatus.error
        ? widget.errorMessage
        : widget.hint;

    final slotsRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: _slotGap,
      children: [
        for (var i = 0; i < widget.length; i++)
          _Slot(
            char: _slots[i],
            mask: widget.mask,
            active: i == activeIndex,
            status: status,
            disabled: widget.disabled,
            reduce: reduce,
            colors: colors,
          ),
      ],
    );

    final grid = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final x = _shake.isAnimating ? _shakeX(_shake.value) : 0.0;
            return x == 0
                ? child!
                : Transform.translate(offset: Offset(x, 0), child: child);
          },
          child: slotsRow,
        ),
        // The transparent input owns focus, the soft keyboard, paste and
        // autofill; the slots are purely presentational.
        Positioned.fill(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: EditableText(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                readOnly: widget.disabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                backgroundCursorColor: Colors.transparent,
                onChanged: _onNativeChanged,
              ),
            ),
          ),
        ),
        // Tap-to-focus proxy above the hidden input: drives the active slot.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            child: MouseRegion(
              cursor: widget.disabled
                  ? SystemMouseCursors.forbidden
                  : SystemMouseCursors.text,
            ),
          ),
        ),
        if (showSuccess)
          Positioned(
            right: -28, // -right-7
            top: 0,
            bottom: 0,
            child: Center(
              child: _SuccessCheck(reduce: reduce, color: _emerald500),
            ),
          ),
      ],
    );

    return Semantics(
      textField: true,
      label: widget.semanticLabel,
      value: _joined,
      enabled: !widget.disabled,
      child: Focus(
        onKeyEvent: _onKey,
        skipTraversal: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 8, // gap-2
          children: [
            if (widget.label != null)
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 14, // text-sm
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            grid,
            if (message != null)
              Semantics(
                liveRegion: true, // aria-live="polite"
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: showSuccess
                        ? _emerald500
                        : status == BeuiOtpStatus.error
                        ? colors.destructive
                        : colors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.char,
    required this.mask,
    required this.active,
    required this.status,
    required this.disabled,
    required this.reduce,
    required this.colors,
  });

  final String char;
  final bool mask;
  final bool active;
  final BeuiOtpStatus status;
  final bool disabled;
  final bool reduce;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final filled = char.isNotEmpty;
    final showSuccess = status == BeuiOtpStatus.success;

    final Color border;
    final Color textColor;
    if (showSuccess) {
      border = _emerald500.withValues(alpha: 0.6);
      textColor = colors.foreground;
    } else if (status == BeuiOtpStatus.error) {
      border = colors.destructive.withValues(alpha: 0.6);
      textColor = colors.foreground;
    } else if (active) {
      border = colors.foreground; // active reads stronger
      textColor = filled ? colors.foreground : colors.mutedForeground;
    } else if (filled) {
      border = colors.borderStrong;
      textColor = colors.foreground;
    } else {
      border = colors.border;
      textColor = colors.mutedForeground;
    }

    Widget slot = AnimatedContainer(
      duration: const Duration(milliseconds: 200), // transition-colors
      width: _slotWidth,
      height: _slotHeight,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11), // overflow-hidden
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active && !showSuccess)
              _Caret(
                reduce: reduce,
                color: colors.foreground,
                trailing: filled,
              ),
            // Digits roll vertically in place: enter from below with blur,
            // exit up (220ms EASE_OUT, source digit variants).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.linear,
              switchOutCurve: Curves.linear,
              transitionBuilder: (child, animation) => _DigitRoll(
                animation: animation,
                reduce: reduce,
                child: child,
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [...previous, ?current],
              ),
              child: filled
                  ? Text(
                      mask ? '•' : char,
                      key: ValueKey('digit-$char'),
                      style: TextStyle(
                        fontSize: 20, // text-xl
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: textColor,
                        height: 1,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('digit-empty')),
            ),
          ],
        ),
      ),
    );
    if (disabled) slot = Opacity(opacity: 0.5, child: slot);
    return slot;
  }
}

/// The blinking caret — opacity steps `[1, 1, 0, 0]` on a 1s linear loop
/// (static under reduced motion). Centered when the slot is empty, trailing
/// the digit when filled.
class _Caret extends StatefulWidget {
  const _Caret({
    required this.reduce,
    required this.color,
    required this.trailing,
  });

  final bool reduce;
  final Color color;
  final bool trailing;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazily-initialized ticker first touched in dispose()
    // trips TickerMode's deactivated-ancestor lookup.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (!widget.reduce) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(width: 1, height: 24, color: widget.color);
    Widget caret = widget.reduce
        ? bar
        : FadeTransition(
            // opacity keyframes [1, 1, 0, 0] evenly spaced on a linear 1s loop:
            // hold lit, fade out across the middle third, hold dark.
            opacity: _controller.drive(
              Animatable.fromCallback(
                (t) => t < 1 / 3
                    ? 1.0
                    : t < 2 / 3
                    ? 1 - (t - 1 / 3) * 3
                    : 0.0,
              ),
            ),
            child: bar,
          );
    caret = IgnorePointer(child: caret);
    if (widget.trailing) {
      // right-3, measured from the slot's padding box (inside the 1px border).
      return Positioned(right: 12, child: caret);
    }
    return caret; // centered by the enclosing Stack
  }
}

/// The per-digit roll: enter y 14→0 + blur(4px)→0, exit y 0→-14 + blur, all
/// 220ms `EASE_OUT`. Reduced motion is an instant swap.
class _DigitRoll extends StatelessWidget {
  const _DigitRoll({
    required this.animation,
    required this.reduce,
    required this.child,
  });

  final Animation<double> animation;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduce) return FadeTransition(opacity: animation, child: child);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final exiting = animation.status == AnimationStatus.reverse;
        final t = animation.value;
        final eased = beuiEaseOut.transform(t);
        final dy = exiting ? -(1 - eased) * 14 : (1 - eased) * 14;
        final sigma = beuiBlurSigma(4) * (1 - t);
        Widget body = child;
        if (sigma > 0.05) {
          body = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: body,
          );
        }
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: body),
        );
      },
    );
  }
}

/// The verified check: the badge pops on a 500/28 spring while the mark draws
/// itself (350ms `EASE_OUT`, 100ms delay) — a `CustomPaint` path, not an
/// asset, per the icon rules.
class _SuccessCheck extends StatefulWidget {
  const _SuccessCheck({required this.reduce, required this.color});

  final bool reduce;
  final Color color;

  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck>
    with SingleTickerProviderStateMixin {
  // Draw progress: 100ms delay + 350ms EASE_OUT (source pathLength tween).
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  static const _popSpring = SpringMotion(
    SpringDescription(mass: 1, stiffness: 500, damping: 28),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _draw.value = 1;
    } else {
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final check = AnimatedBuilder(
      animation: _draw,
      builder: (context, _) {
        final t = ((_draw.value * 450 - 100) / 350).clamp(0.0, 1.0);
        return CustomPaint(
          size: const Size.square(20),
          painter: _CheckPainter(
            color: widget.color,
            progress: widget.reduce ? 1 : beuiEaseOut.transform(t),
          ),
        );
      },
    );
    if (widget.reduce) return check;
    return SingleMotionBuilder(
      value: 1.0,
      from: 0.0,
      motion: _popSpring,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: check,
    );
  }
}

/// Draws `M5 13l4 4L19 7` (24-viewbox) trimmed to [progress] — the source's
/// SVG `pathLength` draw.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final scale = size.width / 24;
    final path = Path()
      ..moveTo(5 * scale, 13 * scale)
      ..lineTo(9 * scale, 17 * scale)
      ..lineTo(19 * scale, 7 * scale);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
