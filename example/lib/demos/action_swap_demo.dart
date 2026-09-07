import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiActionSwapButton].
Widget actionSwapDemo(BuildContext context) => const _ActionSwapDemo();

/// The action-swap showcase — replicates beui.dev/components/motion/action-swap,
/// which ships three preview sections in the page's own order: `Cascade`
/// (`action-swap-cascade.tsx`), `Blur` (`action-swap-blur.tsx`) and `Roll`
/// (`action-swap-roll.tsx`). The page has no hero preview above them.
///
/// Cascade is a single centred primary CTA; Blur and Roll are a centred
/// `gap-4` group of a text pill, an icon-only toggle and a primary CTA. Tap any
/// button to swap its content. The captions stand in for the site's per-section
/// headings.
class _ActionSwapDemo extends StatelessWidget {
  const _ActionSwapDemo();

  // Per-section rows, matching each preview on the page.
  static const _theme = [
    BeuiActionSwapItem(
      id: 'light',
      label: 'Light',
      icon: LucideIcons.sun,
      semanticLabel: 'Use light theme',
    ),
    BeuiActionSwapItem(
      id: 'dark',
      label: 'Dark',
      icon: LucideIcons.moon,
      semanticLabel: 'Use dark theme',
    ),
  ];
  static const _blurText = [
    BeuiActionSwapItem(id: 'copy', label: 'Copy'),
    BeuiActionSwapItem(id: 'copied', label: 'Copied'),
  ];
  static const _blurCta = [
    BeuiActionSwapItem(id: 'copy', label: 'Copy link', icon: LucideIcons.copy),
    BeuiActionSwapItem(id: 'copied', label: 'Copied', icon: LucideIcons.check),
  ];
  static const _rollText = [
    BeuiActionSwapItem(id: 'idle', label: 'Save'),
    BeuiActionSwapItem(id: 'done', label: 'Saved'),
  ];
  static const _rollCta = [
    BeuiActionSwapItem(
      id: 'send',
      label: 'Send invite',
      icon: LucideIcons.send,
    ),
    BeuiActionSwapItem(
      id: 'sent',
      label: 'Invite sent',
      icon: LucideIcons.sparkles,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionLabel(text),
    );

    // The Blur / Roll previews: `flex items-center justify-center gap-3`
    // (12px — measured off the live previews, not guessed).
    Widget row(
      BeuiActionSwapVariant anim,
      List<BeuiActionSwapItem> text,
      List<BeuiActionSwapItem> cta,
    ) => Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BeuiActionSwapButton(
          items: text,
          animation: anim,
          variant: BeuiButtonVariant.secondary,
        ),
        BeuiActionSwapButton(
          items: _theme,
          animation: anim,
          variant: BeuiButtonVariant.outline,
          size: BeuiButtonSize.icon,
          iconOnly: true,
        ),
        BeuiActionSwapButton(
          items: cta,
          animation: anim,
          variant: BeuiButtonVariant.primary,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section 1 — Cascade: a single centred primary CTA.
        caption('Cascade — letter-by-letter slot roll'),
        const Center(
          child: BeuiActionSwapButton(
            items: _blurCta,
            animation: BeuiActionSwapVariant.cascade,
            variant: BeuiButtonVariant.primary,
          ),
        ),
        const SizedBox(height: 40),

        // Section 2 — Blur.
        caption('Blur — swap with blur, opacity and scale'),
        row(BeuiActionSwapVariant.blur, _blurText, _blurCta),
        const SizedBox(height: 40),

        // Section 3 — Roll.
        caption('Roll — the next text or icon rolls in from below'),
        row(BeuiActionSwapVariant.roll, _rollText, _rollCta),
      ],
    );
  }
}
