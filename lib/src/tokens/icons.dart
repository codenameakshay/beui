/// Centralized Lucide icon source for beUI.
///
/// The library defaults to [flutter_lucide](https://pub.dev/packages/flutter_lucide)
/// (actively maintained, tracks Lucide 1.11+, all six platforms, MIT) to mirror
/// the source library's `lucide-react` glyphs. See docs/PORTING_SPEC.md §3.
///
/// This is the ONLY place the icon package is referenced directly — the same
/// discipline as the `motor` rule for motion tokens. Components take the
/// framework-native [IconData] / [Widget] types in their public API and use
/// `LucideIcons.*` only as internal default values, so swapping the icon
/// package later touches this file and the per-component defaults, never the
/// widget surface.
///
/// Re-exported through `package:beui/beui.dart`, so consumers get the default
/// glyphs without adding flutter_lucide themselves. This makes Lucide a
/// consumer-facing transitive dependency — see the package README.
library;

export 'package:flutter_lucide/flutter_lucide.dart' show LucideIcons;
