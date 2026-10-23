import 'package:flutter/widgets.dart';

/// A single wallet account shown in the [BeuiWalletCard] account switcher — the
/// Flutter port of the source's `WalletAccount` type (`types.ts`).
@immutable
class BeuiWalletAccount {
  /// Creates a wallet account.
  const BeuiWalletAccount({
    required this.id,
    required this.name,
    required this.address,
    this.avatar,
  });

  /// Stable identity used to key selection and the generated avatar seed.
  final String id;

  /// Human-readable label (e.g. `Main Wallet`).
  final String name;

  /// The on-chain address; truncated in the switcher rows.
  final String address;

  /// Optional custom avatar. When null a deterministic gradient avatar is
  /// generated from [id]/[address] — the offline analogue of the source's
  /// remote DiceBear "glass" SVG (`account-avatar.tsx`).
  final Widget? avatar;
}
