// App root: owns the theme selection and builds the MaterialApp.
//
// The site is single-brightness at a time with a color-theme picker; this
// mirrors that. Both light and dark ThemeData carry the selected
// [BeuiColorTheme] so brightness toggles animate through MaterialApp's
// themeMode, and [ThemeScope] hands the controls to the top bar.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'shell.dart';
import 'theme_scope.dart';

/// Entry widget — install with `runApp(const BeuiExplorerApp())`.
class BeuiExplorerApp extends StatefulWidget {
  const BeuiExplorerApp({super.key});

  @override
  State<BeuiExplorerApp> createState() => _BeuiExplorerAppState();
}

class _BeuiExplorerAppState extends State<BeuiExplorerApp> {
  Brightness _brightness = Brightness.dark;
  BeuiColorTheme _colorTheme = BeuiColorTheme.defaultMono;

  ThemeData _themeData(Brightness brightness) {
    final colors = BeuiColors.of(_colorTheme, brightness);
    // Geist is the face beui.dev serves; the gallery renders in it so it reads
    // like the site. Bundled in `example/` only — see example/pubspec.yaml.
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Geist',
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      extensions: [colors],
      colorScheme: base.colorScheme.copyWith(
        surface: colors.background,
        primary: colors.primary,
        onPrimary: colors.primaryForeground,
        secondary: colors.secondary,
        onSurface: colors.foreground,
        outline: colors.border,
        error: colors.destructive,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.foreground,
        selectionColor: colors.primary.withValues(alpha: 0.24),
        selectionHandleColor: colors.primary,
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      brightness: _brightness,
      colorTheme: _colorTheme,
      setBrightness: (b) => setState(() => _brightness = b),
      setColorTheme: (t) => setState(() => _colorTheme = t),
      child: MaterialApp(
        title: 'beUI',
        debugShowCheckedModeBanner: false,
        theme: _themeData(Brightness.light),
        darkTheme: _themeData(Brightness.dark),
        themeMode: _brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const ExplorerShell(),
      ),
    );
  }
}
