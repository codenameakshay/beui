import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiInfiniteMasonry] — a responsive, lazily-built masonry
/// feed that loads more tiles as you approach the end.
Widget infiniteMasonryDemo(BuildContext context) =>
    const _InfiniteMasonryDemo();

class _Tile {
  const _Tile(this.id, this.height, this.hue);
  final int id;
  final double height;
  final int hue;
}

class _InfiniteMasonryDemo extends StatefulWidget {
  const _InfiniteMasonryDemo();

  @override
  State<_InfiniteMasonryDemo> createState() => _InfiniteMasonryDemoState();
}

class _InfiniteMasonryDemoState extends State<_InfiniteMasonryDemo> {
  final List<_Tile> _items = [];
  bool _loading = false;
  int _next = 0;

  static const _maxItems = 60;

  @override
  void initState() {
    super.initState();
    _append(12);
  }

  // Deterministic pseudo-heights so the masonry lanes stagger visibly.
  void _append(int count) {
    for (var i = 0; i < count && _items.length < _maxItems; i++) {
      final id = _next++;
      final height = 120.0 + (id * 37 % 5) * 44.0; // 120..296
      _items.add(_Tile(id, height, (id * 47) % 360));
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _items.length >= _maxItems) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _append(8);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return SizedBox(
      width: 640,
      height: 520,
      child: BeuiInfiniteMasonry<_Tile>(
        items: _items,
        getItemKey: (t, _) => t.id,
        hasMore: _items.length < _maxItems,
        loading: _loading,
        onLoadMore: _loadMore,
        estimateSize: (t, _) => t.height,
        endState: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              "You're all caught up",
              style: TextStyle(fontSize: 13, color: colors.mutedForeground),
            ),
          ),
        ),
        renderItem: (t, _) => Container(
          height: t.height,
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(1, t.hue.toDouble(), 0.55, 0.55).toColor(),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${t.id}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
