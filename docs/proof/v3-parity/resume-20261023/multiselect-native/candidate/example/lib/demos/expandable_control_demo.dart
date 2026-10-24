import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiExpandableButton] and [BeuiExpandableChip].
Widget expandableControlDemo(BuildContext context) =>
    const ExpandableControlPreview();

/// The source preview: a Notifications button and removable React chip.
class ExpandableControlPreview extends StatelessWidget {
  /// Creates the expandable-control preview.
  const ExpandableControlPreview({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      BeuiExpandableButton(
        icon: Icon(LucideIcons.bell),
        label: Text('Notifications'),
      ),
      SizedBox(height: 24),
      BeuiExpandableChip(
        label: Text('React'),
        actionIcon: Icon(LucideIcons.x),
        actionLabel: 'Remove React',
      ),
    ],
  );
}
