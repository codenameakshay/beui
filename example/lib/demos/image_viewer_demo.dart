import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiImageViewer].
Widget imageViewerDemo(BuildContext context) => const _ImageViewerDemo();

Widget _photoFallback(BuildContext context, Object error, StackTrace? stack) =>
    const ColoredBox(
      color: Color(0xFFB8C6D1),
      child: Center(child: Icon(Icons.image_outlined, size: 40)),
    );

class _ImageViewerDemo extends StatelessWidget {
  const _ImageViewerDemo();

  static final _photos = [
    BeuiImageViewerImage(
      id: 'architecture',
      alt: 'Sculptural architecture',
      caption: '01 / Form and light',
      width: 4,
      height: 5,
      content: Image.network(
        'https://images.unsplash.com/photo-1487958449943-2429e8be8625?auto=format&fit=crop&w=900&q=85',
        fit: BoxFit.cover,
        errorBuilder: _photoFallback,
      ),
    ),
    BeuiImageViewerImage(
      id: 'landscape',
      alt: 'Open landscape',
      caption: '02 / A little room to breathe',
      width: 4,
      height: 5,
      content: Image.network(
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=85',
        fit: BoxFit.cover,
        errorBuilder: _photoFallback,
      ),
    ),
    BeuiImageViewerImage(
      id: 'workspace',
      alt: 'Light-filled workspace',
      caption: '03 / Places to make things',
      width: 4,
      height: 5,
      content: Image.network(
        'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=900&q=85',
        fit: BoxFit.cover,
        errorBuilder: _photoFallback,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Look a little closer.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 18),
      BeuiImageViewer(
        images: _photos,
        label: 'Collected photographs',
        children: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiImageViewerGallery(
              children: [
                BeuiImageViewerThumbnail(imageId: 'architecture'),
                BeuiImageViewerThumbnail(imageId: 'landscape'),
                BeuiImageViewerThumbnail(imageId: 'workspace'),
              ],
            ),
            BeuiImageViewerContent(),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text('3 photographs', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
