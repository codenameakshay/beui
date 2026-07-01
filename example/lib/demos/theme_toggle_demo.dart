import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiThemeToggle] / [BeuiThemeSwitcher].
///
/// Two ways to use the switcher:
///  * a **bounded** surface — the source's preview card, whose brightness flips
///    with a clip-path reveal confined to the card; and
///  * a **full-screen** page — the same switcher wrapping an entire route, so
///    the reveal spans the whole UI (wrap your `MaterialApp`'s home the same way
///    to re-theme a real app).
Widget themeToggleDemo(BuildContext context) => const _ThemeToggleDemo();

class _ThemeToggleDemo extends StatelessWidget {
  const _ThemeToggleDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bounded: the reveal is confined to the card the switcher wraps.
        Center(
          child: BeuiThemeSwitcher(
            initialBrightness: Brightness.dark,
            builder: (context, brightness) {
              final c = _Palette(brightness);
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 460,
                  height: 300,
                  decoration: BoxDecoration(
                    color: c.bg,
                    border: Border.all(color: c.border),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModeLabel(c),
                      const SizedBox(height: 8),
                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: c.fg,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap a toggle — the new theme wipes in from the bottom.',
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final v in BeuiThemeRevealVariant.values)
                            _ToggleChip(colors: c, variant: v),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const _FullScreenThemeDemo(),
              ),
            ),
            icon: const Icon(Icons.fullscreen),
            label: const Text('Toggle the whole screen'),
          ),
        ),
      ],
    );
  }
}

/// The switcher wrapping an entire route — toggling here re-themes the full UI,
/// exactly how you'd wrap a real app's home. The reveal spans the whole screen
/// because the switcher's [RepaintBoundary] wraps the full-bleed surface.
class _FullScreenThemeDemo extends StatelessWidget {
  const _FullScreenThemeDemo();

  @override
  Widget build(BuildContext context) {
    return BeuiThemeSwitcher(
      initialBrightness: Theme.of(context).brightness,
      builder: (context, brightness) {
        final c = _Palette(brightness);
        return Material(
          color: c.bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _ModeLabel(c),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: c.fg),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: c.fg,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'The whole screen re-themes with the reveal — the same '
                    'switcher, just wrapping an entire page instead of a card.',
                    style: TextStyle(fontSize: 16, height: 1.5, color: c.muted),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final v in BeuiThemeRevealVariant.values)
                        _ToggleChip(colors: c, variant: v, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Resolved theme-toggle demo colors for a brightness (source's zinc palette).
class _Palette {
  _Palette(Brightness brightness) : _dark = brightness == Brightness.dark;

  final bool _dark;

  Color get bg => _dark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF);
  Color get fg => _dark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
  Color get muted => _dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
  Color get border => _dark ? const Color(0x14FFFFFF) : const Color(0x12000000);
  Color get chip => _dark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
  String get name => _dark ? 'DARK' : 'LIGHT';
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel(this.colors);

  final _Palette colors;

  @override
  Widget build(BuildContext context) => Text(
    colors.name,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.5,
      color: colors.muted,
    ),
  );
}

/// A labelled theme-toggle button in a themed chip.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.colors,
    required this.variant,
    this.size = 20,
  });

  final _Palette colors;
  final BeuiThemeRevealVariant variant;
  final double size;

  static const _labels = {
    BeuiThemeRevealVariant.rectangle: 'Rectangle',
    BeuiThemeRevealVariant.circle: 'Circle',
    BeuiThemeRevealVariant.circleBlur: 'Circle blur',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.chip,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: BeuiThemeToggle(
              variant: variant,
              start: BeuiThemeRevealStart.bottomUp,
              size: size,
              color: colors.fg,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _labels[variant]!,
          style: TextStyle(fontSize: 11, color: colors.muted),
        ),
      ],
    );
  }
}
