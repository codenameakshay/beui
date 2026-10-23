// Isolated Voice Orb capture target. The full explorer catalog currently
// fails to compile on sibling Lucide glyph renames (`music`, `building_2`),
// so visual proof of this family uses the same gallery theme without
// importing those demos.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'demos/voice_orb_demo.dart';

void main() => runApp(const VoiceOrbPreviewApp());

/// Renders [voiceOrbDemo] with the gallery theme. Query: `theme=dark|light`.
class VoiceOrbPreviewApp extends StatelessWidget {
  /// Creates the preview app.
  const VoiceOrbPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Uri.base.queryParameters['theme'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final colorTheme = BeuiColorTheme.defaultMono;
    final colors = BeuiColors.of(colorTheme, brightness);
    final theme =
        BeuiTextTheme.trackingNormal(
          ThemeData(
            brightness: brightness,
            useMaterial3: true,
            fontFamily: 'Geist',
          ),
        ).copyWith(
          scaffoldBackgroundColor: colors.background,
          canvasColor: colors.background,
          extensions: [colors],
          splashFactory: NoSplash.splashFactory,
        );
    return MaterialApp(
      title: 'beUI Voice Orb',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: colors.background,
        body: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(child: Builder(builder: voiceOrbDemo)),
        ),
      ),
    );
  }
}
