import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the two `blocks/file-upload` patterns —
/// [BeuiAttachmentUpload] (the mixed attachment workspace) and [BeuiFileUpload]
/// (the progress queue). Both dropzones fake a picker and simulated uploads;
/// the package ships no picker plugin (spec §7).
Widget fileUploadDemo(BuildContext context) => const _FileUploadDemo();

class _FileUploadDemo extends StatelessWidget {
  const _FileUploadDemo();

  // Both source previews render bare (their prose lives in the page chrome),
  // so the route is just the two components stacked.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 48,
        children: [
          const _AttachmentUploadSection(),
          const _UploadQueueSection(),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Attachment workspace
// ---------------------------------------------------------------------------

const _maxAttachmentSize = 20 * 1024 * 1024;

class _AttachmentUploadSection extends StatefulWidget {
  const _AttachmentUploadSection();

  @override
  State<_AttachmentUploadSection> createState() =>
      _AttachmentUploadSectionState();
}

class _AttachmentUploadSectionState extends State<_AttachmentUploadSection> {
  final _controller = BeuiAttachmentUploadController();
  final _timers = <Timer>{};

  List<BeuiAttachmentUploadItem> _items = const [
    BeuiAttachmentUploadItem(
      id: 'brief',
      name: 'launch-brief.pdf',
      size: 32400000,
      status: BeuiAttachmentStatus.failed,
      error: 'Upload failed',
    ),
    BeuiAttachmentUploadItem(
      id: 'docs',
      name: 'beui.dev/blocks',
      kind: BeuiAttachmentKind.link,
      href: 'https://beui.dev/components/blocks/file-upload',
    ),
    BeuiAttachmentUploadItem(
      id: 'voice-note',
      name: 'launch-note.m4a',
      kind: BeuiAttachmentKind.audio,
      currentTime: Duration(seconds: 12),
      duration: Duration(seconds: 48),
    ),
  ];

  ImageProvider? _preview;
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
      _preview = provider;
      _items = [
        _items.first,
        BeuiAttachmentUploadItem(
          id: 'mood-board',
          name: 'mood-board.png',
          kind: BeuiAttachmentKind.image,
          size: 4800000,
          preview: provider,
        ),
        ..._items.skip(1),
      ];
    });
  }

  List<BeuiAttachmentUploadItem> get _fakes => [
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'spec-outline.pdf',
      size: 1240000,
    ),
    BeuiAttachmentUploadItem(
      id: '',
      name: 'orange-flowers.png',
      kind: BeuiAttachmentKind.image,
      size: 2100000,
      preview: _preview,
    ),
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'studio-take.m4a',
      kind: BeuiAttachmentKind.audio,
      size: 3600000,
      currentTime: Duration.zero,
      duration: Duration(seconds: 36),
    ),
    // Deliberately over maxFileSize, so browsing four times shows the
    // too-large rejection path.
    const BeuiAttachmentUploadItem(
      id: '',
      name: 'teaser-cut.mov',
      kind: BeuiAttachmentKind.file,
      size: 84200000,
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeuiAttachmentUpload(
          controller: _controller,
          value: _items,
          onValueChange: (next) => setState(() => _items = next),
          onBrowse: _browse,
          maxFiles: 8,
          maxFileSize: _maxAttachmentSize,
          attachmentsLabel: 'Attachments:',
          playingId: _playingId,
          onAudioToggle: _toggleAudio,
          onRetry: _retry,
          onOpenLink: (item) => _notify('Would open ${item.href}'),
          onAttachmentsRejected: (rejected, reason) {
            final names = rejected.map((item) => item.name).join(', ');
            _notify(switch (reason) {
              BeuiAttachmentRejectReason.tooLarge =>
                '$names is over the 20 MB limit',
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

    return ConstrainedBox(
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
                                  () =>
                                      _variant = BeuiFileUploadVariant.centered,
                                ),
                              ),
                              _VariantChip(
                                label: 'Row',
                                selected: !centered,
                                colors: colors,
                                onPressed: () => setState(
                                  () =>
                                      _variant = BeuiFileUploadVariant.standard,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Reset upload queue',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _reset,
                              child: Container(
                                width: 36,
                                height: 36, // h-9 w-9
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: colors.border),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.rotate_ccw,
                                  size: 14,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
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
                title: centered ? 'Drop files to upload' : 'Drop release files',
                description: 'PDF, images, video or zipped assets',
                onValueChange: (next) => setState(() => _items = next),
                onRetry: (item) => _start(item.id),
                onRemove: (item) => _stop(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One cell of the preview's Centered/Row segmented control.
class _VariantChip extends StatelessWidget {
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
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 28, // h-7
        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.background : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? colors.foreground : colors.mutedForeground,
          ),
        ),
      ),
    ),
  );
}
