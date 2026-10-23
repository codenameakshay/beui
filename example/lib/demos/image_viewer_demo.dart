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
        'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1600&h=2000&q=85',
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
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1600&h=2000&q=85',
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
        'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1600&h=2000&q=85',
        fit: BoxFit.cover,
        errorBuilder: _photoFallback,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 576),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COLLECTED MOMENTS',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: BeuiColors.resolve(context).mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Look a little closer.',
                    style: TextStyle(
                      fontSize: 18,
                      height: 28 / 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.45,
                      color: BeuiColors.resolve(context).foreground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '3 photographs',
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: BeuiColors.resolve(context).mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        BeuiImageViewer(
          images: _photos,
          label: 'Collected photographs',
          children: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiImageViewerGallery(
                columns: 3,
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
        const SizedBox(height: 16),
        Text(
          'Open a photograph. Swipe or use the arrows to explore.',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: BeuiColors.resolve(context).mutedForeground,
          ),
        ),
      ],
    ),
  );
}
