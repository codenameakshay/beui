import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart' show LucideIcons;
import '../tokens/motion.dart';

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

  bool get _open => widget.open ?? _internalOpen;

  void _setOpen(bool value) {
    if (value == _open) return;
    if (widget.open == null) setState(() => _internalOpen = value);
    widget.onOpenChange?.call(value);
  }

  void _dismiss() {
    var focusedInside = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
      element,
    ) {
      if (element.widget == widget) {
        focusedInside = true;
        return false;
      }
      return true;
    });
    _setOpen(false);
    if (focusedInside) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.returnFocus?.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(BeuiAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != null && widget.open == null) {
      _internalOpen = oldWidget.open!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    final color = switch (widget.variant) {
      BeuiAlertVariant.default_ => colors.foreground,
      BeuiAlertVariant.info => colors.primary,
      BeuiAlertVariant.success => colors.success,
      BeuiAlertVariant.warning => colors.warning,
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
      reduce: reduce,
      setOpen: _setOpen,
      dismiss: _dismiss,
    );
    final surface = _open
        ? Semantics(
            key: _surfaceKey,
            container: true,
            role: role == 'alert' ? SemanticsRole.alert : SemanticsRole.status,
            child: AnimatedSize(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: reduce ? Curves.linear : beuiEaseOut,
              alignment: Alignment.topCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: color, fontSize: 14),
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
          )
        : const SizedBox.shrink();

    return _AlertScope(
      state: state,
      child: AnimatedSwitcher(
        duration: reduce
            ? const Duration(milliseconds: 180)
            : const Duration(milliseconds: 200),
        reverseDuration: const Duration(milliseconds: 120),
        switchInCurve: beuiEaseOut,
        switchOutCurve: beuiEaseOut,
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          final movement = reduce
              ? fade
              : SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: fade,
                );
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final exiting =
                  animation.status == AnimationStatus.reverse ||
                  animation.status == AnimationStatus.dismissed;
              return IgnorePointer(
                ignoring: exiting,
                child: ExcludeSemantics(excluding: exiting, child: movement),
              );
            },
          );
        },
        child: _open
            ? KeyedSubtree(
                key: const ValueKey('beui_alert_open'),
                child: _AlertScope(state: state, child: surface),
              )
            : const SizedBox(key: ValueKey('beui_alert_closed')),
      ),
    );
  }
}

/// The variant icon, cross-faded whenever the alert tone changes.
class BeuiAlertIcon extends StatelessWidget {
  const BeuiAlertIcon({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final state = _AlertScope.of(context, 'BeuiAlertIcon');
    final colors = BeuiColors.resolve(context);
    final color = switch (state.variant) {
      BeuiAlertVariant.default_ || BeuiAlertVariant.info => colors.primary,
      BeuiAlertVariant.success => colors.success,
      BeuiAlertVariant.warning => colors.warning,
      BeuiAlertVariant.destructive => colors.destructive,
    };
    final icon =
        child ??
        Icon(switch (state.variant) {
          BeuiAlertVariant.default_ ||
          BeuiAlertVariant.info => LucideIcons.info,
          BeuiAlertVariant.success => LucideIcons.circle_check,
          BeuiAlertVariant.warning => LucideIcons.triangle_alert,
          BeuiAlertVariant.destructive => LucideIcons.circle_alert,
        });
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 12),
      child: IconTheme.merge(
        data: IconThemeData(color: color, size: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey(state.variant),
            child: ExcludeSemantics(child: icon),
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
    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
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
        height: 1.5,
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
class BeuiAlertClose extends StatelessWidget {
  const BeuiAlertClose({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final state = _AlertScope.of(context, 'BeuiAlertClose');
    return IconButton(
      tooltip: 'Dismiss alert',
      visualDensity: VisualDensity.compact,
      onPressed: state.dismiss,
      icon: child ?? const Icon(LucideIcons.x, size: 16),
    );
  }
}
