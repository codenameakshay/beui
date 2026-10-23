import 'package:flutter/widgets.dart';

import '../../theme/beui_colors.dart';

/// Color pairing of a chain badge — the port of the source's Tailwind `tone`
/// class strings, resolved against [BeuiColors].
enum BeuiChainTone {
  /// `bg-primary text-primary-foreground`.
  primary,

  /// `bg-secondary text-secondary-foreground`.
  secondary,

  /// `bg-accent text-accent-foreground`.
  accent,

  /// `bg-muted text-muted-foreground`.
  muted,

  /// `bg-destructive text-primary-foreground`.
  destructive,

  /// `bg-primary/80 text-primary-foreground`.
  primarySoft,

  /// `bg-destructive/80 text-primary-foreground`.
  destructiveSoft;

  /// Resolves the badge colors from the theme.
  ({Color background, Color foreground}) resolve(BeuiColors c) {
    switch (this) {
      case BeuiChainTone.primary:
        return (background: c.primary, foreground: c.primaryForeground);
      case BeuiChainTone.secondary:
        return (background: c.secondary, foreground: c.secondaryForeground);
      case BeuiChainTone.accent:
        return (background: c.accent, foreground: c.accentForeground);
      case BeuiChainTone.muted:
        return (background: c.muted, foreground: c.mutedForeground);
      case BeuiChainTone.destructive:
        return (background: c.destructive, foreground: c.primaryForeground);
      case BeuiChainTone.primarySoft:
        return (
          background: c.primary.withValues(alpha: 0.8),
          foreground: c.primaryForeground,
        );
      case BeuiChainTone.destructiveSoft:
        return (
          background: c.destructive.withValues(alpha: 0.8),
          foreground: c.primaryForeground,
        );
    }
  }
}

/// A chain in a [BeuiMultiChainSwap] (source `Chain`).
@immutable
class BeuiChain {
  /// Creates a chain.
  const BeuiChain({
    required this.id,
    required this.name,
    required this.symbol,
    this.tone = BeuiChainTone.primary,
  });

  /// Stable identity.
  final String id;

  /// Display name.
  final String name;

  /// Single-glyph badge (e.g. `Ξ`).
  final String symbol;

  /// Badge color pairing.
  final BeuiChainTone tone;
}

/// A token in a [BeuiMultiChainSwap] (source `Token`).
@immutable
class BeuiToken {
  /// Creates a token.
  const BeuiToken({
    required this.id,
    required this.symbol,
    required this.name,
    required this.chainId,
    this.address,
    this.balance,
    this.usd,
    this.trending = false,
    this.popular = false,
  });

  /// Stable identity.
  final String id;

  /// Ticker symbol.
  final String symbol;

  /// Display name.
  final String name;

  /// Owning chain id.
  final String chainId;

  /// Truncated contract address, shown in list rows.
  final String? address;

  /// Wallet balance.
  final double? balance;

  /// USD price (drives the demo quote rate).
  final double? usd;

  /// Shown in the trending section.
  final bool trending;

  /// Shown in the popular row.
  final bool popular;
}

/// Which side of the swap a picker targets (source `TokenSide`).
enum BeuiTokenSide {
  /// The pay side.
  from,

  /// The receive side.
  to,
}
