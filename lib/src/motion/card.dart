/// Composable outlined or muted card surfaces.
library;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Surface treatment for [BeuiCard].
enum BeuiCardVariant { outlined, muted }

/// Shared spacing for [BeuiCard] and its parts.
enum BeuiCardSize { compact, defaultSize }

class _CardSizeScope extends InheritedWidget {
  const _CardSizeScope({required this.size, required super.child});

  final BeuiCardSize size;

  static BeuiCardSize of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardSizeScope>()?.size ??
      BeuiCardSize.defaultSize;

  @override
  bool updateShouldNotify(_CardSizeScope oldWidget) => size != oldWidget.size;
}

/// A composable card surface. It is not focusable or independently
/// actionable; place the owning button, link, checkbox, or radio inside it.
/// [selected] changes only its visual ring.
class BeuiCard extends StatefulWidget {
  const BeuiCard({
    required this.child,
    this.variant = BeuiCardVariant.outlined,
    this.size = BeuiCardSize.defaultSize,
    this.interactive = false,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final BeuiCardVariant variant;
  final BeuiCardSize size;
  final bool interactive;
  final bool selected;

  @override
  State<BeuiCard> createState() => _BeuiCardState();
}

class _BeuiCardState extends State<BeuiCard> {
  bool _pressed = false;
  bool _hovered = false;
  double _scaleFrom = 1;

  void _setPressed(BuildContext context, bool value) {
    if (_pressed == value) return;
    _scaleFrom = _pressed ? 0.985 : 1;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final background = widget.variant == BeuiCardVariant.muted
        ? colors.muted
        : colors.background;
    final border = widget.selected
        ? colors.primary
        : (_hovered && widget.interactive
              ? colors.borderStrong
              : colors.border);
    final targetScale = widget.interactive && _pressed && !reduce ? 0.985 : 1.0;

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.selected
            ? [BoxShadow(color: colors.primary, spreadRadius: 1)]
            : null,
      ),
      child: _CardSizeScope(
        size: widget.size,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: widget.size == BeuiCardSize.compact ? 16 : 24,
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.interactive) {
      surface = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) {
          setState(() => _hovered = false);
          _setPressed(context, false);
        },
        child: Listener(
          onPointerDown: (event) {
            // Touch events have a primary pointer but don't consistently use
            // the mouse button bit on every Flutter platform.
            if (event.buttons != 2) {
              _setPressed(context, true);
            }
          },
          onPointerUp: (_) => _setPressed(context, false),
          onPointerCancel: (_) => _setPressed(context, false),
          child: reduce
              ? surface
              : SingleMotionBuilder(
                  key: ValueKey<bool>(_pressed),
                  value: targetScale,
                  from: _scaleFrom,
                  motion: motionFor(context, beuiSpringPress, isMovement: true),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: surface,
                ),
        ),
      );
    }

    return Semantics(container: true, explicitChildNodes: true, child: surface);
  }
}

/// Header row area. Its horizontal inset follows the enclosing card's size.
class BeuiCardHeader extends StatelessWidget {
  const BeuiCardHeader({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: _CardSizeScope.of(context) == BeuiCardSize.compact ? 16 : 24,
    ),
    child: child,
  );
}

/// A card title, optionally rendered as a semantic heading.
class BeuiCardTitle extends StatelessWidget {
  const BeuiCardTitle({required this.child, this.headingLevel, super.key});
  final Widget child;
  final int? headingLevel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 15,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: BeuiColors.resolve(context).foreground,
    );
    return Semantics(
      header: headingLevel != null,
      child: DefaultTextStyle.merge(style: style, child: child),
    );
  }
}

/// Supporting copy for a card heading.
class BeuiCardDescription extends StatelessWidget {
  const BeuiCardDescription({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.45,
      color: BeuiColors.resolve(context).mutedForeground,
    ),
    child: child,
  );
}

/// Trailing action placement for a card header.
class BeuiCardAction extends StatelessWidget {
  const BeuiCardAction({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topRight, child: child);
}

/// Main content area, inset to align with the card header and footer.
class BeuiCardContent extends StatelessWidget {
  const BeuiCardContent({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: _CardSizeScope.of(context) == BeuiCardSize.compact ? 16 : 24,
    ),
    child: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: BeuiColors.resolve(context).foreground,
      ),
      child: child,
    ),
  );
}

/// Footer row, inset to align with the card's other parts.
class BeuiCardFooter extends StatelessWidget {
  const BeuiCardFooter({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: _CardSizeScope.of(context) == BeuiCardSize.compact ? 16 : 24,
    ),
    child: child,
  );
}

/// Use as the last child of a [Stack] that fills a card to stretch a control's
/// hit area over that stack. Keep any other card actions above it in z-order.
/// For a simpler layout, make the control itself fill the card with an
/// [InkWell] (or another full-size gesture widget).
class BeuiCardTarget extends StatelessWidget {
  const BeuiCardTarget({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(child: child);
}
