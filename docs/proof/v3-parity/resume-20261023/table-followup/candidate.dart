import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

// ignore_for_file: avoid_relative_lib_imports

import '../../../../../example/lib/demos/button_demo.dart';
import '../../../../../example/lib/demos/range_slider_demo.dart';
import '../../../../../example/lib/demos/table_demo.dart';
import '../../../../../example/lib/explorer/capture_probe.dart';
import '../../../../../example/lib/explorer/explorer_app.dart';

void main() {
  final theme = Uri.base.queryParameters['theme'] == 'dark'
      ? Brightness.dark
      : Brightness.light;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: beuiGalleryTheme(BeuiColorTheme.blue, theme),
      home: Builder(
        builder: (context) {
          final example = Uri.base.queryParameters['example'] ?? 'metallic';
          final demo = switch (example) {
            'metallic' ||
            'base' ||
            'stateful' ||
            'magnetic' => buttonDemo(context, example: example),
            'data' ||
            'editable' ||
            'editable-recovery' ||
            'async' => tableDemo(context, example: example),
            _ => rangeSliderDemo(context, example: example),
          };
          return Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 592,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 360),
                    child: Center(
                      child: CaptureProbe(
                        enabled: true,
                        background: BeuiColors.resolve(context).background,
                        child: demo,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
