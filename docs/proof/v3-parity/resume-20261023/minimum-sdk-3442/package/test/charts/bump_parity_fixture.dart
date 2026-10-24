// ignore_for_file: avoid_relative_lib_imports

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../example/lib/explorer/capture_probe.dart';
import '../../example/lib/explorer/explorer_app.dart' show beuiGalleryTheme;

const _ranks = [
  [4, 3, 2, 3, 2, 1],
  [1, 1, 3, 2, 1, 2],
  [3, 2, 1, 1, 3, 3],
  [2, 4, 5, 4, 5, 4],
  [5, 5, 4, 5, 4, 5],
];
const _names = ['Studio', 'Canvas', 'Layers', 'Orbit', 'Frame'];
const _colors = ['#8b5cf6', '#0d9488', '#f59e0b', '#3b82f6', '#f43f5e'];

void main() => runApp(const _Fixture());

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  bool updated = false;
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_key);
  }

  bool _key(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyU) {
      setState(() => updated = !updated);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = Uri.base.queryParameters;
    final variant = params['variant'] ?? 'default';
    final brightness = params['theme'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final colors = BeuiColors.of(BeuiColorTheme.defaultMono, brightness);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
      home: Scaffold(
        backgroundColor: colors.background,
        body: Focus(
          canRequestFocus: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: SizedBox(
                width: variant == 'narrow' ? 320 : 592,
                child: CaptureProbe(
                  enabled: true,
                  background: colors.background,
                  child: BeuiBumpChart(
                    label: 'Product rankings',
                    periods: const ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
                    series: variant == 'empty'
                        ? const []
                        : [
                            for (var i = 0; i < _names.length; i++)
                              BeuiBumpSeries(
                                id: _names[i].toLowerCase(),
                                name: _names[i],
                                ranks: variant == 'missing'
                                    ? const []
                                    : updated
                                    ? _ranks[i].reversed.toList()
                                    : _ranks[i],
                                color: _colors[i],
                              ),
                          ],
                    child: variant == 'composed'
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BeuiBumpPlot(),
                              SizedBox(height: 20),
                              BeuiBumpLegend(),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
