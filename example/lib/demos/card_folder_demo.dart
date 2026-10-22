import 'dart:math' as math;

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
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF383A38), Color(0xFF202120), Color(0xFF111211)],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ContourPainter())),
          Positioned(
            left: constraints.maxWidth * 0.06,
            top: constraints.maxHeight * 0.09,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAURABH CHAUHAN',
                  style: TextStyle(
                    color: Color(0x8CFFFFFF),
                    fontSize: 10,
                    letterSpacing: 1.5,
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
                  glyphStyle: const TextStyle(
                    color: Color(0xA6FFFFFF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                  suffixStyle: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1,
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
            bottom: constraints.maxHeight * 0.08,
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
            bottom: constraints.maxHeight * 0.08,
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
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xE6FFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF2F0EA), Color(0xFFB9B7B1), Color(0xFFE4E1D9)],
      ),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
    ),
    child: Stack(
      children: [
        Center(
          child: Container(
            width: 1,
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.36,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.36,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 5,
                height: 15,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
              Container(
                width: 5,
                height: 15,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
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
    final glow = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.56, -0.84),
        radius: 0.7,
        colors: [Color(0x1CFFFFFF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) => false;
}
