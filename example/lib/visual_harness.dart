// Visual-pass harness: renders ONE catalog demo, with no explorer chrome, so a
// headless browser can capture it in isolation and diff it against the matching
// preview on beui.dev.
//
// This is tooling, not part of the gallery. `main.dart` remains the app.
//
//   flutter build web -t lib/visual_harness.dart --output build/visual
//   <serve build/visual>/?slug=switch&theme=dark
//
// Query parameters:
//   slug   — catalog slug to render (e.g. `switch`, `range-slider`). Required.
//   theme  — `dark` (default) or `light`.
//   color  — BeuiColorTheme name (default `defaultMono`, matching the site).
//   pad    — outer padding in logical px (default 48).
//
// An unknown slug renders a plain error card rather than throwing, so a bad
// capture shows up as an obviously-wrong frame instead of a blank page.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'explorer/catalog.dart';
import 'explorer/explorer_app.dart';

void main() => runApp(const VisualHarnessApp());

/// Renders a single demo named by the `slug` query parameter.
class VisualHarnessApp extends StatelessWidget {
  /// Creates the harness app.
  const VisualHarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final params = Uri.base.queryParameters;
    final slug = params['slug'] ?? '';
    final brightness = params['theme'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final colorTheme = BeuiColorTheme.values.firstWhere(
      (t) => t.name == (params['color'] ?? 'defaultMono'),
      orElse: () => BeuiColorTheme.defaultMono,
    );
    final pad = double.tryParse(params['pad'] ?? '') ?? 48;

    final colors = BeuiColors.of(colorTheme, brightness);
    final theme = beuiGalleryTheme(colorTheme, brightness);

    return MaterialApp(
      title: 'beUI visual harness',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: colors.background,
        body: Padding(
          padding: EdgeInsets.all(pad),
          child: Center(child: _Demo(slug: slug)),
        ),
      ),
    );
  }
}

class _Demo extends StatelessWidget {
  const _Demo({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    ExploreEntry? entry;
    for (final e in kAllEntries) {
      if (e.slug == slug) {
        entry = e;
        break;
      }
    }
    final builder = entry?.builder;
    if (builder == null) {
      return _Problem(
        slug.isEmpty
            ? 'No ?slug= given'
            : entry == null
            ? 'Unknown slug "$slug"'
            : 'Slug "$slug" has no demo builder',
      );
    }
    return builder(context);
  }
}

class _Problem extends StatelessWidget {
  const _Problem(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}
