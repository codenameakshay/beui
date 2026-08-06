import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'tooltip.dart';

// ---------------------------------------------------------------------------
// Timings — ported verbatim from the source module constants.
// ---------------------------------------------------------------------------

/// Source `ITEM_TRANSITION` — `{ duration: 0.2, ease: EASE_OUT }`.
const _itemTransition = CurvedMotion(Duration(milliseconds: 200), beuiEaseOut);

/// Source `DEFAULT_MAX_FILE_SIZE` — `500 * 1024 * 1024`.
const _defaultMaxFileSize = 500 * 1024 * 1024;

/// Source `UPLOAD_PROGRESS_MS`.
const _uploadProgress = Duration(milliseconds: 900);

/// Source `UPLOAD_COMPLETE_HOLD_MS`.
const _uploadCompleteHold = Duration(milliseconds: 1000);

/// Source `REMOVE_PENDING_MS`.
const _removePending = Duration(milliseconds: 420);

/// The source shortens both lifecycle waits to 140ms under reduced motion.
const _reducedLifecycle = Duration(milliseconds: 140);

/// Source `arrivalDelay` step — `Math.min(max(arrivalIndex, 0), 5) * 0.055`.
const _arrivalStagger = Duration(milliseconds: 55);

/// Source `WAVEFORM_BARS` heights, in order.
const _waveformBars = <double>[
  18, 31, 24, 39, 30, 43, 27, 18, 9, 29, 38, 24, 34, 18, 26, 37, 21, 14, //
  7, 11, 22, 35, 18, 26, 41, 29, 17, 33,
];

/// The waveform pulse cycle (source `duration: 0.55` with `repeat: Infinity`).
const _waveformCycle = Duration(milliseconds: 550);

/// Per-bar stagger inside the waveform pulse (source `delay: index * 0.018`).
const _waveformBarStagger = 0.018;

// ---------------------------------------------------------------------------
// Public data model
// ---------------------------------------------------------------------------

/// What an attachment *is* (source `AttachmentUploadKind`).
///
/// The kind drives the row layout: [audio] renders the scrubber + waveform,
/// [image] renders a tappable thumbnail, [link] renders the "Web" label plus an
/// open affordance, and [file] renders the plain name/size row.
enum BeuiAttachmentKind {
  /// A generic file — paperclip glyph, name + size.
  file,

  /// A web link — link glyph, "Web" label, optional open action.
  link,

  /// An image — thumbnail with a shared-layout preview overlay.
  image,

  /// An audio clip — waveform, elapsed/total time and a play/pause toggle.
  audio,
}

/// Why a candidate attachment was turned away (source `AttachmentRejectReason`).
enum BeuiAttachmentRejectReason {
  /// The candidate's [BeuiAttachmentUploadItem.size] exceeded `maxFileSize`.
  tooLarge,

  /// The workspace was already at (or would exceed) `maxFiles`.
  maxFiles,
}

/// Per-row upload state (source `AttachmentUploadStatus`).
enum BeuiAttachmentStatus {
  /// Settled — the row shows its remove affordance.
  idle,

  /// In flight — the emerald progress wash sweeps and the action slot is blank.
  uploading,

  /// Finished — the action slot shows a check.
  complete,

  /// Failed — the row tints destructive and offers retry.
  failed,
}

/// One attachment row (source `AttachmentUploadItem`).
///
/// The Flutter port carries **metadata only**. The source's `file: File` handle
/// and its `previewUrl`/`href` object-URLs have no plugin-free analog, so the
/// image bitmap arrives as a framework-native [ImageProvider] ([preview]) that
/// the consumer builds from whatever picker they use, and [href] stays an opaque
/// string the consumer opens via [BeuiAttachmentUpload.onOpenLink] (spec §7 —
/// the package ships no `file_picker`/`url_launcher` dependency).
@immutable
class BeuiAttachmentUploadItem {
  /// Creates an attachment row.
  const BeuiAttachmentUploadItem({
    required this.id,
    required this.name,
    this.kind = BeuiAttachmentKind.file,
    this.size,
    this.href,
    this.preview,
    this.currentTime,
    this.duration,
    this.status = BeuiAttachmentStatus.idle,
    this.error,
  });

  /// Stable identity — drives row keying, the arrival stagger and removal.
  final String id;

  /// Display name. Also the spoken name in every row action's semantics label.
  final String name;

  /// What kind of attachment this is; picks the row layout and glyph.
  final BeuiAttachmentKind kind;

  /// Size in bytes. `null` renders no size label; also the value gated against
  /// [BeuiAttachmentUpload.maxFileSize] when the row is added through the
  /// controller.
  final int? size;

  /// Target of a [BeuiAttachmentKind.link] row. Opening it is the consumer's
  /// job — see [BeuiAttachmentUpload.onOpenLink].
  final String? href;

  /// Bitmap for a [BeuiAttachmentKind.image] row (thumbnail, hover preview and
  /// the full-screen overlay). `null` falls back to a static image glyph, the
  /// port of the source's missing-`src` branch.
  final ImageProvider? preview;

  /// Playhead position of a [BeuiAttachmentKind.audio] row (source
  /// `currentTime`, seconds → [Duration]).
  final Duration? currentTime;

  /// Total length of a [BeuiAttachmentKind.audio] row (source `duration`).
  final Duration? duration;

  /// Row status.
  final BeuiAttachmentStatus status;

  /// Failure note shown under the name when [status] is
  /// [BeuiAttachmentStatus.failed]. Falls back to "Upload failed".
  final String? error;

  /// Copy with fields replaced (`clearError` drops the failure note).
  BeuiAttachmentUploadItem copyWith({
    String? name,
    BeuiAttachmentKind? kind,
    int? size,
    String? href,
    ImageProvider? preview,
    Duration? currentTime,
    Duration? duration,
    BeuiAttachmentStatus? status,
    String? error,
    bool clearError = false,
  }) => BeuiAttachmentUploadItem(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    size: size ?? this.size,
    href: href ?? this.href,
    preview: preview ?? this.preview,
    currentTime: currentTime ?? this.currentTime,
    duration: duration ?? this.duration,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Imperative handle for feeding picked attachments into a
/// [BeuiAttachmentUpload].
///
/// **Why this exists.** The web source owns an `<input type="file">`, so its
/// add pipeline — the `maxFiles`/`maxFileSize` gate, the rejection callbacks,
/// the simulated upload lifecycle and the staggered row arrival — hangs off the
/// input's `onChange`. The Flutter port ships no picker (spec §7), but that
/// pipeline is the component's motion identity and must stay *inside* the
/// widget. So the boundary splits in two: [BeuiAttachmentUpload.onBrowse] fires
/// when the dropzone is activated (open your picker there), and [add] hands the
/// resulting metadata back so the widget runs the same gate and the same
/// arrival motion the source does.
///
/// ```dart
/// final controller = BeuiAttachmentUploadController();
/// // ...
/// BeuiAttachmentUpload(
///   controller: controller,
///   onBrowse: () async {
///     final picked = await myPicker();          // file_picker, image_picker, …
///     controller.add(picked.map(toAttachment)); // gate + lifecycle run here
///   },
/// )
/// ```
class BeuiAttachmentUploadController {
  _BeuiAttachmentUploadState? _state;

  /// Whether a [BeuiAttachmentUpload] is currently listening.
  bool get isAttached => _state != null;

  /// Offers [candidates] to the workspace.
  ///
  /// Runs the source's `addFiles` gate verbatim: candidates past the remaining
  /// [BeuiAttachmentUpload.maxFiles] slots are rejected with
  /// [BeuiAttachmentRejectReason.maxFiles], candidates over
  /// [BeuiAttachmentUpload.maxFileSize] with
  /// [BeuiAttachmentRejectReason.tooLarge], and whatever survives is appended,
  /// announced through [BeuiAttachmentUpload.onAttachmentsAdded], and run
  /// through the uploading → complete lifecycle. A no-op while unattached or
  /// while the widget is disabled.
  void add(Iterable<BeuiAttachmentUploadItem> candidates) =>
      _state?._addAttachments(candidates.toList(growable: false));
}

// ---------------------------------------------------------------------------
// Formatting helpers (source `formatBytes` / `formatDuration` / `formatMaxSize`)
// ---------------------------------------------------------------------------

/// Source `formatBytes` — note this variant tops out at GB and returns `null`
/// for absent/zero sizes (unlike the sibling `beuiFormatBytes`, which is the
/// upload-queue's 5-unit variant and never returns null).
String? _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB'];
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

/// Source `formatDuration` — `m:ss`, clamped at zero.
String _formatDuration(Duration? value) {
  final seconds = math.max(0, (value ?? Duration.zero).inSeconds);
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Source `formatMaxSize` — MB, dropping a trailing `.0`.
String _formatMaxSize(int bytes) {
  final megabytes = bytes / (1024 * 1024);
  final text = megabytes == megabytes.roundToDouble()
      ? megabytes.toStringAsFixed(0)
      : megabytes.toStringAsFixed(1);
  return '$text MB';
}

/// Source `AttachmentIcon`.
IconData _kindIcon(BeuiAttachmentKind kind) => switch (kind) {
  BeuiAttachmentKind.link => LucideIcons.link,
  BeuiAttachmentKind.image => LucideIcons.file_image,
  BeuiAttachmentKind.audio => LucideIcons.mic,
  BeuiAttachmentKind.file => LucideIcons.paperclip,
};

// ---------------------------------------------------------------------------
// The widget
// ---------------------------------------------------------------------------

/// A mixed attachment workspace — files, links, images and audio in one list —
/// with a dropzone, staggered row arrival, per-row upload wash, retry, pending
/// removal, an audio waveform with a play/pause toggle, and a shared-layout
/// image preview. The Flutter port of beUI's `AttachmentUpload` block (the
/// second of the two patterns on `blocks/file-upload`; the first is
/// [BeuiFileUpload](../motion/file_upload.dart)).
///
/// **Documented reduced parity (spec §7)** — mirroring the decision already
/// taken for the sibling `BeuiFileUpload`:
///
/// * The published package ships **no file-picker dependency**, so the source's
///   `<input type="file">` plumbing (`accept`, `multiple`, `onFilesAdded`'s
///   `File[]` argument) is **not** ported. The dropzone fires [onBrowse]; the
///   consumer runs whatever picker fits their platform and hands the resulting
///   metadata back through [BeuiAttachmentUploadController.add], which runs the
///   source's gate, callbacks and arrival motion unchanged. How many files a
///   picker returns — the source's `multiple` — is likewise the consumer's
///   call.
/// * OS drag-and-drop is desktop-only and needs a plugin, so the widget does not
///   listen for drops. The full drag-over motion is still reachable: drive
///   [dragging] from your drop-target plugin.
/// * Opening a link row needs `url_launcher`; the widget renders the affordance
///   and reports through [onOpenLink].
///
/// Everything else ports one-to-one: the rejection reasons, the size and count
/// limits, the upload/complete/failed states, retry, the pending-removal
/// spinner, the audio toggle, the image preview overlay and all of the motion.
class BeuiAttachmentUpload extends StatefulWidget {
  /// Creates an attachment workspace.
  const BeuiAttachmentUpload({
    this.value,
    this.defaultValue = const [],
    this.onValueChange,
    this.controller,
    this.onBrowse,
    this.onAttachmentsAdded,
    this.onAttachmentsRejected,
    this.onRemove,
    this.onRetry,
    this.onOpenLink,
    this.playingId,
    this.onAudioToggle,
    this.maxFiles = 12,
    this.maxFileSize = _defaultMaxFileSize,
    this.disabled = false,
    this.dragging = false,
    this.title = 'Drag and drop or browse files',
    this.description,
    this.attachmentsLabel = 'Attachments',
    super.key,
  });

  /// Controlled attachment list; `null` for uncontrolled with [defaultValue].
  final List<BeuiAttachmentUploadItem>? value;

  /// Initial attachment list when uncontrolled.
  final List<BeuiAttachmentUploadItem> defaultValue;

  /// Fires with the list the widget wants after an add or a removal.
  final ValueChanged<List<BeuiAttachmentUploadItem>>? onValueChange;

  /// Imperative handle used to feed picked attachments in — see
  /// [BeuiAttachmentUploadController].
  final BeuiAttachmentUploadController? controller;

  /// Fires when the dropzone is activated (tap, Enter or Space). Open your
  /// picker here, then call [BeuiAttachmentUploadController.add].
  final VoidCallback? onBrowse;

  /// Fires with the candidates that cleared the gate (source `onFilesAdded`,
  /// minus its web-only `File[]` argument).
  final ValueChanged<List<BeuiAttachmentUploadItem>>? onAttachmentsAdded;

  /// Fires with the candidates that were turned away and why (source
  /// `onFilesRejected`). May fire twice for one [BeuiAttachmentUploadController.add]
  /// — once for oversized candidates, once for the ones past the count limit.
  final void Function(
    List<BeuiAttachmentUploadItem> rejected,
    BeuiAttachmentRejectReason reason,
  )?
  onAttachmentsRejected;

  /// Fires with the row once its pending-removal spinner has run out and the
  /// row has actually left the list.
  final ValueChanged<BeuiAttachmentUploadItem>? onRemove;

  /// Fires when a failed row's retry button is pressed. Non-null is also what
  /// makes a failed row *retryable* — leave it null and failures render as a
  /// static alert glyph (source `retryable`). The widget does not mutate the
  /// row; flip its [BeuiAttachmentUploadItem.status] yourself.
  final ValueChanged<BeuiAttachmentUploadItem>? onRetry;

  /// Fires when a link row's open affordance is pressed. The affordance only
  /// renders when this is non-null and the row carries an
  /// [BeuiAttachmentUploadItem.href].
  final ValueChanged<BeuiAttachmentUploadItem>? onOpenLink;

  /// Id of the audio row currently playing (controlled-only, as in source).
  final String? playingId;

  /// Fires when an audio row's play/pause button is pressed.
  final ValueChanged<BeuiAttachmentUploadItem>? onAudioToggle;

  /// Attachment cap. Reaching it disables the dropzone and swaps its copy.
  final int maxFiles;

  /// Per-attachment byte ceiling used by the add gate.
  final int maxFileSize;

  /// Disables the dropzone and the add pipeline.
  final bool disabled;

  /// Whether a drag is currently hovering the dropzone.
  ///
  /// The port has no OS drop listener of its own (see the class docs); wire this
  /// from a desktop drop-target plugin to get the source's drag-over motion —
  /// the glyph lifts and swells, the dashed frame goes solid-foreground and the
  /// shell scales to 1.006.
  final bool dragging;

  /// Dropzone headline.
  final String title;

  /// Dropzone byline. Defaults to `Maximum <maxFileSize> file size`.
  final String? description;

  /// Heading above the attachment list.
  final String attachmentsLabel;

  @override
  State<BeuiAttachmentUpload> createState() => _BeuiAttachmentUploadState();
}

/// One row's presence entry — the port of the source's `AnimatePresence` child
/// bookkeeping (same shape the sibling `BeuiFileUpload` uses).
class _RowEntry {
  _RowEntry(this.item);

  BeuiAttachmentUploadItem item;
  bool exiting = false;
}

class _BeuiAttachmentUploadState extends State<BeuiAttachmentUpload> {
  late List<BeuiAttachmentUploadItem> _internal = List.of(widget.defaultValue);
  final List<_RowEntry> _entries = [];

  /// Insertion-ordered, so `indexOf` reproduces the source's
  /// `Array.from(uploadingIds).indexOf(id)` arrival index.
  final Set<String> _uploadingIds = <String>{};
  final Set<String> _completeIds = <String>{};
  final Set<String> _removingIds = <String>{};
  final Set<Timer> _timers = <Timer>{};

  /// The row whose image the overlay shows. Kept set while the overlay plays
  /// its exit so the layer still has something to render; [_previewOpen] is the
  /// declarative `open` BeuiOverlay reads.
  BeuiAttachmentUploadItem? _previewItem;
  Rect? _previewOrigin;
  bool _previewOpen = false;
  bool _reduce = false;

  List<BeuiAttachmentUploadItem> get _items => widget.value ?? _internal;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _sync();
  }

  @override
  void didUpdateWidget(BeuiAttachmentUpload oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
    _sync();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _schedule(Duration delay, VoidCallback callback) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) callback();
    });
    _timers.add(timer);
  }

  void _setItems(List<BeuiAttachmentUploadItem> next) {
    if (widget.value == null) {
      setState(() => _internal = next);
    } else {
      setState(() {});
    }
    widget.onValueChange?.call(next);
  }

  /// Mirrors [_items] into row entries; vanished rows animate out before
  /// unmounting (the `AnimatePresence` contract), and a preview whose row is
  /// gone closes itself (source's `previewItem` effect).
  void _sync() {
    final byId = {for (final item in _items) item.id: item};
    final known = {for (final entry in _entries) entry.item.id};
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
    final preview = _previewItem;
    if (preview != null && !byId.containsKey(preview.id)) _previewOpen = false;
  }

  // -- source `addFiles` ------------------------------------------------------

  void _addAttachments(List<BeuiAttachmentUploadItem> incoming) {
    if (widget.disabled || incoming.isEmpty) return;

    final items = _items;
    final availableSlots = math.max(0, widget.maxFiles - items.length);
    if (availableSlots == 0) {
      widget.onAttachmentsRejected?.call(
        incoming,
        BeuiAttachmentRejectReason.maxFiles,
      );
      return;
    }

    final selected = incoming.take(availableSlots).toList();
    final oversized = <BeuiAttachmentUploadItem>[];
    final accepted = <BeuiAttachmentUploadItem>[];
    for (final candidate in selected) {
      if ((candidate.size ?? 0) > widget.maxFileSize) {
        oversized.add(candidate);
      } else {
        accepted.add(candidate);
      }
    }

    if (oversized.isNotEmpty) {
      widget.onAttachmentsRejected?.call(
        oversized,
        BeuiAttachmentRejectReason.tooLarge,
      );
    }
    if (incoming.length > selected.length) {
      widget.onAttachmentsRejected?.call(
        incoming.sublist(selected.length),
        BeuiAttachmentRejectReason.maxFiles,
      );
    }

    if (accepted.isEmpty) return;

    _setItems([...items, ...accepted]);
    final addedIds = accepted.map((item) => item.id).toList();
    setState(() => _uploadingIds.addAll(addedIds));
    _schedule(_reduce ? _reducedLifecycle : _uploadProgress, () {
      setState(() {
        _uploadingIds.removeAll(addedIds);
        _completeIds.addAll(addedIds);
      });
      _schedule(_uploadCompleteHold, () {
        setState(() => _completeIds.removeAll(addedIds));
      });
    });
    widget.onAttachmentsAdded?.call(accepted);
  }

  // -- source `requestRemove` / `finalizeRemove` ------------------------------

  void _requestRemove(BeuiAttachmentUploadItem item) {
    if (_removingIds.contains(item.id)) return;
    setState(() => _removingIds.add(item.id));
    _schedule(_reduce ? _reducedLifecycle : _removePending, () {
      _finalizeRemove(item);
      setState(() => _removingIds.remove(item.id));
    });
  }

  void _finalizeRemove(BeuiAttachmentUploadItem item) {
    if (_previewItem?.id == item.id) _previewOpen = false;
    _uploadingIds.remove(item.id);
    _completeIds.remove(item.id);
    _setItems([..._items]..removeWhere((entry) => entry.id == item.id));
    widget.onRemove?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    _reduce = MediaQuery.disableAnimationsOf(context);
    _sync();

    final items = _items;
    final maxReached = items.length >= widget.maxFiles;
    final uploadOrder = _uploadingIds.toList();

    final workspace = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dropzone(
          colors: colors,
          reduce: _reduce,
          dragging: widget.dragging,
          enabled: !widget.disabled && !maxReached && widget.onBrowse != null,
          dimmed: widget.disabled || maxReached,
          title: maxReached ? 'Attachment limit reached' : widget.title,
          description: maxReached
              ? '${items.length} of ${widget.maxFiles} attachments added'
              : widget.description ??
                    'Maximum ${_formatMaxSize(widget.maxFileSize)} file size',
          onBrowse: widget.onBrowse,
        ),
        if (_entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32), // mt-8
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    widget.attachmentsLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12), // mt-3
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8, // space-y-2
                    children: [
                      for (final entry in _entries)
                        _AttachmentRow(
                          key: ValueKey(entry.item.id),
                          item: entry.item,
                          colors: colors,
                          reduce: _reduce,
                          exiting: entry.exiting,
                          arrivalIndex: uploadOrder.indexOf(entry.item.id),
                          playing:
                              widget.playingId != null &&
                              widget.playingId == entry.item.id,
                          uploading:
                              _uploadingIds.contains(entry.item.id) ||
                              entry.item.status ==
                                  BeuiAttachmentStatus.uploading,
                          uploadComplete:
                              _completeIds.contains(entry.item.id) ||
                              entry.item.status ==
                                  BeuiAttachmentStatus.complete,
                          failed:
                              entry.item.status == BeuiAttachmentStatus.failed,
                          removing: _removingIds.contains(entry.item.id),
                          retryable: widget.onRetry != null,
                          onRemove: () => _requestRemove(entry.item),
                          onRetry: () => widget.onRetry?.call(entry.item),
                          onAudioToggle: widget.onAudioToggle == null
                              ? null
                              : () => widget.onAudioToggle!(entry.item),
                          onOpenLink:
                              widget.onOpenLink == null ||
                                  entry.item.href == null
                              ? null
                              : () => widget.onOpenLink!(entry.item),
                          onPreview: entry.item.preview == null
                              ? null
                              : (originRect) => setState(() {
                                  _previewOrigin = originRect;
                                  _previewItem = entry.item;
                                  _previewOpen = true;
                                }),
                          onExited: () {
                            if (mounted) setState(() => _entries.remove(entry));
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final preview = _previewItem;
    if (preview == null) return workspace;

    // The source portals the preview through `createPortal(document.body)`;
    // repo-wide, floating surfaces go through BeuiOverlay (spec §6 "decide
    // once" — declarative open + onDismiss).
    return BeuiOverlay(
      open: _previewOpen,
      onDismiss: _closePreview,
      barrierColor: const Color(0x73000000), // bg-black/45
      // Static glass backdrop (`backdrop-blur-xl` = 24px) — the documented
      // glass exception to the ≤10px animated-blur cap.
      barrierBlur: _reduce ? 0 : beuiBlurSigma(24),
      enterDuration: const Duration(milliseconds: 200),
      exitDuration: const Duration(milliseconds: 160),
      overlayBuilder: (context, animation, _) => _ImagePreviewLayer(
        item: preview,
        origin: _previewOrigin,
        colors: colors,
        reduce: _reduce,
        animation: animation,
        onClose: _closePreview,
      ),
      child: workspace,
    );
  }

  void _closePreview() => setState(() => _previewOpen = false);
}

// ---------------------------------------------------------------------------
// Dropzone
// ---------------------------------------------------------------------------

class _Dropzone extends StatefulWidget {
  const _Dropzone({
    required this.colors,
    required this.reduce,
    required this.dragging,
    required this.enabled,
    required this.dimmed,
    required this.title,
    required this.description,
    required this.onBrowse,
  });

  final BeuiColors colors;
  final bool reduce;
  final bool dragging;
  final bool enabled;
  final bool dimmed;
  final String title;
  final String description;
  final VoidCallback? onBrowse;

  @override
  State<_Dropzone> createState() => _DropzoneState();
}

class _DropzoneState extends State<_Dropzone> {
  bool _hovered = false;
  bool _focusVisible = false;
  bool _pressed = false;

  void _activate() {
    if (widget.enabled) widget.onBrowse?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final dragging = widget.dragging;

    // Inner dashed frame: `absolute inset-2 rounded-[1.5rem] border-dashed`.
    final frameColor = dragging
        ? colors.foreground.withValues(alpha: 0.65)
        : colors.mutedForeground.withValues(alpha: _hovered ? 0.45 : 0.25);

    // Glyph shell: y -4 / scale 1.08 while dragging (ITEM_TRANSITION).
    final glyph = SingleMotionBuilder(
      value: dragging && !widget.reduce ? 1.0 : 0.0,
      motion: _itemTransition,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -4 * t),
        child: Transform.scale(scale: 1 + 0.08 * t, child: child),
      ),
      child: Container(
        width: 44, // size-11
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dragging
              ? colors.foreground
              : colors.muted.withValues(
                  alpha: _hovered ? colors.muted.a * 0.8 : colors.muted.a,
                ),
          borderRadius: BorderRadius.circular(16), // rounded-2xl
        ),
        child: Icon(
          LucideIcons.upload,
          size: 18,
          color: dragging ? colors.background : colors.foreground,
        ),
      ),
    );

    Widget zone = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted.withValues(
          alpha: colors.muted.a * (_hovered ? 0.85 : 0.65),
        ),
        borderRadius: BorderRadius.circular(32), // rounded-[2rem]
        border: _focusVisible ? Border.all(color: colors.ring, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // p-2 → the dashed frame's inset
        child: CustomPaint(
          painter: _DashedFramePainter(
            color: frameColor,
            radius: 24, // rounded-[1.5rem]
            fill: dragging
                ? colors.muted.withValues(alpha: colors.muted.a * 0.2)
                : colors.background,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 192), // min-h-52 − p-2
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  const SizedBox(height: 12), // mb-3
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.14, // tracking-[-0.01em]
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4), // mt-1
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 20 / 12, // leading-5
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // animate scale 1.006 while dragging · whileTap 0.995, both SPRING_PRESS.
    // Reduce-gated target rather than NoMotion, so a press never freezes
    // mid-squish (spec §1).
    final pressTarget = widget.reduce
        ? 1.0
        : _pressed && widget.enabled
        ? 0.995
        : dragging
        ? 1.006
        : 1.0;
    zone = SingleMotionBuilder(
      value: pressTarget,
      from: 1,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: zone,
    );
    if (widget.dimmed) {
      zone = Opacity(opacity: 0.55, child: zone); // disabled:opacity-55
    }

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Upload attachments',
      onTap: widget.enabled ? _activate : null,
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
              _activate();
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
          onTap: widget.enabled ? _activate : null,
          child: zone,
        ),
      ),
    );
  }
}

/// The dropzone's `border-dashed` inner frame. CSS dashed borders have no
/// Flutter analog, so the stroke is walked with [PathMetric] — same "hand-drawn
/// marks become CustomPaint, never an asset" rule as spec §3.
class _DashedFramePainter extends CustomPainter {
  const _DashedFramePainter({
    required this.color,
    required this.radius,
    required this.fill,
  });

  final Color color;
  final double radius;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final path = Path()..addRRect(rrect.deflate(0.5));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) =>
      old.color != color || old.radius != radius || old.fill != fill;
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

/// The action slot's state (source `RowActionState`).
enum _RowActionState { idle, uploading, complete, failed, removing }

class _AttachmentRow extends StatefulWidget {
  const _AttachmentRow({
    required this.item,
    required this.colors,
    required this.reduce,
    required this.exiting,
    required this.arrivalIndex,
    required this.playing,
    required this.uploading,
    required this.uploadComplete,
    required this.failed,
    required this.removing,
    required this.retryable,
    required this.onRemove,
    required this.onRetry,
    required this.onAudioToggle,
    required this.onOpenLink,
    required this.onPreview,
    required this.onExited,
    super.key,
  });

  final BeuiAttachmentUploadItem item;
  final BeuiColors colors;
  final bool reduce;
  final bool exiting;
  final int arrivalIndex;
  final bool playing;
  final bool uploading;
  final bool uploadComplete;
  final bool failed;
  final bool removing;
  final bool retryable;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final VoidCallback? onAudioToggle;
  final VoidCallback? onOpenLink;
  final ValueChanged<Rect>? onPreview;
  final VoidCallback onExited;

  @override
  State<_AttachmentRow> createState() => _AttachmentRowState();
}

class _AttachmentRowState extends State<_AttachmentRow> {
  final GlobalKey _thumbKey = GlobalKey();
  bool _entered = false;
  Timer? _arrivalTimer;

  /// True when this row arrived through the add pipeline — it gets the
  /// SPRING_LAYOUT entrance with the staggered delay rather than the plain
  /// 0.2s slide (source `arrivalIndex >= 0`).
  bool get _arrival => widget.arrivalIndex >= 0;

  @override
  void initState() {
    super.initState();
    final delay = _arrival && !widget.reduce
        ? _arrivalStagger * widget.arrivalIndex.clamp(0, 5)
        : Duration.zero;
    if (delay == Duration.zero) {
      _entered = true;
    } else {
      _arrivalTimer = Timer(delay, () {
        if (mounted) setState(() => _entered = true);
      });
    }
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = widget.reduce;
    final target = widget.exiting || !_entered ? 0.0 : 1.0;

    // Position/scale + the list reflow ride the row transition: SPRING_LAYOUT
    // for arrivals, ITEM_TRANSITION otherwise (source `rowTransition`).
    final Motion travel = reduce
        ? _itemTransition
        : _arrival
        ? beuiSpringLayout
        : _itemTransition;
    // Opacity keeps its own 0.16s EASE_OUT clock on arrival (source's
    // `opacity` override) and is never dropped under reduced motion.
    final opacityMotion = CurvedMotion(
      Duration(milliseconds: _arrival && !widget.exiting ? 160 : 200),
      beuiEaseOut,
    );

    return SingleMotionBuilder(
      value: target,
      from: 0,
      motion: opacityMotion,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      child: SingleMotionBuilder(
        value: target,
        from: 0,
        motion: travel,
        onAnimationStatusChanged: (status) {
          if (widget.exiting &&
              (status == AnimationStatus.completed ||
                  status == AnimationStatus.dismissed)) {
            widget.onExited();
          }
        },
        builder: (context, t, child) {
          final clamped = t.clamp(0.0, 1.0);
          Widget body = child!;
          if (!reduce) {
            // initial y: -16 on arrival, 6 otherwise; exit y: -4.
            final dy = widget.exiting
                ? -4 * (1 - clamped)
                : (_arrival ? -16 : 6) * (1 - clamped);
            final scale = _arrival && !widget.exiting
                ? 0.985 + 0.015 * clamped
                : 1.0;
            body = Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(scale: scale, child: body),
            );
          }
          // Height collapse so neighbours reflow into the vacated slot — the
          // port of Framer's `layout` on the list item, which the source drops
          // outright under reduced motion (`layout={!reduce}`).
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: reduce ? 1 : clamped,
              child: body,
            ),
          );
        },
        child: _RowBody(
          item: widget.item,
          colors: widget.colors,
          reduce: reduce,
          playing: widget.playing,
          uploading: widget.uploading,
          uploadComplete: widget.uploadComplete,
          failed: widget.failed,
          removing: widget.removing,
          retryable: widget.retryable,
          thumbKey: _thumbKey,
          onRemove: widget.onRemove,
          onRetry: widget.onRetry,
          onAudioToggle: widget.onAudioToggle,
          onOpenLink: widget.onOpenLink,
          onPreview: widget.onPreview == null
              ? null
              : () {
                  final box =
                      _thumbKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  final origin = box == null
                      ? Rect.zero
                      : box.localToGlobal(Offset.zero) & box.size;
                  widget.onPreview!(origin);
                },
        ),
      ),
    );
  }
}

class _RowBody extends StatelessWidget {
  const _RowBody({
    required this.item,
    required this.colors,
    required this.reduce,
    required this.playing,
    required this.uploading,
    required this.uploadComplete,
    required this.failed,
    required this.removing,
    required this.retryable,
    required this.thumbKey,
    required this.onRemove,
    required this.onRetry,
    required this.onAudioToggle,
    required this.onOpenLink,
    required this.onPreview,
  });

  final BeuiAttachmentUploadItem item;
  final BeuiColors colors;
  final bool reduce;
  final bool playing;
  final bool uploading;
  final bool uploadComplete;
  final bool failed;
  final bool removing;
  final bool retryable;
  final GlobalKey thumbKey;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final VoidCallback? onAudioToggle;
  final VoidCallback? onOpenLink;
  final VoidCallback? onPreview;

  _RowActionState get _actionState => removing
      ? _RowActionState.removing
      : uploading
      ? _RowActionState.uploading
      : uploadComplete
      ? _RowActionState.complete
      : failed
      ? _RowActionState.failed
      : _RowActionState.idle;

  @override
  Widget build(BuildContext context) {
    final isDark = colors.brightness == Brightness.dark;
    final leading = item.kind == BeuiAttachmentKind.image
        ? _ImageThumbnail(
            key: thumbKey,
            item: item,
            colors: colors,
            reduce: reduce,
            onPreview: onPreview,
          )
        : SizedBox(
            width: 28, // size-7
            height: 28,
            child: Icon(
              _kindIcon(item.kind),
              size: 16,
              color: colors.mutedForeground,
            ),
          );

    // `self-stretch` inside a `min-h-14` row with `p-1`: 56 − 2×4 = 48.
    final inner = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // rounded-xl
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.background),
          child: Stack(
            children: [
              if (failed)
                Positioned.fill(
                  child: ColoredBox(
                    color: colors.destructive.withValues(alpha: 0.1),
                  ),
                ),
              Positioned.fill(
                child: _UploadWash(
                  show: uploading || uploadComplete,
                  reduce: reduce,
                  label: 'Uploading ${item.name}',
                  // bg-emerald-400/25 · dark:bg-emerald-500/20
                  color: isDark
                      ? const Color(0x3310B981)
                      : const Color(0x4034D399),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, // px-2
                  vertical: 4, // py-1
                ),
                child: Row(
                  spacing: 12, // gap-3
                  children: [
                    leading,
                    if (item.kind == BeuiAttachmentKind.audio)
                      ..._audioSlots(context)
                    else
                      ..._fileSlots(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(4), // p-1
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: colors.muted.a * 0.7),
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      child: Row(
        spacing: 4, // gap-1
        children: [
          Expanded(child: inner),
          Center(
            child: _RowAction(
              state: _actionState,
              label: item.name,
              colors: colors,
              reduce: reduce,
              retryable: retryable,
              onRemove: onRemove,
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fileSlots() {
    final size = _formatBytes(item.size);
    final trailing = item.kind == BeuiAttachmentKind.link ? 'Web' : size;
    return [
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
            if (failed)
              Text(
                item.error ?? 'Upload failed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.destructive),
              ),
          ],
        ),
      ),
      if (trailing != null)
        Text(
          trailing,
          style: TextStyle(fontSize: 12, color: colors.mutedForeground),
        ),
      if (onOpenLink != null && item.kind == BeuiAttachmentKind.link)
        _IconButton(
          icon: LucideIcons.external_link,
          semanticsLabel: 'Open ${item.name}',
          tooltip: 'Open link',
          size: 32, // size-8
          radius: 8, // rounded-lg
          iconSize: 16,
          colors: colors,
          reduce: reduce,
          foreground: colors.mutedForeground,
          hoverForeground: colors.foreground,
          hoverBackground: colors.muted,
          onPressed: onOpenLink!,
        ),
    ];
  }

  List<Widget> _audioSlots(BuildContext context) {
    final duration = item.duration;
    final progress = duration != null && duration > Duration.zero
        ? ((item.currentTime ?? Duration.zero).inMilliseconds /
                  duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;
    final timeStyle = TextStyle(
      fontSize: 12,
      color: colors.mutedForeground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return [
      SizedBox(
        width: 36, // w-9
        child: Text(_formatDuration(item.currentTime), style: timeStyle),
      ),
      Expanded(
        child: _Waveform(
          progress: progress,
          playing: playing,
          reduce: reduce,
          colors: colors,
        ),
      ),
      SizedBox(
        width: 36,
        child: Text(
          _formatDuration(item.duration),
          textAlign: TextAlign.right,
          style: timeStyle,
        ),
      ),
      _PlayToggle(
        playing: playing,
        label: item.name,
        colors: colors,
        reduce: reduce,
        onPressed: onAudioToggle,
      ),
    ];
  }
}

/// The emerald upload wash: `scaleX 0 → 1` over `UPLOAD_PROGRESS_MS` with
/// EASE_OUT, fading out (not shrinking) when the row settles.
class _UploadWash extends StatefulWidget {
  const _UploadWash({
    required this.show,
    required this.reduce,
    required this.label,
    required this.color,
  });

  final bool show;
  final bool reduce;
  final String label;
  final Color color;

  @override
  State<_UploadWash> createState() => _UploadWashState();
}

class _UploadWashState extends State<_UploadWash> {
  int _epoch = 0;
  late bool _alive = widget.show;

  @override
  void didUpdateWidget(_UploadWash old) {
    super.didUpdateWidget(old);
    if (widget.show && !old.show) {
      setState(() {
        _epoch++;
        _alive = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_alive && !widget.show) return const SizedBox.shrink();
    return IgnorePointer(
      child: Semantics(
        label: widget.label,
        child: SingleMotionBuilder(
          value: widget.show ? 1.0 : 0.0,
          from: 1,
          motion: _itemTransition,
          onAnimationStatusChanged: (status) {
            if (!widget.show &&
                status == AnimationStatus.dismissed &&
                mounted) {
              setState(() => _alive = false);
            }
          },
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
          child: SingleMotionBuilder(
            key: ValueKey(_epoch),
            value: 1,
            from: 0,
            motion: CurvedMotion(
              widget.reduce
                  ? const Duration(milliseconds: 100)
                  : _uploadProgress,
              beuiEaseOut,
            ),
            builder: (context, t, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: t.clamp(0.0, 1.0),
                heightFactor: 1,
                child: ColoredBox(color: widget.color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Audio waveform. Bars left of the playhead take the foreground colour; while
/// playing every bar pulses `scaleY [0.72, 1, 0.78]` on a 0.55s EASE_OUT loop
/// staggered by index.
class _Waveform extends StatefulWidget {
  const _Waveform({
    required this.progress,
    required this.playing,
    required this.reduce,
    required this.colors,
  });

  final double progress;
  final bool playing;
  final bool reduce;
  final BeuiColors colors;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  // An endless decorative loop. `motor` has no repeat primitive, so this follows
  // the precedent already set by the sibling BeuiFileUpload's spinner: raw
  // controller for the loop, `motor` for every discrete transition.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _waveformCycle,
  );

  bool get _animating => widget.playing && !widget.reduce;

  @override
  void initState() {
    super.initState();
    if (_animating) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_Waveform old) {
    super.didUpdateWidget(old);
    if (_animating && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!_animating && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Source keyframes `[0.72, 1, 0.78]` with EASE_OUT applied per segment.
  static double _scaleAt(double phase) {
    if (phase < 0.5) {
      return 0.72 + (1 - 0.72) * beuiEaseOut.transform(phase * 2);
    }
    return 1 + (0.78 - 1) * beuiEaseOut.transform((phase - 0.5) * 2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final active = colors.foreground;
    final inactive = colors.mutedForeground.withValues(alpha: 0.35);
    final cycleSeconds = _waveformCycle.inMilliseconds / 1000;

    return ExcludeSemantics(
      child: SizedBox(
        height: 44, // h-11
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 3, // gap-[3px]
                children: [
                  for (var i = 0; i < _waveformBars.length; i++)
                    _bar(i, active, inactive, cycleSeconds),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(int index, Color active, Color inactive, double cycleSeconds) {
    final lit = index / _waveformBars.length <= widget.progress;
    var scale = 1.0;
    if (_animating) {
      final phase =
          (_pulse.value - index * _waveformBarStagger / cycleSeconds) % 1.0;
      scale = _scaleAt(phase < 0 ? phase + 1 : phase);
    }
    return Transform.scale(
      scaleY: scale,
      child: Container(
        width: 3,
        height: _waveformBars[index],
        decoration: BoxDecoration(
          color: lit ? active : inactive,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Audio play/pause toggle — glyph swaps with a 0.2s EASE_OUT scale/fade,
/// press dips to 0.94 on SPRING_PRESS.
/// The play/pause mark inside the audio row's toggle.
///
/// The source renders `<Play className="size-4 translate-x-px fill-current" />`
/// and `<Pause className="size-4 fill-current" />` — Lucide glyphs with their
/// interiors *filled*. An [Icon] can only draw the icon font's stroked outline,
/// which reads as a hollow triangle against the white disc, so the two marks are
/// painted here instead (spec §3: a source mark with no icon-font equivalent
/// ports to [CustomPaint], never to a bundled asset).
class _PlayGlyphPainter extends CustomPainter {
  const _PlayGlyphPainter({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Lucide authors both glyphs in a 24-unit box and strokes them 2 units wide
    // with round joins; filling *and* stroking the same path is what
    // `fill-current` renders.
    final s = size.width / 24;
    // `translate-x-px` nudges the triangle right so it reads centred in the
    // disc; the pause bars are already symmetric and take no offset.
    final dx = playing ? 0.0 : 1.0;
    final path = Path();
    if (playing) {
      for (final x in const [6.0, 14.0]) {
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * s, 4 * s, 4 * s, 16 * s),
            Radius.circular(s),
          ),
        );
      }
    } else {
      path
        ..moveTo(6 * s + dx, 3 * s)
        ..lineTo(20 * s + dx, 12 * s)
        ..lineTo(6 * s + dx, 21 * s)
        ..close();
    }
    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_PlayGlyphPainter old) =>
      old.playing != playing || old.color != color;
}

class _PlayToggle extends StatefulWidget {
  const _PlayToggle({
    required this.playing,
    required this.label,
    required this.colors,
    required this.reduce,
    required this.onPressed,
  });

  final bool playing;
  final String label;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback? onPressed;

  @override
  State<_PlayToggle> createState() => _PlayToggleState();
}

class _PlayToggleState extends State<_PlayToggle> {
  bool _pressed = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    Widget button = Container(
      width: 36, // size-9
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.foreground,
        shape: BoxShape.circle,
        border: _focusVisible ? Border.all(color: colors.ring, width: 2) : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: beuiEaseOut,
        switchOutCurve: beuiEaseOut,
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          if (widget.reduce) return fade;
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
            child: fade,
          );
        },
        child: SizedBox(
          key: ValueKey(widget.playing),
          width: 16, // size-4
          height: 16,
          child: CustomPaint(
            painter: _PlayGlyphPainter(
              playing: widget.playing,
              color: colors.background,
            ),
          ),
        ),
      ),
    );

    button = SingleMotionBuilder(
      value: _pressed && !widget.reduce ? 0.94 : 1.0,
      from: 1,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: button,
    );

    return Semantics(
      button: true,
      label: '${widget.playing ? 'Pause' : 'Play'} ${widget.label}',
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: button,
        ),
      ),
    );
  }
}

/// The trailing slot — source `RowAction`.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.state,
    required this.label,
    required this.colors,
    required this.reduce,
    required this.retryable,
    required this.onRemove,
    required this.onRetry,
  });

  final _RowActionState state;
  final String label;
  final BeuiColors colors;
  final bool reduce;
  final bool retryable;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = colors.brightness == Brightness.dark;
    switch (state) {
      case _RowActionState.uploading:
        return const SizedBox(width: 36, height: 36);

      case _RowActionState.complete:
        return BeuiTooltip(
          content: const Text('Upload complete'),
          delay: const Duration(milliseconds: 100),
          child: Semantics(
            liveRegion: true,
            label: 'Upload complete for $label',
            child: SingleMotionBuilder(
              value: 1,
              from: 0,
              motion: _itemTransition,
              builder: (context, t, child) {
                final clamped = t.clamp(0.0, 1.0);
                final faded = Opacity(opacity: clamped, child: child);
                return reduce
                    ? faded
                    : Transform.scale(
                        scale: 0.75 + 0.25 * clamped,
                        child: faded,
                      );
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  LucideIcons.check,
                  size: 16,
                  // text-emerald-600 dark:text-emerald-400
                  color: isDark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF059669),
                ),
              ),
            ),
          ),
        );

      case _RowActionState.removing:
        return BeuiTooltip(
          content: const Text('Removing attachment'),
          delay: const Duration(milliseconds: 100),
          child: Semantics(
            liveRegion: true,
            label: 'Removing $label',
            child: SizedBox(
              width: 36,
              height: 36,
              child: reduce
                  ? Icon(
                      LucideIcons.loader_circle,
                      size: 16,
                      color: colors.mutedForeground,
                    )
                  : _RemovingSpinner(color: colors.mutedForeground),
            ),
          ),
        );

      case _RowActionState.failed:
        if (!retryable) {
          return BeuiTooltip(
            content: const Text('Upload failed'),
            delay: const Duration(milliseconds: 100),
            child: Semantics(
              liveRegion: true,
              label: 'Upload failed for $label',
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  LucideIcons.circle_alert,
                  size: 16,
                  color: colors.destructive,
                ),
              ),
            ),
          );
        }
        return _IconButton(
          icon: LucideIcons.rotate_ccw,
          semanticsLabel: 'Retry $label',
          tooltip: 'Retry upload',
          size: 36,
          radius: 12, // rounded-xl
          iconSize: 16,
          colors: colors,
          reduce: reduce,
          foreground: colors.destructive,
          hoverForeground: colors.destructive,
          hoverBackground: colors.destructive.withValues(alpha: 0.1),
          onPressed: onRetry,
        );

      case _RowActionState.idle:
        return _IconButton(
          icon: LucideIcons.x,
          semanticsLabel: 'Remove $label',
          tooltip: 'Remove attachment',
          size: 36,
          radius: 12,
          iconSize: 16,
          colors: colors,
          reduce: reduce,
          foreground: colors.mutedForeground,
          hoverForeground: colors.foreground,
          hoverBackground: colors.muted,
          onPressed: onRemove,
        );
    }
  }
}

/// The pending-removal spinner — 0.7s linear loop (source `repeat: Infinity`).
class _RemovingSpinner extends StatefulWidget {
  const _RemovingSpinner({required this.color});

  final Color color;

  @override
  State<_RemovingSpinner> createState() => _RemovingSpinnerState();
}

class _RemovingSpinnerState extends State<_RemovingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(
      turns: _controller,
      child: Icon(LucideIcons.loader_circle, size: 16, color: widget.color),
    ),
  );
}

/// A focusable, tooltipped icon button with the source's `whileTap: 0.92`
/// SPRING_PRESS squish and hover colour swap.
class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.tooltip,
    required this.size,
    required this.radius,
    required this.iconSize,
    required this.colors,
    required this.reduce,
    required this.foreground,
    required this.hoverForeground,
    required this.hoverBackground,
    required this.onPressed,
    this.background = Colors.transparent,
    this.borderColor,
  });

  final IconData icon;
  final String semanticsLabel;
  final String tooltip;
  final double size;
  final double radius;
  final double iconSize;
  final BeuiColors colors;
  final bool reduce;
  final Color foreground;
  final Color hoverForeground;
  final Color hoverBackground;
  final VoidCallback onPressed;
  final Color background;
  final Color? borderColor;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150), // transition-colors
      curve: beuiEaseOut,
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _hovered ? widget.hoverBackground : widget.background,
        borderRadius: BorderRadius.circular(widget.radius),
        border: _focusVisible
            ? Border.all(color: widget.colors.ring, width: 2)
            : widget.borderColor == null
            ? null
            : Border.all(color: widget.borderColor!),
      ),
      child: Icon(
        widget.icon,
        size: widget.iconSize,
        color: _hovered ? widget.hoverForeground : widget.foreground,
      ),
    );

    button = SingleMotionBuilder(
      value: _pressed && !widget.reduce ? 0.92 : 1.0,
      from: 1,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: button,
    );

    return BeuiTooltip(
      content: Text(widget.tooltip),
      delay: const Duration(milliseconds: 100),
      child: Semantics(
        button: true,
        label: widget.semanticsLabel,
        onTap: widget.onPressed,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) =>
              setState(() => _focusVisible = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: button,
          ),
        ),
      ),
    );
  }
}

/// The image row's thumbnail — hover shows a larger preview, tap opens the
/// full-screen overlay.
class _ImageThumbnail extends StatefulWidget {
  const _ImageThumbnail({
    required this.item,
    required this.colors,
    required this.reduce,
    required this.onPreview,
    super.key,
  });

  final BeuiAttachmentUploadItem item;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback? onPreview;

  @override
  State<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<_ImageThumbnail> {
  bool _pressed = false;
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final preview = widget.item.preview;
    if (preview == null || widget.onPreview == null) {
      return SizedBox(
        width: 32, // size-8
        height: 32,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.muted,
            borderRadius: BorderRadius.circular(8), // rounded-lg
          ),
          child: Icon(
            LucideIcons.file_image,
            size: 16,
            color: colors.mutedForeground,
          ),
        ),
      );
    }

    Widget thumb = Container(
      width: 36, // size-9
      height: 36,
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(10), // rounded-[10px]
        border: Border.all(
          color: _focusVisible
              ? colors.ring
              : colors.border.withValues(alpha: colors.border.a * 0.7),
          width: _focusVisible ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(image: preview, fit: BoxFit.cover),
    );

    thumb = SingleMotionBuilder(
      value: _pressed && !widget.reduce ? 0.94 : 1.0,
      from: 1,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: thumb,
    );

    return BeuiTooltip(
      delay: const Duration(milliseconds: 160),
      content: SizedBox(
        width: 128, // w-32
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 80, // h-20
                width: 128,
                child: Image(image: preview, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Click to preview',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
      child: Semantics(
        button: true,
        image: true,
        label: 'Preview ${widget.item.name}',
        onTap: widget.onPreview,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPreview?.call();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) =>
              setState(() => _focusVisible = value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPreview,
            child: thumb,
          ),
        ),
      ),
    );
  }
}

/// The full-screen image preview.
///
/// The source glides the `<img>` between the row and the dialog with a Framer
/// `layoutId`. Per spec §6 that ports to a measured-`Rect` glide on
/// [beuiSpringLayout]: the dialog image measures its own laid-out rect one frame
/// after layout (the sanctioned one-frame-late caveat) and springs *from* the
/// thumbnail's global rect toward it, transform-only. Under reduced motion the
/// morph is dropped entirely and only the fade remains — exactly the source's
/// `layoutId={reduce ? undefined : …}` branch.
class _ImagePreviewLayer extends StatefulWidget {
  const _ImagePreviewLayer({
    required this.item,
    required this.origin,
    required this.colors,
    required this.reduce,
    required this.animation,
    required this.onClose,
  });

  final BeuiAttachmentUploadItem item;
  final Rect? origin;
  final BeuiColors colors;
  final bool reduce;
  final Animation<double> animation;
  final VoidCallback onClose;

  @override
  State<_ImagePreviewLayer> createState() => _ImagePreviewLayerState();
}

class _ImagePreviewLayerState extends State<_ImagePreviewLayer> {
  final GlobalKey _imageKey = GlobalKey();
  Rect? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect != _target) setState(() => _target = rect);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final media = MediaQuery.sizeOf(context);
    final preview = widget.item.preview;

    Widget image = ConstrainedBox(
      key: _imageKey,
      constraints: BoxConstraints(
        maxWidth: media.width * 0.9,
        maxHeight: media.height * 0.9,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        child: preview == null
            ? const SizedBox.shrink()
            : Image(image: preview, fit: BoxFit.contain),
      ),
    );

    // Shared-layout glide: place the image at the thumbnail's rect at t = 0 and
    // spring to its own measured rect. Transform-only, per the motion rules.
    final origin = widget.origin;
    final target = _target;
    if (!widget.reduce &&
        origin != null &&
        target != null &&
        target.width > 0) {
      final delta = origin.center - target.center;
      final scale = origin.width / target.width;
      image = SingleMotionBuilder(
        value: 1,
        from: 0,
        motion: beuiSpringLayout,
        builder: (context, t, child) => Transform.translate(
          offset: Offset.lerp(delta, Offset.zero, t.clamp(0.0, 1.0))!,
          child: Transform.scale(
            scale: scale + (1 - scale) * t.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: image,
      );
    }

    return FadeTransition(
      opacity: CurvedAnimation(parent: widget.animation, curve: beuiEaseOut),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Preview of ${widget.item.name}',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The source hangs the close button off the image's corner
                // (`-right-3 -top-3`). Reserving that overhang inside the stack
                // instead of positioning negatively keeps the same geometry AND
                // keeps the button hit-testable — Flutter drops pointer events
                // for children painted outside their parent's bounds, where CSS
                // would still deliver the click. The sentinel floors the stack
                // at the button's own footprint so a very small (or not yet
                // decoded) image can't shrink the close target out of reach.
                const SizedBox(width: 48, height: 48),
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 12),
                  child: image,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _IconButton(
                    icon: LucideIcons.x,
                    semanticsLabel: 'Close image preview',
                    tooltip: 'Close',
                    size: 36,
                    radius: 999,
                    iconSize: 16,
                    colors: colors,
                    reduce: widget.reduce,
                    foreground: colors.foreground,
                    hoverForeground: colors.foreground,
                    hoverBackground: colors.muted,
                    background: colors.background,
                    borderColor: colors.border.withValues(
                      alpha: colors.border.a * 0.7,
                    ),
                    onPressed: widget.onClose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
