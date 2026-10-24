import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiBottomSheet] — mirrors the source
/// `bottom-sheet.preview.tsx`: a pill trigger, snap points `[0.4, 0.85]`, the
/// "Quick actions" list, and the fling hint below it.
Widget bottomSheetDemo(BuildContext context) => const _BottomSheetDemo();

class _BottomSheetDemo extends StatefulWidget {
  const _BottomSheetDemo();

  @override
  State<_BottomSheetDemo> createState() => _BottomSheetDemoState();
}

class _BottomSheetDemoState extends State<_BottomSheetDemo> {
  bool _open = false;

  static const _actions = [
    'Share',
    'Duplicate',
    'Move to folder',
    'Rename',
    'Archive',
    'Delete',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Stack(
      children: [
        Center(
          child: BeuiButton(
            // Source trigger: h-10 rounded-full border bg-card px-5 text-sm.
            variant: BeuiButtonVariant.secondary,
            onPressed: () => setState(() => _open = true),
            child: const Text('Open bottom sheet'),
          ),
        ),
        BeuiBottomSheet(
          open: _open,
          onOpenChange: (v) => setState(() => _open = v),
          snapPoints: const [0.4, 0.85],
          title: 'Quick actions',
          description: 'Drag the handle, fling, or swipe down to dismiss.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Source: <ul className="divide-y divide-border"> with py-3 rows.
              for (final (i, action) in _actions.indexed) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: colors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    action,
                    style: TextStyle(fontSize: 14, color: colors.foreground),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48), // py-12
                child: Text(
                  'Fling up to expand, fling down to dismiss.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
