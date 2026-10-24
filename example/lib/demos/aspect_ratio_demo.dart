import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAspectRatio].
Widget aspectRatioDemo(BuildContext context) => const _AspectRatioPreview();

/// Mirrors the source preview: nine ratios and one cover-cropped landscape.
class _AspectRatioPreview extends StatefulWidget {
  const _AspectRatioPreview();

  @override
  State<_AspectRatioPreview> createState() => _AspectRatioPreviewState();
}

class _AspectRatioPreviewState extends State<_AspectRatioPreview> {
  static const _ratios = <(String, double)>[
    ('21:9', 21 / 9),
    ('16:9', 16 / 9),
    ('3:2', 3 / 2),
    ('4:3', 4 / 3),
    ('1:1', 1),
    ('4:5', 4 / 5),
    ('3:4', 3 / 4),
    ('2:3', 2 / 3),
    ('9:16', 9 / 16),
  ];

  double _ratio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    final width = math.min(440.0, 360 * _ratio);
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeuiTabs<double>(
              value: _ratio,
              onChanged: (ratio) => setState(() => _ratio = ratio),
              wrap: true,
              tabs: [
                for (final (label, ratio) in _ratios)
                  BeuiTab(value: ratio, label: Text(label)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 400,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: BeuiAspectRatio(
                    ratio: _ratio,
                    child: const BeuiAspectRatioImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1000&q=80',
                      ),
                      alt:
                          'A lakeside cabin beneath mountains, reflected in the water',
                      width: 1000,
                      height: 667,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
