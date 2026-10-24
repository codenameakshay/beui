import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import '../../../../../example/lib/explorer/capture_probe.dart';
import '../../../../../example/lib/explorer/explorer_app.dart';

void main() => runApp(const EmptyFixture());

class EmptyFixture extends StatelessWidget {
  const EmptyFixture({super.key});

  @override
  Widget build(BuildContext context) {
    final dataCase = Uri.base.queryParameters['case'];
    final colors = BeuiColors.dark();
    final Widget chart = dataCase == 'composition'
        ? const BeuiCompositionChart(series: [], periods: [])
        : BeuiFunnelChart(
            stages: dataCase == 'invalid'
                ? const [
                    BeuiFunnelStage(id: 'invalid', label: 'Invalid', value: -1),
                  ]
                : const [],
          );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, Brightness.dark),
      home: Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: SizedBox(
            width: 752,
            child: SingleChildScrollView(
              child: CaptureProbe(
                enabled: true,
                background: colors.background,
                child: chart,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
