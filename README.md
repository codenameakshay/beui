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

## License

MIT
