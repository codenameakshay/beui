import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery preview for [BeuiColorSelector].
Widget colorSelectorDemo(BuildContext context) => const _ColorSelectorPreview();

class _ColorSelectorPreview extends StatefulWidget {
  const _ColorSelectorPreview();
  @override
  State<_ColorSelectorPreview> createState() => _ColorSelectorPreviewState();
}

class _ColorSelectorPreviewState extends State<_ColorSelectorPreview> {
  String _value = 'blue';

  @override
  Widget build(BuildContext context) => BeuiColorSelector(
    value: _value,
    name: 'accent',
    onChanged: (value) => setState(() => _value = value),
    children: const [
      BeuiColorSelectorLabel(child: Text('Accent')),
      BeuiColorSelectorList(
        children: [
          BeuiColorSelectorItem(
            value: 'blue',
            color: Color(0xff3478f6),
            label: 'Blue',
          ),
          BeuiColorSelectorItem(
            value: 'purple',
            color: Color(0xff9270e8),
            label: 'Purple',
          ),
          BeuiColorSelectorItem(
            value: 'pink',
            color: Color(0xffe66aa4),
            label: 'Pink',
          ),
          BeuiColorSelectorItem(
            value: 'red',
            color: Color(0xffe55656),
            label: 'Red',
          ),
          BeuiColorSelectorItem(
            value: 'orange',
            color: Color(0xffed9141),
            label: 'Orange',
          ),
          BeuiColorSelectorItem(
            value: 'amber',
            color: Color(0xffe5b63c),
            label: 'Amber',
          ),
          BeuiColorSelectorItem(
            value: 'green',
            color: Color(0xff65a65a),
            label: 'Green',
          ),
          BeuiColorSelectorItem(
            value: 'teal',
            color: Color(0xff169d83),
            label: 'Teal',
          ),
        ],
      ),
    ],
  );
}
