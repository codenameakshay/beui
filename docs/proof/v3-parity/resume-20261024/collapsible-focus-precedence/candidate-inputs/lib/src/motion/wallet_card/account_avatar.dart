import 'package:flutter/widgets.dart';

import '_types.dart';

/// The account glyph shown in the switcher trigger and rows — the Flutter port
/// of the source's `AccountAvatar`.
///
/// **Deliberate deviation:** the source renders a remote DiceBear "glass" SVG
/// (`https://api.dicebear.com/9.x/glass/svg?seed=…`). The Flutter package ships
/// no assets and must render offline (and golden-stably in tests), so when no
/// custom [BeuiWalletAccount.avatar] is supplied this paints a deterministic
/// two-tone gradient disc seeded from the account id/address — the same
/// "frosted glass" read, generated locally. Pass a custom `avatar` widget to
/// override.
class BeuiAccountAvatar extends StatelessWidget {
  /// Creates an avatar for [account].
  const BeuiAccountAvatar({required this.account, this.size = 28, super.key});

  /// The account to render.
  final BeuiWalletAccount account;

  /// Diameter in logical pixels (source `h-7 w-7` = 28).
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = account.avatar;
    if (avatar != null) {
      return SizedBox(width: size, height: size, child: avatar);
    }

    final seed = account.id.isNotEmpty ? account.id : account.address;
    final (a, b, angle) = _paletteFor(seed);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [a, b],
          begin: Alignment(-angle, -1),
          end: Alignment(angle, 1),
        ),
      ),
    );
  }

  /// Deterministic FNV-1a hash → two hues + a gradient tilt. Stable per seed so
  /// the avatar never changes between renders (or golden runs).
  static (Color, Color, double) _paletteFor(String seed) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < seed.length; i++) {
      hash ^= seed.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final h1 = (hash % 360).toDouble();
    final h2 = ((hash >> 8) % 360).toDouble();
    final tilt = ((hash >> 16) % 100) / 100 * 2 - 1;
    return (
      HSLColor.fromAHSL(1, h1, 0.62, 0.62).toColor(),
      HSLColor.fromAHSL(1, h2, 0.58, 0.5).toColor(),
      tilt,
    );
  }
}
