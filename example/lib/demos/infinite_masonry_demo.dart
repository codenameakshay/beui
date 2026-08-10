import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiInfiniteMasonry] — mirrors
/// `infinite-masonry.preview.tsx`: the "Visual index" gallery that pages in six
/// more tiles as you approach the end.
///
/// The source cards show remote Unsplash photographs. The package ships no
/// assets of its own (spec §3), so each card keeps the source's exact
/// `imageHeight` but fills that box with a flat `muted` panel; everything
/// around it — the header, the captions, the categories, the page size and the
/// tile rhythm — is the preview's.
Widget infiniteMasonryDemo(BuildContext context) =>
    const _InfiniteMasonryDemo();

/// One gallery entry (source `GalleryItem`).
class _Tile {
  const _Tile({
    required this.id,
    required this.title,
    required this.category,
    required this.imageHeight,
  });

  final String id;
  final String title;
  final String category;
  final double imageHeight;
}

/// Source `gallerySource` — six repeating entries.
const _source = <({String title, String category, double imageHeight})>[
  (title: 'Soft geometry', category: 'Architecture', imageHeight: 260),
  (title: 'Open horizon', category: 'Landscape', imageHeight: 190),
  (title: 'Working rhythm', category: 'Workspace', imageHeight: 230),
  (title: 'Shared table', category: 'Studio', imageHeight: 300),
  (title: 'In session', category: 'People', imageHeight: 210),
  (title: 'After hours', category: 'Office', imageHeight: 280),
];

const _pageSize = 6;
const _maxItems = 42;

List<_Tile> _createItems(int start, int count) => [
  for (var offset = 0; offset < count; offset++)
    () {
      final index = start + offset;
      final source = _source[index % _source.length];
      return _Tile(
        id: 'gallery-$index',
        // Source suffixes the pass number: `${title} ${floor(i / 6) + 1}`.
        title: '${source.title} ${index ~/ _source.length + 1}',
        category: source.category,
        imageHeight: source.imageHeight,
      );
    }(),
];

class _InfiniteMasonryDemo extends StatefulWidget {
  const _InfiniteMasonryDemo();

  @override
  State<_InfiniteMasonryDemo> createState() => _InfiniteMasonryDemoState();
}

class _InfiniteMasonryDemoState extends State<_InfiniteMasonryDemo> {
  List<_Tile> _items = _createItems(0, 12);
  bool _loading = false;

  bool get _hasMore => _items.length < _maxItems;

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      final count = _pageSize < _maxItems - _items.length
          ? _pageSize
          : _maxItems - _items.length;
      if (count > 0) {
        _items = [..._items, ..._createItems(_items.length, count)];
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1024), // max-w-5xl
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `mb-3 flex items-end justify-between gap-4 px-1`.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Visual index',
                          style: TextStyle(
                            fontSize: 14, // text-sm
                            height: 20 / 14,
                            fontWeight: FontWeight.w600,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2), // mt-0.5
                        Text(
                          'Scroll to load the next page',
                          style: TextStyle(
                            fontSize: 12, // text-xs
                            height: 16 / 12,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // gap-4
                  Text(
                    '${_items.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontFamily: 'monospace',
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 544, // h-[34rem]
              child: BeuiInfiniteMasonry<_Tile>(
                items: _items,
                getItemKey: (t, _) => t.id,
                hasMore: _hasMore,
                loading: _loading,
                onLoadMore: _loadMore,
                // Source `estimateSize`: image box + the caption row.
                estimateSize: (t, _) => t.imageHeight + 66,
                ariaLabel: 'Visual inspiration gallery',
                renderItem: (t, _) => _GalleryCard(tile: t, colors: colors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card: `overflow-hidden rounded-2xl border border-border bg-card` with a
/// fixed-height media box over a caption row.
class _GalleryCard extends StatelessWidget {
  const _GalleryCard({required this.tile, required this.colors});

  final _Tile tile;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: colors.card,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(16), // rounded-2xl
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stands in for the source's remote photograph.
        SizedBox(
          height: tile.imageHeight,
          child: ColoredBox(color: colors.muted),
        ),
        Padding(
          padding: const EdgeInsets.all(12), // p-3
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  tile.title,
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12), // gap-3
              Text(
                tile.category.toUpperCase(),
                style: TextStyle(
                  fontSize: 10, // text-[10px]
                  letterSpacing: 0.5, // tracking-wider
                  color: colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
