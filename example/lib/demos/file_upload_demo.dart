import 'dart:async';
import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiFileUpload] — the dropzone fakes a picker and
/// simulated uploads (the package ships no picker plugin; spec §7).
Widget fileUploadDemo(BuildContext context) => const _FileUploadDemo();

class _FileUploadDemo extends StatefulWidget {
  const _FileUploadDemo();

  @override
  State<_FileUploadDemo> createState() => _FileUploadDemoState();
}

class _FileUploadDemoState extends State<_FileUploadDemo> {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: BeuiFileUpload(
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
          ),
        ),
      ),
    );
  }
}
