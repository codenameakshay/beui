import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';

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

/// Rejection-notice copy for files [BeuiFileUpload.maxFileSize] filtered out
/// of the queue.
String _rejectionMessage(List<BeuiFileUploadItem> rejected, int maxFileSize) {
  final limit = beuiFormatBytes(maxFileSize);
  if (rejected.length == 1) {
    return '"${rejected.first.name}" is larger than the $limit limit';
  }
  return '${rejected.length} files exceed the $limit limit';
}

/// Lowercase filename extension, or empty when the name has none.
String _extensionOf(BeuiFileUploadItem item) {
  final dot = item.name.lastIndexOf('.');
  return dot > 0 && dot < item.name.length - 1
      ? item.name.substring(dot + 1).toLowerCase()
      : '';
}

String _fileKind(BeuiFileUploadItem item) {
  final extension = _extensionOf(item);
  if (extension.isNotEmpty) return extension.toUpperCase();
  final type = item.type;
  if (type != null && type.contains('/')) {
    return type.split('/').last.toUpperCase();
  }
  return 'FILE';
}

const _imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'];
const _videoExtensions = ['mp4', 'mov', 'webm', 'mkv'];
const _audioExtensions = ['mp3', 'wav', 'flac', 'ogg'];
const _archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz'];
const _spreadsheetExtensions = ['csv', 'xls', 'xlsx'];
const _documentExtensions = ['pdf', 'doc', 'docx', 'md', 'txt'];
const _codeExtensions = [
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
];

IconData _fileIcon(BeuiFileUploadItem item) {
  final extension = _extensionOf(item);
  final type = item.type ?? '';
  if (type.startsWith('image/') || _imageExtensions.contains(extension)) {
    return LucideIcons.file_image;
  }
  if (type.startsWith('video/') || _videoExtensions.contains(extension)) {
    return LucideIcons.file_video_camera;
  }
  if (type.startsWith('audio/') || _audioExtensions.contains(extension)) {
    return LucideIcons.file_music;
  }
  if (type.contains('zip') ||
      type.contains('compressed') ||
      _archiveExtensions.contains(extension)) {
    return LucideIcons.file_archive;
  }
  if (type.contains('spreadsheet') ||
      type.contains('excel') ||
      _spreadsheetExtensions.contains(extension)) {
    return LucideIcons.file_spreadsheet;
  }
  if (type.contains('pdf') ||
      type.startsWith('text/') ||
      _documentExtensions.contains(extension)) {
    return LucideIcons.file_text;
  }
  if (_codeExtensions.contains(extension)) {
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
///
/// The dropzone and every row action are keyboard-reachable: Tab focuses
/// them, Enter/Space activate them, and focus paints a [BeuiFocusRing]
/// rather than shifting layout. [onCancel] distinguishes stopping an
/// in-flight upload from [onRemove]'s discard-a-finished-row, and
/// [maxFileSize] + [onRejected] let a caller reject oversized files before
/// they ever reach the queue, with an inline notice surfacing why.
class BeuiFileUpload extends StatefulWidget {
  /// Creates an upload queue.
  const BeuiFileUpload({
    this.value,
    this.defaultValue = const [],
    this.onValueChange,
    this.onBrowse,
    this.onRemove,
    this.onCancel,
    this.onRetry,
    this.maxFiles,
    this.maxFileSize,
    this.onRejected,
    this.showRejectionNotice = true,
    this.disabled = false,
    this.variant = BeuiFileUploadVariant.standard,
    this.title,
    this.description,
    this.browseLabel = 'Browse files',
    this.dragAndDrop = false,
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

  /// Fires when an in-flight upload is cancelled — as opposed to
  /// [onRemove], which discards a finished or failed row. While a row is
  /// [BeuiFileUploadStatus.uploading] and this is set, the row's trailing X
  /// becomes a cancel control instead of a remove control.
  final ValueChanged<BeuiFileUploadItem>? onCancel;

  /// Fires with the reset row (progress 0, uploading) after a retry.
  final ValueChanged<BeuiFileUploadItem>? onRetry;

  /// Queue cap; reaching it disables the dropzone (source `maxFiles`).
  final int? maxFiles;

  /// Per-file size cap in bytes; null means no limit. Files over the cap
  /// are never added as rows — see [onRejected] and [showRejectionNotice].
  final int? maxFileSize;

  /// Fires once per new batch of oversized files filtered out by
  /// [maxFileSize]. Called after the frame that filtered them, never
  /// during build.
  final void Function(List<BeuiFileUploadItem> rejected)? onRejected;

  /// Shows an inline destructive-tinted notice above the queue while
  /// [maxFileSize] has rejected files. Defaults to true; the notice clears
  /// itself once the offending items stop being passed in.
  final bool showRejectionNotice;

  /// Disables the dropzone.
  final bool disabled;

  /// Dropzone layout.
  final BeuiFileUploadVariant variant;

  /// Dropzone headline. Defaults to 'Add files', or 'Drop files here' when
  /// [dragAndDrop] is true and this is left unset.
  final String? title;

  /// Dropzone byline. Defaults to 'Choose files to upload', or 'Or browse
  /// to add them to the queue' when [dragAndDrop] is true and this is left
  /// unset.
  final String? description;

  /// Trailing browse chip label.
  final String browseLabel;

  /// Set true only if you have wired a real drop target (a desktop drop
  /// plugin); it opts the default [title]/[description] copy into
  /// drag-and-drop wording. The package ships no drop handling of its own —
  /// this flag changes only what the dropzone says, not what it does.
  final bool dragAndDrop;

  @override
  State<BeuiFileUpload> createState() => _BeuiFileUploadState();
}

class _RowEntry {
  _RowEntry(this.item);

  BeuiFileUploadItem item;
  bool exiting = false;
}

/// Single-slot state for the [_RejectionNotice] banner — mirrors
/// [_RowEntry]'s exit-before-unmount contract for one persistent widget
/// instead of a list.
class _RejectionSlot {
  _RejectionSlot(this.text);

  String text;
  bool exiting = false;
}

class _BeuiFileUploadState extends State<BeuiFileUpload> {
  late List<BeuiFileUploadItem> _internal = List.of(widget.defaultValue);
  final List<_RowEntry> _entries = [];
  _RejectionSlot? _rejectionSlot;
  String _lastRejectedKey = '';

  List<BeuiFileUploadItem> get _items => widget.value ?? _internal;

  /// Items actually queued as rows — anything over
  /// [BeuiFileUpload.maxFileSize] never reaches [_entries]; see
  /// [_rejectedItems].
  List<BeuiFileUploadItem> get _acceptedItems {
    final cap = widget.maxFileSize;
    if (cap == null) return _items;
    return _items.where((item) => item.size <= cap).toList();
  }

  /// Items over [BeuiFileUpload.maxFileSize], filtered out of the queue.
  List<BeuiFileUploadItem> get _rejectedItems {
    final cap = widget.maxFileSize;
    if (cap == null) return const [];
    return _items.where((item) => item.size > cap).toList();
  }

  void _setItems(List<BeuiFileUploadItem> next) {
    setState(() {
      if (widget.value == null) _internal = next;
      _syncDerived();
    });
    widget.onValueChange?.call(next);
  }

  @override
  void initState() {
    super.initState();
    _syncDerived();
  }

  @override
  void didUpdateWidget(BeuiFileUpload oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDerived();
  }

  /// Reconciles every piece of state derived from [_items] — row entries,
  /// the rejected-batch callback, and the rejection banner — so it stays
  /// current on every path that can change [_items]: a controlled `value`
  /// update ([didUpdateWidget]) and an uncontrolled internal change
  /// ([_setItems]).
  void _syncDerived() {
    _sync();
    _checkRejections();
    _syncRejectionSlot();
  }

  void _syncRejectionSlot() {
    final rejectedItems = _rejectedItems;
    if (widget.showRejectionNotice && rejectedItems.isNotEmpty) {
      final text = _rejectionMessage(rejectedItems, widget.maxFileSize!);
      if (_rejectionSlot == null) {
        _rejectionSlot = _RejectionSlot(text);
      } else {
        _rejectionSlot!
          ..text = text
          ..exiting = false;
      }
    } else if (_rejectionSlot != null) {
      _rejectionSlot!.exiting = true;
    }
  }

  /// Mirrors [_acceptedItems] into row entries; vanished rows animate out
  /// before unmounting (the AnimatePresence contract).
  void _sync() {
    final accepted = _acceptedItems;
    final byId = {for (final item in accepted) item.id: item};
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
    for (final item in accepted) {
      if (!known.contains(item.id)) _entries.add(_RowEntry(item));
    }
  }

  /// Fires [BeuiFileUpload.onRejected] once per new batch of oversized
  /// files. Scheduled for after the frame, so a consumer callback never
  /// runs mid-build.
  void _checkRejections() {
    final rejected = _rejectedItems;
    final key = rejected.map((e) => e.id).join(',');
    if (key == _lastRejectedKey) return;
    _lastRejectedKey = key;
    final callback = widget.onRejected;
    if (rejected.isEmpty || callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(rejected);
    });
  }

  void _remove(BeuiFileUploadItem item) {
    _setItems([..._items]..removeWhere((e) => e.id == item.id));
    widget.onRemove?.call(item);
  }

  void _cancel(BeuiFileUploadItem item) {
    _setItems([..._items]..removeWhere((e) => e.id == item.id));
    widget.onCancel?.call(item);
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
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final maxReached =
        widget.maxFiles != null && _items.length >= widget.maxFiles!;

    final resolvedTitle =
        widget.title ?? (widget.dragAndDrop ? 'Drop files here' : 'Add files');
    final resolvedDescription =
        widget.description ??
        (widget.dragAndDrop
            ? 'Or browse to add them to the queue'
            : 'Choose files to upload');

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12, // space-y-3
      children: [
        _Dropzone(
          variant: widget.variant,
          title: maxReached ? 'Upload limit reached' : resolvedTitle,
          description: maxReached
              ? '${_items.length} of ${widget.maxFiles} files added'
              : resolvedDescription,
          browseLabel: widget.browseLabel,
          enabled: !widget.disabled && !maxReached && widget.onBrowse != null,
          dimmed: widget.disabled || maxReached,
          reduce: reduce,
          colors: colors,
          onBrowse: widget.onBrowse,
        ),
        if (_rejectionSlot != null)
          _RejectionNotice(
            key: const ValueKey('file-upload-rejection'),
            text: _rejectionSlot!.text,
            exiting: _rejectionSlot!.exiting,
            reduce: reduce,
            colors: colors,
            onExited: () {
              if (mounted) setState(() => _rejectionSlot = null);
            },
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
                  onCancel: widget.onCancel == null
                      ? null
                      : () => _cancel(entry.item),
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
  bool _focusVisible = false;

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
            // Source: `tracking-[-0.01em]` — one of the few beUI labels that
            // asks for tracking at all, so it is pinned rather than left to
            // the theme's (now zero) default.
            letterSpacing: (centered ? 16 : 14) * -0.01,
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
    zone = BeuiFocusRing(
      focused: _focusVisible,
      borderRadius: BorderRadius.circular(24),
      child: zone,
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Upload files',
      onTap: widget.enabled ? widget.onBrowse : null,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onBrowse?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
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
    this.onCancel,
    super.key,
  });

  final BeuiFileUploadItem item;
  final bool exiting;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final VoidCallback onExited;

  /// Set (from [BeuiFileUpload.onCancel]) only while this row is uploading;
  /// when non-null the trailing X becomes a cancel control instead of
  /// remove.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final progress = status == BeuiFileUploadStatus.success
        ? 100.0
        : (item.progress ?? 0).clamp(0.0, 100.0);
    final showProgress =
        status == BeuiFileUploadStatus.uploading ||
        status == BeuiFileUploadStatus.success;
    final canCancel =
        status == BeuiFileUploadStatus.uploading && onCancel != null;
    final metaBase = '${_fileKind(item)} · ${beuiFormatBytes(item.size)}';
    final metaError = status == BeuiFileUploadStatus.error ? item.error : null;

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
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.mutedForeground,
                                ),
                                children: [
                                  TextSpan(text: metaBase),
                                  if (metaError != null)
                                    TextSpan(
                                      text: ' · $metaError',
                                      style: TextStyle(
                                        color: colors.destructive,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusIcon(status: status, reduce: reduce, colors: colors),
                    Row(
                      spacing: 4,
                      children: [
                        if (status == BeuiFileUploadStatus.error)
                          _RowAction(
                            icon: LucideIcons.rotate_ccw,
                            label: 'Retry ${item.name}',
                            colors: colors,
                            onTap: onRetry,
                          ),
                        _RowAction(
                          icon: LucideIcons.x,
                          label: canCancel
                              ? 'Cancel upload of ${item.name}'
                              : 'Remove ${item.name}',
                          colors: colors,
                          onTap: canCancel ? onCancel! : onRemove,
                        ),
                      ],
                    ),
                  ],
                ),
                if (showProgress)
                  Padding(
                    padding: const EdgeInsets.only(top: 12), // mt-3
                    child: Semantics(
                      label: '${item.name} upload progress',
                      value: '${progress.round()}%',
                      liveRegion: status == BeuiFileUploadStatus.success,
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
                                          ? colors.success
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
    return _HeightReveal(
      exiting: exiting,
      reduce: reduce,
      onExited: onExited,
      translateY: (enter: 8.0, exit: -6.0),
      child: card,
    );
  }
}

/// Fades and height-collapses [child] on entry/exit, firing [onExited] once
/// an exit animation finishes — shared by [_Row] and [_RejectionNotice].
class _HeightReveal extends StatelessWidget {
  const _HeightReveal({
    required this.exiting,
    required this.reduce,
    required this.onExited,
    required this.child,
    this.exitDuration = const Duration(milliseconds: 220),
    this.translateY,
  });

  final bool exiting;
  final bool reduce;
  final VoidCallback onExited;
  final Widget child;

  /// Enter is always 220ms; only the exit pace differs between callers.
  static const _enterDuration = Duration(milliseconds: 220);
  final Duration exitDuration;

  /// Optional (enter, exit) vertical slide distance in px, applied under
  /// full motion only. Null keeps the fade/height-collapse alone.
  final ({double enter, double exit})? translateY;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: exiting ? 0.0 : 1.0,
      from: 0.0,
      motion: CurvedMotion(
        exiting ? exitDuration : _enterDuration,
        beuiEaseOut,
      ),
      onAnimationStatusChanged: (animationStatus) {
        if (exiting &&
            (animationStatus == AnimationStatus.completed ||
                animationStatus == AnimationStatus.dismissed)) {
          onExited();
        }
      },
      builder: (context, t, inner) {
        final clamped = t.clamp(0.0, 1.0);
        Widget body = Opacity(opacity: clamped, child: inner);
        final offsets = translateY;
        if (!reduce && offsets != null) {
          final dy = exiting
              ? offsets.exit * (1 - clamped)
              : offsets.enter * (1 - clamped);
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
      child: child,
    );
  }
}

/// Inline notice for files [BeuiFileUpload.maxFileSize] filtered out of the
/// queue — same enter/exit contract as [_Row] (220ms in, faster 160ms out)
/// so the banner doesn't jump when a mixed batch settles.
class _RejectionNotice extends StatelessWidget {
  const _RejectionNotice({
    required this.text,
    required this.exiting,
    required this.reduce,
    required this.colors,
    required this.onExited,
    super.key,
  });

  final String text;
  final bool exiting;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onExited;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(LucideIcons.circle_alert, size: 16, color: colors.destructive),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: colors.destructive),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: _HeightReveal(
        exiting: exiting,
        reduce: reduce,
        onExited: onExited,
        exitDuration: const Duration(milliseconds: 160),
        child: card,
      ),
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
    final (IconData icon, Color color) = switch (status) {
      BeuiFileUploadStatus.success => (
        LucideIcons.circle_check,
        colors.success,
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
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
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
    );

    return BeuiMinHitTarget(
      child: Semantics(
        button: true,
        label: widget.label,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) =>
              setState(() => _focusVisible = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          child: GestureDetector(
            onTap: widget.onTap,
            child: BeuiFocusRing(
              focused: _focusVisible,
              borderRadius: BorderRadius.circular(14),
              child: circle,
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
