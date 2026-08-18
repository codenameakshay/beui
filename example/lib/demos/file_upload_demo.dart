import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gallery route for the two `blocks/file-upload` patterns —
/// [BeuiAttachmentUpload] (the mixed attachment workspace) and [BeuiFileUpload]
/// (the progress queue). Both dropzones fake a picker and simulated uploads;
/// the package ships no picker plugin (spec §7).
Widget fileUploadDemo(BuildContext context) => const _FileUploadDemo();

/// Gallery route for [BeuiAttachmentUpload] on its own.
///
/// It used to be reachable only as the first half of the `file-upload` page,
/// so the largest component in the library (2,300 lines, and the repo's
/// keyboard/semantics reference implementation) had no catalog entry of its
/// own and nothing linked to it.
Widget attachmentUploadDemo(BuildContext context) =>
    const _AttachmentUploadSection();

class _FileUploadDemo extends StatelessWidget {
  const _FileUploadDemo();

  // The source preview renders bare — its prose lives in the page chrome.
  @override
  Widget build(BuildContext context) =>
      const SingleChildScrollView(child: Center(child: _UploadQueueSection()));
}

// ---------------------------------------------------------------------------
// Attachment workspace
// ---------------------------------------------------------------------------

class _AttachmentUploadSection extends StatefulWidget {
  const _AttachmentUploadSection();

  @override
  State<_AttachmentUploadSection> createState() =>
      _AttachmentUploadSectionState();
}

class _AttachmentUploadSectionState extends State<_AttachmentUploadSection> {
  final _controller = BeuiAttachmentUploadController();
  final _timers = <Timer>{};

  // Source `AttachmentUploadPreview.INITIAL_ITEMS`, verbatim: a failed file, an
  // image and an audio note. The image's artwork is the one thing that cannot
  // carry over — the source points `previewUrl` at Unsplash and the package
  // fetches nothing — so `_buildPreview` paints a stand-in bitmap for it.
  List<BeuiAttachmentUploadItem> _items = const [
    BeuiAttachmentUploadItem(
      id: 'brief',
      name: 'launch-brief.pdf',
      size: 32400000,
      status: BeuiAttachmentStatus.failed,
      error: 'Upload failed',
    ),
    BeuiAttachmentUploadItem(
      id: 'flowers',
      name: 'orange-flowers.jpg',
      kind: BeuiAttachmentKind.image,
      size: 9800000,
    ),
    BeuiAttachmentUploadItem(
      id: 'voice-note',
      name: 'launch-note.m4a',
      kind: BeuiAttachmentKind.audio,
      currentTime: Duration(seconds: 12),
      duration: Duration(seconds: 48),
    ),
  ];

  String? _playingId;
  String? _notice;
  Timer? _playback;
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_buildPreview());
  }

  @override
  void dispose() {
    _playback?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _later(Duration delay, VoidCallback body) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) body();
    });
    _timers.add(timer);
  }

  /// The published package bundles no assets, so the demo paints its own
  /// preview bitmap rather than reaching for the network.
  Future<void> _buildPreview() async {
    const size = Size(360, 240);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          const [Color(0xFFF97316), Color(0xFFDB2777)],
        ),
    );
    canvas.drawCircle(
      const Offset(104, 88),
      52,
      Paint()..color = const Color(0x59FFFFFF),
    );
    canvas.drawCircle(
      const Offset(248, 168),
      74,
      Paint()..color = const Color(0x33FFFFFF),
    );
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || !mounted) return;
    final provider = MemoryImage(bytes.buffer.asUint8List());
    setState(() {
      _items = [
        for (final item in _items)
          item.kind == BeuiAttachmentKind.image && item.preview == null
              ? item.copyWith(preview: provider)
              : item,
      ];
    });
  }

  List<BeuiAttachmentUploadItem> get _fakes => [
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'spec-outline.pdf',
      size: 1240000,
    ),
    // The link kind is not in the source preview's rest state, so the gallery
    // reaches it through Browse rather than by seeding a row the site does not
    // show.
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'beui.dev/blocks',
      kind: BeuiAttachmentKind.link,
      href: 'https://beui.dev/components/blocks/file-upload',
    ),
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'studio-take.m4a',
      kind: BeuiAttachmentKind.audio,
      size: 3600000,
      currentTime: Duration.zero,
      duration: Duration(seconds: 36),
    ),
    // Deliberately over the component's 500 MB default, so browsing four times
    // shows the too-large rejection path.
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'teaser-cut.mov',
      kind: BeuiAttachmentKind.file,
      size: 842000000,
    ),
  ];

  void _browse() {
    final template = _fakes[_seed % _fakes.length];
    final id = 'picked-${_seed++}';
    _controller.add([
      BeuiAttachmentUploadItem(
        id: id,
        name: template.name,
        kind: template.kind,
        size: template.size,
        preview: template.preview,
        currentTime: template.currentTime,
        duration: template.duration,
      ),
    ]);
  }

  void _notify(String message) {
    setState(() => _notice = message);
    _later(const Duration(seconds: 3), () {
      if (_notice == message) setState(() => _notice = null);
    });
  }

  void _retry(BeuiAttachmentUploadItem item) {
    _patch(item.id, BeuiAttachmentStatus.uploading, clearError: true);
    _later(const Duration(milliseconds: 900), () {
      _patch(item.id, BeuiAttachmentStatus.complete);
      _later(const Duration(milliseconds: 1000), () {
        _patch(item.id, BeuiAttachmentStatus.idle);
      });
    });
  }

  void _patch(
    String id,
    BeuiAttachmentStatus status, {
    bool clearError = false,
  }) {
    setState(() {
      _items = [
        for (final item in _items)
          if (item.id == id)
            item.copyWith(status: status, clearError: clearError)
          else
            item,
      ];
    });
  }

  void _toggleAudio(BeuiAttachmentUploadItem item) {
    _playback?.cancel();
    if (_playingId == item.id) {
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = item.id);
    _playback = Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = _items.indexWhere((entry) => entry.id == item.id);
      final total = index < 0 ? null : _items[index].duration;
      if (total == null || total == Duration.zero) {
        timer.cancel();
        return;
      }
      final next =
          (_items[index].currentTime ?? Duration.zero) +
          const Duration(seconds: 1);
      setState(() {
        _items = [..._items];
        _items[index] = _items[index].copyWith(
          currentTime: next >= total ? total : next,
        );
        if (next >= total) {
          timer.cancel();
          _playingId = null;
        }
      });
    });
  }

  void _seek(BeuiAttachmentUploadItem item, Duration position) {
    setState(() {
      _items = [
        for (final entry in _items)
          if (entry.id == item.id)
            entry.copyWith(currentTime: position)
          else
            entry,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // Source preview wrapper: `w-full max-w-2xl px-3 py-6 sm:px-6`. Without it
    // the workspace runs the full width of the stage instead of the 624px the
    // site gives it.
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _body(colors),
        ),
      ),
    );
  }

  Widget _body(BeuiColors colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BeuiAttachmentUpload(
        controller: _controller,
        value: _items,
        onValueChange: (next) => setState(() => _items = next),
        onBrowse: _browse,
        attachmentsLabel: 'Attachments:',
        playingId: _playingId,
        onAudioToggle: _toggleAudio,
        onRetry: _retry,
        // The waveform is only a scrubber if something handles the seek.
        onSeek: _seek,
        // Cancelling a transfer in flight is its own act, distinct from
        // discarding a row that already settled.
        onCancel: (item) => _notify('Cancelled ${item.name}'),
        onOpenLink: (item) => _notify('Would open ${item.href}'),
        onAttachmentsRejected: (rejected, reason) {
          final names = rejected.map((item) => item.name).join(', ');
          _notify(switch (reason) {
            BeuiAttachmentRejectReason.tooLarge =>
              '$names is over the 500 MB limit',
            BeuiAttachmentRejectReason.maxFiles =>
              '$names turned away — attachment limit reached',
          });
        },
      ),
      if (_notice != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                LucideIcons.circle_alert,
                size: 14,
                color: colors.destructive,
              ),
              Expanded(
                child: Text(
                  _notice!,
                  style: TextStyle(fontSize: 12, color: colors.destructive),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Upload queue
// ---------------------------------------------------------------------------

class _UploadQueueSection extends StatefulWidget {
  const _UploadQueueSection();

  @override
  State<_UploadQueueSection> createState() => _UploadQueueSectionState();
}

/// Mirrors `file-upload.preview.tsx`: a "Upload package" shell with a
/// Centered/Row variant toggle, a reset button, and three seeded rows —
/// one done, one climbing, one failed.
class _UploadQueueSectionState extends State<_UploadQueueSection> {
  static const _seedItems = [
    BeuiFileUploadItem(
      id: 'brand-assets',
      name: 'brand-assets.zip',
      size: 18400000,
      progress: 100,
      status: BeuiFileUploadStatus.success,
    ),
    BeuiFileUploadItem(
      id: 'release-video',
      name: 'release-cut.mov',
      size: 84200000,
      progress: 58,
      status: BeuiFileUploadStatus.uploading,
    ),
    BeuiFileUploadItem(
      id: 'contracts',
      name: 'vendor-contract.pdf',
      size: 2800000,
      progress: 32,
      status: BeuiFileUploadStatus.error,
      error: 'Connection lost',
    ),
  ];

  List<BeuiFileUploadItem> _items = List.of(_seedItems);
  final Map<String, Timer> _uploads = {};
  final _random = math.Random(7);
  BeuiFileUploadVariant _variant = BeuiFileUploadVariant.centered;

  @override
  void initState() {
    super.initState();
    _start('release-video');
  }

  @override
  void dispose() {
    for (final t in _uploads.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _stop(String id) => _uploads.remove(id)?.cancel();

  void _start(String id) {
    _stop(id);
    _uploads[id] = Timer.periodic(const Duration(milliseconds: 520), (timer) {
      final index = _items.indexWhere((e) => e.id == id);
      if (index < 0 || _items[index].status != BeuiFileUploadStatus.uploading) {
        timer.cancel();
        _uploads.remove(id);
        return;
      }
      final current = _items[index];
      final next = math.min(
        100.0,
        (current.progress ?? 0) + 7 + _random.nextDouble() * 12,
      );
      setState(() {
        _items = List.of(_items)
          ..[index] = current.copyWith(
            progress: next,
            status: next >= 100
                ? BeuiFileUploadStatus.success
                : BeuiFileUploadStatus.uploading,
          );
      });
      if (next >= 100) {
        timer.cancel();
        _uploads.remove(id);
      }
    });
  }

  void _reset() {
    for (final id in _uploads.keys.toList()) {
      _stop(id);
    }
    setState(() => _items = List.of(_seedItems));
    _start('release-video');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final ready = _items
        .where((e) => e.status == BeuiFileUploadStatus.success)
        .length;
    final centered = _variant == BeuiFileUploadVariant.centered;

    // Align first: the stage hands down a tight full-stage width, which a bare
    // ConstrainedBox would enforce straight past `maxWidth` and leave the shell
    // full-bleed instead of the source's centred `max-w-md`.
    return Align(
      child: ConstrainedBox(
        // `min-h-[30rem] items-center justify-center` around a `max-w-md` shell.
        constraints: const BoxConstraints(minHeight: 480, maxWidth: 448),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12), // p-3
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(32), // rounded-[2rem]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), // px-1 mb-3
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Upload package',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.foreground,
                              ),
                            ),
                            Text(
                              '$ready of ${_items.length} files ready',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6, // gap-1.5
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4), // p-1
                            decoration: BoxDecoration(
                              color: colors.muted,
                              border: Border.all(color: colors.border),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _VariantChip(
                                  label: 'Centered',
                                  selected: centered,
                                  colors: colors,
                                  onPressed: () => setState(
                                    () => _variant =
                                        BeuiFileUploadVariant.centered,
                                  ),
                                ),
                                _VariantChip(
                                  label: 'Row',
                                  selected: !centered,
                                  colors: colors,
                                  onPressed: () => setState(
                                    () => _variant =
                                        BeuiFileUploadVariant.standard,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _DemoIconButton(
                            label: 'Reset upload queue',
                            icon: LucideIcons.rotate_ccw,
                            colors: colors,
                            onPressed: _reset,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                BeuiFileUpload(
                  value: _items,
                  variant: _variant,
                  maxFiles: 5,
                  // The default copy no longer promises drag-and-drop the port
                  // does not implement; this route keeps its own wording and
                  // leaves `dragAndDrop` off, which is the honest default.
                  title: centered ? 'Add files to upload' : 'Add release files',
                  description: 'PDF, images, video or zipped assets',
                  // 8MB, so the oversized candidate below is refused with a
                  // visible reason rather than silently vanishing.
                  maxFileSize: 8 * 1024 * 1024,
                  onValueChange: (next) => setState(() => _items = next),
                  onRetry: (item) => _start(item.id),
                  onRemove: (item) => _stop(item.id),
                  // Cancelling an upload in flight is not the same act as
                  // discarding a row that already finished.
                  onCancel: (item) => _stop(item.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One cell of the preview's Centered/Row segmented control.
class _VariantChip extends StatefulWidget {
  const _VariantChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_VariantChip> createState() => _VariantChipState();
}

class _VariantChipState extends State<_VariantChip> {
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      // A segmented control is a set of toggles; say so.
      toggled: widget.selected,
      label: widget.label,
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
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            height: 28, // h-7
            padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected ? colors.background : null,
              border: Border.all(
                color: _focusVisible ? colors.focusRing : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.selected
                    ? colors.foreground
                    : colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A demo icon button with the contract the gallery should be teaching:
/// button semantics, keyboard activation, a hover cursor and a focus ring.
class _DemoIconButton extends StatefulWidget {
  const _DemoIconButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_DemoIconButton> createState() => _DemoIconButtonState();
}

class _DemoIconButtonState extends State<_DemoIconButton> {
  bool _focusVisible = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      label: widget.label,
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
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 36,
            height: 36, // h-9 w-9
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: _focusVisible ? colors.focusRing : colors.border,
                width: _focusVisible ? 2 : 1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 14, color: colors.mutedForeground),
          ),
        ),
      ),
    );
  }
}
