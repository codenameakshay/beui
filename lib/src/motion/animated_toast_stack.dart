import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Status of a toast — a fixed, exhaustive set mirroring the source
/// `ToastStatus` union. Each status carries a default glyph (source
/// `STATUS_ICON`), overridable per toast via [BeuiToast.icon] or per stack via
/// [BeuiAnimatedToastStack.icons].
enum BeuiToastStatus {
  /// Informationless (source `neutral` → `Bell`).
  neutral(LucideIcons.bell),

  /// Informational (source `info` → `Info`).
  info(LucideIcons.info),

  /// In progress; the default glyph spins (source `loading` → `LoaderCircle`).
  loading(LucideIcons.loader_circle),

  /// Completed successfully (source `success` → `Check`).
  success(LucideIcons.check),

  /// Failed (source `error` → `AlertCircle`, renamed `circle_alert` in
  /// Lucide 1.x).
  error(LucideIcons.circle_alert);

  const BeuiToastStatus(this.icon);

  /// The default glyph for this status.
  final IconData icon;
}

/// Where the stack sits and how it grows (source `ToastPosition`).
///
/// In Flutter the consumer positions the widget (an `Align`/`Positioned` in a
/// `Stack`, or an app-level `Overlay` entry) — the analog of the source's
/// default `placement: "static"`; there is no `document.body` portal to reach
/// for. The position still matters to the widget itself: bottom positions
/// stack the first (oldest) toast nearest the bottom edge and grow upward
/// (source `flex-col-reverse`), top positions grow downward.
enum BeuiToastPosition {
  /// Anchored top-left; the stack grows downward.
  topLeft,

  /// Anchored top-center; the stack grows downward.
  topCenter,

  /// Anchored top-right; the stack grows downward.
  topRight,

  /// Anchored bottom-left; the stack grows upward.
  bottomLeft,

  /// Anchored bottom-center; the stack grows upward.
  bottomCenter,

  /// Anchored bottom-right; the stack grows upward.
  bottomRight;

  /// Whether this is a bottom edge position.
  bool get isBottom =>
      this == bottomLeft || this == bottomCenter || this == bottomRight;
}

/// An action button rendered under a toast's text (source
/// `AnimatedToastAction`).
@immutable
class BeuiToastAction {
  /// Creates a toast action.
  const BeuiToastAction({required this.label, required this.onPressed});

  /// The button label.
  final String label;

  /// Called with the owning toast when pressed.
  final ValueChanged<BeuiToast> onPressed;
}

/// One toast's data (source `AnimatedToast`). Immutable — update a toast by
/// replacing it in the list (or via [BeuiToastController.update]).
@immutable
class BeuiToast {
  /// Creates a toast. [id] must be unique within the stack.
  const BeuiToast({
    required this.id,
    required this.title,
    this.description,
    this.status = BeuiToastStatus.neutral,
    this.icon,
    this.action,
    this.duration,
    this.dismissible = true,
  });

  /// Unique identity — drives enter/exit animations across list updates.
  final String id;

  /// Primary line.
  final String title;

  /// Secondary line, up to two lines.
  final String? description;

  /// Selects the icon-slot color scheme and default glyph.
  final BeuiToastStatus status;

  /// Overrides the status glyph with arbitrary content.
  final Widget? icon;

  /// Optional action button.
  final BeuiToastAction? action;

  /// Auto-dismiss timeout, used by [BeuiToastController]. `null` means the
  /// controller default; [Duration.zero] or less means sticky (never
  /// auto-dismissed).
  final Duration? duration;

  /// Whether the close button and swipe-to-dismiss are available.
  final bool dismissible;

  /// Copies with the given fields replaced. `null` arguments keep the current
  /// value (fields cannot be cleared through this — construct a new [BeuiToast]
  /// for that).
  BeuiToast copyWith({
    String? title,
    String? description,
    BeuiToastStatus? status,
    Widget? icon,
    BeuiToastAction? action,
    Duration? duration,
    bool? dismissible,
  }) => BeuiToast(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    icon: icon ?? this.icon,
    action: action ?? this.action,
    duration: duration ?? this.duration,
    dismissible: dismissible ?? this.dismissible,
  );
}

/// Owns a toast list with auto-dismiss timers — the port of the source's
/// `useAnimatedToastStack` hook. Listen (e.g. [ListenableBuilder]) and feed
/// [toasts] to a [BeuiAnimatedToastStack].
///
/// ```dart
/// final toasts = BeuiToastController();
/// toasts.show(title: 'Saved', status: BeuiToastStatus.success);
/// // ...
/// ListenableBuilder(
///   listenable: toasts,
///   builder: (context, _) => BeuiAnimatedToastStack(
///     toasts: toasts.toasts,
///     onDismiss: toasts.dismiss,
///   ),
/// )
/// ```
class BeuiToastController extends ChangeNotifier {
  /// Creates a controller. [defaultDuration] mirrors the source's 4200ms;
  /// [limit], when set, keeps only the newest N toasts.
  BeuiToastController({
    this.defaultDuration = const Duration(milliseconds: 4200),
    this.limit,
  });

  /// Auto-dismiss timeout applied when a toast has no [BeuiToast.duration].
  final Duration defaultDuration;

  /// Maximum retained toasts; older ones are dropped (source `slice(-limit)`).
  final int? limit;

  final List<BeuiToast> _toasts = [];
  final Map<String, Timer> _timers = {};
  int _seed = 0;

  /// The live toasts, oldest first.
  List<BeuiToast> get toasts => List.unmodifiable(_toasts);

  /// Adds a toast and returns its id. A provided [id] replaces any existing
  /// toast with the same id.
  String show({
    required String title,
    String? description,
    BeuiToastStatus status = BeuiToastStatus.neutral,
    Widget? icon,
    BeuiToastAction? action,
    Duration? duration,
    bool dismissible = true,
    String? id,
  }) {
    final toastId = id ?? 'beui-toast-${_seed++}';
    final toast = BeuiToast(
      id: toastId,
      title: title,
      description: description,
      status: status,
      icon: icon,
      action: action,
      duration: duration,
      dismissible: dismissible,
    );
    _toasts
      ..removeWhere((t) => t.id == toastId)
      ..add(toast);
    final limit = this.limit;
    if (limit != null && _toasts.length > limit) {
      for (final dropped in _toasts.take(_toasts.length - limit)) {
        _cancel(dropped.id);
      }
      _toasts.removeRange(0, _toasts.length - limit);
    }
    _arm(toast);
    notifyListeners();
    return toastId;
  }

  /// Patches the toast with [id]. Passing [duration] re-arms its auto-dismiss
  /// timer (the source resets `createdAt` when duration is patched) — the
  /// loading→success flow: `update(id, status: success, duration: 2s)`.
  void update(
    String id, {
    String? title,
    String? description,
    BeuiToastStatus? status,
    Widget? icon,
    BeuiToastAction? action,
    Duration? duration,
    bool? dismissible,
  }) {
    final index = _toasts.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _toasts[index] = _toasts[index].copyWith(
      title: title,
      description: description,
      status: status,
      icon: icon,
      action: action,
      duration: duration,
      dismissible: dismissible,
    );
    if (duration != null) _arm(_toasts[index]);
    notifyListeners();
  }

  /// Removes the toast with [id]. Safe to call for unknown ids.
  void dismiss(String id) {
    _cancel(id);
    final before = _toasts.length;
    _toasts.removeWhere((t) => t.id == id);
    if (_toasts.length != before) notifyListeners();
  }

  /// Removes every toast.
  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    if (_toasts.isNotEmpty) {
      _toasts.clear();
      notifyListeners();
    }
  }

  void _arm(BeuiToast toast) {
    _cancel(toast.id);
    final duration = toast.duration ?? defaultDuration;
    if (duration <= Duration.zero) return; // sticky
    _timers[toast.id] = Timer(duration, () {
      _timers.remove(toast.id);
      dismiss(toast.id);
    });
  }

  void _cancel(String id) => _timers.remove(id)?.cancel();

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

/// A stacked toast list with status morphs, swipe dismissal and layout-aware
/// motion — the Flutter port of beUI's `AnimatedToastStack`.
///
/// Controlled: the consumer owns [toasts] (typically via [BeuiToastController])
/// and reacts to [onDismiss]. Removed toasts animate out (slide right + blur,
/// faster than the entrance) before unmounting; new toasts spring in from
/// below while the stack glides to make room (source `layout` +
/// `STACK_SPRING`).
///
/// Reduced motion keeps the opacity fades and drops all movement, blur and
/// swipe-to-dismiss (source `useReducedMotion()` branches).
class BeuiAnimatedToastStack extends StatefulWidget {
  /// Creates a toast stack.
  const BeuiAnimatedToastStack({
    required this.toasts,
    this.onDismiss,
    this.position = BeuiToastPosition.bottomRight,
    this.maxVisible = 4,
    this.maxWidth = 384,
    this.icons,
    this.toastBuilder,
    super.key,
  });

  /// The toasts, oldest first (source `toasts`).
  final List<BeuiToast> toasts;

  /// Called with a toast id when its close button is pressed or it is swiped
  /// away. The consumer removes it from [toasts]. Without this, toasts are not
  /// dismissible by the user.
  final ValueChanged<String>? onDismiss;

  /// Stacking direction (source `position`); see [BeuiToastPosition].
  final BeuiToastPosition position;

  /// How many of the newest toasts are rendered (source `maxVisible`).
  final int maxVisible;

  /// Stack width cap (source `max-w-sm` = 384).
  final double maxWidth;

  /// Per-status icon overrides for the whole stack (source `icons`).
  final Map<BeuiToastStatus, Widget>? icons;

  /// Replaces a toast's default surface content entirely (source
  /// `renderToast`). The enter/exit/swipe motion still applies.
  final Widget Function(BuildContext context, BeuiToast toast)? toastBuilder;

  @override
  State<BeuiAnimatedToastStack> createState() => _BeuiAnimatedToastStackState();
}

class _ToastEntry {
  _ToastEntry(this.toast);

  BeuiToast toast;
  bool exiting = false;
}

class _BeuiAnimatedToastStackState extends State<BeuiAnimatedToastStack> {
  final List<_ToastEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BeuiAnimatedToastStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Mirrors the visible slice of [BeuiAnimatedToastStack.toasts] into
  /// [_entries], marking vanished toasts as exiting (they unmount when their
  /// exit animation reports done — the AnimatePresence contract).
  void _sync() {
    final toasts = widget.toasts;
    final visible = toasts.length > widget.maxVisible
        ? toasts.sublist(toasts.length - widget.maxVisible)
        : toasts;
    final byId = {for (final t in visible) t.id: t};
    final known = {for (final e in _entries) e.toast.id};
    for (final entry in _entries) {
      final match = byId[entry.toast.id];
      if (match != null) {
        entry
          ..toast = match
          ..exiting = false;
      } else {
        entry.exiting = true;
      }
    }
    for (final toast in visible) {
      if (!known.contains(toast.id)) _entries.add(_ToastEntry(toast));
    }
  }

  void _onExited(_ToastEntry entry) {
    if (!mounted) return;
    setState(() => _entries.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    final isBottom = widget.position.isBottom;
    return Semantics(
      container: true,
      liveRegion: true, // source aria-live="polite"
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Source: bottom positions use flex-col-reverse — the first (oldest)
          // toast sits nearest the bottom edge and the stack grows upward.
          verticalDirection: isBottom
              ? VerticalDirection.up
              : VerticalDirection.down,
          spacing: 8, // gap-2
          children: [
            for (final entry in _entries)
              _ToastItem(
                key: ValueKey(entry.toast.id),
                toast: entry.toast,
                exiting: entry.exiting,
                isBottom: isBottom,
                onDismiss: widget.onDismiss,
                onExited: () => _onExited(entry),
                iconOverride: widget.icons?[entry.toast.status],
                toastBuilder: widget.toastBuilder,
              ),
          ],
        ),
      ),
    );
  }
}

/// The stack spring — bespoke to this component (source `STACK_SPRING`,
/// stiffness 420 · damping 34 · mass 0.75). Not a shared token; see the spec's
/// component-local springs table.
const _stackSpring = SpringMotion(
  SpringDescription(mass: 0.75, stiffness: 420, damping: 34),
);

/// Exit: 180ms `EASE_OUT` (source exit transition), faster than the entrance.
const _exitMotion = CurvedMotion(Duration(milliseconds: 180), beuiEaseOut);

/// Swipe thresholds (source `onDragEnd`): raw offset > 72px or velocity >
/// 520px/s dismisses.
const _swipeOffsetThreshold = 72.0;
const _swipeVelocityThreshold = 520.0;

/// Drag elasticity — constraints are [0,0] so all travel is elastic (source
/// `dragElastic: 0.18`).
const _dragElastic = 0.18;

class _ToastItem extends StatefulWidget {
  const _ToastItem({
    required this.toast,
    required this.exiting,
    required this.isBottom,
    required this.onDismiss,
    required this.onExited,
    required this.iconOverride,
    required this.toastBuilder,
    super.key,
  });

  final BeuiToast toast;
  final bool exiting;
  final bool isBottom;
  final ValueChanged<String>? onDismiss;
  final VoidCallback onExited;
  final Widget? iconOverride;
  final Widget Function(BuildContext context, BeuiToast toast)? toastBuilder;

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem> {
  /// Raw horizontal drag travel; rendered at [_dragElastic] resistance.
  double _dragRaw = 0;
  bool _dragging = false;

  bool get _canDismiss => widget.toast.dismissible && widget.onDismiss != null;

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final qualifies =
        _dragRaw.abs() > _swipeOffsetThreshold ||
        velocity.abs() > _swipeVelocityThreshold;
    setState(() {
      _dragging = false;
      _dragRaw = 0;
    });
    if (qualifies) widget.onDismiss?.call(widget.toast.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final exiting = widget.exiting;

    Widget card = _ToastSurface(
      toast: widget.toast,
      colors: colors,
      reduce: reduce,
      canDismiss: _canDismiss,
      onDismiss: widget.onDismiss,
      iconOverride: widget.iconOverride,
      toastBuilder: widget.toastBuilder,
    );

    // Swipe-to-dismiss — drag disabled under reduced motion (source
    // `drag={canDismiss && !reduce ? "x" : false}`).
    if (_canDismiss && !reduce && !exiting) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() {
          _dragging = true;
          _dragRaw = 0;
        }),
        onHorizontalDragUpdate: (d) => setState(() => _dragRaw += d.delta.dx),
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: () => setState(() {
          _dragging = false;
          _dragRaw = 0;
        }),
        child: card,
      );
    }

    // Elastic drag follow: tracks the pointer instantly while dragging
    // (active: false snaps), springs back on release.
    card = SingleMotionBuilder(
      value: _dragging ? _dragRaw * _dragElastic : 0.0,
      motion: _stackSpring,
      active: !_dragging,
      builder: (context, dx, child) => dx.abs() < 0.01
          ? child!
          : Transform.translate(offset: Offset(dx, 0), child: child),
      child: card,
    );

    // Enter (0→1, STACK_SPRING): opacity + y 22 + scale 0.96 + blur 10px.
    // Exit (1→0, 180ms EASE_OUT): opacity + x 32 + scale 0.96 + blur 8px, and
    // the occupied height collapses so siblings glide closed (the source's
    // popLayout + `layout` reflow). Reduced motion keeps only the fades.
    return SingleMotionBuilder(
      value: exiting ? 0.0 : 1.0,
      from: 0.0,
      motion: exiting ? _exitMotion : _stackSpring,
      onAnimationStatusChanged: (status) {
        if (widget.exiting &&
            (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed)) {
          widget.onExited();
        }
      },
      builder: (context, t, child) {
        final opacity = t.clamp(0.0, 1.0);
        Widget body = child!;
        if (!reduce) {
          // Blur: enter 10px→0, exit 0→8px (σ = px/2).
          final sigma = exiting ? 4.0 * (1 - opacity) : 5.0 * (1 - opacity);
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
          final scale = 0.96 + 0.04 * math.min(t, 1.0);
          final offset = exiting
              ? Offset(32 * (1 - t), 0) // exit: slide right
              : Offset(0, 22 * (1 - t)); // enter: rise from below
          body = Transform.translate(
            offset: offset,
            child: Transform.scale(scale: scale, child: body),
          );
        }
        body = Opacity(opacity: opacity, child: body);
        // Layout reflow: the slot's height rides the same progress, so
        // siblings glide as a toast enters or leaves (source `layout` +
        // popLayout). Kept under reduced motion? No — movement; snap instead.
        final heightFactor = reduce ? 1.0 : opacity;
        return ClipRect(
          child: Align(
            alignment: widget.isBottom
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            heightFactor: heightFactor,
            child: body,
          ),
        );
      },
      child: card,
    );
  }
}

/// The toast card surface: glass card, status icon slot, rolling content,
/// action + close buttons.
class _ToastSurface extends StatelessWidget {
  const _ToastSurface({
    required this.toast,
    required this.colors,
    required this.reduce,
    required this.canDismiss,
    required this.onDismiss,
    required this.iconOverride,
    required this.toastBuilder,
  });

  final BeuiToast toast;
  final BeuiColors colors;
  final bool reduce;
  final bool canDismiss;
  final ValueChanged<String>? onDismiss;
  final Widget? iconOverride;
  final Widget Function(BuildContext context, BeuiToast toast)? toastBuilder;

  @override
  Widget build(BuildContext context) {
    final content = toastBuilder != null
        ? toastBuilder!(context, toast)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2), // mt-0.5
                child: _IconSlot(
                  toast: toast,
                  colors: colors,
                  reduce: reduce,
                  overrideIcon: iconOverride,
                ),
              ),
              const SizedBox(width: 12), // gap-3
              Expanded(
                child: _ContentSlot(toast: toast, colors: colors),
              ),
              if (canDismiss) ...[
                const SizedBox(width: 12),
                _CloseButton(
                  color: colors.mutedForeground,
                  onPressed: () => onDismiss?.call(toast.id),
                ),
              ],
            ],
          );

    // rounded-2xl border bg-card/95 p-3 shadow-2xl backdrop-blur-xl.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // backdrop-blur-xl
        child: Container(
          padding: const EdgeInsets.all(12), // p-3
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.95),
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              // shadow-2xl
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 50,
                offset: Offset(0, 25),
                spreadRadius: -12,
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Resolved icon-slot colors per status (source `STATUS_CLASS`).
({Color foreground, Color background}) _statusScheme(
  BeuiToastStatus status,
  BeuiColors c,
) {
  switch (status) {
    case BeuiToastStatus.neutral:
      return (
        foreground: c.mutedForeground,
        background: c.primary.withValues(alpha: 0.05),
      );
    case BeuiToastStatus.info:
    case BeuiToastStatus.loading:
      return (
        foreground: c.primary,
        background: c.primary.withValues(alpha: 0.10),
      );
    case BeuiToastStatus.success:
      // text-emerald-600 (light) / emerald-400 (dark), bg emerald-500/10.
      const emerald500 = Color(0xFF10B981);
      final fg = c.brightness == Brightness.dark
          ? const Color(0xFF34D399)
          : const Color(0xFF059669);
      return (foreground: fg, background: emerald500.withValues(alpha: 0.10));
    case BeuiToastStatus.error:
      return (
        foreground: c.destructive,
        background: c.destructive.withValues(alpha: 0.10),
      );
  }
}

/// The 28×28 status circle. On a status change the glyph rolls out the top and
/// the new one rolls in from below with blur (source icon `AnimatePresence`,
/// 280ms EASE_OUT). The default loading glyph spins.
class _IconSlot extends StatelessWidget {
  const _IconSlot({
    required this.toast,
    required this.colors,
    required this.reduce,
    required this.overrideIcon,
  });

  final BeuiToast toast;
  final BeuiColors colors;
  final bool reduce;
  final Widget? overrideIcon;

  @override
  Widget build(BuildContext context) {
    final status = toast.status;
    final scheme = _statusScheme(status, colors);
    final spin =
        status == BeuiToastStatus.loading &&
        overrideIcon == null &&
        toast.icon == null &&
        !reduce;
    final Widget glyph =
        overrideIcon ??
        toast.icon ??
        (spin
            ? _Spinner(size: 14, color: scheme.foreground)
            : Icon(status.icon, size: 14, color: scheme.foreground));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: beuiEaseOut,
      width: 28, // h-7 w-7
      height: 28,
      decoration: BoxDecoration(
        color: scheme.background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280), // CONTENT_TRANSITION
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          transitionBuilder: (child, animation) => _ContentRoll(
            animation: animation,
            reduce: reduce,
            rise: 8,
            scaleFrom: 0.8,
            child: child,
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey('icon-${status.name}'),
            child: glyph,
          ),
        ),
      ),
    );
  }
}

/// Title + description + action. Title/description roll on change (source
/// keyed on `id-status-title`, y ±8 + blur, 280ms EASE_OUT).
class _ContentSlot extends StatelessWidget {
  const _ContentSlot({required this.toast, required this.colors});

  final BeuiToast toast;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.linear,
            switchOutCurve: Curves.linear,
            transitionBuilder: (child, animation) => _ContentRoll(
              animation: animation,
              reduce: reduce,
              rise: 8,
              child: child,
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Column(
              key: ValueKey(
                'content-${toast.status.name}-${toast.title}'
                '-${toast.description ?? ''}',
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toast.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // truncate
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    height: 20 / 14, // leading-5
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
                if (toast.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2), // mt-0.5
                    child: Text(
                      toast.description!,
                      maxLines: 2, // line-clamp-2
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12, // text-xs
                        height: 16 / 12, // leading-4
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (toast.action != null)
          Padding(
            padding: const EdgeInsets.only(top: 8), // mt-2
            child: _ActionButton(toast: toast, colors: colors),
          ),
      ],
    );
  }
}

/// The rolling swap used by the icon and text slots — y ±8, blur 6px, eased
/// with `EASE_OUT`, mirroring the source `CONTENT_TRANSITION`. Reduced motion
/// collapses to a fade.
class _ContentRoll extends StatelessWidget {
  const _ContentRoll({
    required this.animation,
    required this.reduce,
    required this.rise,
    required this.child,
    this.scaleFrom = 1.0,
  });

  final Animation<double> animation;
  final bool reduce;
  final double rise;
  final double scaleFrom;
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
        // Enter from below (+rise → 0); exit up and out (0 → -rise).
        final dy = exiting ? -(1 - eased) * rise : (1 - eased) * rise;
        final scale = scaleFrom + (1 - scaleFrom) * eased;
        final sigma = (1 - t) * 3; // blur(6px) ≈ σ3
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
          child: Transform.translate(
            offset: Offset(0, dy),
            child: scaleFrom == 1.0
                ? body
                : Transform.scale(scale: scale, child: body),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.toast, required this.colors});

  final BeuiToast toast;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final action = toast.action!;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => action.onPressed(toast),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 28, // h-7
            padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14), // rounded-full
            ),
            child: Text(
              action.label,
              style: TextStyle(
                fontSize: 12, // text-xs
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dismiss toast',
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 28, // h-7 w-7
            height: 28,
            child: Icon(LucideIcons.x, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}

/// The default loading spinner — a centre-painted 3/4 arc spun in place
/// (Lucide `loader-circle` + the source's spin), same approach as the badge's.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _SpinnerPainter(
            color: widget.color,
            stroke: widget.size * 0.12,
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.color != color || old.stroke != stroke;
}
