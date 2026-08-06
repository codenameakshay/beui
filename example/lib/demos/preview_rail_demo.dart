import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPreviewRail] — hover (or focus) the ticks to magnify
/// the nearest one and glide the preview card along the rail. Mirrors the
/// source `preview-rail.preview.tsx`: the same items, `defaultActiveId: 'docs'`,
/// shown in both orientations, plus the mirrored [BeuiPreviewRailPreviewSide],
/// a preview-less rail, and the resting `highlightActive` highlight.
Widget previewRailDemo(BuildContext context) => const _PreviewRailDemo();

const _items = <BeuiPreviewRailItem>[
  BeuiPreviewRailItem(
    id: 'dashboard',
    label: 'Dashboard',
    description: Text('Return to your workspace overview and recent activity.'),
  ),
  BeuiPreviewRailItem(
    id: 'components',
    label: 'Components',
    description: Text('Browse motion primitives for React and Next.js.'),
  ),
  BeuiPreviewRailItem(
    id: 'blocks',
    label: 'Blocks',
    description: Text('Explore composed, product-ready interface blocks.'),
  ),
  BeuiPreviewRailItem(
    id: 'playground',
    label: 'Playground',
    description: Text('Tune motion values and preview behavior live.'),
  ),
  BeuiPreviewRailItem(
    id: 'docs',
    label: 'Documentation',
    description: Text('Read installation, usage, and API reference notes.'),
  ),
  BeuiPreviewRailItem(
    id: 'changelog',
    label: 'Changelog',
    description: Text('Review newly launched components and improvements.'),
  ),
  BeuiPreviewRailItem(
    id: 'sponsors',
    label: 'Sponsors',
    description: Text(
      'Support continued development of the open-source library.',
    ),
  ),
  BeuiPreviewRailItem(
    id: 'pro',
    label: 'beUI Pro',
    description: Text('Get premium components and lifetime access.'),
  ),
  BeuiPreviewRailItem(
    id: 'examples',
    label: 'Examples',
    description: Text(
      'See components composed in practical interface patterns.',
    ),
  ),
  BeuiPreviewRailItem(
    id: 'templates',
    label: 'Templates',
    description: Text(
      'Start from polished layouts built with beUI components.',
    ),
  ),
  BeuiPreviewRailItem(
    id: 'guides',
    label: 'Guides',
    description: Text('Learn how to combine motion primitives effectively.'),
  ),
  BeuiPreviewRailItem(
    id: 'community',
    label: 'Community',
    description: Text('Discover what other builders are creating with beUI.'),
  ),
  BeuiPreviewRailItem(
    id: 'github',
    label: 'GitHub',
    description: Text(
      'View the source, report issues, and contribute improvements.',
    ),
  ),
  BeuiPreviewRailItem(
    id: 'about',
    label: 'About',
    description: Text('Learn more about the ideas and people behind beUI.'),
  ),
];

class _PreviewRailDemo extends StatelessWidget {
  const _PreviewRailDemo();

  @override
  Widget build(BuildContext context) {
    // Source preview: two rails in a `flex flex-col gap-8` (32) — a vertical
    // one at `h-[360px] max-w-2xl` (672) and a horizontal one at `h-[280px]`,
    // both `defaultActiveId: 'docs'`. The remaining variants
    // (previewSide/showPreview/highlightActive) are covered by the widget
    // tests rather than shown here, matching the source page.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SizedBox(
              height: 360,
              child: BeuiPreviewRail(items: _items, defaultActiveId: 'docs'),
            ),
            SizedBox(height: 32),
            SizedBox(
              height: 280,
              child: BeuiPreviewRail(
                items: _items,
                orientation: BeuiPreviewRailOrientation.horizontal,
                defaultActiveId: 'docs',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
