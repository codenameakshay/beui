import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One preview shown in a [BeuiProjectFolder].
@immutable
class BeuiProjectFolderPreview {
  /// Creates a preview with a stable identifier for its shared-layout motion.
  const BeuiProjectFolderPreview({required this.id, required this.content});

  /// Stable identity for this preview.
  final String id;

  /// Preview artwork.
  final Widget content;
}

/// A folder card that fans out previews and opens them in a modal grid.
class BeuiProjectFolder extends StatefulWidget {
  /// Creates a project folder.
  const BeuiProjectFolder({
    required this.title,
    this.description = 'Updated recently',
    this.previews = const [],
    this.count,
    this.itemLabel = 'file',
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    this.onClick,
    this.disabled = false,
    this.semanticLabel,
    super.key,
  });

  /// Folder title.
  final String title;

  /// Supporting footer text.
  final String description;

  /// Preview cards; only the first five are displayed.
  final List<BeuiProjectFolderPreview> previews;

  /// Footer item count. Defaults to [previews].length.
  final int? count;

  /// Singular label used in the footer.
  final String itemLabel;

  /// Controls the fanned state when non-null.
  final bool? open;

  /// Initial fanned state when [open] is uncontrolled.
  final bool defaultOpen;

  /// Called when the fanned state changes.
  final ValueChanged<bool>? onOpenChange;

  /// Controls the dialog state when non-null.
  final bool? expanded;

  /// Initial dialog state when [expanded] is uncontrolled.
  final bool defaultExpanded;

  /// Called when the dialog state changes.
  final ValueChanged<bool>? onExpandedChange;

  /// Called after the folder is activated.
  final VoidCallback? onClick;

  /// Disables folder interaction.
  final bool disabled;

  /// Accessible button label. Defaults to [title].
  final String? semanticLabel;

  @override
  State<BeuiProjectFolder> createState() => _BeuiProjectFolderState();
}

const int _maxPreviews = 5;
const Duration _overlayMotionDuration = Duration(milliseconds: 520);

class _BeuiProjectFolderState extends State<BeuiProjectFolder> {
  final GlobalKey _buttonKey = GlobalKey();
  final FocusNode _buttonFocus = FocusNode(debugLabel: 'BeuiProjectFolder');
  final FocusNode _closeFocus = FocusNode(debugLabel: 'BeuiProjectFolderClose');
  bool _internalOpen = false;
  bool _internalExpanded = false;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _restoreFocus = false;
  bool _morphToGrid = false;
  Timer? _restoreTimer;

  List<BeuiProjectFolderPreview> get _previews =>
      widget.previews.take(_maxPreviews).toList(growable: false);

  bool get _isExpanded => widget.expanded ?? _internalExpanded;
  bool get _isOpen => (widget.open ?? _internalOpen) || _isExpanded;

  int get _count => widget.count ?? widget.previews.length;

  String get _countText =>
      '$_count ${widget.itemLabel}${_count == 1 ? '' : 's'}';

  @override
  void initState() {
    super.initState();
    _internalOpen = widget.defaultOpen;
    _internalExpanded = widget.defaultExpanded;
    _morphToGrid = _internalExpanded;
    if (_internalExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isExpanded) _closeFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant BeuiProjectFolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isExpanded && !_morphToGrid) _scheduleGridMorph();
    if (!_isExpanded && _morphToGrid) _morphToGrid = false;
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _buttonFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  void _setOpen(bool value) {
    if (widget.disabled) return;
    if (widget.open == null) setState(() => _internalOpen = value);
    widget.onOpenChange?.call(value);
  }

  void _setExpanded(bool value) {
    if (widget.disabled || (value && _previews.isEmpty)) return;
    _restoreTimer?.cancel();
    if (widget.expanded == null) {
      setState(() {
        _internalExpanded = value;
        if (!value) _morphToGrid = false;
      });
    }
    widget.onExpandedChange?.call(value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isExpanded) _closeFocus.requestFocus();
      });
      _scheduleGridMorph();
    } else {
      _restoreFocus = true;
      _restoreTimer = Timer(_overlayMotionDuration, () {
        if (mounted && _restoreFocus && !_isExpanded) {
          _restoreFocus = false;
          _buttonFocus.requestFocus();
        }
      });
    }
  }

  void _scheduleGridMorph() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isExpanded && !_morphToGrid) {
        setState(() => _morphToGrid = true);
      }
    });
  }

  void _activate() {
    if (widget.disabled) return;
    _restoreTimer?.cancel();
    _restoreFocus = false;
    _setExpanded(true);
    _setOpen(true);
    widget.onClick?.call();
  }

  void _close() {
    _setExpanded(false);
    _setOpen(false);
  }

  Rect _buttonRect() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  ({double x, double y, double rotate, double scale, double opacity, int z})
  _previewTransform(int index, int count, {required bool open}) {
    final offset = index - (count - 1) / 2;
    final distance = offset.abs();
    final lift = math.max(0.0, 2 - distance) * 8;
    var x = offset * 44.0;
    var y = 8 - lift;
    var rotate = offset * 6.0;
    var scale = distance == 0 ? 1.04 : (distance == 1 ? 0.95 : 0.88);
    var opacity = distance == 0 ? 1.0 : (distance == 1 ? 0.78 : 0.58);
    if (open) {
      x *= 1.4;
      y -= 8;
      rotate *= 1.3;
      scale *= 1.02;
      opacity = math.min(1, opacity + 0.18);
    }
    return (
      x: x,
      y: y,
      rotate: rotate,
      scale: scale,
      opacity: opacity,
      z: 10 - distance.round(),
    );
  }

  Rect _sourceRect(int index, int count, {required bool open}) {
    final origin = _buttonRect();
    final t = _previewTransform(index, count, open: open);
    final width = 96.0 * t.scale;
    final height = 160.0 * t.scale;
    return Rect.fromLTWH(
      origin.left + origin.width / 2 - 48 + t.x + (96 - width) / 2,
      origin.top + t.y + (160 - height) / 2,
      width,
      height,
    );
  }

  Rect _gridRect(BoxConstraints constraints, int index, int count) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final columns = width < 640
        ? 2
        : width < 1024
        ? 3
        : 5;
    final gridWidth = math.min(976.0, width - 48);
    final cardWidth = math.min(
      160.0,
      (gridWidth - (columns - 1) * 12) / columns,
    );
    final cardHeight = cardWidth * 4 / 3;
    final rows = (count / columns).ceil();
    final contentHeight = 72.0 + 24 + rows * cardHeight + (rows - 1) * 12;
    final left = (width - (columns * cardWidth + (columns - 1) * 12)) / 2;
    final top = math.max(24.0, (height - contentHeight) / 2) + 96;
    return Rect.fromLTWH(
      left + (index % columns) * (cardWidth + 12),
      top + (index ~/ columns) * (cardHeight + 12),
      cardWidth,
      cardHeight,
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final viewport = MediaQuery.sizeOf(context);
    final previews = _previews;
    final open = _morphToGrid;
    final viewportConstraints = BoxConstraints.tight(viewport);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: widget.title,
      scopesRoute: true,
      namesRoute: true,
      child: SizedBox(
        width: viewport.width,
        height: viewport.height,
        child: Stack(
          children: [
            Positioned(
              top: _gridHeaderTop(viewportConstraints, previews.length),
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 976),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: colors.foreground,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _countText,
                                style: TextStyle(
                                  color: colors.mutedForeground,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          focusNode: _closeFocus,
                          tooltip: 'Close ${widget.title}',
                          onPressed: _close,
                          icon: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: colors.mutedForeground,
                          ),
                          style: IconButton.styleFrom(
                            fixedSize: const Size(40, 40),
                            side: BorderSide(
                              color: colors.border.withValues(alpha: 0.7),
                            ),
                            backgroundColor: colors.background.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: _FolderOverlayGrid(
                previews: previews,
                colors: colors,
                targetRects: [
                  for (var i = 0; i < previews.length; i++)
                    _gridRect(viewportConstraints, i, previews.length),
                ],
                sourceRects: [
                  for (var i = 0; i < previews.length; i++)
                    _sourceRect(i, previews.length, open: true),
                ],
                open: open,
                reduce: reduce,
              ),
            ),
            if (animation.value < 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: colors.background.withValues(
                      alpha: (1 - animation.value) * 0.08,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _gridHeaderTop(BoxConstraints constraints, int count) {
    final width = constraints.maxWidth;
    final columns = width < 640
        ? 2
        : width < 1024
        ? 3
        : 5;
    final gridWidth = math.min(976.0, width - 48);
    final cardWidth = math.min(
      160.0,
      (gridWidth - (columns - 1) * 12) / columns,
    );
    final cardHeight = cardWidth * 4 / 3;
    final rows = (count / columns).ceil();
    final contentHeight = 72.0 + 24 + rows * cardHeight + (rows - 1) * 12;
    return math.max(24.0, (constraints.maxHeight - contentHeight) / 2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final previews = _previews;
    final isExpanded = _isExpanded;
    final isOpen = _isOpen;
    final layoutMotion = motionFor(context, beuiSpringLayout, isMovement: true);
    final pressMotion = motionFor(context, beuiSpringPress, isMovement: true);
    final openTargets = [
      for (var i = 0; i < previews.length; i++)
        _previewTransform(i, previews.length, open: true),
    ];
    final restTargets = [
      for (var i = 0; i < previews.length; i++)
        _previewTransform(i, previews.length, open: false),
    ];
    final fanOrder = List<int>.generate(previews.length, (i) => i)
      ..sort((a, b) => restTargets[a].z.compareTo(restTargets[b].z));

    return BeuiOverlay(
      open: isExpanded,
      onDismiss: _close,
      barrierColor: colors.background.withValues(alpha: 0.8),
      barrierBlur: beuiBlurSigma(24),
      enterDuration: _overlayMotionDuration,
      exitDuration: _overlayMotionDuration,
      overlayBuilder: _buildOverlay,
      child: SizedBox(
        width: 288,
        height: 224,
        child: Focus(
          focusNode: _buttonFocus,
          onFocusChange: (focused) {
            if (_restoreFocus && focused) {
              _restoreFocus = false;
              _focused = false;
              return;
            }
            _focused = focused;
            if (!isExpanded && !_restoreFocus) _setOpen(focused || _hovered);
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              _activate();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            button: true,
            enabled: !widget.disabled,
            label: widget.semanticLabel ?? widget.title,
            expanded: isExpanded,
            hint: 'Opens a dialog',
            onTap: widget.disabled ? null : _activate,
            child: GestureDetector(
              key: _buttonKey,
              behavior: HitTestBehavior.opaque,
              onTap: widget.disabled ? null : _activate,
              onTapDown: widget.disabled
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapUp: widget.disabled
                  ? null
                  : (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: MouseRegion(
                cursor: widget.disabled
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                onEnter: (_) {
                  _hovered = true;
                  if (!isExpanded) _setOpen(true);
                },
                onExit: (_) {
                  _hovered = false;
                  if (!isExpanded) _setOpen(_focused);
                },
                child: SingleMotionBuilder(
                  value: _pressed && !reduce ? 0.98 : 1,
                  motion: pressMotion,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: SingleMotionBuilder(
                          value: isOpen && !reduce ? 15.0 : 0.0,
                          motion: layoutMotion,
                          builder: (context, angle, child) => Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX((reduce ? 0 : angle) * math.pi / 180),
                            child: child,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.background.withValues(alpha: 0.25),
                              border: Border.all(
                                color: colors.border.withValues(alpha: 0.7),
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      if (!isExpanded)
                        for (final i in fanOrder)
                          _FanPreview(
                            preview: previews[i],
                            colors: colors,
                            rest: restTargets[i],
                            open: openTargets[i],
                            isOpen: isOpen && !reduce,
                            motion: layoutMotion,
                          ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SingleMotionBuilder(
                          value: isOpen && !reduce ? -25.0 : 0.0,
                          motion: layoutMotion,
                          builder: (context, angle, child) => Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX((reduce ? 0 : angle) * math.pi / 180),
                            child: child,
                          ),
                          child: _FolderFront(
                            title: widget.title,
                            countText: _countText,
                            description: widget.description,
                            colors: colors,
                          ),
                        ),
                      ),
                      if (widget.disabled)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.background.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }
}

class _FanPreview extends StatelessWidget {
  const _FanPreview({
    required this.preview,
    required this.colors,
    required this.rest,
    required this.open,
    required this.isOpen,
    required this.motion,
  });

  final BeuiProjectFolderPreview preview;
  final BeuiColors colors;
  final ({
    double x,
    double y,
    double rotate,
    double scale,
    double opacity,
    int z,
  })
  rest;
  final ({
    double x,
    double y,
    double rotate,
    double scale,
    double opacity,
    int z,
  })
  open;
  final bool isOpen;
  final Motion motion;

  Rect _rect(
    ({double x, double y, double rotate, double scale, double opacity, int z})
    value,
  ) {
    final width = 96.0 * value.scale;
    final height = 160.0 * value.scale;
    return Rect.fromLTWH(
      96 + value.x + (96 - width) / 2,
      value.y + (160 - height) / 2,
      width,
      height,
    );
  }

  @override
  Widget build(BuildContext context) => MotionBuilder<Rect>(
    value: _rect(isOpen ? open : rest),
    motion: motion,
    converter: const RectMotionConverter(),
    builder: (context, rect, child) {
      final start = _rect(rest);
      final end = _rect(open);
      final dx = end.left - start.left;
      final dy = end.top - start.top;
      final progress = dx.abs() >= dy.abs()
          ? (dx == 0 ? 0.0 : (rect.left - start.left) / dx)
          : (dy == 0 ? 0.0 : (rect.top - start.top) / dy);
      final t = progress.clamp(0.0, 1.0);
      return Positioned.fromRect(
        rect: rect,
        child: Transform.rotate(
          angle:
              (rest.rotate + (open.rotate - rest.rotate) * t) * math.pi / 180,
          child: Opacity(
            opacity: rest.opacity + (open.opacity - rest.opacity) * t,
            child: child,
          ),
        ),
      );
    },
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(8),
        color: colors.background.withValues(alpha: 0.45),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: preview.content,
      ),
    ),
  );
}

class _FolderFront extends StatelessWidget {
  const _FolderFront({
    required this.title,
    required this.countText,
    required this.description,
    required this.colors,
  });

  final String title;
  final String countText;
  final String description;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colors.background.withValues(alpha: 0.9),
      border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 64,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.border.withValues(alpha: 0.65)),
            ),
          ),
          child: Row(
            children: [
              Text(
                countText,
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: colors.mutedForeground, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FolderOverlayGrid extends StatelessWidget {
  const _FolderOverlayGrid({
    required this.previews,
    required this.colors,
    required this.targetRects,
    required this.sourceRects,
    required this.open,
    required this.reduce,
  });

  final List<BeuiProjectFolderPreview> previews;
  final BeuiColors colors;
  final List<Rect> targetRects;
  final List<Rect> sourceRects;
  final bool open;
  final bool reduce;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < previews.length; i++)
          MotionBuilder<Rect>(
            value: open ? targetRects[i] : sourceRects[i],
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            converter: const RectMotionConverter(),
            builder: (context, rect, child) {
              final shown = reduce
                  ? (open ? targetRects[i] : sourceRects[i])
                  : rect;
              return Positioned.fromRect(
                rect: shown,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: 0.5),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.8),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: child,
                  ),
                ),
              );
            },
            child: previews[i].content,
          ),
      ],
    ),
  );
}
