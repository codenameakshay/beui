import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiBottomSheet] — a draggable sheet with two snap points
/// (half / almost-full). Drag the handle to move between them, fling down to
/// dismiss, or tap the scrim.
Widget bottomSheetDemo(BuildContext context) => const _BottomSheetDemo();

class _BottomSheetDemo extends StatefulWidget {
  const _BottomSheetDemo();

  @override
  State<_BottomSheetDemo> createState() => _BottomSheetDemoState();
}

class _BottomSheetDemoState extends State<_BottomSheetDemo> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Drag the handle between snap points, fling down to dismiss, '
              'or tap the backdrop.',
              style: TextStyle(fontSize: 14, color: colors.mutedForeground),
            ),
            const SizedBox(height: 20),
            BeuiButton(
              onPressed: () => setState(() => _open = true),
              child: const Text('Open bottom sheet'),
            ),
          ],
        ),
        BeuiBottomSheet(
          open: _open,
          onOpenChange: (v) => setState(() => _open = v),
          snapPoints: const [0.5, 0.92],
          title: 'Trip to the mountains',
          description: 'Pick the details for your weekend getaway.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (icon, label, sub) in const [
                (Icons.calendar_today, 'Dates', 'Fri 12 – Sun 14 July'),
                (Icons.group, 'Travellers', '2 adults, 1 child'),
                (Icons.hotel, 'Lodging', 'Alpine cabin, 2 nights'),
                (Icons.hiking, 'Activities', 'Trail hike, kayaking'),
                (Icons.restaurant, 'Dining', 'Half-board included'),
                (Icons.local_gas_station, 'Transport', 'Rental SUV, full tank'),
                (Icons.backpack, 'Packing', 'Layers, boots, sunscreen'),
                (Icons.paid, 'Budget', r'$1,240 estimated'),
              ])
                _Row(icon: icon, label: label, sub: sub, colors: colors),
              const SizedBox(height: 12),
              BeuiButton(
                onPressed: () => setState(() => _open = false),
                child: const Text('Confirm booking'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.sub,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String sub;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colors.foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(fontSize: 13, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
