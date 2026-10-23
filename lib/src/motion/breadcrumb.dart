import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart'
    show SingleMotionBuilder, SingleMotionController, CurvedMotion;

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
class BeuiBreadcrumbList extends StatefulWidget {
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
  State<BeuiBreadcrumbList> createState() => _BreadcrumbListState();
}

class _BreadcrumbEntry {
  _BreadcrumbEntry(this.id, this.child, this.initial);
  final Key id;
  Widget child;
  final bool initial;
  final measure = GlobalKey();
  Rect? exitRect;
  Timer? timer;
}

class _BreadcrumbListState extends State<BeuiBreadcrumbList>
    with TickerProviderStateMixin {
  final _listKey = GlobalKey();
  final _entries = <_BreadcrumbEntry>[];
  _RenderBreadcrumbWrap? _layout;

  List<Widget> _visible() {
    final children = widget.children;
    final maxItems = widget.maxItems;
    final finiteLimit = maxItems == null
        ? children.length
        : (maxItems < 3 ? 3 : maxItems);
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
                    label: widget.overflowLabel,
                    children: children.sublist(1, children.length - tailCount),
                  ),
                ],
              ),
            ),
            ...children.skip(children.length - tailCount),
          ]
        : children;

    return visible;
  }

  @override
  void initState() {
    super.initState();
    _reconcile(initial: true);
  }

  @override
  void didUpdateWidget(BeuiBreadcrumbList old) {
    super.didUpdateWidget(old);
    _reconcile();
  }

  void _reconcile({bool initial = false}) {
    final visible = _visible();
    final next = <_BreadcrumbEntry>[];
    for (var i = 0; i < visible.length; i++) {
      final child = visible[i];
      final id = child.key ?? ValueKey(i);
      final entry =
          _entries.where((entry) => entry.id == id).firstOrNull ??
          _BreadcrumbEntry(id, child, initial);
      entry.child = child;
      entry.exitRect = null;
      entry.timer?.cancel();
      next.add(entry);
    }
    final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
    for (final entry in _entries.where((entry) => !next.contains(entry))) {
      if (entry.exitRect == null) {
        final box =
            entry.measure.currentContext?.findRenderObject() as RenderBox?;
        if (list == null || box == null || !box.hasSize) continue;
        entry.exitRect =
            list.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
        entry.timer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _entries.remove(entry));
        });
      }
      next.add(entry);
    }
    _entries
      ..clear()
      ..addAll(next);
  }

  @override
  void dispose() {
    _layout?.disposePositions();
    for (final entry in _entries) {
      entry.timer?.cancel();
    }
    super.dispose();
  }

  Widget _item(_BreadcrumbEntry entry) => KeyedSubtree(
    key: entry.measure,
    child: IgnorePointer(
      ignoring: entry.exitRect != null,
      child: ExcludeFocus(
        excluding: entry.exitRect != null,
        child: ExcludeSemantics(
          excluding: entry.exitRect != null,
          child: SingleMotionBuilder(
            value: entry.exitRect == null ? 1 : 0,
            from: entry.initial ? 1 : 0,
            motion: const CurvedMotion(
              Duration(milliseconds: 200),
              beuiEaseOut,
            ),
            child: _BreadcrumbInteraction(
              isEnabled: () =>
                  mounted &&
                  entry.exitRect == null &&
                  _BreadcrumbInteraction.enabledOf(context),
              child: entry.child,
            ),
            builder: (context, p, child) => Opacity(
              opacity: p.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.disableAnimationsOf(context) ? 0 : 6 * (1 - p),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    explicitChildNodes: true,
    child: Stack(
      key: _listKey,
      clipBehavior: Clip.none,
      children: [
        _BreadcrumbWrap(
          vsync: this,
          onCreated: (layout) => _layout = layout,
          ids: [
            for (final entry in _entries.where(
              (entry) => entry.exitRect == null,
            ))
              entry.id,
          ],
          reduce: MediaQuery.disableAnimationsOf(context),
          spacing: widget.spacing,
          runSpacing: widget.runSpacing,
          children: [
            for (final entry in _entries.where(
              (entry) => entry.exitRect == null,
            ))
              _item(entry),
          ],
        ),
        for (final entry in _entries.where((entry) => entry.exitRect != null))
          Positioned.fromRect(rect: entry.exitRect!, child: _item(entry)),
      ],
    ),
  );
}

class _BreadcrumbWrap extends MultiChildRenderObjectWidget {
  const _BreadcrumbWrap({
    required this.vsync,
    required this.ids,
    required this.reduce,
    required this.spacing,
    required this.runSpacing,
    required this.onCreated,
    required super.children,
  });
  final TickerProvider vsync;
  final List<Key> ids;
  final bool reduce;
  final double spacing, runSpacing;
  final ValueChanged<_RenderBreadcrumbWrap> onCreated;
  @override
  _RenderBreadcrumbWrap createRenderObject(BuildContext context) {
    final layout = _RenderBreadcrumbWrap(
      vsync,
      ids,
      reduce,
      spacing,
      runSpacing,
      Directionality.of(context),
    );
    onCreated(layout);
    return layout;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBreadcrumbWrap renderObject,
  ) {
    renderObject
      ..configure(ids, reduce)
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..textDirection = Directionality.of(context);
  }
}

class _BreadcrumbPosition {
  _BreadcrumbPosition(this.target, TickerProvider vsync, VoidCallback changed)
    : x = SingleMotionController(
        motion: beuiSpringLayout,
        vsync: vsync,
        initialValue: target.dx,
      ),
      y = SingleMotionController(
        motion: beuiSpringLayout,
        vsync: vsync,
        initialValue: target.dy,
      ) {
    x.addListener(changed);
    y.addListener(changed);
  }
  Offset target;
  final SingleMotionController x, y;
  void move(Offset next) {
    if (next.dx != target.dx) x.animateTo(next.dx);
    if (next.dy != target.dy) y.animateTo(next.dy);
    target = next;
  }

  void dispose() {
    x.dispose();
    y.dispose();
  }
}

class _RenderBreadcrumbWrap extends RenderWrap {
  _RenderBreadcrumbWrap(
    this.vsync,
    this.ids,
    this.reduce,
    double spacing,
    double runSpacing,
    TextDirection textDirection,
  ) : super(
        spacing: spacing,
        runSpacing: runSpacing,
        textDirection: textDirection,
        crossAxisAlignment: WrapCrossAlignment.center,
      );
  final TickerProvider vsync;
  List<Key> ids;
  bool reduce;
  final _positions = <Key, _BreadcrumbPosition>{};
  void configure(List<Key> next, bool reduced) {
    for (final key in _positions.keys.toList()) {
      if (reduced || !next.contains(key)) _positions.remove(key)!.dispose();
    }
    ids = next;
    reduce = reduced;
    markNeedsLayout();
  }

  void disposePositions() {
    for (final position in _positions.values) {
      position.dispose();
    }
    _positions.clear();
  }

  @override
  void dispose() {
    disposePositions();
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (reduce) return;
    RenderBox? child = firstChild;
    var index = 0;
    while (child != null) {
      final data = child.parentData! as WrapParentData;
      final position = _positions.putIfAbsent(
        ids[index++],
        () => _BreadcrumbPosition(data.offset, vsync, markNeedsLayout),
      );
      position.move(data.offset);
      data.offset = Offset(position.x.value, position.y.value);
      child = data.nextSibling;
    }
  }
}

/// One path segment. Use stable keys when replacing route segments.
class BeuiBreadcrumbItem extends StatelessWidget {
  const BeuiBreadcrumbItem({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(container: true, explicitChildNodes: true, child: child);
  }
}

class _BreadcrumbInteraction extends InheritedWidget {
  const _BreadcrumbInteraction({required this.isEnabled, required super.child});

  final bool Function() isEnabled;

  static bool enabledOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<_BreadcrumbInteraction>()
          ?.isEnabled() ??
      true;

  @override
  bool updateShouldNotify(_BreadcrumbInteraction oldWidget) => false;
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
        onPressed: onPressed == null
            ? null
            : () {
                if (_BreadcrumbInteraction.enabledOf(context)) onPressed!();
              },
        style:
            TextButton.styleFrom(
              foregroundColor: colors.mutedForeground,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              textStyle: const TextStyle(fontSize: 14, height: 20 / 14),
              splashFactory: NoSplash.splashFactory,
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
  final _triggerKey = GlobalKey();
  final _panelKey = GlobalKey();
  final _triggerFocus = FocusNode();
  final _panelFocus = FocusScopeNode();
  Offset _panelOffset = const Offset(0, 38);
  bool _above = false;
  Timer? _closeTimer;
  final FocusNode _firstLinkFocus = FocusNode(
    debugLabel: 'Breadcrumb overflow first link',
  );

  @override
  void dispose() {
    _closeTimer?.cancel();
    _firstLinkFocus.dispose();
    _triggerFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  void _openAndFocus() {
    setState(() => _open = true);
    _focusFirst();
  }

  void _focusFirst([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) {
        final link = _panelFocus.traversalDescendants
            .where((node) => node.canRequestFocus && !node.skipTraversal)
            .firstOrNull;
        link?.requestFocus();
        if (link == null && attempt < 3) _focusFirst(attempt + 1);
      }
    });
  }

  void _close() {
    final returnFocus = _panelFocus.hasFocus;
    setState(() => _open = false);
    if (returnFocus) _triggerFocus.requestFocus();
  }

  void _measurePanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      final trigger =
          _triggerKey.currentContext?.findRenderObject() as RenderBox?;
      final panel = _panelKey.currentContext?.findRenderObject() as RenderBox?;
      if (trigger == null || panel == null || !panel.hasSize) return;
      final rect = trigger.localToGlobal(Offset.zero) & trigger.size;
      final viewport = MediaQuery.sizeOf(context);
      final above =
          rect.bottom + 6 + panel.size.height > viewport.height - 8 &&
          rect.top > viewport.height - rect.bottom;
      final x =
          rect.left.clamp(
            8.0,
            (viewport.width - panel.size.width - 8).clamp(8.0, double.infinity),
          ) -
          rect.left;
      final offset = Offset(
        x,
        above ? -panel.size.height - 6 : rect.height + 6,
      );
      if (_panelOffset != offset || _above != above) {
        setState(() {
          _panelOffset = offset;
          _above = above;
        });
      }
    });
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _cancelClose();
    _closeTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted && !_panelFocus.hasFocus) _close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    _measurePanel();
    return BeuiOverlay(
      open: _open,
      barrier: true,
      barrierColor: Colors.transparent,
      onDismiss: _close,
      enterDuration: const Duration(milliseconds: 500),
      exitDuration: const Duration(milliseconds: 500),
      overlayBuilder: (context, animation, link) => IgnorePointer(
        ignoring: !_open,
        child: ExcludeFocus(
          excluding: !_open,
          child: ExcludeSemantics(
            excluding: !_open,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: CompositedTransformFollower(
                      link: link,
                      showWhenUnlinked: false,
                      offset: _panelOffset,
                      child: MouseRegion(
                        onEnter: (_) => _cancelClose(),
                        onExit: (_) => _scheduleClose(),
                        child: SingleMotionBuilder(
                          value: _open ? 1 : 0,
                          from: 0,
                          motion: motionFor(
                            context,
                            beuiSpringPanel,
                            isMovement: true,
                            reducedFallback: const CurvedMotion(
                              Duration(milliseconds: 120),
                            ),
                          ),
                          builder: (context, p, child) => Opacity(
                            opacity: p.clamp(0, 1),
                            child: MediaQuery.disableAnimationsOf(context)
                                ? child
                                : Transform.scale(
                                    scale: .96 + .04 * p,
                                    alignment: _above
                                        ? Alignment.bottomLeft
                                        : Alignment.topLeft,
                                    child: ClipPath(
                                      clipper: _BreadcrumbMorphClip(
                                        p.clamp(0, 1),
                                        _above,
                                      ),
                                      child: child,
                                    ),
                                  ),
                          ),
                          child: _BreadcrumbInteraction(
                            isEnabled: () =>
                                mounted &&
                                _open &&
                                _BreadcrumbInteraction.enabledOf(this.context),
                            child: FocusScope(
                              node: _panelFocus,
                              child: Material(
                                key: _panelKey,
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (
                                            var index = 0;
                                            index < widget.children.length;
                                            index++
                                          )
                                            Focus(
                                              skipTraversal: true,
                                              canRequestFocus: false,
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            key: _triggerKey,
            focusNode: _triggerFocus,
            tooltip: widget.label,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () {
              if (_open) {
                _close();
              } else if (FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional) {
                _openAndFocus();
              } else {
                setState(() => _open = true);
              }
            },
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

class _BreadcrumbMorphClip extends CustomClipper<Path> {
  const _BreadcrumbMorphClip(this.progress, this.above);
  final double progress;
  final bool above;
  @override
  Path getClip(Size size) {
    final hidden = .92 * (1 - progress);
    final rect = Rect.fromLTRB(
      0,
      above ? size.height * hidden : 0,
      size.width * (1 - hidden),
      above ? size.height : size.height * (1 - hidden),
    );
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)));
  }

  @override
  bool shouldReclip(_BreadcrumbMorphClip old) =>
      old.progress != progress || old.above != above;
}
