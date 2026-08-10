import 'dart:async';
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiImageGeneration] — mirrors the source preview:
/// progressive queued → generating → refining → complete cycle with Replay.
Widget imageGenerationDemo(BuildContext context) =>
    const _ImageGenerationDemo();

class _ImageGenerationDemo extends StatefulWidget {
  const _ImageGenerationDemo();

  @override
  State<_ImageGenerationDemo> createState() => _ImageGenerationDemoState();
}

class _ImageGenerationDemoState extends State<_ImageGenerationDemo> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Generated image surface',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              _GenerationRun(
                key: ValueKey<int>(_run),
                onReplay: () => setState(() => _run++),
              ),
              const SizedBox(height: 24),
              Text(
                'Statuses',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final status in BeuiImageGenerationStatus.values)
                    SizedBox(
                      width: 160,
                      child: BeuiImageGeneration(
                        status: status,
                        prompt: status == BeuiImageGenerationStatus.error
                            ? 'a quiet mountain landscape at sunset'
                            : null,
                        resolution: '512 × 512',
                        onRetry: status == BeuiImageGenerationStatus.error
                            ? () {}
                            : null,
                        child:
                            status == BeuiImageGenerationStatus.complete ||
                                status == BeuiImageGenerationStatus.refining ||
                                status == BeuiImageGenerationStatus.error
                            ? const _GeneratedArtwork()
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-playing generation cycle (source GenerationDemo)
// ---------------------------------------------------------------------------

class _GenerationRun extends StatefulWidget {
  const _GenerationRun({required this.onReplay, super.key});

  final VoidCallback onReplay;

  @override
  State<_GenerationRun> createState() => _GenerationRunState();
}

class _GenerationRunState extends State<_GenerationRun> {
  BeuiImageGenerationStatus _status = BeuiImageGenerationStatus.queued;
  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _arm() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    _cancel();

    if (reduce) {
      setState(() => _status = BeuiImageGenerationStatus.complete);
      return;
    }

    setState(() => _status = BeuiImageGenerationStatus.queued);
    _timers.addAll([
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _status = BeuiImageGenerationStatus.generating);
        }
      }),
      Timer(const Duration(milliseconds: 3000), () {
        if (mounted) {
          setState(() => _status = BeuiImageGenerationStatus.refining);
        }
      }),
      Timer(const Duration(milliseconds: 5200), () {
        if (mounted) {
          setState(() => _status = BeuiImageGenerationStatus.complete);
        }
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Column(
      children: [
        BeuiImageGeneration(
          label: 'A quiet mountain landscape at sunset',
          prompt: 'a quiet mountain landscape at sunset',
          resolution: '1024 × 1024',
          status: _status,
          onRetry: widget.onReplay,
          child: const _GeneratedArtwork(),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: widget.onReplay,
          icon: Icon(
            LucideIcons.rotate_ccw,
            size: 16,
            color: colors.mutedForeground,
          ),
          label: Text(
            'Replay',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.mutedForeground,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: colors.mutedForeground,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative landscape (source GeneratedArtwork SVG)
// ---------------------------------------------------------------------------

class _GeneratedArtwork extends StatelessWidget {
  const _GeneratedArtwork();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _LandscapePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Map 800×600 artboard → local size.
    double x(double v) => v / 800 * w;
    double y(double v) => v / 600 * h;

    final sky = ui.Gradient.linear(
      Offset.zero,
      Offset(w, h),
      const [Color(0xFF191B33), Color(0xFF60538D), Color(0xFFE59B7B)],
      const [0.0, 0.48, 1.0],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = sky);

    final glow = ui.Gradient.radial(Offset(x(570), y(210)), x(150), [
      const Color(0xFFFFE6B2).withValues(alpha: 0.95),
      const Color(0xFFEFB47E).withValues(alpha: 0),
    ]);
    canvas.drawCircle(Offset(x(570), y(210)), x(150), Paint()..shader = glow);
    canvas.drawCircle(
      Offset(x(570), y(210)),
      x(54),
      Paint()..color = const Color(0xFFFFE5AD),
    );

    // Far ridge.
    final ridge = Path()
      ..moveTo(x(0), y(395))
      ..lineTo(x(120), y(314))
      ..lineTo(x(212), y(368))
      ..lineTo(x(344), y(225))
      ..lineTo(x(460), y(351))
      ..lineTo(x(538), y(285))
      ..lineTo(x(630), y(373))
      ..lineTo(x(800), y(312))
      ..lineTo(x(800), y(600))
      ..lineTo(x(0), y(600))
      ..close();
    canvas.drawPath(
      ridge,
      Paint()..color = const Color(0xFF283D43).withValues(alpha: 0.9),
    );

    // Ground.
    final groundGrad = ui.Gradient.linear(Offset(0, y(0)), Offset(0, h), const [
      Color(0xFF314946),
      Color(0xFF101817),
    ]);
    final ground = Path()
      ..moveTo(x(0), y(432))
      ..lineTo(x(118), y(376))
      ..lineTo(x(217), y(449))
      ..lineTo(x(332), y(352))
      ..lineTo(x(439), y(444))
      ..lineTo(x(551), y(392))
      ..lineTo(x(659), y(460))
      ..lineTo(x(800), y(412))
      ..lineTo(x(800), y(600))
      ..lineTo(x(0), y(600))
      ..close();
    canvas.drawPath(ground, Paint()..shader = groundGrad);

    // Near slope.
    final near = Path()
      ..moveTo(x(0), y(505))
      ..cubicTo(x(116), y(461), x(190), y(473), x(280), y(511))
      ..cubicTo(x(383), y(555), x(492), y(558), x(610), y(504))
      ..cubicTo(x(678), y(473), x(736), y(467), x(800), y(476))
      ..lineTo(x(800), y(600))
      ..lineTo(x(0), y(600))
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF13201F));

    // Stars.
    final starPaint = Paint()
      ..color = const Color(0xFFC9D7C3).withValues(alpha: 0.65);
    for (final s in const [
      (108.0, 142.0, 2.0),
      (168.0, 102.0, 1.5),
      (248.0, 154.0, 2.0),
      (332.0, 84.0, 1.5),
      (414.0, 138.0, 2.0),
    ]) {
      canvas.drawCircle(Offset(x(s.$1), y(s.$2)), s.$3 * (w / 800), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
