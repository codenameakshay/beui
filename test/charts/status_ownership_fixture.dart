// ignore_for_file: avoid_relative_lib_imports

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../example/lib/explorer/capture_probe.dart';
import '../../example/lib/explorer/explorer_app.dart' show beuiGalleryTheme;

const periods = [
  BeuiStatusBarDatum(
    id: 'a',
    label: 'Monday',
    status: 'operational',
    description: 'Monday detail',
  ),
  BeuiStatusBarDatum(
    id: 'b',
    label: 'Tuesday',
    status: 'degraded',
    description: 'Tuesday detail',
  ),
  BeuiStatusBarDatum(
    id: 'c',
    label: 'Wednesday',
    status: 'operational',
    description: 'Wednesday detail',
  ),
];

void main() {
  final brightness = Uri.base.queryParameters['theme'] == 'light'
      ? Brightness.light
      : Brightness.dark;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
      home: const _OwnershipFixture(),
    ),
  );
}

class _OwnershipFixture extends StatefulWidget {
  const _OwnershipFixture();
  @override
  State<_OwnershipFixture> createState() => _OwnershipFixtureState();
}

class _OwnershipFixtureState extends State<_OwnershipFixture> {
  bool included = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BeuiColors.resolve(context).background,
    body: Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final next = switch (event.logicalKey) {
          LogicalKeyboardKey.keyR => false,
          LogicalKeyboardKey.keyI => true,
          _ => null,
        };
        if (next == null) return KeyEventResult.ignored;
        setState(() => included = next);
        return KeyEventResult.handled;
      },
      child: Center(
        child: SizedBox(
          width: 480,
          child: CaptureProbe(
            enabled: true,
            background: BeuiColors.resolve(context).background,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Status identity ownership fixture'),
                const Text(
                  'Tab focuses Tuesday. R removes it. I reinserts it.',
                ),
                const Text('Focus stays on the native inspector throughout.'),
                const SizedBox(height: 120),
                BeuiStatusBar(
                  defaultActiveId: 'b',
                  data: included ? periods : [periods.first, periods.last],
                ),
                const SizedBox(height: 24),
                Text('Visible periods: ${included ? 'a b c' : 'a c'}'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
