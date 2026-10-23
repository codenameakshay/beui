import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

const _demoNumber = '3745 6987 4096 0806';

Widget cardFolderDemo(BuildContext context) => const _CardFolderDemo();

class _CardFolderDemo extends StatefulWidget {
  const _CardFolderDemo();
  @override
  State<_CardFolderDemo> createState() => _CardFolderDemoState();
}

class _CardFolderDemoState extends State<_CardFolderDemo> {
  bool _detailsVisible = false;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 288),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: BeuiCardFolder(
          title: 'Saurabh Chauhan',
          cardNumber: _demoNumber,
          expiry: '08/29',
          cvv: '123',
          detailsVisible: _detailsVisible,
          onDetailsVisibleChange: (value) =>
              setState(() => _detailsVisible = value),
          card: _DemoCard(detailsVisible: _detailsVisible),
        ),
      ),
    ),
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.detailsVisible});
  final bool detailsVisible;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _ContourPainter())),
        Positioned(
          left: constraints.maxWidth * 0.06,
          top: constraints.maxHeight * 0.08,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SAURABH CHAUHAN',
                style: TextStyle(
                  color: Color(0x8CFFFFFF),
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              BeuiDigitSwap(
                value: detailsVisible ? _demoNumber : '•••• •••• •••• 0806',
                animationKey: detailsVisible ? 'revealed' : 'masked',
                direction: detailsVisible
                    ? BeuiDigitSwapDirection.up
                    : BeuiDigitSwapDirection.down,
                suffixLength: 4,
                glyphStyle: TextStyle(
                  color: detailsVisible ? Color(0xE6FFFFFF) : Color(0xA6FFFFFF),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1.56,
                ),
                suffixStyle: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1.56,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: constraints.maxWidth * 0.07,
          top: constraints.maxHeight * 0.08,
          width: constraints.maxWidth * 0.13,
          height: constraints.maxHeight * 0.2,
          child: const _Chip(),
        ),
        Positioned(
          left: constraints.maxWidth * 0.06,
          bottom: constraints.maxHeight * 0.09,
          child: Row(
            children: [
              const Text(
                'beUI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(width: 8),
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: constraints.maxWidth * 0.07,
          bottom: constraints.maxHeight * 0.1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _ArtworkField(label: 'Expiry', value: '08/29'),
              const SizedBox(width: 20),
              _ArtworkField(
                label: 'CVV',
                value: detailsVisible ? '123' : '•••',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ArtworkField extends StatelessWidget {
  const _ArtworkField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0x66FFFFFF),
          fontSize: 8,
          letterSpacing: 1.28,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      if (label == 'CVV')
        BeuiDigitSwap(
          value: value,
          animationKey: value,
          direction: value == '•••'
              ? BeuiDigitSwapDirection.down
              : BeuiDigitSwapDirection.up,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        )
      else
        Text(
          value,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip();
  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _ChipPainter());
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = Radius.elliptical(size.width * .18, size.height * .18);
    final outline = RRect.fromRectAndRadius(bounds.deflate(.5), radius);
    final extent = (size.width + size.height) / 4;
    final center = bounds.center;
    canvas.save();
    canvas.clipRRect(outline);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          center + Offset(-extent, -extent),
          center + Offset(extent, extent),
          const [Color(0xFFF2F0EA), Color(0xFFB9B7B1), Color(0xFFE4E1D9)],
          const [0, .45, 1],
        ),
    );
    final line = Paint()
      ..color = const Color(0x4D000000)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      line,
    );
    for (final fraction in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(0, size.height * fraction + .5),
        Offset(size.width, size.height * fraction + .5),
        line,
      );
    }
    final contactWidth = (size.width - 2) * .28;
    final contactHeight = (size.height - 2) * .34;
    final contactTop = (size.height - contactHeight) / 2;
    final contactRadius = Radius.elliptical(
      contactWidth * .35,
      contactHeight * .35,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-.5, contactTop, contactWidth + 1, contactHeight),
        topRight: contactRadius,
        bottomRight: contactRadius,
      ),
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          size.width - contactWidth - .5,
          contactTop,
          contactWidth + 1,
          contactHeight,
        ),
        topLeft: contactRadius,
        bottomLeft: contactRadius,
      ),
      line,
    );
    canvas.restore();
    canvas.drawRRect(outline, line);
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) => false;
}

class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final extent = (size.width + size.height) / 4;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          center - Offset(extent, extent),
          center + Offset(extent, extent),
          const [Color(0xFF383A38), Color(0xFF202120), Color(0xFF111211)],
          const [0, 0.48, 1],
        ),
    );
    canvas.save();
    final scale = math.min(size.width / 640, size.height / 404);
    canvas.translate(
      (size.width - 640 * scale) / 2,
      (size.height - 404 * scale) / 2,
    );
    canvas.scale(scale);
    for (var i = 0; i < 18; i++) {
      final radius = 72.0 + i * 24;
      canvas.drawCircle(
        const Offset(-20, -28),
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.32 - i * 0.009)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.restore();
    // CSS circle defaults to farthest-corner; the transparent stop is 32%.
    final radius =
        math.sqrt(
          math.pow(size.width * 0.78, 2) + math.pow(size.height * 0.92, 2),
        ) *
        0.32;
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.78, size.height * 0.08),
        radius,
        const [Color(0x1CFFFFFF), Color(0x00FFFFFF)],
      );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) => false;
}
