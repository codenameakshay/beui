import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery builder for [BeuiAdaptiveStepper].
Widget adaptiveStepperDemo(BuildContext context) =>
    const _AdaptiveStepperPreview();

/// Mirrors the source preview: two guests, with a range from zero to three.
class _AdaptiveStepperPreview extends StatefulWidget {
  const _AdaptiveStepperPreview();

  @override
  State<_AdaptiveStepperPreview> createState() =>
      _AdaptiveStepperPreviewState();
}

class _AdaptiveStepperPreviewState extends State<_AdaptiveStepperPreview> {
  double _guests = 2;

  @override
  Widget build(BuildContext context) => Center(
    child: BeuiAdaptiveStepper(
      value: _guests,
      min: 0,
      max: 3,
      semanticLabel: 'Guests',
      onChanged: (value) => setState(() => _guests = value),
      children: const [
        BeuiAdaptiveStepperDecrement(),
        BeuiAdaptiveStepperValue(),
        BeuiAdaptiveStepperIncrement(),
      ],
    ),
  );
}
