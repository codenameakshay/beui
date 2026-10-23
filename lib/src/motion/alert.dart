import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart' show LucideIcons;
import '../tokens/motion.dart';
import '_engine.dart';

/// Visual tone of a [BeuiAlert].
enum BeuiAlertVariant { default_, info, success, warning, destructive }

/// Shared state for the composable parts of a [BeuiAlert].
@immutable
class _AlertState {
  const _AlertState({
    required this.open,
    required this.variant,
    required this.reduce,
    required this.setOpen,
    required this.dismiss,
  });

  final bool open;
  final BeuiAlertVariant variant;
  final bool reduce;
  final ValueChanged<bool> setOpen;
  final VoidCallback dismiss;
}

class _AlertScope extends InheritedWidget {
  const _AlertScope({required this.state, required super.child});

  final _AlertState state;

  static _AlertState of(BuildContext context, String part) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AlertScope>();
    assert(scope != null, '$part must be used inside BeuiAlert');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_AlertScope oldWidget) => state != oldWidget.state;
}

/// An animated, composable inline feedback surface.
///
/// Supply [open] and [onOpenChange] for controlled visibility, or use
/// [defaultOpen] for an internally managed alert. Parts must be descendants of
/// this widget. Reduced motion keeps fades and removes positional transitions.
class BeuiAlert extends StatefulWidget {
  const BeuiAlert({
    this.variant = BeuiAlertVariant.default_,
    this.open,
    this.defaultOpen = true,
    this.onOpenChange,
    this.returnFocus,
    this.role,
    required this.children,
    super.key,
  });

  final BeuiAlertVariant variant;
  final bool? open;
  final bool defaultOpen;
  final ValueChanged<bool>? onOpenChange;
  final FocusNode? returnFocus;

  /// Semantic role override: `alert` or `status`.
  final String? role;
  final List<Widget> children;

  @override
  State<BeuiAlert> createState() => _BeuiAlertState();
}

class _BeuiAlertState extends State<BeuiAlert> {
  final GlobalKey _surfaceKey = GlobalKey();
  late bool _internalOpen = widget.defaultOpen;
  late final bool _initialOpen = _open;

  bool get _open => widget.open ?? _internalOpen;

  void _setOpen(bool value) {
    if (value == _open) return;
    if (widget.open == null) {
      if (!value) _restoreFocusIfInside();
      setState(() => _internalOpen = value);
    }
    widget.onOpenChange?.call(value);
  }

  void _restoreFocusIfInside() {
    var focusedInside = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
      element,
    ) {
      if (element == context) {
        focusedInside = true;
        return false;
      }
      return true;
    });
    if (focusedInside) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_open) widget.returnFocus?.requestFocus();
      });
    }
  }

  void _dismiss() => _setOpen(false);

  @override
  void didUpdateWidget(BeuiAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != null && widget.open == null) {
      _internalOpen = oldWidget.open!;
    }
    if ((oldWidget.open ?? _internalOpen) && !_open) _restoreFocusIfInside();
  }

  @override
  Widget build(BuildContext context) {
    final movement = motionFor(context, beuiSpringLayout, isMovement: true);
    final colors = BeuiColors.resolve(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final defaults = BeuiColors.of(colors.colorTheme, colors.brightness);
    final color = switch (widget.variant) {
      BeuiAlertVariant.default_ => colors.foreground,
      BeuiAlertVariant.info => colors.primary,
      BeuiAlertVariant.success =>
        colors.success != defaults.success
            ? colors.success
            : dark
            ? const Color(0xff00d492)
            : const Color(0xff007a55),
      BeuiAlertVariant.warning =>
        colors.warning != defaults.warning
            ? colors.warning
            : dark
            ? const Color(0xffffd230)
            : const Color(0xff973c00),
      BeuiAlertVariant.destructive => colors.destructive,
    };
    final role =
        widget.role ??
        (widget.variant == BeuiAlertVariant.warning ||
                widget.variant == BeuiAlertVariant.destructive
            ? 'alert'
            : 'status');
    final state = _AlertState(
      open: _open,
      variant: widget.variant,
      reduce: movement is NoMotion,
      setOpen: _setOpen,
      dismiss: _dismiss,
    );
    final surface = Semantics(
      key: _surfaceKey,
      container: true,
      role: role == 'alert' ? SemanticsRole.alert : SemanticsRole.status,
      child: _AlertScope(
        state: state,
        child: IgnorePointer(
          ignoring: !_open,
          child: ExcludeFocus(
            excluding: !_open,
            child: ExcludeSemantics(
              excluding: !_open,
              child: _buildAlertSurface(color, movement),
            ),
          ),
        ),
      ),
    );

    return _AlertScope(state: state, child: surface);
  }

  Widget _buildAlertSurface(Color color, Motion movement) {
    final colors = BeuiColors.resolve(context);
    final defaults = BeuiColors.of(colors.colorTheme, colors.brightness);
    final background = switch (widget.variant) {
      BeuiAlertVariant.success =>
        colors.success == defaults.success
            ? const Color(0xff00bc7d)
            : colors.success,
      BeuiAlertVariant.warning =>
        colors.warning == defaults.warning
            ? const Color(0xfffe9a00)
            : colors.warning,
      _ => color,
    };
    final fade = SingleMotionBuilder(
      value: _open ? 1 : 0,
      from: _initialOpen ? 1 : 0,
      motion: CurvedMotion(
        Duration(milliseconds: _open ? 180 : 120),
        beuiEaseOut,
      ),
      child: _AlertHeight(
        reduce: movement is NoMotion,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: beuiEaseOut,
          decoration: BoxDecoration(
            color: widget.variant == BeuiAlertVariant.default_
                ? BeuiColors.resolve(context).background
                : background.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: beuiEaseOut,
              style: DefaultTextStyle.of(
                context,
              ).style.copyWith(color: color, fontSize: 14, height: 20 / 14),
              child: IconTheme.merge(
                data: IconThemeData(color: color, size: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final child in widget.children) child],
                ),
              ),
            ),
          ),
        ),
      ),
      builder: (context, opacity, child) => !_open && opacity <= 0
          ? const SizedBox.shrink()
          : Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
    );
    if (movement is NoMotion) {
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: _open ? 1 : 0,
          child: fade,
        ),
      );
    }
    return SingleMotionBuilder(
      value: _open ? 1 : 0,
      from: _initialOpen ? 1 : 0,
      motion: CurvedMotion(
        Duration(milliseconds: _open ? 200 : 120),
        beuiEaseOut,
      ),
      child: fade,
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, -6 * (1 - progress)),
        child: child,
      ),
    );
  }
}

class _AlertHeight extends StatefulWidget {
  const _AlertHeight({required this.child, required this.reduce});
  final Widget child;
  final bool reduce;
  @override
  State<_AlertHeight> createState() => _AlertHeightState();
}

class _AlertHeightState extends State<_AlertHeight> {
  final _key = GlobalKey();
  double? _height;
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && _height != box.size.height) {
        setState(() => _height = box.size.height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final child = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measure();
        return false;
      },
      child: SizeChangedLayoutNotifier(key: _key, child: widget.child),
    );
    if (_height == null || widget.reduce) return child;
    return SingleMotionBuilder(
      value: _height!,
      motion: beuiSpringLayout,
      child: child,
      builder: (context, height, child) => SizedBox(
        height: height,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

/// The variant icon, cross-faded whenever the alert tone changes.
class BeuiAlertIcon extends StatefulWidget {
  const BeuiAlertIcon({super.key, this.child});
  final Widget? child;

  @override
  State<BeuiAlertIcon> createState() => _BeuiAlertIconState();
}

class _BeuiAlertIconState extends State<BeuiAlertIcon> {
  final _entries = <({int id, BeuiAlertVariant variant, bool initial})>[];
  int _nextId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final variant = _AlertScope.of(context, 'BeuiAlertIcon').variant;
    if (_entries.isEmpty || _entries.last.variant != variant) {
      _entries.add((
        id: _nextId++,
        variant: variant,
        initial: _entries.isEmpty,
      ));
    }
  }

  void _removeExited(int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entries.last.id == id) return;
      setState(() => _entries.removeWhere((entry) => entry.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _AlertScope.of(context, 'BeuiAlertIcon');
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 12),
      child: IconTheme.merge(
        data: const IconThemeData(size: 16),
        child: SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in _entries)
                SingleMotionBuilder(
                  key: ValueKey(entry.id),
                  value: entry.id == _entries.last.id ? 1 : 0,
                  from: entry.initial ? 1 : 0,
                  motion: CurvedMotion(
                    Duration(
                      milliseconds: entry.id == _entries.last.id ? 180 : 100,
                    ),
                    beuiEaseOut,
                  ),
                  onAnimationStatusChanged: (status) {
                    if (status == AnimationStatus.completed &&
                        entry.id != _entries.last.id) {
                      _removeExited(entry.id);
                    }
                  },
                  child: ExcludeSemantics(
                    child:
                        widget.child ??
                        Icon(switch (entry.variant) {
                          BeuiAlertVariant.default_ ||
                          BeuiAlertVariant.info => LucideIcons.info,
                          BeuiAlertVariant.success => LucideIcons.circle_check,
                          BeuiAlertVariant.warning =>
                            LucideIcons.triangle_alert,
                          BeuiAlertVariant.destructive =>
                            LucideIcons.circle_alert,
                        }),
                  ),
                  builder: (context, progress, child) => Opacity(
                    opacity: progress.clamp(0.0, 1.0),
                    child: state.reduce
                        ? child
                        : Transform.translate(
                            offset: Offset(
                              0,
                              (entry.id == _entries.last.id ? 4 : -4) *
                                  (1 - progress),
                            ),
                            child: Transform.scale(
                              scale: 0.9 + 0.1 * progress,
                              child: child,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flexible column for an alert's title, description, and actions.
class BeuiAlertContent extends StatelessWidget {
  const BeuiAlertContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [child],
    ),
  );
}

/// Prominent alert heading.
class BeuiAlertTitle extends StatelessWidget {
  const BeuiAlertTitle({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: const TextStyle(fontWeight: FontWeight.w500, height: 20 / 14),
    child: child,
  );
}

/// Supporting alert copy.
class BeuiAlertDescription extends StatelessWidget {
  const BeuiAlertDescription({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        color: BeuiColors.resolve(context).mutedForeground,
        height: 1.625,
      ),
      child: child,
    ),
  );
}

/// Layout container for optional alert actions.
class BeuiAlertAction extends StatelessWidget {
  const BeuiAlertAction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(spacing: 8, runSpacing: 8, children: [child]),
  );
}

/// Dismisses the enclosing alert; the default button is labelled for assistive
/// technology and returns focus to [BeuiAlert.returnFocus] when supplied.
class BeuiAlertClose extends StatefulWidget {
  const BeuiAlertClose({super.key, this.child});
  final Widget? child;

  @override
  State<BeuiAlertClose> createState() => _BeuiAlertCloseState();
}

class _BeuiAlertCloseState extends State<BeuiAlertClose> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = _AlertScope.of(context, 'BeuiAlertClose');
    final colors = BeuiColors.resolve(context);
    final foreground = colors.foreground;
    return Transform.translate(
      offset: const Offset(6, -6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered
                ? foreground.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            tooltip: 'Dismiss alert',
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              foregroundColor: _hovered ? foreground : colors.mutedForeground,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: state.dismiss,
            icon: widget.child ?? const Icon(LucideIcons.x, size: 16),
          ),
        ),
      ),
    );
  }
}
