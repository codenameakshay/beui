import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSelect], mirroring the source `select.preview.tsx`
/// exactly: a single `w-56` (224) select over the four frameworks, seeded to
/// `next`, with the `Pick a framework` placeholder.
///
/// The source preview — and the whole `motion/select` registry entry — ships
/// one select and nothing else, so this route shows one. (`BeuiMorphSelect`
/// has no counterpart on beui.dev; it is not part of this preview.)
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Source preview wrapper: `w-56` (224).
      width: 224,
      child: BeuiSelect(
        options: _frameworks,
        value: _value,
        placeholder: 'Pick a framework',
        onChanged: (v) => setState(() => _value = v),
      ),
    );
  }
}
