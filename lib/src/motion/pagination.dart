import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_focus_ring.dart';
import '_engine.dart';

/// The two distinct gap positions emitted by [beuiPaginationRange].
enum BeuiPaginationGap {
  /// The omitted pages are before the middle window.
  start,

  /// The omitted pages are after the middle window.
  end,
}

/// A typed entry in the visible pagination range.
sealed class BeuiPaginationItem {
  /// Creates a range entry.
  const BeuiPaginationItem();
}

/// One visible page number.
final class BeuiPaginationPage extends BeuiPaginationItem {
  /// Creates a page range entry.
  const BeuiPaginationPage(this.page);

  /// The one-based page number.
  final int page;

  @override
  bool operator ==(Object other) =>
      other is BeuiPaginationPage && other.page == page;

  @override
  int get hashCode => Object.hash(BeuiPaginationPage, page);
}

/// A gap in the visible range, whose direction determines its jump action.
final class BeuiPaginationEllipsis extends BeuiPaginationItem {
  /// Creates a typed start or end gap.
  const BeuiPaginationEllipsis(this.gap);

  /// Whether the gap is before or after the middle range.
  final BeuiPaginationGap gap;

  @override
  bool operator ==(Object other) =>
      other is BeuiPaginationEllipsis && other.gap == gap;

  @override
  int get hashCode => Object.hash(BeuiPaginationEllipsis, gap);
}

/// Returns the source-ordered page and ellipsis entries for a pagination row.
///
/// The slot threshold and four range outcomes match `pagination.tsx` exactly.
/// Values of [siblings] and [boundaries] are not normalized; the source leaves
/// those inputs unvalidated as well. Non-positive sibling/boundary/jump values
/// remain an unresolved API-validation decision, so this port does not invent
/// a validation or clamping rule.
List<BeuiPaginationItem> beuiPaginationRange(
  int page,
  int totalPages, {
  int siblings = 1,
  int boundaries = 1,
}) {
  List<BeuiPaginationItem> range(int start, int end) => [
    for (var value = start; value <= end; value++) BeuiPaginationPage(value),
  ];

  final slots = boundaries * 2 + siblings * 2 + 3;
  if (totalPages <= slots) return range(1, totalPages);

  final leftCandidate = page - siblings;
  final left = leftCandidate > boundaries ? leftCandidate : boundaries;
  final rightCandidate = page + siblings;
  final rightLimit = totalPages - boundaries;
  final right = rightCandidate < rightLimit ? rightCandidate : rightLimit;
  final showStart = left > boundaries + 2;
  final showEnd = right < totalPages - (boundaries + 1);

  if (!showStart && showEnd) {
    return [
      ...range(1, siblings * 2 + boundaries + 2),
      const BeuiPaginationEllipsis(BeuiPaginationGap.end),
      ...range(totalPages - boundaries + 1, totalPages),
    ];
  }
  if (showStart && !showEnd) {
    return [
      ...range(1, boundaries),
      const BeuiPaginationEllipsis(BeuiPaginationGap.start),
      ...range(totalPages - (boundaries + 1 + siblings * 2), totalPages),
    ];
  }
  return [
    ...range(1, boundaries),
    const BeuiPaginationEllipsis(BeuiPaginationGap.start),
    ...range(left, right),
    const BeuiPaginationEllipsis(BeuiPaginationGap.end),
    ...range(totalPages - boundaries + 1, totalPages),
  ];
}

/// Metadata supplied to an optional application-router link builder.
@immutable
class BeuiPaginationLinkProps {
  /// Creates router-link metadata for [page].
  const BeuiPaginationLinkProps({
    required this.page,
    required this.href,
    required this.label,
    required this.current,
    required this.child,
    required this.activate,
  });

  /// Target page represented by this link.
  final int page;

  /// Shareable route string returned by `getHref`.
  final String href;

  /// Accessible name for this page control.
  final String label;

  /// Whether this is the displayed page.
  final bool current;

  /// Visual content for the control, including the source directional glyph.
  final Widget child;

  /// Routes an unmodified activation to [page].
  ///
  /// Router adapters should pass through the original browser event state:
  /// `defaultPrevented` and Meta/Control/Shift/Alt activation leave navigation
  /// to the host, just as the source anchor does. Flutter itself has no DOM
  /// default-prevention event, so callers must provide those flags explicitly
  /// when adapting a web/router event.
  final void Function({
    bool? defaultPrevented,
    bool? metaKey,
    bool? ctrlKey,
    bool? shiftKey,
    bool? altKey,
  })
  activate;
}

/// Builds a router-specific link while retaining pagination metadata.
///
/// The builder should render [BeuiPaginationLinkProps.child] and apply its
/// label/current state to the host link's semantics. The host link owns actual
/// route navigation; call `activate` only for unmodified activation.
typedef BeuiPaginationLinkBuilder =
    Widget Function(BuildContext context, BeuiPaginationLinkProps props);

/// Animated page navigation matching beUI's `pagination` component.
///
/// Pass [page] to control the displayed page, or use [defaultPage] for
/// internally managed state. The range algorithm is also exposed separately
/// as [beuiPaginationRange]. The component has no arrow-key paging contract:
/// controls participate in ordinary Tab order and support Enter/Space.
/// The row follows ambient [Directionality] for logical control order, while
/// its chevron glyphs retain the source's LTR left/right meanings; source RTL
/// glyph mirroring has no pinned behavior contract.
///
/// Under reduced motion, page/layout positions snap to their targets, while
/// the source's 120ms opacity transitions remain.
class BeuiPagination extends StatefulWidget {
  /// Creates a pagination row for [totalPages].
  const BeuiPagination({
    required this.totalPages,
    this.page,
    this.defaultPage = 1,
    this.onPageChange,
    this.siblings = 1,
    this.boundaries = 1,
    this.jump = 5,
    this.getHref,
    this.linkBuilder,
    this.semanticLabel = 'Pagination',
    this.style,
    super.key,
  });

  /// Number of pages; values below one display a single page.
  final int totalPages;

  /// Controlled page. Values are bounded to the available pages.
  final int? page;

  /// Initial page used when [page] is null.
  final int defaultPage;

  /// Called only when the bounded target differs from the displayed page.
  final ValueChanged<int>? onPageChange;

  /// Pages shown on either side of the current page.
  final int siblings;

  /// Pages always shown at either end.
  final int boundaries;

  /// Page delta represented by either ellipsis.
  final int jump;

  /// Optional shareable route metadata for page links.
  final String Function(int page)? getHref;

  /// Optional router-specific link widget. Without it, controls remain buttons.
  final BeuiPaginationLinkBuilder? linkBuilder;

  /// Navigation landmark label; defaults to `Pagination`.
  final String semanticLabel;

  /// Optional decoration for the navigation row.
  final BoxDecoration? style;

  @override
  State<BeuiPagination> createState() => _BeuiPaginationState();
}

class _BeuiPaginationState extends State<BeuiPagination> {
  late int _internalPage = _bounded(widget.defaultPage);

  int get _total => widget.totalPages < 1 ? 1 : widget.totalPages;
  int _bounded(int value) => value.clamp(1, _total).toInt();
  int get _current => _bounded(widget.page ?? _internalPage);

  void _go(int requested) {
    final target = _bounded(requested);
    if (target == _current) return;
    if (widget.page == null) setState(() => _internalPage = target);
    widget.onPageChange?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final compact = MediaQuery.sizeOf(context).width < 640;
    final size = compact ? 32.0 : 36.0;
    final current = _current;
    final entries = beuiPaginationRange(
      current,
      _total,
      siblings: widget.siblings,
      boundaries: widget.boundaries,
    );

    Widget button({
      required int target,
      required String label,
      required Widget child,
      bool? disabled,
      bool? selected,
      bool? hoverBackground,
      Color? foreground,
      Color? background,
      Key? key,
      Key? measureKey,
    }) {
      final isDisabled = disabled ?? false;
      final isSelected = selected ?? false;
      final hasHoverBackground = hoverBackground ?? false;
      final href = widget.getHref?.call(target);
      if (href != null && !isDisabled && widget.linkBuilder != null) {
        return KeyedSubtree(
          key: key,
          child: SizedBox(
            width: size,
            height: size,
            child: Semantics(
              key: measureKey,
              child: widget.linkBuilder!(
                context,
                BeuiPaginationLinkProps(
                  page: target,
                  href: href,
                  label: label,
                  current: isSelected,
                  child: child,
                  activate:
                      ({
                        bool? defaultPrevented,
                        bool? metaKey,
                        bool? ctrlKey,
                        bool? shiftKey,
                        bool? altKey,
                      }) {
                        if (defaultPrevented == true ||
                            metaKey == true ||
                            ctrlKey == true ||
                            shiftKey == true ||
                            altKey == true) {
                          return;
                        }
                        _go(target);
                      },
                ),
              ),
            ),
          ),
        );
      }
      return _PaginationControl(
        key: key,
        size: size,
        label: label,
        selected: isSelected,
        hoverBackground: hasHoverBackground,
        disabled: isDisabled,
        foreground: foreground ?? colors.mutedForeground,
        background: background ?? Colors.transparent,
        measureKey: measureKey,
        onActivate: isDisabled ? null : () => _go(target),
        child: child,
      );
    }

    final previous = button(
      target: current - 1,
      label: 'Previous page',
      disabled: current == 1,
      child: Icon(LucideIcons.chevron_left, size: 16),
      key: const ValueKey('pagination-previous'),
    );
    final next = button(
      target: current + 1,
      label: 'Next page',
      disabled: current == _total,
      child: Icon(LucideIcons.chevron_right, size: 16),
      key: const ValueKey('pagination-next'),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: DecoratedBox(
        decoration: widget.style ?? const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            previous,
            SizedBox(width: compact ? 2 : 4),
            _PaginationWindow(
              key: const ValueKey('pagination-window'),
              entries: entries,
              current: current,
              jump: widget.jump,
              compact: compact,
              reduce: reduce,
              colors: colors,
              makeButton: button,
            ),
            SizedBox(width: compact ? 2 : 4),
            next,
          ],
        ),
      ),
    );
  }
}

/// A button with native focus traversal and keyboard activation.
class _PaginationControl extends StatefulWidget {
  const _PaginationControl({
    required this.size,
    required this.label,
    required this.selected,
    required this.hoverBackground,
    required this.disabled,
    required this.foreground,
    required this.background,
    required this.measureKey,
    required this.child,
    required this.onActivate,
    super.key,
  });

  final double size;
  final String label;
  final bool selected;
  final bool hoverBackground;
  final bool disabled;
  final Color foreground;
  final Color background;
  final Key? measureKey;
  final Widget child;
  final VoidCallback? onActivate;

  @override
  State<_PaginationControl> createState() => _PaginationControlState();
}

class _PaginationControlState extends State<_PaginationControl> {
  final FocusNode _focusNode = FocusNode();
  bool _focusVisible = false;
  bool _focused = false;
  bool _pressed = false;
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    final scale = _pressed && !reduce ? 0.94 : 1.0;
    return Semantics(
      key: widget.measureKey,
      excludeSemantics: true,
      button: true,
      enabled: !widget.disabled,
      selected: widget.selected,
      focused: widget.disabled ? null : _focused,
      label: widget.label,
      onTap: widget.disabled ? null : widget.onActivate,
      onFocus: widget.disabled ? null : _requestFocus,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: FocusableActionDetector(
          enabled: !widget.disabled,
          focusNode: _focusNode,
          onFocusChange: (focused) => setState(() {
            _focused = focused;
          }),
          onShowFocusHighlight: (visible) => setState(() {
            _focusVisible = visible;
          }),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (!widget.disabled) widget.onActivate?.call();
                return null;
              },
            ),
          },
          child: _PaginationFocusVisibleScope(
            focused: _focusVisible,
            child: MouseRegion(
              onEnter: widget.disabled
                  ? null
                  : (_) => setState(() => _hovered = true),
              onExit: widget.disabled
                  ? null
                  : (_) => setState(() => _hovered = false),
              cursor: widget.disabled
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.disabled
                    ? null
                    : (_) => setState(() => _pressed = true),
                onTapUp: widget.disabled
                    ? null
                    : (_) => setState(() => _pressed = false),
                onTapCancel: widget.disabled
                    ? null
                    : () => setState(() => _pressed = false),
                onTap: widget.disabled ? null : widget.onActivate,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: BeuiFocusRing(
                    focused: _focusVisible,
                    borderRadius: BorderRadius.circular(9999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      transform: Matrix4.diagonal3Values(scale, scale, 1),
                      transformAlignment: Alignment.center,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.disabled
                            ? Colors.transparent
                            : widget.selected ||
                                  !_hovered ||
                                  !widget.hoverBackground
                            ? widget.background
                            : colors.foreground.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: widget.disabled
                                ? colors.mutedForeground.withValues(alpha: 0.4)
                                : _hovered && !widget.selected
                                ? colors.foreground
                                : widget.foreground,
                            fontSize: 14,
                            height: 1,
                            fontWeight: widget.selected
                                ? FontWeight.w500
                                : null,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          child: IconTheme.merge(
                            data: IconThemeData(
                              color: widget.disabled
                                  ? colors.mutedForeground.withValues(
                                      alpha: 0.4,
                                    )
                                  : _hovered
                                  ? colors.foreground
                                  : widget.foreground,
                            ),
                            child: widget.child,
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
    );
  }

  void _requestFocus() {
    if (!widget.disabled) _focusNode.requestFocus();
  }
}

class _PaginationFocusVisibleScope extends InheritedWidget {
  const _PaginationFocusVisibleScope({
    required this.focused,
    required super.child,
  });

  final bool focused;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_PaginationFocusVisibleScope>()
          ?.focused ??
      false;

  @override
  bool updateShouldNotify(_PaginationFocusVisibleScope oldWidget) =>
      focused != oldWidget.focused;
}

typedef _MakeButton =
    Widget Function({
      required int target,
      required String label,
      required Widget child,
      bool? disabled,
      bool? selected,
      bool? hoverBackground,
      Color? foreground,
      Color? background,
      Key? key,
      Key? measureKey,
    });

class _PaginationWindow extends StatefulWidget {
  const _PaginationWindow({
    required this.entries,
    required this.current,
    required this.jump,
    required this.compact,
    required this.reduce,
    required this.colors,
    required this.makeButton,
    super.key,
  });

  final List<BeuiPaginationItem> entries;
  final int current;
  final int jump;
  final bool compact;
  final bool reduce;
  final BeuiColors colors;
  final _MakeButton makeButton;

  @override
  State<_PaginationWindow> createState() => _PaginationWindowState();
}

class _PaginationWindowState extends State<_PaginationWindow> {
  final _stackKey = GlobalKey();
  final Map<int, GlobalKey> _pageKeys = {};
  Rect? _activeRect;
  late List<_VisibleEntry> _entries = [
    for (final item in widget.entries) _VisibleEntry(item),
  ];

  @override
  void didUpdateWidget(covariant _PaginationWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameRange =
        oldWidget.entries.length == widget.entries.length &&
        oldWidget.entries.asMap().entries.every(
          (entry) => entry.value == widget.entries[entry.key],
        );
    if (sameRange && oldWidget.compact == widget.compact) return;
    final byItem = {for (final entry in _entries) entry.item: entry};
    final priorActive = _entries.where((entry) => !entry.exiting).toList();
    final row = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final oldPositions = <BeuiPaginationItem, double>{};
    final oldSizes = <BeuiPaginationItem, Size>{};
    if (row != null && row.hasSize) {
      for (final entry in _entries) {
        final renderBox =
            entry.renderKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) continue;
        final origin = row.globalToLocal(renderBox.localToGlobal(Offset.zero));
        oldPositions[entry.item] = origin.dx;
        oldSizes[entry.item] = renderBox.size;
      }
    }
    for (final entry in priorActive) {
      if (!widget.entries.contains(entry.item)) {
        final left = oldPositions[entry.item];
        final size = oldSizes[entry.item];
        if (left != null && size != null) {
          entry.exitRect = Rect.fromLTWH(left, 0, size.width, size.height);
        }
        entry.exiting = true;
        entry.offset = Offset.zero;
        entry.moveGeneration++;
        entry.exitOpacityDone = false;
        entry.exitScaleDone =
            widget.reduce || entry.item is! BeuiPaginationPage;
        entry.timer = Timer(
          Duration(milliseconds: widget.reduce ? 120 : 160),
          () => _markExitOpacityDone(entry),
        );
      }
    }
    final ordered = <_VisibleEntry>[];
    for (var index = 0; index < widget.entries.length; index++) {
      final item = widget.entries[index];
      final entry = byItem[item] ?? _VisibleEntry(item, entering: true);
      if (entry.exiting) {
        entry.timer?.cancel();
        entry.entering = false;
        entry.exitOpacityDone = false;
        entry.exitScaleDone = false;
      }
      entry.exiting = false;
      entry.exitRect = null;
      final oldPosition = oldPositions[item];
      if (oldPosition != null) {
        final newExtent =
            (widget.compact ? 32.0 : 36.0) + (widget.compact ? 2.0 : 4.0);
        final targetPosition = index * newExtent;
        entry.offset = Offset(oldPosition - targetPosition, 0);
        if (entry.offset != Offset.zero) {
          // Re-keying cancels the old spring at its *rendered* value and starts
          // the replacement from that exact point, so rapid page changes do
          // not jump backward to an obsolete index-based estimate.
          entry.moveGeneration++;
        }
      } else if (oldWidget.compact != widget.compact) {
        entry.offset = Offset.zero;
        entry.moveGeneration++;
      }
      ordered.add(entry);
    }
    _entries = [
      ...ordered,
      for (final entry in _entries)
        if (entry.exiting && !widget.entries.contains(entry.item)) entry,
    ];
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureActive());
    final gap = widget.compact ? 2.0 : 4.0;
    final activeEntries = _entries.where((entry) => !entry.exiting).toList();
    final row = Row(
      key: _stackKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < activeEntries.length; index++) ...[
          if (index > 0) SizedBox(width: gap),
          _entry(activeEntries[index]),
        ],
      ],
    );
    final overlays = <Widget>[
      for (final entry in _entries)
        if (entry.exitRect case final rect? when entry.exiting)
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: _entry(entry),
          ),
    ];
    final rect = _activeRect;
    if (rect == null) {
      return Stack(clipBehavior: Clip.none, children: [row, ...overlays]);
    }
    final pill = Positioned.fill(
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(rect.left, rect.top),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.colors.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final indicator = widget.reduce
        ? pill
        : MotionBuilder<Rect>(
            value: rect,
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            converter: const RectMotionConverter(),
            builder: (context, animatedRect, child) => Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(animatedRect.left, animatedRect.top),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: animatedRect.width,
                      height: animatedRect.height,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.colors.foreground,
                shape: BoxShape.circle,
              ),
            ),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [indicator, row, ...overlays],
    );
  }

  void _measureActive() {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    final index = widget.entries.indexWhere(
      (entry) => entry is BeuiPaginationPage && entry.page == widget.current,
    );
    if (index < 0) return;
    final extent =
        (widget.compact ? 32.0 : 36.0) + (widget.compact ? 2.0 : 4.0);
    final size = widget.compact ? 32.0 : 36.0;
    final next = Rect.fromLTWH(index * extent, 0, size, size);
    if (next != _activeRect) setState(() => _activeRect = next);
  }

  void _markExitOpacityDone(_VisibleEntry entry) {
    if (!mounted || !entry.exiting) return;
    entry.exitOpacityDone = true;
    _finishExitIfReady(entry);
  }

  void _markExitScaleDone(_VisibleEntry entry) {
    if (!mounted || !entry.exiting) return;
    entry.exitScaleDone = true;
    _finishExitIfReady(entry);
  }

  void _finishExitIfReady(_VisibleEntry entry) {
    if (!mounted || !entry.exitOpacityDone || !entry.exitScaleDone) return;
    setState(() {
      _entries.remove(entry);
      entry.timer?.cancel();
      if (entry.item case BeuiPaginationPage(:final page)) {
        _pageKeys.remove(page);
      }
    });
  }

  Widget _entry(_VisibleEntry entry) {
    if (entry.entering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !entry.entering) return;
        setState(() => entry.entering = false);
      });
    }
    final item = entry.item;
    final exiting = entry.exiting;
    if (exiting && widget.reduce && !entry.exitScaleDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markExitScaleDone(entry);
      });
    }
    final isCurrent = item is BeuiPaginationPage && item.page == widget.current;
    final child = switch (item) {
      BeuiPaginationPage(:final page) => widget.makeButton(
        target: page,
        label: 'Page $page',
        selected: isCurrent,
        hoverBackground: !isCurrent,
        foreground: isCurrent
            ? widget.colors.background
            : widget.colors.mutedForeground,
        background: Colors.transparent,
        child: Stack(alignment: Alignment.center, children: [Text('$page')]),
        key: _pageKeys.putIfAbsent(page, GlobalKey.new),
        measureKey: entry.renderKey,
      ),
      BeuiPaginationEllipsis(:final gap) => _ellipsis(gap, entry.renderKey),
    };
    final activeMotion = widget.reduce
        ? const NoMotion()
        : motionFor(context, beuiSpringLayout, isMovement: true);
    final scales = item is BeuiPaginationPage;
    final enteringScale = scales && entry.entering && !widget.reduce;
    final exitingScale = scales && exiting && !widget.reduce;
    final identity = switch (item) {
      BeuiPaginationPage(:final page) => 'page-$page',
      BeuiPaginationEllipsis(:final gap) => 'gap-${gap.name}',
    };
    final positionedChild = MotionBuilder<Offset>(
      key: ValueKey('pagination-position-$identity-${entry.moveGeneration}'),
      value: Offset.zero,
      from: entry.offset,
      motion: activeMotion,
      converter: const OffsetMotionConverter(),
      builder: (context, offset, child) => Transform.translate(
        offset: widget.reduce ? Offset.zero : offset,
        child: child,
      ),
      child: child,
    );
    return KeyedSubtree(
      key: ValueKey('pagination-presence-$identity'),
      child: KeyedSubtree(
        key: entry.key,
        child: ExcludeSemantics(
          excluding: exiting,
          child: ExcludeFocus(
            excluding: exiting,
            child: IgnorePointer(
              ignoring: exiting,
              child: AnimatedOpacity(
                opacity: exiting || entry.entering ? 0 : 1,
                duration: Duration(milliseconds: widget.reduce ? 120 : 160),
                curve: beuiEaseOut,
                child: SingleMotionBuilder(
                  value: exitingScale || enteringScale ? 0.8 : 1,
                  from: enteringScale ? 0.8 : 1,
                  motion: activeMotion,
                  onAnimationStatusChanged: (status) {
                    if (status == AnimationStatus.completed && exitingScale) {
                      _markExitScaleDone(entry);
                    }
                  },
                  builder: (context, scale, child) => Transform.scale(
                    scale: widget.reduce || !scales ? 1 : scale,
                    alignment: Alignment.center,
                    child: child,
                  ),
                  child: positionedChild,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ellipsis(BeuiPaginationGap direction, Key renderKey) {
    final back = direction == BeuiPaginationGap.start;
    final target = widget.current + (back ? -widget.jump : widget.jump);
    final label = back
        ? 'Back ${widget.jump} pages'
        : 'Forward ${widget.jump} pages';
    return widget.makeButton(
      target: target,
      label: label,
      foreground: widget.colors.mutedForeground,
      child: _EllipsisGlyph(back: back, reduce: widget.reduce),
      key: ValueKey('pagination-gap-${direction.name}'),
      measureKey: renderKey,
    );
  }
}

class _VisibleEntry {
  _VisibleEntry(this.item, {this.entering = false});

  final BeuiPaginationItem item;
  final GlobalKey key = GlobalKey();
  final GlobalKey renderKey = GlobalKey();
  bool entering;
  bool exiting = false;
  Timer? timer;
  bool exitOpacityDone = false;
  bool exitScaleDone = false;
  Rect? exitRect;
  Offset offset = Offset.zero;
  int moveGeneration = 0;
}

class _EllipsisGlyph extends StatefulWidget {
  const _EllipsisGlyph({required this.back, required this.reduce});

  final bool back;
  final bool reduce;

  @override
  State<_EllipsisGlyph> createState() => _EllipsisGlyphState();
}

class _EllipsisGlyphState extends State<_EllipsisGlyph> {
  bool _active = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _active = true),
    onExit: (_) => setState(() => _active = false),
    child: Builder(
      builder: (context) {
        final focused = _PaginationFocusVisibleScope.of(context);
        final active = _active || focused;
        return SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: active ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedScale(
                  scale: widget.reduce ? 1 : (active ? 0.75 : 1),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Text(
                    '…',
                    style: TextStyle(
                      fontSize: 14,
                      color: BeuiColors.resolve(context).mutedForeground,
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedScale(
                  scale: widget.reduce ? 1 : (active ? 1 : 0.75),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Icon(
                    widget.back
                        ? LucideIcons.chevrons_left
                        : LucideIcons.chevrons_right,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
