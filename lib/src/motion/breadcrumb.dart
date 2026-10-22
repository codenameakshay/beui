import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder;

/// A labelled navigation landmark for a path of [BeuiBreadcrumbItem]s.
class BeuiBreadcrumb extends StatelessWidget {
  const BeuiBreadcrumb({
    required this.child,
    super.key,
    this.label = 'Breadcrumb',
  });

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    child: child,
  );
}

/// A wrapping path. Set [maxItems] to collapse middle items into an ellipsis.
class BeuiBreadcrumbList extends StatelessWidget {
  const BeuiBreadcrumbList({
    required this.children,
    super.key,
    this.maxItems = 4,
    this.overflowLabel = 'Show hidden paths',
    this.spacing = 4,
    this.runSpacing = 4,
  });

  final List<Widget> children;

  /// Maximum number of visible slots, including the overflow button. Null
  /// disables collapsing.
  final int? maxItems;
  final String overflowLabel;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final finiteLimit = maxItems == null
        ? children.length
        : (maxItems! < 3 ? 3 : maxItems!);
    final collapse = maxItems != null && children.length > finiteLimit;
    final tailCount = finiteLimit - 2;
    final visible = collapse
        ? <Widget>[
            children.first,
            BeuiBreadcrumbItem(
              key: const ValueKey<String>('breadcrumb-overflow'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BeuiBreadcrumbSeparator(),
                  BeuiBreadcrumbEllipsis(
                    label: overflowLabel,
                    children: children.sublist(1, children.length - tailCount),
                  ),
                ],
              ),
            ),
            ...children.skip(children.length - tailCount),
          ]
        : children;

    return Semantics(
      explicitChildNodes: true,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: visible,
      ),
    );
  }
}

/// One path segment. Use stable keys when replacing route segments.
class BeuiBreadcrumbItem extends StatelessWidget {
  const BeuiBreadcrumbItem({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final movement = motionFor(context, beuiSpringLayout, isMovement: true);
    final fade = motionFor(context, beuiSpringSwap, isMovement: false);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SingleMotionBuilder(
        value: 1,
        from: 0,
        motion: movement,
        builder: (context, position, child) => Opacity(
          opacity: position.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - position)),
            child: child,
          ),
        ),
        child: SingleMotionBuilder(
          value: 1,
          from: 0,
          motion: fade,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
          child: child,
        ),
      ),
    );
  }
}

/// An ancestor path segment. [onPressed] may update the current path.
class BeuiBreadcrumbLink extends StatelessWidget {
  const BeuiBreadcrumbLink({
    required this.child,
    super.key,
    this.onPressed,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Semantics(
      link: true,
      label: semanticLabel,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              foregroundColor: colors.mutedForeground,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.hovered)
                    ? colors.muted.withValues(alpha: 0.6)
                    : Colors.transparent;
              }),
              foregroundColor: WidgetStateColor.resolveWith((states) {
                return states.contains(WidgetState.hovered)
                    ? colors.foreground
                    : colors.mutedForeground;
              }),
            ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w500),
          child: child,
        ),
      ),
    );
  }
}

/// The current path segment, announced as the current page.
class BeuiBreadcrumbPage extends StatelessWidget {
  const BeuiBreadcrumbPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Semantics(
      container: true,
      label: 'Current page',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: colors.foreground,
            fontWeight: FontWeight.w500,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A decorative path divider, hidden from semantics.
class BeuiBreadcrumbSeparator extends StatelessWidget {
  const BeuiBreadcrumbSeparator({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconTheme(
          data: IconThemeData(
            color: colors.mutedForeground.withValues(alpha: 0.55),
            size: 14,
          ),
          child: child ?? Icon(LucideIcons.chevron_right, size: 14),
        ),
      ),
    );
  }
}

/// A hoverable and keyboard-operable disclosure for hidden ancestor segments.
class BeuiBreadcrumbEllipsis extends StatefulWidget {
  const BeuiBreadcrumbEllipsis({
    required this.children,
    super.key,
    this.label = 'Show hidden paths',
  });

  final List<Widget> children;
  final String label;

  @override
  State<BeuiBreadcrumbEllipsis> createState() => _BeuiBreadcrumbEllipsisState();
}

class _BeuiBreadcrumbEllipsisState extends State<BeuiBreadcrumbEllipsis> {
  bool _open = false;
  Timer? _closeTimer;
  final FocusNode _firstLinkFocus = FocusNode(
    debugLabel: 'Breadcrumb overflow first link',
  );

  @override
  void dispose() {
    _closeTimer?.cancel();
    _firstLinkFocus.dispose();
    super.dispose();
  }

  void _openAndFocus() {
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _firstLinkFocus.requestFocus();
    });
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _cancelClose();
    _closeTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted && !_firstLinkFocus.hasFocus) setState(() => _open = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return BeuiOverlay(
      open: _open,
      barrier: true,
      barrierColor: Colors.transparent,
      onDismiss: () => setState(() => _open = false),
      enterDuration: const Duration(milliseconds: 200),
      exitDuration: const Duration(milliseconds: 150),
      overlayBuilder: (context, animation, link) => Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                offset: const Offset(0, 38),
                child: MouseRegion(
                  onEnter: (_) => _cancelClose(),
                  onExit: (_) => _scheduleClose(),
                  child: FadeTransition(
                    opacity: animation,
                    child: Material(
                      color: colors.background,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: colors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 224,
                          maxHeight: 256,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var index = 0;
                                index < widget.children.length;
                                index++
                              )
                                Focus(
                                  focusNode: index == 0
                                      ? _firstLinkFocus
                                      : null,
                                  child: widget.children[index],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _openAndFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) {
            _cancelClose();
            setState(() => _open = true);
          },
          onExit: (_) => _scheduleClose(),
          child: IconButton(
            tooltip: widget.label,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => setState(() => _open = !_open),
            style: IconButton.styleFrom(foregroundColor: colors.mutedForeground)
                .copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.hovered)
                        ? colors.muted.withValues(alpha: 0.6)
                        : Colors.transparent;
                  }),
                  foregroundColor: WidgetStateColor.resolveWith((states) {
                    return states.contains(WidgetState.hovered)
                        ? colors.foreground
                        : colors.mutedForeground;
                  }),
                ),
            icon: const Icon(LucideIcons.ellipsis, size: 16),
          ),
        ),
      ),
    );
  }
}
