import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiSelect], mirroring the source `select.preview.tsx`
/// exactly: a single `w-56` (224) select over the four frameworks, seeded to
/// `next`, with the `Pick a framework` placeholder.
///
/// The source preview — and the whole `motion/select` registry entry — ships
/// one select and nothing else, so that's the first section below. A second
/// section adds [BeuiMorphSelect], which has no counterpart on beui.dev, so
/// the gallery is the only place it gets a live preview.
Widget selectDemo(BuildContext context) => const _SelectDemo();

const _frameworks = <BeuiSelectOption>[
  BeuiSelectOption(value: 'next', label: 'Next.js'),
  BeuiSelectOption(value: 'remix', label: 'Remix'),
  BeuiSelectOption(value: 'astro', label: 'Astro'),
  BeuiSelectOption(value: 'vite', label: 'Vite'),
];

class _SelectDemo extends StatefulWidget {
  const _SelectDemo();

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

class _SelectDemoState extends State<_SelectDemo> {
  String _value = 'next';
  String? _morphValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          // Source preview wrapper: `w-56` (224).
          width: 224,
          child: BeuiSelect(
            options: _frameworks,
            value: _value,
            placeholder: 'Pick a framework',
            onChanged: (v) => setState(() => _value = v),
          ),
        ),
        const SizedBox(height: 40),
        const SectionLabel('Morph — panel unfolds from the trigger'),
        const SizedBox(height: 16),
        SizedBox(
          width: 224,
          child: BeuiMorphSelect(
            options: _frameworks,
            value: _morphValue,
            placeholder: 'Pick a framework',
            onChanged: (v) => setState(() => _morphValue = v),
          ),
        ),
      ],
    );
  }
}
