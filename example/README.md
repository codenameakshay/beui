# beUI example — component explorer

A Flutter gallery that mirrors [beui.dev](https://beui.dev): a sidebar, a card
grid, and a detail page per component with live **Preview / Usage / Code** tabs,
plus a Motion Guides page. Each Preview renders the real ported widget, so the
app doubles as the living showcase and the render target for golden tests.

**Live demo:** <https://codenameakshay.github.io/beui/>

Deep links (also used to recapture README screenshots):

* `?section=components|blocks|agents`
* `?slug=chat-app` (any catalog slug)
* `?page=guides`
* `?theme=light|dark` and `?color=violet` (or any `BeuiColorTheme` slug)

## Run it

```bash
cd example
flutter pub get
flutter run          # or: flutter run -d chrome | macos | ios | android
```

## Minimal usage

Register the `BeuiColors` theme extension on your `ThemeData`, then drop in any
`Beui*` widget:

```dart
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.of(BeuiColorTheme.violet, Brightness.dark);
    return MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: [colors]),
      home: const Scaffold(body: Center(child: WifiToggle())),
    );
  }
}

class WifiToggle extends StatefulWidget {
  const WifiToggle({super.key});

  @override
  State<WifiToggle> createState() => _WifiToggleState();
}

class _WifiToggleState extends State<WifiToggle> {
  bool on = true;

  @override
  Widget build(BuildContext context) => BeuiSwitch(
    value: on,
    label: const Text('Wi-Fi'),
    onChanged: (value) => setState(() => on = value),
  );
}
```

## Where to look

* [`lib/demos/`](lib/demos) — a runnable demo for every component in the catalog.
* [`lib/explorer/`](lib/explorer) — the gallery chrome (sidebar, cards, detail
  pages, Motion Guides).
* The package [README](../README.md) — the full component catalog, theming, and
  the motion-token system.
