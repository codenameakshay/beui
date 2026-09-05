import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Size of a [BeuiOverflowActions] rail (source `OverflowActionsSize`).
enum BeuiOverflowActionsSize {
  /// Compact (source `sm`).
  sm,

  /// Default (source `md`).
  md,
}

/// One action in a [BeuiOverflowActions] rail (source `OverflowActionItem`).
@immutable
class BeuiOverflowActionItem {
  /// Creates an overflow action.
  const BeuiOverflowActionItem({
    required this.id,
    required this.label,
    this.icon,
    this.onPressed,
    this.disabled = false,
    this.semanticLabel,
  });

  /// Stable identity.
  final String id;

  /// Button label.
  final String label;

  /// Optional leading glyph.
  final IconData? icon;

  /// Invoked on tap.
  final VoidCallback? onPressed;

  /// Disables and dims the action.
  final bool disabled;

  /// Accessibility label override (source `ariaLabel`).
  final String? semanticLabel;
}

/// A softer layout spring than the app defaults so the overflow group stays
/// visually attached to the toggle while entering and leaving (source
/// `SHELL_TRANSITION`, 220 · 17 · 0.85).
const _shellSpring = SpringMotion(
  SpringDescription(mass: 0.85, stiffness: 220, damping: 17),
);

/// A connected pill rail that springs open to reveal extra controls — the
/// Flutter port of beUI's `OverflowActions`.
///
/// Primary actions stay visible; the primary-colored toggle (⋯ ↔ ✕, fading
/// through a 3px blur) unfolds the overflow group on the soft shell spring.
/// `expanded` follows the controlled + uncontrolled convention. Reduced
/// motion snaps the width and keeps only the fades.
class BeuiOverflowActions extends StatefulWidget {
  /// Creates an overflow-actions rail.
  const BeuiOverflowActions({
    required this.primaryActions,
    required this.overflowActions,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    this.onAction,
    this.collapseOnAction = false,
    this.size = BeuiOverflowActionsSize.md,
    this.openLabel = 'Show extra actions',
    this.closeLabel = 'Hide extra actions',
    super.key,
  });

  /// Always-visible actions.
  final List<BeuiOverflowActionItem> primaryActions;

  /// Actions revealed by the toggle.
  final List<BeuiOverflowActionItem> overflowActions;

  /// Controlled expansion; null for uncontrolled with [defaultExpanded].
  final bool? expanded;

  /// Initial expansion when uncontrolled.
  final bool defaultExpanded;

  /// Fires when the rail wants to expand/collapse.
  final ValueChanged<bool>? onExpandedChange;

  /// Fires with the tapped action (after its own `onPressed`).
  final ValueChanged<BeuiOverflowActionItem>? onAction;

  /// Collapse the rail after any action (source `collapseOnAction`).
  final bool collapseOnAction;

  /// Size preset.
  final BeuiOverflowActionsSize size;

  /// Toggle tooltip/semantics when collapsed.
  final String openLabel;

  /// Toggle tooltip/semantics when expanded.
  final String closeLabel;

  @override
  State<BeuiOverflowActions> createState() => _BeuiOverflowActionsState();
}

class _Metrics {
  const _Metrics({
    required this.trackPad,
    required this.gap,
    required this.actionHeight,
    required this.actionPad,
    required this.toggleSize,
    required this.iconSize,
    required this.fontSize,
  });

  final double trackPad;
  final double gap;
  final double actionHeight;
  final double actionPad;
  final double toggleSize;
  final double iconSize;
  final double fontSize;
}

// sm: p-1 gap-1 text-xs, action h-8 px-3, toggle 32, icon 14.
// md: p-1.5 gap-1.5 text-sm, action h-9 px-3.5, toggle 36, icon 16.
const _metrics = {
  BeuiOverflowActionsSize.sm: _Metrics(
    trackPad: 4,
    gap: 4,
    actionHeight: 32,
    actionPad: 12,
    toggleSize: 32,
    iconSize: 14,
    fontSize: 12,
  ),
  BeuiOverflowActionsSize.md: _Metrics(
    trackPad: 6,
    gap: 6,
    actionHeight: 36,
    actionPad: 14,
    toggleSize: 36,
    iconSize: 16,
    fontSize: 14,
  ),
};

class _BeuiOverflowActionsState extends State<BeuiOverflowActions> {
  late bool _internalExpanded = widget.defaultExpanded;

  bool get _expanded => widget.expanded ?? _internalExpanded;

  void _setExpanded(bool value) {
    if (widget.expanded == null) setState(() => _internalExpanded = value);
    widget.onExpandedChange?.call(value);
  }

  void _handleAction(BeuiOverflowActionItem item) {
    item.onPressed?.call();
    widget.onAction?.call(item);
    if (widget.collapseOnAction) _setExpanded(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final m = _metrics[widget.size]!;

    return Container(
      padding: EdgeInsets.all(m.trackPad),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in widget.primaryActions)
            Padding(
              padding: EdgeInsets.only(right: m.gap),
              child: _ActionButton(
                item: item,
                metrics: m,
                colors: colors,
                reduce: reduce,
                onAction: () => _handleAction(item),
              ),
            ),
          // The overflow group unfolds between the primaries and the toggle
          // on the soft shell spring; items fade through a 4px blur.
          SingleMotionBuilder(
            value: _expanded ? 1.0 : 0.0,
            motion: _shellSpring,
            active: !reduce,
            builder: (context, raw, child) {
              final t = raw.clamp(0.0, 1.0);
              if (raw <= 0.001) return const SizedBox.shrink();
              Widget body = Opacity(opacity: t, child: child);
              if (!reduce) {
                final sigma = (1 - t) * 2; // blur(4px) ≈ σ2
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
              }
              return ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: raw.clamp(0.0, double.infinity),
                  child: body,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in widget.overflowActions)
                  Padding(
                    padding: EdgeInsets.only(right: m.gap),
                    child: _ActionButton(
                      item: item,
                      metrics: m,
                      colors: colors,
                      reduce: reduce,
                      onAction: () => _handleAction(item),
                    ),
                  ),
              ],
            ),
          ),
          _Toggle(
            expanded: _expanded,
            metrics: m,
            colors: colors,
            reduce: reduce,
            label: _expanded ? widget.closeLabel : widget.openLabel,
            onPressed: () => _setExpanded(!_expanded),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.item,
    required this.metrics,
    required this.colors,
    required this.reduce,
    required this.onAction,
  });

  final BeuiOverflowActionItem item;
  final _Metrics metrics;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback onAction;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final m = widget.metrics;
    final colors = widget.colors;
    final interactive = !item.disabled && !widget.reduce;

    Widget body = Container(
      height: m.actionHeight,
      constraints: BoxConstraints(minWidth: m.actionHeight),
      padding: EdgeInsets.symmetric(horizontal: m.actionPad),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: m.gap + 2,
        children: [
          if (item.icon != null)
            Icon(item.icon, size: m.iconSize, color: colors.foreground),
          Text(
            item.label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: m.fontSize,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );

    // whileTap 0.97 / whileHover 1.008 on the shell spring.
    body = SingleMotionBuilder(
      value: !interactive
          ? 1.0
          : _pressed
          ? 0.97
          : _hovered
          ? 1.008
          : 1.0,
      motion: _shellSpring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: body,
    );

    if (item.disabled) body = Opacity(opacity: 0.45, child: body);

    return Semantics(
      button: true,
      enabled: !item.disabled,
      label: item.semanticLabel ?? item.label,
      child: MouseRegion(
        cursor: item.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: item.disabled
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: item.disabled ? null : widget.onAction,
          child: body,
        ),
      ),
    );
  }
}

/// The primary-colored circular toggle: ⋯ collapsed, ✕ expanded, swapped with
/// a fade through a 3px blur (source `ICON_VARIANTS`, 180ms `EASE_OUT`).
class _Toggle extends StatefulWidget {
  const _Toggle({
    required this.expanded,
    required this.metrics,
    required this.colors,
    required this.reduce,
    required this.label,
    required this.onPressed,
  });

  final bool expanded;
  final _Metrics metrics;
  final BeuiColors colors;
  final bool reduce;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final colors = widget.colors;
    final reduce = widget.reduce;

    Widget glyph = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) {
        if (reduce) return FadeTransition(opacity: animation, child: child);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = beuiEaseOut.transform(animation.value);
            final sigma = (1 - t) * 1.5; // blur(3px) ≈ σ1.5
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
            return Opacity(opacity: t, child: body);
          },
        );
      },
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: Icon(
        widget.expanded ? LucideIcons.x : LucideIcons.ellipsis,
        key: ValueKey(widget.expanded),
        size: m.iconSize,
        color: colors.primaryForeground,
      ),
    );

    Widget body = Container(
      width: m.toggleSize,
      height: m.toggleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: glyph,
    );

    body = SingleMotionBuilder(
      value: reduce
          ? 1.0
          : _pressed
          ? 0.96
          : _hovered
          ? 1.03
          : 1.0,
      motion: _shellSpring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: body,
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: body,
        ),
      ),
    );
  }
}
