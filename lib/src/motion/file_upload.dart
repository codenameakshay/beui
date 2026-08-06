import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Upload state of one row (source `FileUploadStatus`).
enum BeuiFileUploadStatus {
  /// Waiting to start.
  queued,

  /// In flight; shows the spinner + progress bar.
  uploading,

  /// Done; check icon + full emerald bar.
  success,

  /// Failed; alert icon + retry affordance.
  error,
}

/// Dropzone layout (source `FileUploadVariant`).
enum BeuiFileUploadVariant {
  /// Horizontal row dropzone (source `default`).
  standard,

  /// Tall centered dropzone (source `centered`).
  centered,
}

/// One queued file (source `FileUploadItem`).
///
/// The Flutter port carries metadata only — actual file handles come from
/// whatever picker/drop plugin the consumer wires up (spec §7: the package
/// itself ships no file-picker dependency).
@immutable
class BeuiFileUploadItem {
  /// Creates a queue row.
  const BeuiFileUploadItem({
    required this.id,
    required this.name,
    required this.size,
    this.type,
    this.progress,
    this.status = BeuiFileUploadStatus.queued,
    this.error,
  });

  /// Stable identity.
  final String id;

  /// File name (drives the type icon and kind label).
  final String name;

  /// Size in bytes.
  final int size;

  /// Optional MIME type (fallback for the icon/kind).
  final String? type;

  /// Upload progress 0–100 (success clamps to 100).
  final double? progress;

  /// Row status.
  final BeuiFileUploadStatus status;

  /// Error note appended to the meta line when failed.
  final String? error;

  /// Copy with fields replaced (`clearError` drops the error note).
  BeuiFileUploadItem copyWith({
    double? progress,
    BeuiFileUploadStatus? status,
    String? error,
    bool clearError = false,
  }) => BeuiFileUploadItem(
    id: id,
    name: name,
    size: size,
    type: type,
    progress: progress ?? this.progress,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Human-readable byte size (source `formatBytes`).
String beuiFormatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final exponent = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    units.length - 1,
  );
  final value = bytes / math.pow(1024, exponent);
  final text = value >= 10 || exponent == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[exponent]}';
}

String _fileKind(BeuiFileUploadItem item) {
  final dot = item.name.lastIndexOf('.');
  if (dot > 0 && dot < item.name.length - 1) {
    return item.name.substring(dot + 1).toUpperCase();
  }
  final type = item.type;
  if (type != null && type.contains('/')) {
    return type.split('/').last.toUpperCase();
  }
  return 'FILE';
}

IconData _fileIcon(BeuiFileUploadItem item) {
  final dot = item.name.lastIndexOf('.');
  final extension = dot > 0 && dot < item.name.length - 1
      ? item.name.substring(dot + 1).toLowerCase()
      : '';
  final type = item.type ?? '';
  if (type.startsWith('image/') ||
      ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].contains(extension)) {
    return LucideIcons.file_image;
  }
  if (type.startsWith('video/') ||
      ['mp4', 'mov', 'webm', 'mkv'].contains(extension)) {
    return LucideIcons.file_video_camera;
  }
  if (type.startsWith('audio/') ||
      ['mp3', 'wav', 'flac', 'ogg'].contains(extension)) {
    return LucideIcons.file_music;
  }
  if (type.contains('zip') ||
      type.contains('compressed') ||
      ['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) {
    return LucideIcons.file_archive;
  }
  if (type.contains('spreadsheet') ||
      type.contains('excel') ||
      ['csv', 'xls', 'xlsx'].contains(extension)) {
    return LucideIcons.file_spreadsheet;
  }
  if (type.contains('pdf') ||
      type.startsWith('text/') ||
      ['pdf', 'doc', 'docx', 'md', 'txt'].contains(extension)) {
    return LucideIcons.file_text;
  }
  if ([
    'css',
    'html',
    'js',
    'jsx',
    'json',
    'mdx',
    'ts',
    'tsx',
    'xml',
    'yaml',
    'yml',
    'dart',
  ].contains(extension)) {
    return LucideIcons.file_code;
  }
  return LucideIcons.file;
}

/// An upload queue with a dropzone, progress rows, retry/remove — the Flutter
/// port of beUI's `FileUpload` block.
///
/// **Documented reduced parity** (spec §7): the web source owns a native
/// `<input type=file>` and OS drag-drop; Flutter has no plugin-free analog,
/// so the dropzone fires [onBrowse] and the consumer feeds picked files back
/// through `value`/`defaultValue` (with [BeuiFileUploadItem] metadata) using
/// whatever picker or drop plugin fits their platform. Everything visual —
/// rows, status morphs, progress motion — is ported one-to-one.
class BeuiFileUpload extends StatefulWidget {
  /// Creates an upload queue.
  const BeuiFileUpload({
    this.value,
    this.defaultValue = const [],
    this.onValueChange,
    this.onBrowse,
    this.onRemove,
    this.onRetry,
    this.maxFiles,
    this.disabled = false,
    this.variant = BeuiFileUploadVariant.standard,
    this.title = 'Drop files here',
    this.description = 'Add files to the upload queue',
    this.browseLabel = 'Browse',
    super.key,
  });

  /// Controlled queue; null for uncontrolled with [defaultValue].
  final List<BeuiFileUploadItem>? value;

  /// Initial queue when uncontrolled.
  final List<BeuiFileUploadItem> defaultValue;

  /// Fires with the queue the widget wants (after remove/retry).
  final ValueChanged<List<BeuiFileUploadItem>>? onValueChange;

  /// Fires when the dropzone is activated — open your picker here.
  final VoidCallback? onBrowse;

  /// Fires with the removed row.
  final ValueChanged<BeuiFileUploadItem>? onRemove;

  /// Fires with the reset row (progress 0, uploading) after a retry.
  final ValueChanged<BeuiFileUploadItem>? onRetry;

  /// Queue cap; reaching it disables the dropzone (source `maxFiles`).
  final int? maxFiles;

  /// Disables the dropzone.
  final bool disabled;

  /// Dropzone layout.
  final BeuiFileUploadVariant variant;

  /// Dropzone headline.
  final String title;

  /// Dropzone byline.
  final String description;

  /// Trailing browse chip label.
  final String browseLabel;

  @override
  State<BeuiFileUpload> createState() => _BeuiFileUploadState();
}

class _RowEntry {
  _RowEntry(this.item);

  BeuiFileUploadItem item;
  bool exiting = false;
}

class _BeuiFileUploadState extends State<BeuiFileUpload> {
  late List<BeuiFileUploadItem> _internal = List.of(widget.defaultValue);
  final List<_RowEntry> _entries = [];

  List<BeuiFileUploadItem> get _items => widget.value ?? _internal;

  void _setItems(List<BeuiFileUploadItem> next) {
    if (widget.value == null) {
      setState(() => _internal = next);
    } else {
      setState(() {});
    }
    widget.onValueChange?.call(next);
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BeuiFileUpload oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Mirrors [_items] into row entries; vanished rows animate out before
  /// unmounting (the AnimatePresence contract).
  void _sync() {
    final byId = {for (final item in _items) item.id: item};
    final known = {for (final e in _entries) e.item.id};
    for (final entry in _entries) {
      final match = byId[entry.item.id];
      if (match != null) {
        entry
          ..item = match
          ..exiting = false;
      } else {
        entry.exiting = true;
      }
    }
    for (final item in _items) {
      if (!known.contains(item.id)) _entries.add(_RowEntry(item));
    }
  }

  void _remove(BeuiFileUploadItem item) {
    _setItems([..._items]..removeWhere((e) => e.id == item.id));
    widget.onRemove?.call(item);
  }

  void _retry(BeuiFileUploadItem item) {
    final reset = item.copyWith(
      progress: 0,
      status: BeuiFileUploadStatus.uploading,
      clearError: true,
    );
    _setItems([
      for (final entry in _items) entry.id == item.id ? reset : entry,
    ]);
    widget.onRetry?.call(reset);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final maxReached =
        widget.maxFiles != null && _items.length >= widget.maxFiles!;
    _sync();

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12, // space-y-3
      children: [
        _Dropzone(
          variant: widget.variant,
          title: maxReached ? 'Upload limit reached' : widget.title,
          description: maxReached
              ? '${_items.length} of ${widget.maxFiles} files added'
              : widget.description,
          browseLabel: widget.browseLabel,
          enabled: !widget.disabled && !maxReached && widget.onBrowse != null,
          dimmed: widget.disabled || maxReached,
          reduce: reduce,
          colors: colors,
          onBrowse: widget.onBrowse,
        ),
        // The queue is its own list: the source nests the rows in a
        // `<ul className="space-y-2">` inside the root's `space-y-3`, so rows
        // sit 8px apart while the dropzone keeps its 12px from the list. Kept
        // out of the tree entirely when empty, or the root's spacing would add
        // a 12px gap under the dropzone with nothing beneath it.
        if (_entries.isNotEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8, // space-y-2
            children: [
              for (final entry in _entries)
                _Row(
                  key: ValueKey(entry.item.id),
                  item: entry.item,
                  exiting: entry.exiting,
                  reduce: reduce,
                  colors: colors,
                  onRemove: () => _remove(entry.item),
                  onRetry: () => _retry(entry.item),
                  onExited: () {
                    if (mounted) setState(() => _entries.remove(entry));
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _Dropzone extends StatefulWidget {
  const _Dropzone({
    required this.variant,
    required this.title,
    required this.description,
    required this.browseLabel,
    required this.enabled,
    required this.dimmed,
    required this.reduce,
    required this.colors,
    required this.onBrowse,
  });

  final BeuiFileUploadVariant variant;
  final String title;
  final String description;
  final String browseLabel;
  final bool enabled;
  final bool dimmed;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback? onBrowse;

  @override
  State<_Dropzone> createState() => _DropzoneState();
}

class _DropzoneState extends State<_Dropzone> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final centered = widget.variant == BeuiFileUploadVariant.centered;

    // The cloud icon lifts 2px while hovered/dragged-over (source dragging).
    final iconBox = SingleMotionBuilder(
      value: _hovered && !widget.reduce ? -2.0 : 0.0,
      motion: const CurvedMotion(Duration(milliseconds: 160), beuiEaseOut),
      builder: (context, dy, child) =>
          Transform.translate(offset: Offset(0, dy), child: child),
      child: Container(
        width: centered ? 64 : 56,
        height: centered ? 64 : 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.muted,
          border: centered ? Border.all(color: colors.border) : null,
          borderRadius: BorderRadius.circular(centered ? 21.6 : 20),
        ),
        child: Icon(
          LucideIcons.cloud_upload,
          size: centered ? 28 : 24,
          color: colors.foreground,
        ),
      ),
    );

    final headline = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: centered ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: centered ? 4 : 2),
          child: Text(
            widget.description,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
        ),
      ],
    );

    final browseChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: centered ? 16 : 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _hovered ? colors.muted : Colors.transparent,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        widget.browseLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.foreground,
        ),
      ),
    );

    Widget zone = Container(
      width: double.infinity,
      constraints: centered ? const BoxConstraints(minHeight: 224) : null,
      padding: EdgeInsets.all(centered ? 28 : 20),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24), // rounded-3xl
        border: Border.all(
          color: _hovered
              ? colors.foreground.withValues(alpha: 0.4)
              : colors.border,
        ),
      ),
      child: centered
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [iconBox, headline, browseChip],
            )
          : Row(
              spacing: 16, // gap-4
              children: [
                iconBox,
                Expanded(child: headline),
                browseChip,
              ],
            ),
    );

    // Dashed borders aren't native; the solid border above carries the state
    // color and the press dips to 0.99 like the source.
    zone = SingleMotionBuilder(
      value: _pressed && widget.enabled && !widget.reduce ? 0.99 : 1.0,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: zone,
    );
    if (widget.dimmed) zone = Opacity(opacity: 0.55, child: zone);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Upload files',
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.enabled ? widget.onBrowse : null,
          child: zone,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.exiting,
    required this.reduce,
    required this.colors,
    required this.onRemove,
    required this.onRetry,
    required this.onExited,
    super.key,
  });

  final BeuiFileUploadItem item;
  final bool exiting;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final VoidCallback onExited;

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final progress = status == BeuiFileUploadStatus.success
        ? 100.0
        : (item.progress ?? 0).clamp(0.0, 100.0);
    final showProgress =
        status == BeuiFileUploadStatus.uploading ||
        status == BeuiFileUploadStatus.success;
    final meta = StringBuffer(
      '${_fileKind(item)} · ${beuiFormatBytes(item.size)}',
    );
    if (status == BeuiFileUploadStatus.error && item.error != null) {
      meta.write(' · ${item.error}');
    }

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12), // p-3
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      child: Row(
        spacing: 12, // gap-3
        children: [
          Container(
            width: 44, // h-11 w-11
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _fileIcon(item),
              size: 20,
              color: colors.mutedForeground,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.foreground,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              meta.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusIcon(status: status, reduce: reduce, colors: colors),
                    if (status == BeuiFileUploadStatus.error)
                      _RowAction(
                        icon: LucideIcons.rotate_ccw,
                        label: 'Retry ${item.name}',
                        colors: colors,
                        onTap: onRetry,
                      ),
                    _RowAction(
                      icon: LucideIcons.x,
                      label: 'Remove ${item.name}',
                      colors: colors,
                      onTap: onRemove,
                    ),
                  ],
                ),
                if (showProgress)
                  Padding(
                    padding: const EdgeInsets.only(top: 12), // mt-3
                    child: Semantics(
                      label: '${item.name} upload progress',
                      value: '${progress.round()}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 6, // h-1.5
                          color: colors.muted,
                          alignment: Alignment.centerLeft,
                          // Fill eases to the new ratio (280ms EASE_OUT);
                          // reduced motion snaps.
                          child: SingleMotionBuilder(
                            value: progress / 100,
                            motion: const CurvedMotion(
                              Duration(milliseconds: 280),
                              beuiEaseOut,
                            ),
                            active: !reduce,
                            builder: (context, ratio, _) =>
                                FractionallySizedBox(
                                  widthFactor: ratio.clamp(0.0, 1.0),
                                  heightFactor: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color:
                                          status == BeuiFileUploadStatus.success
                                          ? const Color(0xFF10B981)
                                          : colors.foreground,
                                      borderRadius: BorderRadius.circular(999),
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
        ],
      ),
    );

    // Row enter: y 8 → 0 fade over 220ms EASE_OUT; exit y → -6 and collapse
    // so the queue reflows (source ROW_TRANSITION + layout).
    return SingleMotionBuilder(
      value: exiting ? 0.0 : 1.0,
      from: 0.0,
      motion: const CurvedMotion(Duration(milliseconds: 220), beuiEaseOut),
      onAnimationStatusChanged: (animationStatus) {
        if (exiting &&
            (animationStatus == AnimationStatus.completed ||
                animationStatus == AnimationStatus.dismissed)) {
          onExited();
        }
      },
      builder: (context, t, child) {
        final clamped = t.clamp(0.0, 1.0);
        Widget body = Opacity(opacity: clamped, child: child);
        if (!reduce) {
          final dy = exiting ? -6.0 * (1 - clamped) : 8.0 * (1 - clamped);
          body = Transform.translate(offset: Offset(0, dy), child: body);
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: reduce ? 1 : clamped,
            child: body,
          ),
        );
      },
      child: card,
    );
  }
}

/// Status glyph swap: y ±4 fade over 160ms EASE_OUT (source `StatusIcon`).
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.status,
    required this.reduce,
    required this.colors,
  });

  final BeuiFileUploadStatus status;
  final bool reduce;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final isDark = colors.brightness == Brightness.dark;
    final (IconData icon, Color color) = switch (status) {
      BeuiFileUploadStatus.success => (
        LucideIcons.circle_check,
        isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
      ),
      BeuiFileUploadStatus.error => (
        LucideIcons.circle_alert,
        colors.destructive,
      ),
      BeuiFileUploadStatus.uploading => (
        LucideIcons.loader_circle,
        colors.foreground,
      ),
      BeuiFileUploadStatus.queued => (LucideIcons.file, colors.mutedForeground),
    };

    Widget glyph = status == BeuiFileUploadStatus.uploading && !reduce
        ? _UploadSpinner(color: color)
        : Icon(icon, size: 16, color: color);

    return Semantics(
      label: switch (status) {
        BeuiFileUploadStatus.queued => 'Queued',
        BeuiFileUploadStatus.uploading => 'Uploading',
        BeuiFileUploadStatus.success => 'Uploaded',
        BeuiFileUploadStatus.error => 'Failed',
      },
      child: SizedBox(
        width: 24,
        height: 24,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          transitionBuilder: (child, animation) {
            if (reduce) return FadeTransition(opacity: animation, child: child);
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final exitingGlyph =
                    animation.status == AnimationStatus.reverse;
                final t = beuiEaseOut.transform(animation.value);
                return Opacity(
                  opacity: animation.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      exitingGlyph ? -4 * (1 - t) : 4 * (1 - t),
                    ),
                    child: child,
                  ),
                );
              },
            );
          },
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey(status),
            child: Center(child: glyph),
          ),
        ),
      ),
    );
  }
}

class _RowAction extends StatefulWidget {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28, // h-7 w-7
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered ? widget.colors.muted : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered
                  ? widget.colors.foreground
                  : widget.colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadSpinner extends StatefulWidget {
  const _UploadSpinner({required this.color});

  final Color color;

  @override
  State<_UploadSpinner> createState() => _UploadSpinnerState();
}

class _UploadSpinnerState extends State<_UploadSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: Icon(LucideIcons.loader_circle, size: 16, color: widget.color),
      ),
    );
  }
}
