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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 40,
            children: [
              _Section(
                label: 'Attachment workspace',
                blurb:
                    'Files, links, images and audio in one list — browse to add '
                    '(the fourth is oversized on purpose), play the voice note, '
                    'retry the failed row.',
                child: _AttachmentUploadSection(),
              ),
              _Section(
                label: 'Upload queue',
                blurb: 'Dropzone with per-file progress, retry and removal.',
                child: _UploadQueueSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.blurb,
    required this.child,
  });

  final String label;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 16),
          child: Text(
            blurb,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colors.mutedForeground,
            ),
          ),
        ),
        child,
      ],
    );
  }
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

class _UploadQueueSectionState extends State<_UploadQueueSection> {
  final List<BeuiFileUploadItem> _items = [];
  final Map<String, Timer> _uploads = {};
  int _seed = 0;
  final _random = math.Random(7);

  static const _fakes = [
    ('quarterly-report.pdf', 2411724),
    ('hero-banner.png', 4837291),
    ('release-notes.md', 18231),
    ('podcast-episode.mp3', 48273645),
    ('archive-2025.zip', 104857600),
    ('main.dart', 5231),
  ];

  @override
  void dispose() {
    for (final t in _uploads.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _browse() {
    final (name, size) = _fakes[_seed % _fakes.length];
    final item = BeuiFileUploadItem(
      id: 'file-${_seed++}',
      name: name,
      size: size,
      status: BeuiFileUploadStatus.uploading,
      progress: 0,
    );
    setState(() => _items.add(item));
    _simulate(item.id, failChance: 0.3);
  }

  void _simulate(String id, {double failChance = 0}) {
    _uploads[id]?.cancel();
    final willFail = _random.nextDouble() < failChance;
    _uploads[id] = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      final index = _items.indexWhere((e) => e.id == id);
      if (index < 0) {
        timer.cancel();
        return;
      }
      final current = _items[index];
      final next = (current.progress ?? 0) + 12 + _random.nextInt(14);
      setState(() {
        if (willFail && next > 55) {
          timer.cancel();
          _items[index] = current.copyWith(
            status: BeuiFileUploadStatus.error,
            error: 'Connection dropped',
          );
        } else if (next >= 100) {
          timer.cancel();
          _items[index] = current.copyWith(
            progress: 100,
            status: BeuiFileUploadStatus.success,
          );
        } else {
          _items[index] = current.copyWith(progress: next.toDouble());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BeuiFileUpload(
      value: List.of(_items),
      maxFiles: 6,
      onBrowse: _browse,
      onRemove: (item) {
        _uploads.remove(item.id)?.cancel();
        setState(() => _items.removeWhere((e) => e.id == item.id));
      },
      onRetry: (item) {
        final index = _items.indexWhere((e) => e.id == item.id);
        if (index >= 0) {
          setState(() => _items[index] = item);
          _simulate(item.id);
        }
      },
    );
  }
}
