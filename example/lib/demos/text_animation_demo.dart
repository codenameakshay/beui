import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiChromaticTextReveal], [BeuiTextReveal],
/// [BeuiTextShimmer] and [BeuiTextCascade].
Widget textAnimationDemo(BuildContext context) => const _TextAnimationDemo();

/// The text-animation showcase — the four previews
/// beui.dev/components/motion/text-animation ships, in the page's own order:
/// `ChromaticTextRevealPreview`, `TextRevealPreview`, `TextShimmerPreview`,
/// `TextCascadePreview`. Each block mirrors its source preview verbatim; the
/// captions stand in for the site's per-primitive section headings.
///
/// Type sizes take the source's `sm:` branch (the ≥640px one), which is what the
/// site renders in the 824px-wide preview band: `text-5xl` = 48px,
/// `tracking-[-0.04em]` = −1.92px at that size.
class _TextAnimationDemo extends StatefulWidget {
  const _TextAnimationDemo();

  @override
  State<_TextAnimationDemo> createState() => _TextAnimationDemoState();
}

class _TextAnimationDemoState extends State<_TextAnimationDemo> {
  static const _phrases = ['Install skills', 'Open settings', 'Ship updates'];

  int _phrase = 0;
  int _replay = 0;
  Timer? _cascadeTimer;

  @override
  void initState() {
    super.initState();
    // Source TextCascadePreview cycles its phrases every 2.4s.
    _cascadeTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted) setState(() => _phrase = (_phrase + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _cascadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionLabel(text),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ChromaticTextRevealPreview: prefix + cycling words, `text-5xl
        // font-medium tracking-[-0.04em]`, started on mount (startOnView false).
        caption('Dia text animation — a colour edge paints each word in'),
        Center(
          child: BeuiChromaticTextReveal(
            prefix: 'Motion that feels',
            words: const ['natural.', 'intentional.', 'alive.'],
            startOnView: false,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.92,
              color: colors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 48),

        // TextRevealPreview: centred headline + delayed subtitle (`gap-2`), then
        // `gap-8` to the Replay pill.
        caption('Reveal — word by word, with a soft blur'),
        KeyedSubtree(
          key: ValueKey(_replay),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiTextReveal(
                const ['Motion that feels', 'considered.'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  height: 0.95, // leading-[0.95]
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.92, // tracking-[-0.04em]
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 8), // gap-2
              BeuiTextReveal(
                'Word by word, with a soft blur.',
                delay: const Duration(milliseconds: 900),
                stagger: const Duration(milliseconds: 50),
                blur: 6,
                yOffset: 0.2,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.mutedForeground),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32), // gap-8
        Center(child: ReplayButton(onPressed: () => setState(() => _replay++))),
        const SizedBox(height: 48),

        // TextShimmerPreview: `flex flex-col gap-4`, left-aligned inside a
        // centred block.
        caption('Shimmer — gradient sweep'),
        Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiTextShimmer(
                'Loading projects…',
                style: TextStyle(
                  fontSize: 30, // text-3xl
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 16), // gap-4
              BeuiTextShimmer(
                'Faster shimmer',
                duration: const Duration(milliseconds: 1500),
                style: TextStyle(fontSize: 14, color: colors.foreground),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // TextCascadePreview: one centred `text-lg font-medium` line, cycling.
        caption('Cascade — per-letter slot roll (cycles)'),
        Center(
          child: BeuiTextCascade(
            _phrases[_phrase],
            style: TextStyle(
              fontSize: 18, // text-lg
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}
