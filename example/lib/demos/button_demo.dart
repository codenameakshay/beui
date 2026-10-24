import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiMetallicButton], [BeuiButton], [BeuiStatefulButton]
/// and [BeuiMagneticButton].
Widget buttonDemo(BuildContext context, {String? example}) =>
    _ButtonDemo(example: example ?? Uri.base.queryParameters['example']);

/// The four pinned-source previews, optionally selected independently.
class _ButtonDemo extends StatefulWidget {
  const _ButtonDemo({this.example});

  final String? example;

  @override
  State<_ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<_ButtonDemo> {
  BeuiButtonState _okState = BeuiButtonState.idle;
  BeuiButtonState _errorState = BeuiButtonState.idle;

  Future<void> _runLifecycle({required bool succeeds}) async {
    void update(BeuiButtonState state) => setState(() {
      if (succeeds) {
        _okState = state;
      } else {
        _errorState = state;
      }
    });

    update(BeuiButtonState.loading);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    update(succeeds ? BeuiButtonState.success : BeuiButtonState.error);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) update(BeuiButtonState.idle);
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
        if (widget.example == null || widget.example == 'metallic') ...[
          if (widget.example == null)
            caption('Metallic — chrome rim with a traveling reflection'),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BeuiMetallicButton(
                onPressed: () {},
                child: _row(const [
                  Text('Continue'),
                  Icon(LucideIcons.arrow_up_right),
                ]),
              ),
              BeuiMetallicButton(
                size: BeuiButtonSize.sm,
                onPressed: () {},
                child: _row(const [
                  Icon(LucideIcons.sparkles, size: 14),
                  Text('Generate'),
                ]),
              ),
              BeuiMetallicButton(
                size: BeuiButtonSize.icon,
                onPressed: () {},
                child: Semantics(
                  label: 'Magic tools',
                  child: const Icon(LucideIcons.sparkles),
                ),
              ),
            ],
          ),
          if (widget.example == null) const SizedBox(height: 40),
        ],

        // Section 2 — Button (base.tsx).
        if (widget.example == null || widget.example == 'base') ...[
          if (widget.example == null)
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
                child: _row(const [
                  Icon(LucideIcons.download),
                  Text('Download'),
                ]),
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
                variant: BeuiButtonVariant.secondary,
                onPressed: () {},
                child: Semantics(
                  label: 'Delete',
                  child: const Icon(LucideIcons.trash),
                ),
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
          if (widget.example == null) const SizedBox(height: 40),
        ],

        // Section 2 — Stateful Button (stateful.tsx): a centred *column*, not
        // a row.
        if (widget.example == null || widget.example == 'stateful') ...[
          if (widget.example == null)
            caption('Stateful — idle → loading → success, morphing width'),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiStatefulButton(
                label: 'Save changes',
                loadingText: 'Saving',
                successText: 'Saved',
                icon: LucideIcons.arrow_right,
                state: _okState,
                onPressed: () => _runLifecycle(succeeds: true),
              ),
              const SizedBox(height: 12), // gap-3
              BeuiStatefulButton(
                label: 'Submit',
                loadingText: 'Submitting',
                errorText: 'Failed',
                state: _errorState,
                variant: BeuiButtonVariant.secondary,
                onPressed: () => _runLifecycle(succeeds: false),
              ),
            ],
          ),
          if (widget.example == null) const SizedBox(height: 40),
        ],

        // Section 3 — Magnetic Button (magnetic.tsx): one centred row at
        // `gap-4`, wider than the base preview's `gap-3`.
        if (widget.example == null || widget.example == 'magnetic') ...[
          if (widget.example == null)
            caption('Magnetic — the button leans toward the cursor'),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              BeuiMagneticButton(
                strength: 0.35,
                onPressed: () {},
                child: _row(const [
                  Text('Hover me'),
                  Icon(LucideIcons.arrow_right),
                ]),
              ),
              BeuiMagneticButton(
                variant: BeuiButtonVariant.secondary,
                strength: 0.25,
                onPressed: () {},
                child: const Text('Subtle pull'),
              ),
              BeuiMagneticButton(
                variant: BeuiButtonVariant.outline,
                strength: 0.5,
                onPressed: () {},
                child: const Text('Strong pull'),
              ),
            ],
          ),
        ],
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
