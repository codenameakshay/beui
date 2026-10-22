import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiImageViewer].
Widget imageViewerDemo(BuildContext context) => const _ImageViewerDemo();

class _ImageViewerDemo extends StatelessWidget {
  const _ImageViewerDemo();

  static const _photos = [
    BeuiImageViewerImage(
      id: 'architecture',
      alt: 'Sculptural architecture',
      caption: '01 / Form and light',
      width: 4,
      height: 5,
      content: _PhotoPlaceholder(color: Color(0xffc7a88c), label: 'FORM'),
    ),
    BeuiImageViewerImage(
      id: 'landscape',
      alt: 'Open landscape',
      caption: '02 / A little room to breathe',
      width: 4,
      height: 5,
      content: _PhotoPlaceholder(color: Color(0xff788d79), label: 'OPEN'),
    ),
    BeuiImageViewerImage(
      id: 'workspace',
      alt: 'Light-filled workspace',
      caption: '03 / Places to make things',
      width: 4,
      height: 5,
      content: _PhotoPlaceholder(color: Color(0xffb9a969), label: 'MAKE'),
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Collected moments', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      Text(
        'Look a little closer.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 18),
      BeuiImageViewer(
        images: _photos,
        label: 'Collected photographs',
        children: const BeuiImageViewerGallery(
          children: [
            BeuiImageViewerThumbnail(imageId: 'architecture'),
            BeuiImageViewerThumbnail(imageId: 'landscape'),
            BeuiImageViewerThumbnail(imageId: 'workspace'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Open a photograph. Use the arrows to explore.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
        ),
      ),
    ),
  );
}
