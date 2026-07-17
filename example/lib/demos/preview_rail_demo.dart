import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPreviewRail] — hover (or focus) the ticks to magnify
/// the nearest one and glide the preview card along the rail. Mirrors the
/// source `preview-rail.preview.tsx`: the same items, `defaultActiveId: 'docs'`,
/// shown in both orientations.
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
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
        ),
        child,
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section(
                'VERTICAL',
                const BeuiPreviewRail(items: _items, defaultActiveId: 'docs'),
              ),
              const SizedBox(height: 48),
              section(
                'HORIZONTAL',
                const BeuiPreviewRail(
                  items: _items,
                  orientation: BeuiPreviewRailOrientation.horizontal,
                  defaultActiveId: 'docs',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
