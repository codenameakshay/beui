import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/catalog.dart';
import '../explorer/explorer_app.dart';
import 'agents_capture_probe.dart';

/// Capture-only entrypoint. Reports actual constraints and effective motion.
void main() => runApp(const AgentsCaptureApp());

/// Opt-in capture palette from source `a76e57c9`'s full default token set.
/// The mono base already matches its non-primary tokens at 8-bit precision.
ThemeData agentsCaptureTheme(Brightness brightness, {String? palette}) {
  final base = beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness);
  if (palette != 'source-default-a76e57c9') return base;
  final colors = base.extension<BeuiColors>()!.copyWith(
    primary: const Color(0xFF0285F7),
    primaryForeground: Colors.white,
  );
  return base.copyWith(
    extensions: [colors],
    colorScheme: base.colorScheme.copyWith(
      primary: colors.primary,
      onPrimary: colors.primaryForeground,
    ),
    textSelectionTheme: base.textSelectionTheme.copyWith(
      selectionHandleColor: colors.primary,
      selectionColor: colors.accent.withValues(alpha: 0.3),
    ),
  );
}

class AgentsCaptureApp extends StatelessWidget {
  const AgentsCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    final params = Uri.base.queryParameters;
    final brightness = params['theme'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final palette = params['palette'];
    final theme = agentsCaptureTheme(brightness, palette: palette);
    final paletteLabel = palette == 'source-default-a76e57c9'
        ? palette!
        : 'defaultMono';
    final entry = kAllEntries.firstWhere(
      (entry) => entry.slug == params['slug'],
    );
    final width =
        double.tryParse(params['previewWidth'] ?? params['stageWidth'] ?? '') ??
        752;
    final background = brightness == Brightness.light
        ? const Color(0xFFFCFCFC)
        : const Color(0xFF151515);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: background,
        body: Builder(
          builder: (context) {
            return Center(
              child: SizedBox(
                width: width,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final reduced = MediaQuery.disableAnimationsOf(context);
                    return Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label:
                          'Capture stage width ${constraints.maxWidth} height ${constraints.maxHeight} reduced $reduced palette $paletteLabel',
                      child: params['captureProbe'] == '1'
                          ? AgentsCaptureProbe(
                              background: background,
                              child: entry.builder(context),
                            )
                          : entry.builder(context),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
