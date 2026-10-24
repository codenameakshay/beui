import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// Source `CONTINUITY_SPRING`: softer than the shared-layout token so the
// expanding shell stays visually attached to its trigger (220 / 17 / 0.85).
const _continuitySpring = SpringMotion(
  SpringDescription(mass: 0.85, stiffness: 220, damping: 17),
);

/// Click-to-expand icon button that reveals [label].
class BeuiExpandableButton extends StatefulWidget {
  /// Creates a compact icon button that expands to show its label.
  const BeuiExpandableButton({
    required this.icon,
    required this.label,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    this.onPressed,
    this.disabled = false,
    this.semanticLabel,
    super.key,
  });

  /// Icon shown in both states.
  final Widget icon;

  /// Content revealed when expanded.
  final Widget label;

  /// Controlled expanded state. When null, state is held internally.
  final bool? expanded;

  /// Initial expanded state for uncontrolled use.
  final bool defaultExpanded;

  /// Called when the user requests a different expanded state.
  final ValueChanged<bool>? onExpandedChange;

  /// Optional callback invoked on each button activation.
  final VoidCallback? onPressed;

  /// Whether this button is disabled.
  final bool disabled;

  /// Accessible name override, useful when [label] is not a [Text].
  final String? semanticLabel;

  @override
  State<BeuiExpandableButton> createState() => _BeuiExpandableButtonState();
}

class _BeuiExpandableButtonState extends State<BeuiExpandableButton> {
  late bool _internalExpanded = widget.defaultExpanded;
  bool _hovered = false;
  bool get _isExpanded => widget.expanded ?? _internalExpanded;

  void _setExpanded(bool value) {
    if (widget.expanded == null) setState(() => _internalExpanded = value);
    widget.onExpandedChange?.call(value);
  }

  @override
  void didUpdateWidget(covariant BeuiExpandableButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultExpanded != widget.defaultExpanded &&
        widget.expanded == null) {
      _internalExpanded = widget.defaultExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final expanded = _isExpanded;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final foreground = _hovered && !widget.disabled
        ? colors.foreground
        : colors.mutedForeground;
    final label = widget.label;
    final labelText = label is Text ? label.data : null;
    return _ExpandableSurface(
      expanded: expanded,
      reduce: reduce,
      height: 44,
      borderColor: colors.border,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.disabled
                ? null
                : () {
                    widget.onPressed?.call();
                    _setExpanded(!expanded);
                  },
            customBorder: const StadiumBorder(),
            child: Semantics(
              button: true,
              enabled: !widget.disabled,
              expanded: expanded,
              label: widget.semanticLabel ?? labelText,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: IconTheme.merge(
                          data: IconThemeData(color: foreground, size: 18),
                          child: ExcludeSemantics(child: widget.icon),
                        ),
                      ),
                    ),
                    if (expanded)
                      _Reveal(
                        reduce: reduce,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, right: 12),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            child: ExcludeSemantics(child: label),
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

/// Label button that reveals a trailing action button when expanded.
class BeuiExpandableChip extends StatefulWidget {
  /// Creates a chip with an optional trailing action.
  const BeuiExpandableChip({
    required this.label,
    required this.actionIcon,
    required this.actionLabel,
    this.onAction,
    this.collapseOnAction = true,
    this.disabled = false,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    super.key,
  });

  /// Chip's main label.
  final Widget label;

  /// Icon shown inside the trailing action button.
  final Widget actionIcon;

  /// Accessible name for the action button.
  final String actionLabel;

  /// Invoked when the trailing action is activated.
  final VoidCallback? onAction;

  /// Whether the chip collapses after [onAction].
  final bool collapseOnAction;

  /// Disables both the label and action buttons.
  final bool disabled;

  /// Controlled expanded state. When null, state is held internally.
  final bool? expanded;

  /// Initial expanded state for uncontrolled use.
  final bool defaultExpanded;

  /// Called when the user requests a different expanded state.
  final ValueChanged<bool>? onExpandedChange;

  @override
  State<BeuiExpandableChip> createState() => _BeuiExpandableChipState();
}

class _BeuiExpandableChipState extends State<BeuiExpandableChip> {
  late bool _internalExpanded = widget.defaultExpanded;
  final FocusNode _triggerFocus = FocusNode();
  bool _hovered = false;

  bool get _isExpanded => widget.expanded ?? _internalExpanded;

  void _setExpanded(bool value) {
    if (widget.expanded == null) setState(() => _internalExpanded = value);
    widget.onExpandedChange?.call(value);
  }

  @override
  void didUpdateWidget(covariant BeuiExpandableChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultExpanded != widget.defaultExpanded &&
        widget.expanded == null) {
      _internalExpanded = widget.defaultExpanded;
    }
  }

  @override
  void dispose() {
    _triggerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final expanded = _isExpanded;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final foreground = _hovered && !widget.disabled
        ? colors.foreground
        : colors.mutedForeground;
    return _ExpandableSurface(
      expanded: expanded,
      reduce: reduce,
      height: 40,
      borderColor: colors.border,
      child: MouseRegion(
        onEnter: widget.disabled
            ? null
            : (_) => setState(() => _hovered = true),
        onHover: widget.disabled
            ? null
            : (_) {
                if (!_hovered) setState(() => _hovered = true);
              },
        onExit: widget.disabled
            ? null
            : (_) => setState(() => _hovered = false),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              enabled: !widget.disabled,
              expanded: expanded,
              child: TextButton(
                focusNode: _triggerFocus,
                onPressed: widget.disabled
                    ? null
                    : () => _setExpanded(!expanded),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  padding: EdgeInsets.only(left: 12, right: expanded ? 4 : 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  child: widget.label,
                ),
              ),
            ),
            if (expanded)
              _Reveal(
                reduce: reduce,
                child: SizedBox(
                  width: 32,
                  height: 40,
                  child: Semantics(
                    button: true,
                    enabled: !widget.disabled,
                    label: widget.actionLabel,
                    child: IconButton(
                      onPressed: widget.disabled
                          ? null
                          : () {
                              widget.onAction?.call();
                              if (widget.collapseOnAction) {
                                _setExpanded(false);
                                _triggerFocus.requestFocus();
                              }
                            },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 40,
                      ),
                      icon: IconTheme.merge(
                        data: IconThemeData(color: foreground, size: 14),
                        child: ExcludeSemantics(child: widget.actionIcon),
                      ),
                    ),
                  ),
                ),
              )
            else
              const ExcludeSemantics(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _ExpandableSurface extends StatefulWidget {
  const _ExpandableSurface({
    required this.expanded,
    required this.reduce,
    required this.height,
    required this.borderColor,
    required this.child,
  });

  final bool expanded;
  final bool reduce;
  final double height;
  final Color borderColor;
  final Widget child;

  @override
  State<_ExpandableSurface> createState() => _ExpandableSurfaceState();
}

class _ExpandableSurfaceState extends State<_ExpandableSurface> {
  final GlobalKey _contentKey = GlobalKey();
  Size? _contentSize;

  @override
  void didUpdateWidget(covariant _ExpandableSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size == _contentSize) return;
    setState(() => _contentSize = box.size);
  }

  @override
  Widget build(BuildContext context) {
    final measured = _contentSize;
    if (measured == null) {
      return Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: widget.borderColor),
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
        child: IntrinsicWidth(
          child: SizedBox(
            key: _contentKey,
            height: widget.height,
            child: widget.child,
          ),
        ),
      );
    }
    final target = widget.expanded
        ? measured
        : Size(measured.width, widget.height);
    final motion = motionFor(context, _continuitySpring, isMovement: true);
    return MotionBuilder<Size>(
      value: target,
      converter: const SizeMotionConverter(),
      motion: motion,
      builder: (context, size, child) {
        final resolvedSize = widget.reduce ? target : size;
        return Container(
          width: resolvedSize.width,
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: widget.borderColor),
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: SizedBox(key: _contentKey, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.reduce, required this.child});

  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    child: child,
    builder: (context, opacity, child) => Opacity(
      opacity: opacity,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: reduce ? 0 : beuiBlurSigma(4) * (1 - opacity),
          sigmaY: reduce ? 0 : beuiBlurSigma(4) * (1 - opacity),
        ),
        child: child,
      ),
    ),
  );
}
