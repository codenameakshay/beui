import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart'
    show MotionBuilder, NoMotion, RectMotionConverter, SingleMotionBuilder;

/// A gallery image and the content rendered for it in both gallery and viewer.
@immutable
class BeuiImageViewerImage {
  /// Creates an image entry. [content] should preserve the supplied aspect ratio.
  const BeuiImageViewerImage({
    required this.id,
    required this.alt,
    required this.width,
    required this.height,
    required this.content,
    this.caption,
  }) : assert(width > 0 && height > 0);

  /// Stable identity used by thumbnails and selection.
  final String id;

  /// Accessible image description.
  final String alt;

  /// Intrinsic width used to preserve the image ratio.
  final double width;

  /// Intrinsic height used to preserve the image ratio.
  final double height;

  /// Image content; pass an [Image] for network/assets or a placeholder widget.
  final Widget content;

  /// Optional caption. Defaults to [alt].
  final String? caption;
}

/// Composable photo gallery and modal image viewer.
///
/// Selection is controlled when [value] is non-null (or [isControlled] is true
/// for a deliberately null closed value); otherwise the gallery owns its
/// selection, seeded by [defaultValue].
class BeuiImageViewer extends StatefulWidget {
  /// Creates a viewer around gallery children or a default thumbnail grid.
  const BeuiImageViewer({
    required this.images,
    this.value,
    this.defaultValue,
    this.isControlled = false,
    this.onChanged,
    this.label = 'Image gallery',
    this.children,
    super.key,
  });

  /// Images available in the viewer.
  final List<BeuiImageViewerImage> images;

  /// Selected image id, or null when closed. Use with [onChanged].
  final String? value;

  /// Initial selected image in uncontrolled mode.
  final String? defaultValue;

  /// Set true when [value] is controlled and intentionally null (closed).
  /// Non-null [value] is controlled automatically.
  final bool isControlled;

  /// Called when a thumbnail, navigation control, or dismiss action requests a
  /// new selection.
  final ValueChanged<String?>? onChanged;

  /// Accessible label for the gallery and dialog.
  final String label;

  /// Custom composition. If omitted, a thumbnail grid and viewer are supplied.
  final Widget? children;

  @override
  State<BeuiImageViewer> createState() => _BeuiImageViewerState();
}

class _BeuiImageViewerState extends State<BeuiImageViewer> {
  String? _internalValue;
  late Map<String, GlobalKey> _thumbnailKeys;
  Rect? _sourceRect;
  Rect? _pendingSourceRect;
  String? _pendingSourceImageId;
  String? _returnId;

  bool get _controlled => widget.isControlled || widget.value != null;
  String? get _selected => _controlled ? widget.value : _internalValue;

  @override
  void initState() {
    super.initState();
    _internalValue = widget.defaultValue;
    _thumbnailKeys = {for (final image in widget.images) image.id: GlobalKey()};
    _validateImages();
  }

  @override
  void didUpdateWidget(covariant BeuiImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateImages();
    if (_controlled && widget.value != oldWidget.value) {
      if (oldWidget.value != null && widget.value == null) _restoreFocus();
      if (widget.value != null) {
        if (oldWidget.value == null) _returnId = widget.value;
        _sourceRect = widget.value == _pendingSourceImageId
            ? _pendingSourceRect
            : null;
      }
      _pendingSourceRect = null;
      _pendingSourceImageId = null;
    }
    if (oldWidget.images.map((image) => image.id).join('|') !=
        widget.images.map((image) => image.id).join('|')) {
      _thumbnailKeys = {
        for (final image in widget.images) image.id: GlobalKey(),
      };
    }
    if (!_controlled &&
        _selected != null &&
        !widget.images.any((image) => image.id == _selected)) {
      _internalValue = null;
    }
  }

  void _validateImages() {
    final ids = widget.images.map((image) => image.id).toSet();
    if (ids.length != widget.images.length) {
      throw ArgumentError('BeuiImageViewer image ids must be unique.');
    }
  }

  void _select(String? id) {
    if (!_controlled && id != null && _selected == null) _returnId = id;
    if (id != null && id != _selected) {
      final key = _thumbnailKeys[id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      final rect = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      if (_controlled) {
        // Keep request geometry separate until the controlled owner accepts
        // that id. An unrelated owner selection discards it.
        _pendingSourceRect = rect;
        _pendingSourceImageId = id;
      } else {
        _sourceRect = rect;
      }
    }
    if (!_controlled) {
      setState(() => _internalValue = id);
      if (id == null) _restoreFocus();
    }
    widget.onChanged?.call(id);
  }

  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selected != null) return;
      final target = _thumbnailKeys[_returnId]?.currentState;
      if (target is _ImageViewerThumbnailButtonState) {
        target._focus.requestFocus();
      }
    });
  }

  void _move(int delta) {
    final index = widget.images.indexWhere((image) => image.id == _selected);
    final next = index + delta;
    if (index >= 0 && next >= 0 && next < widget.images.length) {
      _select(widget.images[next].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ImageViewerScope(
      images: widget.images,
      selectedId: _selected,
      label: widget.label,
      select: _select,
      move: _move,
      thumbnailKeys: _thumbnailKeys,
      sourceRect: _sourceRect,
      child: Align(
        alignment: Alignment.topCenter,
        child:
            widget.children ??
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiImageViewerGallery(
                  children: [
                    for (final image in widget.images)
                      BeuiImageViewerThumbnail(imageId: image.id),
                  ],
                ),
                const BeuiImageViewerContent(),
              ],
            ),
      ),
    );
  }
}

class _ImageViewerScope extends InheritedWidget {
  const _ImageViewerScope({
    required this.images,
    required this.selectedId,
    required this.label,
    required this.select,
    required this.move,
    required this.thumbnailKeys,
    required this.sourceRect,
    required super.child,
  });

  final List<BeuiImageViewerImage> images;
  final String? selectedId;
  final String label;
  final ValueChanged<String?> select;
  final ValueChanged<int> move;
  final Map<String, GlobalKey> thumbnailKeys;
  final Rect? sourceRect;

  static _ImageViewerScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ImageViewerScope>();
    if (scope == null) {
      throw FlutterError('Image viewer parts must be inside BeuiImageViewer.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(_ImageViewerScope oldWidget) =>
      images != oldWidget.images ||
      selectedId != oldWidget.selectedId ||
      label != oldWidget.label ||
      sourceRect != oldWidget.sourceRect;
}

/// Gallery layout for [BeuiImageViewerThumbnail] children.
class BeuiImageViewerGallery extends StatelessWidget {
  /// Creates a responsive thumbnail grid.
  const BeuiImageViewerGallery({
    required this.children,
    this.columns,
    this.gap = 12,
    super.key,
  }) : assert(columns == null || columns > 0),
       assert(gap >= 0);

  /// Thumbnail widgets.
  final List<Widget> children;

  /// Defaults to two columns below 640px and three above, like the source grid.
  final int? columns;

  /// Space between thumbnails on both axes.
  final double gap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: _ImageViewerScope.of(context).label,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final count =
            columns ?? (MediaQuery.sizeOf(context).width < 640 ? 2 : 3);
        final width = constraints.hasBoundedWidth
            ? ((constraints.maxWidth - gap * (count - 1)) / count).clamp(
                0.0,
                double.infinity,
              )
            : 120.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    ),
  );
}

/// A button that opens the corresponding image in the lightbox.
class BeuiImageViewerThumbnail extends StatelessWidget {
  /// Creates a thumbnail trigger.
  const BeuiImageViewerThumbnail({required this.imageId, super.key});

  /// The image id from [BeuiImageViewer.images].
  final String imageId;

  @override
  Widget build(BuildContext context) {
    final scope = _ImageViewerScope.of(context);
    final image = scope.images.firstWhere(
      (item) => item.id == imageId,
      orElse: () => throw FlutterError('Unknown image id "$imageId".'),
    );
    final selected = scope.selectedId == imageId;
    final colors = BeuiColors.resolve(context);
    return _ImageViewerThumbnailButton(
      key: scope.thumbnailKeys[imageId],
      image: image,
      selected: selected,
      color: colors.muted,
      onTap: () => scope.select(imageId),
    );
  }
}

class _ImageViewerThumbnailButton extends StatefulWidget {
  const _ImageViewerThumbnailButton({
    required this.image,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  final BeuiImageViewerImage image;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ImageViewerThumbnailButton> createState() =>
      _ImageViewerThumbnailButtonState();
}

class _ImageViewerThumbnailButtonState
    extends State<_ImageViewerThumbnailButton> {
  bool _pressed = false;
  final _focus = FocusNode(debugLabel: 'Image thumbnail');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movement = motionFor(context, beuiSpringLayout, isMovement: true);
    return Semantics(
      button: true,
      expanded: widget.selected,
      label: 'Open ${widget.image.alt}',
      child: SingleMotionBuilder(
        value: _pressed ? 0.98 : 1.0,
        motion: motionFor(context, beuiSpringPress, isMovement: true),
        builder: (context, scale, child) => movement is NoMotion
            ? child!
            : Transform.scale(scale: scale, child: child),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: widget.color,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              focusNode: _focus,
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: AspectRatio(
                aspectRatio: widget.image.width / widget.image.height,
                child: widget.image.content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Counter showing the selected image index and total.
class BeuiImageViewerCounter extends StatelessWidget {
  /// Creates the live counter.
  const BeuiImageViewerCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _ImageViewerScope.of(context);
    final index = scope.images.indexWhere(
      (image) => image.id == scope.selectedId,
    );
    return Semantics(
      liveRegion: true,
      label: '${index + 1} of ${scope.images.length}',
      child: Text(
        '${index + 1} / ${scope.images.length}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

/// Caption for the selected image; defaults to its caption and then alt text.
class BeuiImageViewerCaption extends StatelessWidget {
  /// Creates the live caption.
  const BeuiImageViewerCaption({this.child, super.key});

  /// Optional replacement caption.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scope = _ImageViewerScope.of(context);
    final image = scope.images
        .where((item) => item.id == scope.selectedId)
        .firstOrNull;
    return Semantics(
      liveRegion: true,
      child:
          child ??
          Text(
            image?.caption ?? image?.alt ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
    );
  }
}

/// Dismisses the lightbox.
class BeuiImageViewerClose extends StatelessWidget {
  /// Creates the close control.
  const BeuiImageViewerClose({super.key});

  @override
  Widget build(BuildContext context) => _ViewerControl(
    label: 'Close viewer',
    icon: LucideIcons.x,
    onPressed: () => _ImageViewerScope.of(context).select(null),
  );
}

/// Selects the previous image.
class BeuiImageViewerPrevious extends StatelessWidget {
  /// Creates the previous-image control.
  const BeuiImageViewerPrevious({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _ImageViewerScope.of(context);
    final index = scope.images.indexWhere(
      (image) => image.id == scope.selectedId,
    );
    return _ViewerControl(
      label: 'Previous image',
      icon: LucideIcons.chevron_left,
      enabled: index > 0,
      onPressed: () => scope.move(-1),
    );
  }
}

/// Selects the next image.
class BeuiImageViewerNext extends StatelessWidget {
  /// Creates the next-image control.
  const BeuiImageViewerNext({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _ImageViewerScope.of(context);
    final index = scope.images.indexWhere(
      (image) => image.id == scope.selectedId,
    );
    return _ViewerControl(
      label: 'Next image',
      icon: LucideIcons.chevron_right,
      enabled: index >= 0 && index < scope.images.length - 1,
      onPressed: () => scope.move(1),
    );
  }
}

class _ViewerControl extends StatelessWidget {
  const _ViewerControl({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    child: IconButton(
      tooltip: label,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        minimumSize: const Size(40, 40),
        fixedSize: const Size(40, 40),
      ),
    ),
  );
}

/// Modal image surface, rendered through [BeuiOverlay].
class BeuiImageViewerContent extends StatefulWidget {
  /// Creates the viewer surface. [header] and [footer] replace default controls.
  const BeuiImageViewerContent({this.header, this.footer, super.key});

  /// Optional header composition.
  final Widget? header;

  /// Optional footer composition.
  final Widget? footer;

  @override
  State<BeuiImageViewerContent> createState() => _BeuiImageViewerContentState();
}

class _BeuiImageViewerContentState extends State<BeuiImageViewerContent> {
  BeuiImageViewerImage? _lastImage;

  @override
  Widget build(BuildContext context) {
    final scope = _ImageViewerScope.of(context);
    final selected = scope.images
        .where((image) => image.id == scope.selectedId)
        .firstOrNull;
    if (selected != null) _lastImage = selected;
    final displayed = selected ?? _lastImage;
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return BeuiOverlay(
      open: selected != null,
      onDismiss: () => scope.select(null),
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierEnterDuration: const Duration(milliseconds: 180),
      barrierExitDuration: const Duration(milliseconds: 120),
      enterDuration: const Duration(milliseconds: 500),
      exitDuration: const Duration(milliseconds: 500),
      overlayBuilder: (context, animation, _) {
        if (displayed == null) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return IgnorePointer(
              ignoring: selected == null,
              child: ExcludeFocus(
                excluding: selected == null,
                child: ExcludeSemantics(
                  excluding: selected == null,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 640 ? 12 : 24,
                      ),
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: (_, event) {
                          if (HardwareKeyboard.instance.isAltPressed ||
                              HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isMetaPressed ||
                              HardwareKeyboard.instance.isShiftPressed) {
                            return KeyEventResult.ignored;
                          }
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.arrowLeft) {
                            scope.move(-1);
                            return KeyEventResult.handled;
                          }
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight) {
                            scope.move(1);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          scopesRoute: true,
                          namesRoute: true,
                          label: scope.label,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  widget.header ??
                                      const BeuiImageViewerCounter(),
                                  if (widget.header == null)
                                    const BeuiImageViewerClose(),
                                ],
                              ),
                              Expanded(
                                child: ClipRect(
                                  child: _MorphingViewerImage(
                                    image: displayed,
                                    sourceRect: scope.sourceRect,
                                    opening: selected != null,
                                    reduce: reduce,
                                    colors: colors,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  if (widget.footer == null)
                                    const BeuiImageViewerPrevious(),
                                  Expanded(
                                    child:
                                        widget.footer ??
                                        const BeuiImageViewerCaption(),
                                  ),
                                  if (widget.footer == null)
                                    const BeuiImageViewerNext(),
                                ],
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
          },
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

class _MorphingViewerImage extends StatefulWidget {
  const _MorphingViewerImage({
    required this.image,
    required this.sourceRect,
    required this.opening,
    required this.reduce,
    required this.colors,
  });

  final BeuiImageViewerImage image;
  final Rect? sourceRect;
  final bool opening;
  final bool reduce;
  final BeuiColors colors;

  @override
  State<_MorphingViewerImage> createState() => _MorphingViewerImageState();
}

class _MorphingViewerImageState extends State<_MorphingViewerImage> {
  final GlobalKey _stackKey = GlobalKey();
  Rect? _sourceLocal;
  bool _measureScheduled = false;

  @override
  void didUpdateWidget(covariant _MorphingViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceRect != widget.sourceRect) {
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    if (_measureScheduled || widget.sourceRect == null || widget.reduce) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final source = widget.sourceRect;
      if (box == null || !box.hasSize || source == null) return;
      final sourceLocal = box.globalToLocal(source.topLeft) & source.size;
      if (_sourceLocal != sourceLocal) {
        setState(() => _sourceLocal = sourceLocal);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final aspect = widget.image.width / widget.image.height;
      final fittedWidth = math.min(
        width,
        math.min(height, MediaQuery.sizeOf(context).height - 160) * aspect,
      );
      final fittedHeight = fittedWidth / aspect;
      final destination = Rect.fromLTWH(
        (width - fittedWidth) / 2,
        (height - fittedHeight) / 2,
        fittedWidth,
        fittedHeight,
      );
      _scheduleMeasure();
      final sourceLocal = _sourceLocal;
      final target = widget.opening ? destination : sourceLocal ?? destination;
      Widget positioned(Rect rect) => Positioned.fill(
        child: _ZoomableImage(
          image: widget.image,
          reduce: widget.reduce,
          colors: widget.colors,
          viewport: Size(width, height),
          rect: rect,
        ),
      );

      return Stack(
        key: _stackKey,
        clipBehavior: Clip.none,
        children: [
          if (widget.reduce || widget.sourceRect == null || sourceLocal == null)
            Positioned.fill(
              child: _ZoomableImage(
                image: widget.image,
                reduce: widget.reduce,
                colors: widget.colors,
                viewport: Size(width, height),
                rect: destination,
              ),
            )
          else
            MotionBuilder<Rect>(
              key: const ValueKey('image-viewer-morph'),
              value: target,
              from: widget.opening ? sourceLocal : null,
              motion: beuiSpringLayout,
              converter: const RectMotionConverter(),
              builder: (context, rect, _) => positioned(rect),
            ),
        ],
      );
    },
  );
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.image,
    required this.reduce,
    required this.colors,
    required this.viewport,
    required this.rect,
  });

  final BeuiImageViewerImage image;
  final bool reduce;
  final BeuiColors colors;
  final Size viewport;
  final Rect rect;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _zoomFocus = FocusNode(debugLabel: 'Image zoom');
  bool _zoomed = false;
  Offset _pan = Offset.zero;
  Offset? _swipeStart;
  Offset? _swipeCurrent;
  int _direction = 1;

  @override
  void dispose() {
    _zoomFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id) {
      final images = _ImageViewerScope.of(context).images;
      _direction =
          images.indexWhere((image) => image.id == widget.image.id) <
              images.indexWhere((image) => image.id == oldWidget.image.id)
          ? -1
          : 1;
      _zoomed = false;
      _pan = Offset.zero;
      _swipeStart = null;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _swipeStart = details.focalPoint;
        _swipeCurrent = details.focalPoint;
      },
      onScaleEnd: (_) {
        final start = _swipeStart;
        final current = _swipeCurrent;
        _swipeStart = null;
        _swipeCurrent = null;
        if (!_zoomed && start != null && current != null) {
          final dx = current.dx - start.dx;
          final dy = current.dy - start.dy;
          if (dx.abs() > 50 && dx.abs() > dy.abs() * 1.5) {
            final scope = _ImageViewerScope.of(context);
            scope.move(dx < 0 ? 1 : -1);
          }
        }
      },
      onScaleUpdate: (details) {
        _swipeCurrent = details.focalPoint;
        if (_zoomed) {
          setState(
            () => _pan = _clampPan(
              _pan + details.focalPointDelta,
              widget.rect.size,
            ),
          );
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Transform.translate(
              offset:
                  widget.rect.center -
                  widget.viewport.center(Offset.zero) +
                  (_zoomed ? _pan : Offset.zero),
              child: SingleMotionBuilder(
                value: _zoomed ? 2 : 1,
                motion: motionFor(context, beuiSpringLayout, isMovement: true),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.rect.width,
                    maxHeight: widget.rect.height,
                  ),
                  child: AspectRatio(
                    aspectRatio: widget.image.width / widget.image.height,
                    child: AnimatedSwitcher(
                      duration: Duration(
                        milliseconds: widget.reduce ? 100 : 280,
                      ),
                      switchInCurve: beuiEaseDrawer,
                      switchOutCurve: beuiEaseDrawer.flipped,
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) => widget.reduce
                          ? FadeTransition(opacity: animation, child: child)
                          : SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(
                                  (child.key == ValueKey(widget.image.id)
                                          ? _direction
                                          : -_direction)
                                      .toDouble(),
                                  0,
                                ),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                      child: SizedBox.expand(
                        key: ValueKey(widget.image.id),
                        child: widget.image.content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Focus(
              onKeyEvent: (_, event) {
                if (!_zoomed || event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final delta = switch (event.logicalKey) {
                  LogicalKeyboardKey.arrowLeft => const Offset(-40, 0),
                  LogicalKeyboardKey.arrowRight => const Offset(40, 0),
                  LogicalKeyboardKey.arrowUp => const Offset(0, -40),
                  LogicalKeyboardKey.arrowDown => const Offset(0, 40),
                  _ => Offset.zero,
                };
                if (delta == Offset.zero) return KeyEventResult.ignored;
                setState(
                  () => _pan = _clampPan(_pan + delta, widget.rect.size),
                );
                return KeyEventResult.handled;
              },
              child: Semantics(
                button: true,
                toggled: _zoomed,
                label: _zoomed ? 'Zoom out' : 'Zoom in',
                child: IconButton.filled(
                  focusNode: _zoomFocus,
                  tooltip: _zoomed ? 'Zoom out' : 'Zoom in',
                  onPressed: () => setState(() {
                    _zoomFocus.requestFocus();
                    _zoomed = !_zoomed;
                    _pan = Offset.zero;
                  }),
                  icon: Icon(_zoomed ? LucideIcons.minus : LucideIcons.plus),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Offset _clampPan(Offset value, Size image) {
    final x = math.max(0.0, (image.width * 2 - widget.viewport.width) / 2);
    final y = math.max(0.0, (image.height * 2 - widget.viewport.height) / 2);
    return Offset(value.dx.clamp(-x, x), value.dy.clamp(-y, y));
  }
}
