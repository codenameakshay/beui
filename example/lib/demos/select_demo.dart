import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSelect] and [BeuiMorphSelect] — the page documents
/// both, so the route shows both. Content mirrors the source previews
/// (`select.preview.tsx` / `select-morph.preview.tsx`): a `w-56` select over the
/// four frameworks, seeded to `next`.
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
  String _morph = 'next';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 56),
        SizedBox(
          width: 224,
          child: BeuiMorphSelect(
            options: _frameworks,
            value: _morph,
            placeholder: 'Pick a framework',
            onChanged: (v) => setState(() => _morph = v),
          ),
        ),
      ],
    );
  }
}
