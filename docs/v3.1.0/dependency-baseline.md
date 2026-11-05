# v3.1.0 dependency baseline

The `flutter_lucide` upper bound is exclusive at `1.64.0`. An initial check of
alert glyphs alone suggested `1.67.0` was compatible: its published archive
contains `LucideIcons.triangle_alert` and `LucideIcons.circle_alert`, while
`1.68.0` removes both. Exact-SDK analysis then exposed a second unchanged
example dependency: `LucideIcons.bold` at
`example/lib/demos/tooltip_demo.dart:65` is present through `1.63.0` but absent
from `1.64.0` onward. The published `1.63.0` archive retains all three used
identifiers, making it the narrowest compatible resolution for the untouched
root and example. The package's lower bound remains `1.41.0`.

To reproduce the archive check, download the `1.63.0`, `1.64.0`, `1.67.0`, and `1.68.0`
archives from `https://pub.dev/api/archives/flutter_lucide-<version>.tar.gz`,
then search `lib/src/flutter_lucide.dart` for `bold`, `triangle_alert`, and
`circle_alert`. The compatibility boundary is set by `bold` disappearing in
`1.64.0`; the alert glyphs disappear in `1.68.0`.

Resolution and compilation proof for this baseline uses Flutter/Dart 3.44.4.
The root and example `pubspec.lock` files are gitignored local artifacts, not
release pins; preserve them with the build provenance when reproducing the
shared immutable baseline. Do not rename/replace glyphs in widgets to bypass
this dependency boundary.
