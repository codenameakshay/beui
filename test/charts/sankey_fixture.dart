// ignore_for_file: avoid_relative_lib_imports
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import '../../example/lib/demos/sankey_chart_demo.dart';
import '../../example/lib/explorer/capture_probe.dart';
import '../../example/lib/explorer/explorer_app.dart' show beuiGalleryTheme;

void main() {
  final brightness = Uri.base.queryParameters['theme'] == 'light'
      ? Brightness.light
      : Brightness.dark;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CaptureProbe(
                enabled: true,
                background: BeuiColors.resolve(context).background,
                child: const SankeyChartDemo(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
