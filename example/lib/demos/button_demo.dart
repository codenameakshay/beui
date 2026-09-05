import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiButton], [BeuiStatefulButton] and
/// [BeuiMagneticButton].
Widget buttonDemo(BuildContext context) => const _ButtonDemo();

/// The button showcase — the three preview sections
/// beui.dev/components/motion/button ships, in the page's own order:
/// `Button` (`base.tsx`), `Stateful Button` (`stateful.tsx`) and
/// `Magnetic Button` (`magnetic.tsx`). Every preview on that page is centred;
/// the captions stand in for the site's per-section headings.
///
/// Measured off the live previews: base is three centred rows at `gap-3` (12px)
/// with `gap-6` (24px) between rows; stateful stacks its two buttons in a
/// centred column at `gap-3`; magnetic is one centred row at `gap-4` (16px).
class _ButtonDemo extends StatefulWidget {
  const _ButtonDemo();

  @override
  State<_ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<_ButtonDemo> {
  BeuiButtonState _state = BeuiButtonState.idle;

  Future<void> _runLifecycle() async {
    setState(() => _state = BeuiButtonState.loading);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _state = BeuiButtonState.success);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _state = BeuiButtonState.idle);
  }

  @override
  Widget build(BuildContext context) {
    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionLabel(text),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section 1 — Button (base.tsx).
        caption('Button — press scale, hover lift, variants and sizes'),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiButton(
              onPressed: () {},
              child: _row(const [
                Text('Continue'),
                Icon(LucideIcons.arrow_right),
              ]),
            ),
            BeuiButton(
              variant: BeuiButtonVariant.secondary,
              onPressed: () {},
              child: _row(const [Icon(LucideIcons.download), Text('Download')]),
            ),
            BeuiButton(
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Text('Outline'),
            ),
            BeuiButton(
              variant: BeuiButtonVariant.ghost,
              onPressed: () {},
              child: const Text('Ghost'),
            ),
          ],
        ),
        const SizedBox(height: 24), // gap-6
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BeuiButton(
              size: BeuiButtonSize.sm,
              onPressed: () {},
              child: const Text('Small'),
            ),
            BeuiButton(
              size: BeuiButtonSize.md,
              onPressed: () {},
              child: const Text('Medium'),
            ),
            BeuiButton(
              size: BeuiButtonSize.lg,
              onPressed: () {},
              child: const Text('Large'),
            ),
            BeuiButton(
              size: BeuiButtonSize.icon,
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Icon(LucideIcons.trash),
            ),
          ],
        ),
        const SizedBox(height: 24), // gap-6
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiButton(
              ripple: true,
              onPressed: () {},
              child: const Text('Ripple'),
            ),
            BeuiButton(
              ripple: true,
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Text('Tap me'),
            ),
          ],
        ),
        const SizedBox(height: 40),

        // Section 2 — Stateful Button (stateful.tsx): a centred *column*, not
        // a row.
        caption('Stateful — idle → loading → success, morphing width'),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiStatefulButton(
              label: 'Save changes',
              icon: LucideIcons.arrow_right,
              state: _state,
              onPressed: _runLifecycle,
            ),
            const SizedBox(height: 12), // gap-3
            BeuiButton(
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Text('Submit'),
            ),
          ],
        ),
        const SizedBox(height: 40),

        // Section 3 — Magnetic Button (magnetic.tsx): one centred row at
        // `gap-4`, wider than the base preview's `gap-3`.
        caption('Magnetic — the button leans toward the cursor'),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            BeuiMagneticButton(
              onPressed: () {},
              child: _row(const [
                Text('Hover me'),
                Icon(LucideIcons.arrow_right),
              ]),
            ),
            BeuiMagneticButton(
              variant: BeuiButtonVariant.outline,
              strength: 0.15,
              onPressed: () {},
              child: const Text('Subtle pull'),
            ),
            BeuiMagneticButton(
              variant: BeuiButtonVariant.outline,
              strength: 0.4,
              onPressed: () {},
              child: const Text('Strong pull'),
            ),
          ],
        ),
      ],
    );
  }

  /// A min-width row with the source button's 8px gap between children.
  Widget _row(List<Widget> children) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        children[i],
      ],
    ],
  );
}
