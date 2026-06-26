# beUI

Motion components for Flutter — a one-to-one port of [beUI v2](https://beui.dev) (`starc007/ui-components`).

Spring-physics UI primitives and composed widgets, built on the [`motor`](https://pub.dev/packages/motor) motion engine so the original's exact spring feel carries over.

> Status: early scaffolding. Components are being ported per the catalog in [`docs/PORTING_SPEC.md`](docs/PORTING_SPEC.md). Not yet published to pub.dev.

## Install

Once published:

```yaml
dependencies:
  beui: ^0.0.1
```

```dart
import 'package:beui/beui.dart';
```

## Develop

Uses FVM (pinned to Flutter stable in `.fvmrc`).

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
cd example && fvm flutter run   # the component gallery
```

See [`CLAUDE.md`](CLAUDE.md) for architecture and conventions, and [`docs/PORTING_SPEC.md`](docs/PORTING_SPEC.md) for the full component catalog and the motion-token mapping.

## Icons

beUI re-exports the [`flutter_lucide`](https://pub.dev/packages/flutter_lucide) icon set (the Flutter equivalent of the source's `lucide-react` glyphs), so the default icons in components like badges, toasts, and the command palette work out of the box.

> **Transitive dependency:** adding `beui` pulls in the Lucide icon font whether or not you use a defaulted icon — its bundle weight and version come along. Icon props accept the framework-native `IconData` (any glyph) or `Widget` (custom content), so you can override every default without depending on Lucide directly.

## Credits

A Flutter port of **beUI** by **Saurabh Chauhan** — [beui.dev](https://beui.dev) (`starc007/ui-components`). All component designs and the original motion work are his; this package brings them to Flutter.

## License

MIT — see [`LICENSE`](LICENSE). Both the upstream copyright (Saurabh Chauhan) and the port's copyright are preserved, as the MIT license requires for derivative works.
