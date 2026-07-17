// Theme plumbing + layout constants for the explorer shell.
//
// [ThemeScope] exposes the current brightness / color-theme and setters to the
// whole tree so the top-bar controls can drive the app's palette. Layout
// constants keep the chrome dimensions in one place.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Shell layout constants (mirroring the source's docs chrome proportions).
abstract final class ExplorerMetrics {
  /// Height of the fixed top navigation bar.
  static const double topBar = 60;

  /// Width of the left navigation sidebar (desktop).
  static const double sidebar = 264;

  /// Width of the right "On this page" rail (wide desktop only).
  static const double onThisPage = 240;

  /// Max width of the centered content column.
  static const double content = 1120;

  /// Below this width the sidebar collapses into a drawer.
  static const double sidebarBreakpoint = 1000;

  /// Below this width the "On this page" rail is hidden.
  static const double onThisPageBreakpoint = 1360;
}

/// The teal "NEW" accent used across badges, resolved for [brightness].
Color newAccent(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF5EEAD4)
    : const Color(0xFF0D9488);

/// Inherited holder for the app-wide theme selection.
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.brightness,
    required this.colorTheme,
    required this.setBrightness,
    required this.setColorTheme,
    required super.child,
  });

  final Brightness brightness;
  final BeuiColorTheme colorTheme;
  final ValueChanged<Brightness> setBrightness;
  final ValueChanged<BeuiColorTheme> setColorTheme;

  void toggleBrightness() => setBrightness(
    brightness == Brightness.dark ? Brightness.light : Brightness.dark,
  );

  static ThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeScope old) =>
      brightness != old.brightness || colorTheme != old.colorTheme;
}
