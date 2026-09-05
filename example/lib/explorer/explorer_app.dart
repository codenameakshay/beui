// App root: owns the theme selection and builds the MaterialApp.
//
// The site is single-brightness at a time with a color-theme picker; this
// mirrors that. Both light and dark ThemeData carry the selected
// [BeuiColorTheme] so brightness toggles animate through MaterialApp's
// themeMode, and [ThemeScope] hands the controls to the top bar.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'shell.dart';
import 'theme_scope.dart';

/// Parse the gallery's launch URL into an [ExplorerRoute].
///
/// Supported query parameters (used by the live GitHub Pages gallery and by
/// screenshot captures):
///   `page=guides` — Motion Guides
///   `slug=<catalog-slug>` — a detail page (e.g. `chat-app`)
///   `section=components|blocks|agents` — a section index
ExplorerRoute explorerRouteFromUri(Uri uri) {
  final page = uri.queryParameters['page'];
  if (page == 'guides') return const GuidesRoute();

  final slug = uri.queryParameters['slug'];
  if (slug != null && slug.isNotEmpty) {
    for (final entry in kAllEntries) {
      if (entry.slug == slug) return DetailRoute(entry);
    }
  }

  return IndexRoute(switch (uri.queryParameters['section']) {
    'blocks' => ExploreSection.blocks,
    'agents' => ExploreSection.agents,
    _ => ExploreSection.components,
  });
}

Brightness explorerBrightnessFromUri(Uri uri) =>
    uri.queryParameters['theme'] == 'light'
    ? Brightness.light
    : Brightness.dark;

BeuiColorTheme explorerColorThemeFromUri(Uri uri) {
  final name = uri.queryParameters['color'];
  if (name == null || name.isEmpty) return BeuiColorTheme.defaultMono;
  return BeuiColorTheme.values.firstWhere(
    (t) => t.name == name || t.slug == name,
    orElse: () => BeuiColorTheme.defaultMono,
  );
}

/// The gallery's [ThemeData] for [colorTheme] at [brightness] — Geist,
/// tracking stripped to match the Tailwind source, and every [BeuiColors]
/// slot wired into Material's [ColorScheme]. Shared by the live gallery
/// ([BeuiExplorerApp]) and the visual-diff harness so both render identically.
ThemeData beuiGalleryTheme(BeuiColorTheme colorTheme, Brightness brightness) {
  final colors = BeuiColors.of(colorTheme, brightness);
  // Geist is the face beui.dev serves; the gallery renders in it so it reads
  // like the site. Bundled in `example/` only — see example/pubspec.yaml.
  // Material bakes a non-zero letterSpacing into every 2021 text style; the
  // Tailwind source leaves tracking at normal. Strip it so labels measure
  // like the site — see BeuiTextTheme.trackingNormal.
  final base = BeuiTextTheme.trackingNormal(
    ThemeData(brightness: brightness, useMaterial3: true, fontFamily: 'Geist'),
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

/// Entry widget — install with `runApp(const BeuiExplorerApp())`.
class BeuiExplorerApp extends StatefulWidget {
  const BeuiExplorerApp({super.key});

  @override
  State<BeuiExplorerApp> createState() => _BeuiExplorerAppState();
}

class _BeuiExplorerAppState extends State<BeuiExplorerApp> {
  late Brightness _brightness = explorerBrightnessFromUri(Uri.base);
  late BeuiColorTheme _colorTheme = explorerColorThemeFromUri(Uri.base);
  late final ExplorerRoute _initialRoute = explorerRouteFromUri(Uri.base);

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
        theme: beuiGalleryTheme(_colorTheme, Brightness.light),
        darkTheme: beuiGalleryTheme(_colorTheme, Brightness.dark),
        themeMode: _brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: ExplorerShell(initialRoute: _initialRoute),
      ),
    );
  }
}
